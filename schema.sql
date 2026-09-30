-- =====================================================================
-- BookMyShow High-Concurrency Ticketing Engine - Database Schema (DDL)
-- Dialect: MySQL 8.0+
-- Storage Engine: InnoDB (ACID Compliant)
-- Charset: utf8mb4 / Collation: utf8mb4_unicode_ci
-- =====================================================================

DROP DATABASE IF EXISTS bookmyshow_db;
CREATE DATABASE bookmyshow_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE bookmyshow_db;

-- ---------------------------------------------------------------------
-- 1. CITIES / REGIONS
-- ---------------------------------------------------------------------
CREATE TABLE cities (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    country VARCHAR(100) NOT NULL DEFAULT 'India',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_city_name (name)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. THEATRES
-- ---------------------------------------------------------------------
CREATE TABLE theatres (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    city_id BIGINT NOT NULL,
    name VARCHAR(150) NOT NULL,
    address TEXT NOT NULL,
    pincode VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_theatres_city FOREIGN KEY (city_id) REFERENCES cities (id) ON DELETE RESTRICT,
    INDEX idx_theatre_city (city_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. SCREENS (AUDITORIUMS)
-- ---------------------------------------------------------------------
CREATE TABLE screens (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    theatre_id BIGINT NOT NULL,
    screen_number VARCHAR(20) NOT NULL,
    screen_type ENUM('2D', '3D', 'IMAX 2D', 'IMAX 3D', '4DX') NOT NULL DEFAULT '2D',
    sound_system VARCHAR(50) DEFAULT 'Dolby Atmos 7.1',
    total_seats INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_screens_theatre FOREIGN KEY (theatre_id) REFERENCES theatres (id) ON DELETE CASCADE,
    CONSTRAINT uq_theatre_screen UNIQUE (theatre_id, screen_number)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. SEATS (Master Seat Layout per Screen)
-- ---------------------------------------------------------------------
CREATE TABLE seats (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    screen_id BIGINT NOT NULL,
    row_label VARCHAR(5) NOT NULL,       -- e.g., 'A', 'B', 'K'
    seat_number INT NOT NULL,            -- e.g., 1, 2, 15
    seat_tier ENUM('RECLINER', 'PRIME_PLUS', 'PRIME', 'CLASSIC') NOT NULL DEFAULT 'CLASSIC',
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT fk_seats_screen FOREIGN KEY (screen_id) REFERENCES screens (id) ON DELETE CASCADE,
    CONSTRAINT uq_screen_seat UNIQUE (screen_id, row_label, seat_number),
    INDEX idx_screen_tier (screen_id, seat_tier)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. MOVIES
-- ---------------------------------------------------------------------
CREATE TABLE movies (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    duration_mins INT NOT NULL,          -- Runtime in minutes
    release_date DATE NOT NULL,
    language VARCHAR(50) NOT NULL,
    genre VARCHAR(100) NOT NULL,
    certification ENUM('U', 'UA', 'A', 'S') NOT NULL DEFAULT 'UA',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_movie_title (title)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. SHOWS
-- ---------------------------------------------------------------------
CREATE TABLE shows (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    theatre_id BIGINT NOT NULL,          -- Denormalized for high-speed P2 filtering without screen join
    screen_id BIGINT NOT NULL,
    movie_id BIGINT NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_shows_theatre FOREIGN KEY (theatre_id) REFERENCES theatres (id) ON DELETE RESTRICT,
    CONSTRAINT fk_shows_screen FOREIGN KEY (screen_id) REFERENCES screens (id) ON DELETE RESTRICT,
    CONSTRAINT fk_shows_movie FOREIGN KEY (movie_id) REFERENCES movies (id) ON DELETE RESTRICT,
    -- Composite index optimized for the core P2 query: Find shows at a theatre on a specific date range
    INDEX idx_theatre_date_time (theatre_id, start_time, movie_id),
    INDEX idx_screen_schedule (screen_id, start_time, end_time)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7. SHOW_TIER_PRICING (Dynamic or Tiered Pricing per Show)
-- ---------------------------------------------------------------------
CREATE TABLE show_tier_pricing (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    show_id BIGINT NOT NULL,
    seat_tier ENUM('RECLINER', 'PRIME_PLUS', 'PRIME', 'CLASSIC') NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    CONSTRAINT fk_pricing_show FOREIGN KEY (show_id) REFERENCES shows (id) ON DELETE CASCADE,
    CONSTRAINT uq_show_tier UNIQUE (show_id, seat_tier)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 8. USERS
-- ---------------------------------------------------------------------
CREATE TABLE users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_email UNIQUE (email),
    CONSTRAINT uq_user_phone UNIQUE (phone)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 9. BOOKINGS
-- ---------------------------------------------------------------------
CREATE TABLE bookings (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    booking_reference VARCHAR(64) NOT NULL,  -- Unique alphanumeric booking code (e.g. BMS-20261001-XYZ)
    user_id BIGINT NOT NULL,
    show_id BIGINT NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    booking_status ENUM('PENDING', 'CONFIRMED', 'CANCELLED', 'EXPIRED') NOT NULL DEFAULT 'PENDING',
    expires_at DATETIME NOT NULL,            -- 10-minute hold expiry timestamp
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_bookings_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT fk_bookings_show FOREIGN KEY (show_id) REFERENCES shows (id) ON DELETE RESTRICT,
    CONSTRAINT uq_booking_ref UNIQUE (booking_reference),
    INDEX idx_user_bookings (user_id, created_at),
    INDEX idx_status_expiry (booking_status, expires_at)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 10. SHOW_SEATS (Seat Inventory per Show - Concurrency Hotspot)
-- ---------------------------------------------------------------------
CREATE TABLE show_seats (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    show_id BIGINT NOT NULL,
    seat_id BIGINT NOT NULL,
    booking_id BIGINT NULL,                  -- NULL when AVAILABLE
    status ENUM('AVAILABLE', 'HELD', 'BOOKED') NOT NULL DEFAULT 'AVAILABLE',
    price DECIMAL(10, 2) NOT NULL,
    version INT NOT NULL DEFAULT 0,          -- Optimistic locking counter
    held_at DATETIME NULL,
    held_until DATETIME NULL,                -- Expiry for HELD status
    CONSTRAINT fk_show_seats_show FOREIGN KEY (show_id) REFERENCES shows (id) ON DELETE CASCADE,
    CONSTRAINT fk_show_seats_seat FOREIGN KEY (seat_id) REFERENCES seats (id) ON DELETE RESTRICT,
    CONSTRAINT fk_show_seats_booking FOREIGN KEY (booking_id) REFERENCES bookings (id) ON DELETE SET NULL,
    -- HARD DATABASE GUARDRAIL: A seat can only exist once per show
    CONSTRAINT uq_show_seat UNIQUE (show_id, seat_id),
    INDEX idx_show_status (show_id, status)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 11. PAYMENTS (Idempotent Payment Webhook Processing)
-- ---------------------------------------------------------------------
CREATE TABLE payments (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    booking_id BIGINT NOT NULL,
    idempotency_key VARCHAR(128) NOT NULL,   -- Webhook idempotency key or Gateway order ID
    gateway_transaction_id VARCHAR(128) NULL,
    payment_gateway ENUM('RAZORPAY', 'STRIPE', 'PAYTM', 'UPI') NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    payment_status ENUM('INITIATED', 'SUCCESS', 'FAILED', 'REFUNDED') NOT NULL DEFAULT 'INITIATED',
    raw_response JSON NULL,                  -- Gateway payload for auditing
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_payments_booking FOREIGN KEY (booking_id) REFERENCES bookings (id) ON DELETE RESTRICT,
    -- HARD IDEMPOTENCY GUARDRAIL: Gateway events cannot be processed twice
    CONSTRAINT uq_idempotency_key UNIQUE (idempotency_key),
    INDEX idx_booking_payments (booking_id)
) ENGINE=InnoDB;
