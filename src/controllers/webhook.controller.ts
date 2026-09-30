import { Request, Response } from 'express';
import { PaymentService } from '../services/payment.service';
import { z } from 'zod';

const paymentWebhookSchema = z.object({
  idempotencyKey: z.string().min(5),
  bookingId: z.number().int().positive(),
  gatewayTransactionId: z.string().min(5),
  paymentGateway: z.enum(['RAZORPAY', 'STRIPE', 'PAYTM', 'UPI']),
  amount: z.number().positive(),
  paymentStatus: z.enum(['SUCCESS', 'FAILED']),
  rawResponse: z.any().optional(),
});

export class WebhookController {
  /**
   * Idempotent Payment Webhook Endpoint
   * POST /api/v1/webhooks/payment
   */
  static async handlePaymentWebhook(req: Request, res: Response) {
    try {
      const parseResult = paymentWebhookSchema.safeParse(req.body);
      if (!parseResult.success) {
        return res.status(400).json({ error: 'Invalid webhook payload', details: parseResult.error.format() });
      }

      const result = await PaymentService.processWebhook(parseResult.data);

      if (result.status === 'DUPLICATE_IGNORED') {
        // Return 200 OK so the payment gateway stops retrying, but log that it was an idempotent skip
        return res.status(200).json({
          status: 'DUPLICATE_IGNORED',
          message: result.message,
        });
      }

      return res.status(200).json({
        status: 'SUCCESS',
        message: result.message,
      });
    } catch (error) {
      console.error('Error handling payment webhook:', error);
      return res.status(500).json({ error: 'Internal error processing payment webhook.' });
    }
  }
}
