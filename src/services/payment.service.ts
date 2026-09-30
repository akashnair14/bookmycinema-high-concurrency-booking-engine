import { pool } from '../config/db';
import { SeatLockService } from './seatLock.service';
import { RowDataPacket } from 'mysql2';

export interface PaymentWebhookPayload {
  idempotencyKey: string;
  bookingId: number;
  gatewayTransactionId: string;
  paymentGateway: 'RAZORPAY' | 'STRIPE' | 'PAYTM' | 'UPI';
  amount: number;
  paymentStatus: 'SUCCESS' | 'FAILED';
  rawResponse?: any;
}

export class PaymentService {
  /**
   * Process payment webhook idempotently:
   * Prevents duplicate charging, duplicate status updates, and race conditions.
   */
  static async processWebhook(payload: PaymentWebhookPayload): Promise<{
    status: 'PROCESSED' | 'DUPLICATE_IGNORED' | 'FAILED';
    message: string;
  }> {
    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      // Check if this idempotency key was already processed
      const [existingPayments] = await connection.query<RowDataPacket[]>(
        `SELECT id, payment_status FROM payments WHERE idempotency_key = ?`,
        [payload.idempotencyKey]
      );

      if (existingPayments.length > 0) {
        await connection.commit();
        return {
          status: 'DUPLICATE_IGNORED',
          message: `Webhook with key ${payload.idempotencyKey} has already been processed.`,
        };
      }

      // Attempt to record payment atomically.
      // Under high concurrency, two identical webhook calls might pass any prior SELECT check.
      // We rely on the UNIQUE uq_idempotency_key constraint for atomic deduplication.
      let isDuplicate = false;
      try {
        await connection.query(
          `INSERT INTO payments (
            booking_id, idempotency_key, gateway_transaction_id, payment_gateway, amount, payment_status, raw_response
          ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [
            payload.bookingId,
            payload.idempotencyKey,
            payload.gatewayTransactionId,
            payload.paymentGateway,
            payload.amount,
            payload.paymentStatus,
            JSON.stringify(payload.rawResponse || {}),
          ]
        );
      } catch (err: any) {
        if (err.code === 'ER_DUP_ENTRY' || err.message?.includes('Duplicate entry')) {
          isDuplicate = true;
        } else {
          throw err;
        }
      }

      if (isDuplicate) {
        await connection.commit();
        return {
          status: 'DUPLICATE_IGNORED',
          message: `Webhook with key ${payload.idempotencyKey} has already been processed.`,
        };
      }

      if (payload.paymentStatus === 'SUCCESS') {
        // Fetch booking with lock
        const [bookings] = await connection.query<RowDataPacket[]>(
          `SELECT id, show_id, user_id, booking_status, expires_at FROM bookings WHERE id = ? FOR UPDATE`,
          [payload.bookingId]
        );

        if (bookings.length === 0) {
          throw new Error(`Booking ${payload.bookingId} not found.`);
        }

        const booking = bookings[0];

        // Guard against payments arriving after the 10-minute hold has expired
        if (booking.booking_status === 'EXPIRED' || (booking.booking_status === 'PENDING' && new Date(booking.expires_at) < new Date())) {
          await connection.query(
            `UPDATE bookings SET booking_status = 'EXPIRED' WHERE id = ?`,
            [payload.bookingId]
          );
          await connection.query(
            `UPDATE payments SET payment_status = 'REFUNDED' WHERE idempotency_key = ?`,
            [payload.idempotencyKey]
          );
          await connection.commit();
          return {
            status: 'FAILED',
            message: 'Seat hold expired before payment was confirmed. Refund initiated automatically.',
          };
        }

        // Confirm booking
        await connection.query(
          `UPDATE bookings SET booking_status = 'CONFIRMED' WHERE id = ?`,
          [payload.bookingId]
        );

        // Fetch seat IDs for this booking
        const [seatRows] = await connection.query<RowDataPacket[]>(
          `SELECT seat_id FROM show_seats WHERE booking_id = ?`,
          [payload.bookingId]
        );
        const seatIds = seatRows.map((r) => r.seat_id);

        // Permanently confirm seats in MySQL
        await connection.query(
          `UPDATE show_seats 
           SET status = 'BOOKED', held_until = NULL, version = version + 1
           WHERE booking_id = ?`,
          [payload.bookingId]
        );

        await connection.commit();

        // Release temporary Redis holds since seat is now permanently stored in MySQL
        await SeatLockService.releaseSeatHolds(booking.show_id, seatIds, `user_${booking.user_id}`);

        return { status: 'PROCESSED', message: 'Payment confirmed and seats booked successfully.' };
      } else {
        // Payment failed: mark booking as cancelled
        await connection.query(
          `UPDATE bookings SET booking_status = 'CANCELLED' WHERE id = ?`,
          [payload.bookingId]
        );

        // Release seats back to AVAILABLE
        await connection.query(
          `UPDATE show_seats
           SET status = 'AVAILABLE', booking_id = NULL, held_at = NULL, held_until = NULL, version = version + 1
           WHERE booking_id = ?`,
          [payload.bookingId]
        );

        await connection.commit();
        return { status: 'PROCESSED', message: 'Payment failure recorded and seats released.' };
      }
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }
}
