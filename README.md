# High-Concurrency Movie Booking Engine (BookMyShow Architecture)

A production-grade, highly-concurrent cinema ticketing database architecture designed to handle flash-sale bursts, eliminate double-booking, manage automatic 10-minute seat hold releases, and process idempotent payment webhooks.

---

## 1. System Architecture Overview

```
                        [ Thousands of Concurrent Users ]
                                       │
                                       ▼
                              [ API Gateway / CDN ]
                                       │
                   ┌───────────────────┴───────────────────┐
                   ▼                                       ▼
        [ In-Memory Redis Layer ]                [ Asynchronous Queue ]
        • Atomic Seat Hold (SET NX EX)           • Payment Webhook Buffer
        • Sub-millisecond Lock Contention        • Notification & PDF Generation
        • Automatic 10-Min Expiry (TTL)                    │
                   │                                       │
                   └───────────────────┬───────────────────┘
                                       │
                                       ▼
                            [ MySQL 8.0 (InnoDB) ]
                       • ACID Source of Truth
                       • Hard UNIQUE Constraints (uq_show_seat)
                       • Row-Level Locking (SELECT ... FOR UPDATE)
                       • Idempotency Ledger (uq_idempotency_key)
```

---

## 2. Entities & Relational Data Dictionary

| Entity | Primary Key | Attributes | Description & Relationships |
| :--- | :--- | :--- | :--- |
| **`cities`** | `id` | `name`, `state`, `country`, `created_at` | Master geographic regions. 1 City has many Theatres. |
| **`theatres`** | `id` | `city_id`, `name`, `address`, `pincode`, `created_at` | Physical cinema complexes. Belongs to a City; has many Screens. |
| **`screens`** | `id` | `theatre_id`, `screen_number`, `screen_type`, `sound_system`, `total_seats` | Auditoriums inside a theatre (e.g., Audi 1, IMAX 3D). |
| **`seats`** | `id` | `screen_id`, `row_label`, `seat_number`, `seat_tier`, `is_active` | Physical seats layout per screen. Unique on `(screen_id, row_label, seat_number)`. |
| **`movies`** | `id` | `title`, `description`, `duration_mins`, `release_date`, `language`, `genre`, `certification` | Master catalog of movies running across theatres. |
| **`shows`** | `id` | `theatre_id`, `screen_id`, `movie_id`, `start_time`, `end_time` | Specific show scheduled at a screen for a movie. |
| **`show_tier_pricing`**| `id` | `show_id`, `seat_tier`, `price` | Pricing structure per seat tier for a specific show. |
| **`users`** | `id` | `name`, `email`, `phone`, `created_at` | Customer profiles with unique email and phone constraints. |
| **`bookings`** | `id` | `booking_reference`, `user_id`, `show_id`, `total_amount`, `booking_status`, `expires_at` | Customer booking reservations (`PENDING`, `CONFIRMED`, `CANCELLED`, `EXPIRED`). |
| **`show_seats`** | `id` | `show_id`, `seat_id`, `booking_id`, `status`, `price`, `version`, `held_at`, `held_until` | **Concurrency Hotspot**: Inventory status per seat for a show (`AVAILABLE`, `HELD`, `BOOKED`). |
| **`payments`** | `id` | `booking_id`, `idempotency_key`, `gateway_transaction_id`, `payment_gateway`, `amount`, `payment_status`, `raw_response` | Payment audit ledger with unique idempotency keys. |

---

## 3. Database Normalization (1NF $\to$ 2NF $\to$ 3NF $\to$ BCNF)

### 1NF (First Normal Form)
* **Atomic Values:** Every column holds indivisible values (no comma-separated lists of seats, e.g., seat `row_label` and `seat_number` are distinct atomic columns).
* **Unique Rows:** Every table has an explicit synthetic Primary Key (`id BIGINT AUTO_INCREMENT`).

### 2NF (Second Normal Form)
* All non-key attributes are fully functionally dependent on the entire primary key (no partial dependencies).
* *Example:* In `show_seats`, the seat attributes (row, number, tier) are not duplicated; they reside in `seats`. `show_seats` depends solely on its own surrogate key and the composite domain key `(show_id, seat_id)`.

### 3NF (Third Normal Form)
* No transitive functional dependencies ($X \to Y$ and $Y \to Z$ where $X$ is the PK).
* *Example:* `theatres` references `cities(id)`, rather than repeating `state` and `country` inside `theatres`. Screen details (sound system, screen type) reside in `screens`, not duplicated across `shows`.

### BCNF (Boyce-Codd Normal Form)
* For every non-trivial functional dependency $X \to Y$, $X$ is a superkey.
* In `seats`, the candidate keys are `id` and `(screen_id, row_label, seat_number)`. All non-prime attributes depend only on superkeys.
* In `show_seats`, `(show_id, seat_id)` is a strict candidate key enforced by `UNIQUE KEY uq_show_seat (show_id, seat_id)`.

---

## 4. High-Concurrency & Locking Strategy

When thousands of users compete for the same seats in high-demand shows:

### A. The 2-Tier Locking Architecture
1. **Tier 1 — Distributed In-Memory Lock (Redis):**
   * Eliminates 99% of lock contention before hitting disk.
   * Atomically acquire a lock using Redis Lua or `SET NX EX`:
     ```redis
     SET lock:show:1:seat:16 "user_101" NX EX 600
     ```
   * If `OK`: Proceed to reserve in MySQL.
   * If `nil`: Return immediate response: *"Seat currently selected by another user"*.

2. **Tier 2 — ACID Database Guardrail (MySQL InnoDB):**
   * Even under network partition or Redis failover, MySQL guarantees consistency through:
     ```sql
     CONSTRAINT uq_show_seat UNIQUE (show_id, seat_id)
     ```
   * Any attempt to double-allocate produces an immediate MySQL error `1062 (Duplicate entry)`.

### B. Pessimistic vs. Optimistic Locking Trade-offs

| Criterion | Pessimistic Locking (`SELECT ... FOR UPDATE`) | Optimistic Locking (`version` column) |
| :--- | :--- | :--- |
| **Mechanism** | Acquires row-level exclusive locks in InnoDB during transaction. | Checks `WHERE version = current_version` on `UPDATE`. |
| **Best Used When** | **Extreme Contention (Flash Sales):** Prevents repeated failed retries by queuing readers. | **Low-to-Medium Contention:** Higher throughput when conflicts are rare. |
| **Drawback** | Database connection pool contention; deadlock potential if multiple seats are not locked in deterministic order (e.g., sorted `seat_id ASC`). | High failure/retry rate under heavy flash sales (users experience wasted compute). |
| **Implementation** | See `queries.sql` Section 1. | See `queries.sql` Section 2. |

### C. Self-Expiring Holds (10-Minute Timer)
1. **Redis TTL:** The primary lock automatically evaporates after 600 seconds without running database queries.
2. **Database Fallback:** The `show_seats` table stores `held_until`. A lightweight sweeper runs:
   ```sql
   UPDATE show_seats 
   SET status = 'AVAILABLE', booking_id = NULL, held_until = NULL 
   WHERE status = 'HELD' AND held_until < NOW();
   ```

---

## 5. Idempotent Payment Webhook Processing

Payment gateways (Stripe, Razorpay, UPI) guarantee **at-least-once delivery**, which means duplicate webhooks for the same transaction will occur.

1. **Unique Idempotency Key:**
   The `payments` table enforces `UNIQUE KEY uq_idempotency_key (idempotency_key)`.
2. **Atomic Ingestion Query:**
   ```sql
   INSERT INTO payments (
       booking_id, idempotency_key, gateway_transaction_id, payment_gateway, amount, payment_status, raw_response
   ) VALUES (
       2, 'PAY-WEBHOOK-RAZORPAY-TXN-12345678', 'txn_rzp_live_12345678', 'RAZORPAY', 600.00, 'SUCCESS', '{"event": "payment.captured"}'
   )
   ON DUPLICATE KEY UPDATE 
       gateway_transaction_id = VALUES(gateway_transaction_id),
       updated_at = CURRENT_TIMESTAMP;
   ```
3. If an incoming event is a duplicate, the query succeeds without corrupting financial records or double-crediting bookings.

---

## 6. P1: Database Schema & Setup

### Execution
Run the scripts in order on MySQL 8.0+:
```bash
mysql -u root -p < schema.sql
mysql -u root -p < seed_data.sql
```

---

## 7. P2: Showtimes by Date & Theatre Query

### The Query
To fetch all shows for Theatre `1` on Date `2026-10-01`:

```sql
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
```

### Query Optimization & Indexing Strategy
* **Composite Index:** `idx_theatre_date_time (theatre_id, start_time, movie_id)` on `shows`.
* **SARGable Filtering:** Instead of `DATE(s.start_time) = '2026-10-01'` (which prevents index range scans), we use:
  ```sql
  s.start_time >= '2026-10-01 00:00:00' AND s.start_time < '2026-10-02 00:00:00'
  ```
  This allows MySQL to perform an index range scan directly on the B-Tree index.

---

## 8. Concurrency & Load Testing Plan (k6 / Locust)

To verify the locking engine:
1. **Scenario:** 5,000 virtual users attempt to book the exact same 10 seats for Show `1` in a 10-second burst.
2. **Success Metrics:**
   * **Double Bookings:** Exactly 0.
   * **Confirmed Bookings:** Exactly 10 seats allocated.
   * **Hold Expirations:** If payment is not simulated within 10 minutes, seats return to `AVAILABLE`.
   * **HTTP 409 / Conflict Rate:** 4,990 requests gracefully rejected with informative conflict payloads without 500 server errors.
