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

      // Record payment attempt
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

      if (payload.paymentStatus === 'SUCCESS') {
        // Fetch booking and check if not already confirmed/expired
        const [bookings] = await connection.query<RowDataPacket[]>(
          `SELECT id, show_id, user_id, booking_status, expires_at FROM bookings WHERE id = ? FOR UPDATE`,
          [payload.bookingId]
        );

        if (bookings.length === 0) {
          throw new Error(`Booking ${payload.bookingId} not found.`);
        }

        const booking = bookings[0];

        // Confirm booking
        await connection.query(
          `UPDATE bookings SET booking_status = 'CONFIRMED' WHERE id = ?`,
          [payload.bookingId]
        );

        // Fetch seat IDs for this booking to update them to BOOKED
        const [seatRows] = await connection.query<RowDataPacket[]>(
          `SELECT seat_id FROM show_seats WHERE booking_id = ?`,
          [payload.bookingId]
        );
        const seatIds = seatRows.map((r) => r.seat_id);

        // Permanently book seats in MySQL
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
