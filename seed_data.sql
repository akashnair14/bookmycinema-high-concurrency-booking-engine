-- =====================================================================
-- BookMyShow High-Concurrency Ticketing Engine - Seed Data
-- =====================================================================

USE bookmyshow_db;

-- 1. Cities
INSERT INTO cities (id, name, state, country) VALUES
(1, 'Bengaluru', 'Karnataka', 'India'),
(2, 'Mumbai', 'Maharashtra', 'India');

-- 2. Theatres
INSERT INTO theatres (id, city_id, name, address, pincode) VALUES
(1, 1, 'PVR INOX: Forum Mall, Koramangala', 'Hosur Rd, Chikku Lakshmaiah Layout, Koramangala', '560095'),
(2, 1, 'Cinepolis: Orion Mall, Rajajinagar', 'Dr Rajkumar Rd, Rajajinagar', '560055');

-- 3. Screens
INSERT INTO screens (id, theatre_id, screen_number, screen_type, sound_system, total_seats) VALUES
(1, 1, 'Audi 1', 'IMAX 3D', 'Dolby Atmos 7.1', 20),
(2, 1, 'Audi 2', '4DX', 'Dolby 5.1', 20),
(3, 2, 'Screen 1', '2D', 'Dolby Atmos', 20);

-- 4. Seats (Layout for Audi 1 - Screen 1: 4 rows x 5 seats = 20 seats)
INSERT INTO seats (screen_id, row_label, seat_number, seat_tier) VALUES
-- Row A: CLASSIC
(1, 'A', 1, 'CLASSIC'), (1, 'A', 2, 'CLASSIC'), (1, 'A', 3, 'CLASSIC'), (1, 'A', 4, 'CLASSIC'), (1, 'A', 5, 'CLASSIC'),
-- Row B: PRIME
(1, 'B', 1, 'PRIME'), (1, 'B', 2, 'PRIME'), (1, 'B', 3, 'PRIME'), (1, 'B', 4, 'PRIME'), (1, 'B', 5, 'PRIME'),
-- Row C: PRIME_PLUS
(1, 'C', 1, 'PRIME_PLUS'), (1, 'C', 2, 'PRIME_PLUS'), (1, 'C', 3, 'PRIME_PLUS'), (1, 'C', 4, 'PRIME_PLUS'), (1, 'C', 5, 'PRIME_PLUS'),
-- Row D: RECLINER
(1, 'D', 1, 'RECLINER'), (1, 'D', 2, 'RECLINER'), (1, 'D', 3, 'RECLINER'), (1, 'D', 4, 'RECLINER'), (1, 'D', 5, 'RECLINER');

-- Seats for Audi 2 (Screen 2: 10 seats for brevity)
INSERT INTO seats (screen_id, row_label, seat_number, seat_tier) VALUES
(2, 'A', 1, 'CLASSIC'), (2, 'A', 2, 'CLASSIC'), (2, 'A', 3, 'CLASSIC'), (2, 'A', 4, 'CLASSIC'), (2, 'A', 5, 'CLASSIC'),
(2, 'B', 1, 'RECLINER'), (2, 'B', 2, 'RECLINER'), (2, 'B', 3, 'RECLINER'), (2, 'B', 4, 'RECLINER'), (2, 'B', 5, 'RECLINER');

-- 5. Movies
INSERT INTO movies (id, title, description, duration_mins, release_date, language, genre, certification) VALUES
(1, 'Dune: Part Two', 'Paul Atreides unites with Chani and the Fremen while seeking revenge.', 166, '2024-03-01', 'English', 'Sci-Fi/Adventure', 'UA'),
(2, 'Kalki 2898 AD', 'A modern avatar of Vishnu descends to protect the world from evil forces.', 181, '2024-06-27', 'Telugu', 'Action/Sci-Fi', 'UA'),
(3, 'Oppenheimer', 'The story of American scientist J. Robert Oppenheimer and his role in the Manhattan Project.', 180, '2023-07-21', 'English', 'Biography/Drama', 'A');

-- 6. Shows (Spanning next 7 days for Theatre 1: 2026-10-01 to 2026-10-07)
INSERT INTO shows (id, theatre_id, screen_id, movie_id, start_time, end_time) VALUES
-- Day 1: 2026-10-01 (Multiple shows on Audi 1 and Audi 2)
(1, 1, 1, 1, '2026-10-01 09:30:00', '2026-10-01 12:16:00'), -- Audi 1: Dune (Morning)
(2, 1, 1, 1, '2026-10-01 13:30:00', '2026-10-01 16:16:00'), -- Audi 1: Dune (Matinee)
(3, 1, 1, 2, '2026-10-01 18:00:00', '2026-10-01 21:01:00'), -- Audi 1: Kalki (Evening)
(4, 1, 1, 3, '2026-10-01 22:00:00', '2026-10-02 01:00:00'), -- Audi 1: Oppenheimer (Night)
(5, 1, 2, 2, '2026-10-01 10:00:00', '2026-10-01 13:01:00'), -- Audi 2: Kalki
(6, 1, 2, 1, '2026-10-01 15:00:00', '2026-10-01 17:46:00'), -- Audi 2: Dune

-- Day 2: 2026-10-02
(7, 1, 1, 1, '2026-10-02 10:00:00', '2026-10-02 12:46:00'),
(8, 1, 1, 2, '2026-10-02 14:00:00', '2026-10-02 17:01:00'),

-- Day 3: 2026-10-03
(9, 1, 1, 1, '2026-10-03 11:00:00', '2026-10-03 13:46:00'),

-- Day 4: 2026-10-04
(10, 1, 1, 3, '2026-10-04 18:30:00', '2026-10-04 21:30:00'),

-- Day 5: 2026-10-05
(11, 1, 1, 1, '2026-10-05 20:00:00', '2026-10-05 22:46:00'),

-- Day 6: 2026-10-06
(12, 1, 1, 2, '2026-10-06 16:00:00', '2026-10-06 19:01:00'),

-- Day 7: 2026-10-07
(13, 1, 1, 1, '2026-10-07 19:00:00', '2026-10-07 21:46:00');

-- 7. Show Tier Pricing (For Show 1)
INSERT INTO show_tier_pricing (show_id, seat_tier, price) VALUES
(1, 'CLASSIC', 250.00),
(1, 'PRIME', 350.00),
(1, 'PRIME_PLUS', 450.00),
(1, 'RECLINER', 600.00);

-- 8. Users
INSERT INTO users (id, name, email, phone) VALUES
(1, 'Rahul Sharma', 'rahul.sharma@example.com', '+919876543210'),
(2, 'Priya Nair', 'priya.nair@example.com', '+919812345678'),
(3, 'Amit Verma', 'amit.verma@example.com', '+919700011223');

-- 9. Sample Bookings
INSERT INTO bookings (id, booking_reference, user_id, show_id, total_amount, booking_status, expires_at, created_at) VALUES
-- User 1 booked and confirmed
(1, 'BMS-20261001-A1B2C3', 1, 1, 700.00, 'CONFIRMED', '2026-10-01 09:10:00', '2026-10-01 09:00:00'),
-- User 2 has an active 10-minute hold (pending payment)
(2, 'BMS-20261001-D4E5F6', 2, 1, 600.00, 'PENDING', DATE_ADD(NOW(), INTERVAL 8 MINUTE), NOW());

-- 10. Show Seats (Seating state for Show 1)
-- Generating inventory for Show 1 (Seats 1-20)
INSERT INTO show_seats (show_id, seat_id, booking_id, status, price, version, held_at, held_until) VALUES
-- Row A: Seats 1 and 2 booked by User 1
(1, 1, 1, 'BOOKED', 250.00, 1, NULL, NULL),
(1, 2, 1, 'BOOKED', 250.00, 1, NULL, NULL),
(1, 3, NULL, 'AVAILABLE', 250.00, 0, NULL, NULL),
(1, 4, NULL, 'AVAILABLE', 250.00, 0, NULL, NULL),
(1, 5, NULL, 'AVAILABLE', 250.00, 0, NULL, NULL),

-- Row B: Seats 6-10 (Available)
(1, 6, NULL, 'AVAILABLE', 350.00, 0, NULL, NULL),
(1, 7, NULL, 'AVAILABLE', 350.00, 0, NULL, NULL),
(1, 8, NULL, 'AVAILABLE', 350.00, 0, NULL, NULL),
(1, 9, NULL, 'AVAILABLE', 350.00, 0, NULL, NULL),
(1, 10, NULL, 'AVAILABLE', 350.00, 0, NULL, NULL),

-- Row C: Seats 11-15 (Available)
(1, 11, NULL, 'AVAILABLE', 450.00, 0, NULL, NULL),
(1, 12, NULL, 'AVAILABLE', 450.00, 0, NULL, NULL),
(1, 13, NULL, 'AVAILABLE', 450.00, 0, NULL, NULL),
(1, 14, NULL, 'AVAILABLE', 450.00, 0, NULL, NULL),
(1, 15, NULL, 'AVAILABLE', 450.00, 0, NULL, NULL),

-- Row D: Seat 16 currently HELD by User 2 (Recliner)
(1, 16, 2, 'HELD', 600.00, 1, NOW(), DATE_ADD(NOW(), INTERVAL 8 MINUTE)),
(1, 17, NULL, 'AVAILABLE', 600.00, 0, NULL, NULL),
(1, 18, NULL, 'AVAILABLE', 600.00, 0, NULL, NULL),
(1, 19, NULL, 'AVAILABLE', 600.00, 0, NULL, NULL),
(1, 20, NULL, 'AVAILABLE', 600.00, 0, NULL, NULL);

-- 11. Payments (Demonstrating idempotency for Booking 1)
INSERT INTO payments (id, booking_id, idempotency_key, gateway_transaction_id, payment_gateway, amount, payment_status, raw_response) VALUES
(1, 1, 'PAY-IDEMP-99887766-B1', 'txn_razorpay_99887766', 'RAZORPAY', 700.00, 'SUCCESS', '{"status": "captured", "bank_ref": "REF123456"}');
