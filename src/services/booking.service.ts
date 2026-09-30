import { pool } from '../config/db';
import { SeatLockService } from './seatLock.service';
import { RowDataPacket, ResultSetHeader } from 'mysql2';

export class BookingService {
  /**
   * Hold seats for a user with two-tier locking:
   * 1. Fast Redis atomic hold with 10-min TTL
   * 2. Database row update to 'HELD' with held_until timestamp
   */
  static async holdSeats(
    showId: number,
    seatIds: number[],
    userId: number,
    ttlSeconds: number = 600
  ): Promise<{ success: boolean; bookingId?: number; bookingRef?: string; message: string }> {
    const userKey = `user_${userId}`;

    // Tier 1: Acquire atomic lock in Redis
    const lockAcquired = await SeatLockService.acquireSeatHolds(showId, seatIds, userKey, ttlSeconds);
    if (!lockAcquired) {
      return { success: false, message: 'One or more selected seats are currently held or booked by another user.' };
    }

    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();

      // Ensure seats are actually available in MySQL (or previous hold expired)
      const sortedSeatIds = [...seatIds].sort((a, b) => a - b);
      const [rows] = await connection.query<RowDataPacket[]>(
        `SELECT id, seat_id, status, price, held_until
         FROM show_seats
         WHERE show_id = ? AND seat_id IN (?)
         FOR UPDATE`,
        [showId, sortedSeatIds]
      );

      if (rows.length !== seatIds.length) {
        await connection.rollback();
        await SeatLockService.releaseSeatHolds(showId, seatIds, userKey);
        return { success: false, message: 'Invalid seat selection.' };
      }

      const now = new Date();
      for (const row of rows) {
        const isExpiredHold = row.status === 'HELD' && row.held_until && new Date(row.held_until) < now;
        if (row.status !== 'AVAILABLE' && !isExpiredHold) {
          await connection.rollback();
          await SeatLockService.releaseSeatHolds(showId, seatIds, userKey);
          return { success: false, message: `Seat ${row.seat_id} is no longer available.` };
        }
      }

      // Calculate total amount
      const totalAmount = rows.reduce((sum, r) => sum + Number(r.price), 0);
      const bookingRef = `BMS-${Date.now()}-${Math.random().toString(36).substring(2, 7).toUpperCase()}`;
      const expiresAt = new Date(Date.now() + ttlSeconds * 1000);

      // Create Pending Booking
      const [bookingResult] = await connection.query<ResultSetHeader>(
        `INSERT INTO bookings (booking_reference, user_id, show_id, total_amount, booking_status, expires_at)
         VALUES (?, ?, ?, ?, 'PENDING', ?)`,
        [bookingRef, userId, showId, totalAmount, expiresAt]
      );
      const bookingId = bookingResult.insertId;

      // Update seat states in database
      await connection.query(
        `UPDATE show_seats
         SET status = 'HELD', booking_id = ?, held_at = NOW(), held_until = ?, version = version + 1
         WHERE show_id = ? AND seat_id IN (?)`,
        [bookingId, expiresAt, showId, sortedSeatIds]
      );

      await connection.commit();
      return { success: true, bookingId, bookingRef, message: 'Seats successfully held for 10 minutes.' };
    } catch (error) {
      await connection.rollback();
      await SeatLockService.releaseSeatHolds(showId, seatIds, userKey);
      throw error;
    } finally {
      connection.release();
    }
  }

  /**
   * Release expired seat holds (Safety background task / worker)
   */
  static async releaseExpiredHolds(): Promise<number> {
    const [result] = await pool.query<ResultSetHeader>(
      `UPDATE show_seats
       SET status = 'AVAILABLE', booking_id = NULL, held_at = NULL, held_until = NULL, version = version + 1
       WHERE status = 'HELD' AND held_until < NOW()`
    );

    await pool.query(
      `UPDATE bookings
       SET booking_status = 'EXPIRED'
       WHERE booking_status = 'PENDING' AND expires_at < NOW()`
    );

    return result.affectedRows;
  }
}
