import { Router } from 'express';
import { ShowController } from '../controllers/show.controller';
import { BookingController } from '../controllers/booking.controller';
import { WebhookController } from '../controllers/webhook.controller';

const router = Router();

// P2 Endpoint: Showtimes for a theatre on a specific date
router.get('/theatres/:theatreId/shows', ShowController.getShowsByTheatreAndDate);

// Supporting Date Picker Endpoint (Next 7 days strip)
router.get('/theatres/:theatreId/dates', ShowController.getNextSevenDates);

// Seat Holding Endpoint (Two-tier Redis + MySQL locking)
router.post('/shows/:showId/hold-seats', BookingController.holdSeats);

// Idempotent Payment Webhook Endpoint
router.post('/webhooks/payment', WebhookController.handlePaymentWebhook);

export default router;
