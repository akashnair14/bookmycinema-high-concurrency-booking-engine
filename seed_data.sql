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
(3, 1, 'Audi 3', '2D', 'Dolby Atmos', 20),
(4, 1, 'Audi 4', '2D', 'Dolby 7.1', 20),
(5, 2, 'Screen 1', '2D', 'Dolby Atmos', 20);

-- 4. Seats (Layout for Audi 1 - Screen 1: 4 rows x 5 seats = 20 seats)
INSERT INTO seats (screen_id, row_label, seat_number, seat_tier) VALUES
-- Screen 1 (Audi 1)
(1, 'A', 1, 'CLASSIC'), (1, 'A', 2, 'CLASSIC'), (1, 'A', 3, 'CLASSIC'), (1, 'A', 4, 'CLASSIC'), (1, 'A', 5, 'CLASSIC'),
(1, 'B', 1, 'PRIME'), (1, 'B', 2, 'PRIME'), (1, 'B', 3, 'PRIME'), (1, 'B', 4, 'PRIME'), (1, 'B', 5, 'PRIME'),
(1, 'C', 1, 'PRIME_PLUS'), (1, 'C', 2, 'PRIME_PLUS'), (1, 'C', 3, 'PRIME_PLUS'), (1, 'C', 4, 'PRIME_PLUS'), (1, 'C', 5, 'PRIME_PLUS'),
(1, 'D', 1, 'RECLINER'), (1, 'D', 2, 'RECLINER'), (1, 'D', 3, 'RECLINER'), (1, 'D', 4, 'RECLINER'), (1, 'D', 5, 'RECLINER'),
-- Screen 2 (Audi 2)
(2, 'A', 1, 'CLASSIC'), (2, 'A', 2, 'CLASSIC'), (2, 'A', 3, 'CLASSIC'), (2, 'A', 4, 'CLASSIC'), (2, 'A', 5, 'CLASSIC'),
(2, 'B', 1, 'PRIME'), (2, 'B', 2, 'PRIME'), (2, 'B', 3, 'PRIME'), (2, 'B', 4, 'PRIME'), (2, 'B', 5, 'PRIME'),
(2, 'C', 1, 'RECLINER'), (2, 'C', 2, 'RECLINER'), (2, 'C', 3, 'RECLINER'), (2, 'C', 4, 'RECLINER'), (2, 'C', 5, 'RECLINER'),
-- Screen 3 (Audi 3)
(3, 'A', 1, 'CLASSIC'), (3, 'A', 2, 'CLASSIC'), (3, 'A', 3, 'CLASSIC'), (3, 'A', 4, 'CLASSIC'), (3, 'A', 5, 'CLASSIC'),
(3, 'B', 1, 'PRIME'), (3, 'B', 2, 'PRIME'), (3, 'B', 3, 'PRIME'), (3, 'B', 4, 'PRIME'), (3, 'B', 5, 'PRIME'),
(3, 'C', 1, 'RECLINER'), (3, 'C', 2, 'RECLINER'), (3, 'C', 3, 'RECLINER'), (3, 'C', 4, 'RECLINER'), (3, 'C', 5, 'RECLINER'),
-- Screen 4 (Audi 4)
(4, 'A', 1, 'CLASSIC'), (4, 'A', 2, 'CLASSIC'), (4, 'A', 3, 'CLASSIC'), (4, 'A', 4, 'CLASSIC'), (4, 'A', 5, 'CLASSIC'),
(4, 'B', 1, 'PRIME'), (4, 'B', 2, 'PRIME'), (4, 'B', 3, 'PRIME'), (4, 'B', 4, 'PRIME'), (4, 'B', 5, 'PRIME'),
(4, 'C', 1, 'RECLINER'), (4, 'C', 2, 'RECLINER'), (4, 'C', 3, 'RECLINER'), (4, 'C', 4, 'RECLINER'), (4, 'C', 5, 'RECLINER');

-- 5. Movies (From BookMyShow Reference Screenshot)
INSERT INTO movies (id, title, description, duration_mins, release_date, language, genre, certification) VALUES
(1, 'The Odyssey', 'An epic mythological adventure across ancient uncharted realms.', 160, '2026-09-15', 'English, Hindi, Tamil, Telugu', 'Action/Adventure', 'A'),
(2, 'Hanuman Ansh', 'The sacred story of devotion, strength and divine protection.', 145, '2026-09-20', 'Hindi', 'Mythological/Drama', 'U'),
(3, 'Mirzapur: The Movie', 'The battle for the throne of Purvanchal reaches the silver screen.', 155, '2026-09-25', 'Hindi, Telugu', 'Action/Crime/Thriller', 'A'),
(4, 'Daayra', 'A gripping mystery unraveling the boundaries of justice and truth.', 138, '2026-09-28', 'Hindi, Malayalam', 'Mystery/Thriller', 'A'),
(5, 'Toxic: A Fairy Tale for Grown-ups', 'A dark underworld saga tracing the rise of an antihero.', 170, '2026-10-01', 'Kannada, Telugu, Tamil, Malayalam', 'Action/Crime/Drama', 'A');

-- 6. Shows (Comprehensive Schedule for Theatre 1: 2026-10-01 to 2026-10-07)
INSERT INTO shows (id, theatre_id, screen_id, movie_id, start_time, end_time) VALUES
-- Day 1: 2026-10-01 (Full 4-Screen Multi-Show Schedule)
-- The Odyssey (Movie 1)
(1, 1, 1, 1, '2026-10-01 09:30:00', '2026-10-01 12:10:00'), -- Audi 1 (IMAX 3D)
(2, 1, 3, 1, '2026-10-01 13:15:00', '2026-10-01 15:55:00'), -- Audi 3 (Dolby Atmos)
(3, 1, 1, 1, '2026-10-01 17:00:00', '2026-10-01 19:40:00'), -- Audi 1 (IMAX 3D)
(4, 1, 1, 1, '2026-10-01 21:00:00', '2026-10-01 23:40:00'), -- Audi 1 (IMAX 3D)
(5, 1, 3, 1, '2026-10-01 22:30:00', '2026-10-02 01:10:00'), -- Audi 3 (Dolby Atmos)

-- Hanuman Ansh (Movie 2)
(6, 1, 2, 2, '2026-10-01 10:15:00', '2026-10-01 12:40:00'), -- Audi 2 (4DX)
(7, 1, 4, 2, '2026-10-01 14:00:00', '2026-10-01 16:25:00'), -- Audi 4 (2D)
(8, 1, 4, 2, '2026-10-01 18:30:00', '2026-10-01 20:55:00'), -- Audi 4 (2D)

-- Mirzapur: The Movie (Movie 3)
(9, 1, 3, 3, '2026-10-01 09:45:00', '2026-10-01 12:20:00'), -- Audi 3 (Dolby Atmos)
(10, 1, 1, 3, '2026-10-01 13:00:00', '2026-10-01 15:35:00'), -- Audi 1 (IMAX 3D)
(11, 1, 2, 3, '2026-10-01 16:00:00', '2026-10-01 18:35:00'), -- Audi 2 (4DX)
(12, 1, 2, 3, '2026-10-01 21:45:00', '2026-10-02 00:20:00'), -- Audi 2 (4DX)

-- Daayra (Movie 4)
(13, 1, 4, 4, '2026-10-01 10:00:00', '2026-10-01 12:18:00'), -- Audi 4 (2D)
(14, 1, 2, 4, '2026-10-01 13:15:00', '2026-10-01 15:33:00'), -- Audi 2 (4DX)
(15, 1, 4, 4, '2026-10-01 21:30:00', '2026-10-01 23:48:00'), -- Audi 4 (2D)

-- Toxic: A Fairy Tale for Grown-ups (Movie 5)
(16, 1, 4, 5, '2026-10-01 12:30:00', '2026-10-01 15:20:00'), -- Audi 4 (2D)
(17, 1, 3, 5, '2026-10-01 16:15:00', '2026-10-01 19:05:00'), -- Audi 3 (Dolby Atmos)
(18, 1, 2, 5, '2026-10-01 18:45:00', '2026-10-01 21:35:00'), -- Audi 2 (4DX)
(19, 1, 3, 5, '2026-10-01 19:30:00', '2026-10-01 22:20:00'), -- Audi 3 (Dolby Atmos)

-- Day 2: 2026-10-02
(20, 1, 1, 1, '2026-10-02 10:00:00', '2026-10-02 12:40:00'),
(21, 1, 1, 5, '2026-10-02 14:00:00', '2026-10-02 16:50:00'),
(22, 1, 2, 3, '2026-10-02 18:00:00', '2026-10-02 20:35:00'),
(23, 1, 3, 2, '2026-10-02 20:00:00', '2026-10-02 22:25:00'),

-- Day 3: 2026-10-03
(24, 1, 1, 2, '2026-10-03 11:00:00', '2026-10-03 13:25:00'),
(25, 1, 1, 5, '2026-10-03 15:00:00', '2026-10-03 17:50:00'),
(26, 1, 2, 1, '2026-10-03 19:00:00', '2026-10-03 21:40:00'),

-- Day 4: 2026-10-04
(27, 1, 1, 3, '2026-10-04 18:30:00', '2026-10-04 21:05:00'),
(28, 1, 2, 5, '2026-10-04 21:00:00', '2026-10-04 23:50:00'),

-- Day 5: 2026-10-05
(29, 1, 1, 1, '2026-10-05 20:00:00', '2026-10-05 22:40:00'),

-- Day 6: 2026-10-06
(30, 1, 1, 4, '2026-10-06 16:00:00', '2026-10-06 18:18:00'),

-- Day 7: 2026-10-07
(31, 1, 1, 5, '2026-10-07 19:00:00', '2026-10-07 21:50:00');

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
