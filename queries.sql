-- =====================================================================
-- BookMyShow High-Concurrency Ticketing Engine - Queries
-- =====================================================================

USE bookmyshow_db;

-- =====================================================================
-- P2 QUERY: List all shows on a given date at a given theatre
-- Scenario: Theatre ID = 1 (PVR Forum Mall Koramangala), Date = '2026-10-01'
-- =====================================================================

-- Option A: Detailed Flat Result (Ideal for Backend Services / ORM Hydration)
-- Uses composite index: idx_theatre_date_time (theatre_id, start_time, movie_id)
SELECT 
    t.id AS theatre_id,
    t.name AS theatre_name,
    m.id AS movie_id,
    m.title AS movie_title,
    m.language AS movie_language,
    m.certification,
    m.duration_mins,
    sc.screen_number,
    sc.screen_type,
    sc.sound_system,
    s.id AS show_id,
    TIME_FORMAT(s.start_time, '%h:%i %p') AS show_time,
    s.start_time,
    s.end_time
FROM shows s
JOIN theatres t ON s.theatre_id = t.id
JOIN movies m ON s.movie_id = m.id
JOIN screens sc ON s.screen_id = sc.id
WHERE s.theatre_id = 1
  AND s.start_time >= '2026-10-01 00:00:00'
  AND s.start_time < '2026-10-02 00:00:00'
ORDER BY m.title ASC, sc.screen_number ASC, s.start_time ASC;


-- Option B: Grouped / Aggregated by Movie (Exact Match for BookMyShow UI Card Layout)
-- In the BookMyShow UI, a single movie card displays badges for all its showtimes
SELECT 
    m.title AS movie_title,
    m.language AS language,
    m.certification,
    m.genre,
    sc.screen_type AS format,
    GROUP_CONCAT(
        CONCAT(
            TIME_FORMAT(s.start_time, '%h:%i %p'),
            ' (', sc.screen_number, ')'
        ) 
        ORDER BY s.start_time ASC 
        SEPARATOR '  |  '
    ) AS available_showtimes
FROM shows s
JOIN movies m ON s.movie_id = m.id
JOIN screens sc ON s.screen_id = sc.id
WHERE s.theatre_id = 1
  AND s.start_time >= '2026-10-01 00:00:00'
  AND s.start_time < '2026-10-02 00:00:00'
GROUP BY m.id, m.title, m.language, m.certification, m.genre, sc.screen_type
ORDER BY m.title ASC;


-- =====================================================================
-- SUPPORTING UI QUERY: Next 7 Available Dates for a Theatre (Top Date-Picker Strip)
-- =====================================================================
SELECT DISTINCT
    DATE(s.start_time) AS show_date,
    DATE_FORMAT(s.start_time, '%a') AS day_short,       -- e.g. 'THU'
    DATE_FORMAT(s.start_time, '%d %b') AS day_month      -- e.g. '01 OCT'
FROM shows s
WHERE s.theatre_id = 1
  AND s.start_time >= '2026-10-01 00:00:00'
  AND s.start_time < DATE_ADD('2026-10-01 00:00:00', INTERVAL 7 DAY)
ORDER BY show_date ASC;


-- =====================================================================
-- CONCURRENCY QUERIES (P1: Seat Locking & Payment Webhooks)
-- =====================================================================

-- 1. Pessimistic Row Lock (Acquiring lock on seats 3 and 4 for Show 1)
-- Running inside an active transaction:
START TRANSACTION;

SELECT id, seat_id, status, price, version
FROM show_seats
WHERE show_id = 1 
  AND seat_id IN (3, 4)
  AND (status = 'AVAILABLE' OR (status = 'HELD' AND held_until < NOW()))
FOR UPDATE;

-- If both seats are returned and available, create pending booking and transition seat status:
-- INSERT INTO bookings (booking_reference, user_id, show_id, total_amount, booking_status, expires_at) ...
-- UPDATE show_seats 
-- SET status = 'HELD', booking_id = @booking_id, held_at = NOW(), held_until = DATE_ADD(NOW(), INTERVAL 10 MINUTE)
-- WHERE show_id = 1 AND seat_id IN (3, 4);

COMMIT;


-- 2. Optimistic Locking Transition
-- Uses version check to ensure no concurrent modification occurred
UPDATE show_seats
SET status = 'HELD',
    booking_id = 2,
    held_at = NOW(),
    held_until = DATE_ADD(NOW(), INTERVAL 10 MINUTE),
    version = version + 1
WHERE show_id = 1 
  AND seat_id = 6 
  AND status = 'AVAILABLE'
  AND version = 0;
-- If Affected Rows == 0, another user acquired the seat; throw conflict back to caller.


-- 3. Automatic Release of Expired Holds (Safety Background Task)
UPDATE show_seats
SET status = 'AVAILABLE',
    booking_id = NULL,
    held_at = NULL,
    held_until = NULL,
    version = version + 1
WHERE status = 'HELD' 
  AND held_until < NOW();


-- 4. Idempotent Payment Webhook Processing
-- If the gateway sends duplicate webhook calls with the same idempotency key,
-- the transaction commits successfully without duplicate charges or state corruption.
START TRANSACTION;

-- Step 4A: Check or Insert payment record (Protected by UNIQUE uq_idempotency_key)
INSERT INTO payments (
    booking_id, idempotency_key, gateway_transaction_id, payment_gateway, amount, payment_status, raw_response
) VALUES (
    2, 'PAY-WEBHOOK-RAZORPAY-TXN-12345678', 'txn_rzp_live_12345678', 'RAZORPAY', 600.00, 'SUCCESS', '{"event": "payment.captured"}'
)
ON DUPLICATE KEY UPDATE 
    gateway_transaction_id = VALUES(gateway_transaction_id),
    updated_at = CURRENT_TIMESTAMP;

-- Step 4B: Confirm Booking
UPDATE bookings 
SET booking_status = 'CONFIRMED'
WHERE id = 2 AND booking_status = 'PENDING';

-- Step 4C: Confirm Show Seats permanently
UPDATE show_seats
SET status = 'BOOKED',
    held_until = NULL,
    version = version + 1
WHERE booking_id = 2 AND status = 'HELD';

COMMIT;
