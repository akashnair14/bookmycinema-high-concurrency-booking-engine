import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import apiRoutes from './routes/api';
import { BookingService } from './services/booking.service';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'UP', timestamp: new Date().toISOString() });
});

// Mount API routes
app.use('/api/v1', apiRoutes);

// Background safety sweeper for expired holds (runs every 30 seconds)
const holdSweeperInterval = setInterval(async () => {
  try {
    const released = await BookingService.releaseExpiredHolds();
    if (released > 0) {
      console.log(`[Sweeper] Automatically released ${released} expired seat hold(s).`);
    }
  } catch (err) {
    // Ignore if DB is not connected yet during test startup
  }
}, 30000);

if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    console.log(`🚀 BookMyShow Concurrency Engine server running on port ${PORT}`);
    console.log(`📡 P2 Endpoint: http://localhost:${PORT}/api/v1/theatres/1/shows?date=2026-10-01`);
  });
}

process.on('SIGTERM', () => {
  clearInterval(holdSweeperInterval);
  process.exit(0);
});

export default app;
