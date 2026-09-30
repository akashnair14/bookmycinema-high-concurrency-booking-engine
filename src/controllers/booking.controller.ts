import { Request, Response } from 'express';
import { BookingService } from '../services/booking.service';
import { z } from 'zod';

const holdSeatsSchema = z.object({
  seatIds: z.array(z.number().int().positive()).min(1).max(10), // Max 10 seats per booking
  userId: z.number().int().positive(),
  ttlSeconds: z.number().int().positive().default(600),
});

export class BookingController {
  /**
   * Hold Seats endpoint:
   * POST /api/v1/shows/:showId/hold-seats
   */
  static async holdSeats(req: Request, res: Response) {
    try {
      const showId = Number(req.params.showId);
      if (isNaN(showId)) {
        return res.status(400).json({ error: 'Valid showId is required.' });
      }

      const parseResult = holdSeatsSchema.safeParse(req.body);
      if (!parseResult.success) {
        return res.status(400).json({ error: 'Validation failed', details: parseResult.error.format() });
      }

      const { seatIds, userId, ttlSeconds } = parseResult.data;

      const result = await BookingService.holdSeats(showId, seatIds, userId, ttlSeconds);

      if (!result.success) {
        return res.status(409).json({
          status: 'CONFLICT',
          message: result.message,
        });
      }

      return res.status(200).json({
        status: 'HELD',
        bookingId: result.bookingId,
        bookingReference: result.bookingRef,
        message: result.message,
        expiresInSeconds: ttlSeconds,
      });
    } catch (error) {
      console.error('Error holding seats:', error);
      return res.status(500).json({ error: 'Internal error processing seat hold request.' });
    }
  }

  /**
   * Release Seats endpoint:
   * POST /api/v1/shows/:showId/release-seats
   */
  static async releaseHold(req: Request, res: Response) {
    try {
      const showId = Number(req.params.showId);
      const { bookingId, userId = 1 } = req.body;

      if (!bookingId || isNaN(showId)) {
        return res.status(400).json({ error: 'Valid showId and bookingId are required.' });
      }

      await BookingService.releaseUserHold(showId, Number(bookingId), Number(userId));

      return res.json({
        status: 'RELEASED',
        message: 'Seats have been successfully released back to available inventory.',
      });
    } catch (error) {
      console.error('Error releasing seats:', error);
      return res.status(500).json({ error: 'Internal error releasing seat hold.' });
    }
  }
}
