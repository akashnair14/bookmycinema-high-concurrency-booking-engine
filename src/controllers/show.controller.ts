import { Request, Response } from 'express';
import { pool } from '../config/db';
import { RowDataPacket } from 'mysql2';

export class ShowController {
  /**
   * P2 Endpoint: List all shows on a given date at a given theatre
   * GET /api/v1/theatres/:theatreId/shows?date=2026-10-01
   */
  static async getShowsByTheatreAndDate(req: Request, res: Response) {
    try {
      const theatreId = Number(req.params.theatreId);
      const dateStr = (req.query.date as string) || new Date().toISOString().split('T')[0];

      if (isNaN(theatreId)) {
        return res.status(400).json({ error: 'Valid theatreId parameter is required.' });
      }

      const startDateTime = `${dateStr} 00:00:00`;
      const endDateTime = `${dateStr} 23:59:59`;

      // Optimized query using composite index (theatre_id, start_time, movie_id)
      const query = `
        SELECT 
          m.id AS movie_id,
          m.title AS movie_title,
          m.language,
          m.certification,
          m.genre,
          m.duration_mins,
          sc.id AS screen_id,
          sc.screen_number,
          sc.screen_type,
          sc.sound_system,
          s.id AS show_id,
          TIME_FORMAT(s.start_time, '%h:%i %p') AS show_time,
          s.start_time,
          s.end_time
        FROM shows s
        JOIN movies m ON s.movie_id = m.id
        JOIN screens sc ON s.screen_id = sc.id
        WHERE s.theatre_id = ?
          AND s.start_time >= ?
          AND s.start_time <= ?
        ORDER BY m.title ASC, sc.screen_number ASC, s.start_time ASC;
      `;

      const [rows] = await pool.query<RowDataPacket[]>(query, [theatreId, startDateTime, endDateTime]);

      // Group shows by movie (matching BookMyShow UI card format)
      const groupedMovies = new Map<number, any>();

      for (const row of rows) {
        if (!groupedMovies.has(row.movie_id)) {
          groupedMovies.set(row.movie_id, {
            id: row.movie_id,
            title: row.movie_title,
            language: row.language,
            certification: row.certification,
            genre: row.genre,
            duration: `${row.duration_mins} mins`,
            shows: [],
          });
        }

        groupedMovies.get(row.movie_id).shows.push({
          showId: row.show_id,
          screenId: row.screen_id,
          screenNumber: row.screen_number,
          screenType: row.screen_type,
          soundSystem: row.sound_system,
          showTime: row.show_time,
          startTime: row.start_time,
          endTime: row.end_time,
        });
      }

      return res.json({
        theatreId,
        date: dateStr,
        totalMovies: groupedMovies.size,
        movies: Array.from(groupedMovies.values()),
      });
    } catch (error) {
      console.error('Error fetching shows:', error);
      return res.status(500).json({ error: 'Internal server error while retrieving shows.' });
    }
  }

  /**
   * Supporting Endpoint: Next 7 available dates for date-picker strip
   * GET /api/v1/theatres/:theatreId/dates
   */
  static async getNextSevenDates(req: Request, res: Response) {
    try {
      const theatreId = Number(req.params.theatreId);
      const startDateStr = (req.query.startDate as string) || new Date().toISOString().split('T')[0];

      const query = `
        SELECT DISTINCT
          DATE(s.start_time) AS show_date,
          DATE_FORMAT(s.start_time, '%a') AS day_short,
          DATE_FORMAT(s.start_time, '%d %b') AS day_month
        FROM shows s
        WHERE s.theatre_id = ?
          AND s.start_time >= ?
          AND s.start_time < DATE_ADD(?, INTERVAL 7 DAY)
        ORDER BY show_date ASC;
      `;

      const [rows] = await pool.query<RowDataPacket[]>(query, [theatreId, `${startDateStr} 00:00:00`, `${startDateStr} 00:00:00`]);

      return res.json({
        theatreId,
        dates: rows,
      });
    } catch (error) {
      console.error('Error fetching dates:', error);
      return res.status(500).json({ error: 'Internal server error while retrieving dates.' });
    }
  }
}
