-- RentMadeEasy bulk test data (Portfolio 2)
-- The Portfolio 1 seed only has 8 customers, which is too small to see any
-- difference from indexes. This file adds generated data so query plans
-- and timings can be measured.
-- Run after the Portfolio 1 schema and seed:
--   \i /portfolio/portfolio-2-query-optimisation/01_bulk_data.sql

SET search_path TO rme;

-- Same random numbers every run, so the results can be repeated
SELECT setseed(0.42);

-- 50,000 customers
INSERT INTO customers (first_name, last_name, email, phone, date_of_birth, created_at)
SELECT 'Customer', 'Number ' || g,
       'customer' || g || '@mail.com',
       '070' || lpad(g::text, 8, '0'),
       DATE '1970-01-01' + floor(random() * 12000)::int,
       TIMESTAMP '2025-01-01' + random() * INTERVAL '600 days'
FROM generate_series(1, 50000) AS g;

-- A wallet for every customer who does not have one yet
INSERT INTO wallets (customer_id, account_number)
SELECT customer_id, '8' || lpad(customer_id::text, 9, '0')
FROM customers
WHERE customer_id NOT IN (SELECT customer_id FROM wallets);

-- 2,000 properties shared between the 4 existing landlords,
-- with rent between 600,000 and 3,000,000
INSERT INTO properties (landlord_id, address, city, property_type, annual_rent)
SELECT 1 + (g % 4),
       g || ' Allen Avenue',
       (ARRAY['Lagos', 'Abuja', 'Ibadan', 'Port Harcourt'])[1 + (g % 4)],
       (ARRAY['SELF_CONTAIN', 'MINI_FLAT', 'FLAT', 'DUPLEX'])[1 + (g % 4)],
       round((600000 + random() * 2400000) / 50000) * 50000
FROM generate_series(1, 2000) AS g;

-- 300,000 wallet top-ups, each for a random new customer
INSERT INTO wallet_transactions (wallet_id, transaction_type, amount, reference, description, created_at)
SELECT w.wallet_id,
       'CREDIT',
       r.amount,
       'BULK-' || r.g,
       'Wallet top-up',
       r.created_at
FROM (
    SELECT g,
           1 + floor(random() * 50000)::int AS customer_n,
           round((5000 + random() * 95000)::numeric, -2) AS amount,
           TIMESTAMP '2025-01-01' + random() * INTERVAL '650 days' AS created_at
    FROM generate_series(1, 300000) AS g
) AS r
JOIN customers c ON c.email = 'customer' || r.customer_n || '@mail.com'
JOIN wallets w   ON w.customer_id = c.customer_id;

-- 40,000 loan applications on the Rent Monthly product.
-- The amount is half the rent, so it always passes the trigger.
-- About 70% approved, 20% rejected and 10% pending.
INSERT INTO loan_applications (customer_id, property_id, product_id, requested_amount, tenure_months, status, applied_at)
SELECT c.customer_id,
       p.property_id,
       1,
       p.annual_rent / 2,
       6,
       CASE WHEN r.outcome < 0.7 THEN 'APPROVED'
            WHEN r.outcome < 0.9 THEN 'REJECTED'
            ELSE 'PENDING' END,
       TIMESTAMP '2025-01-01' + r.day * INTERVAL '1 day'
FROM (
    SELECT 1 + floor(random() * 50000)::int AS customer_n,
           1 + floor(random() * 2000)::int  AS property_n,
           random() AS outcome,
           floor(random() * 600)::int AS day
    FROM generate_series(1, 40000)
) AS r
JOIN customers c  ON c.email = 'customer' || r.customer_n || '@mail.com'
JOIN properties p ON p.address = r.property_n || ' Allen Avenue';

-- A loan for every approved application that does not have one yet
INSERT INTO loans (application_id, principal, monthly_interest_rate, tenure_months, disbursed_at)
SELECT application_id, requested_amount, 0.0350, tenure_months, applied_at + INTERVAL '2 days'
FROM loan_applications
WHERE status = 'APPROVED'
  AND application_id NOT IN (SELECT application_id FROM loans);

-- 6 monthly instalments for each new loan.
-- Before 2026-10-22 ("today") an instalment is PAID, or OVERDUE about 1 time in 10.
INSERT INTO repayment_schedules (loan_id, installment_number, due_date, amount_due, status)
SELECT l.loan_id,
       i,
       (l.disbursed_at + i * INTERVAL '1 month')::date,
       round(l.principal / 6 + l.principal * 0.035, 2),
       CASE WHEN (l.disbursed_at + i * INTERVAL '1 month')::date >= DATE '2026-10-22' THEN 'PENDING'
            WHEN random() < 0.1 THEN 'OVERDUE'
            ELSE 'PAID' END
FROM loans l, generate_series(1, 6) AS i
WHERE l.loan_id NOT IN (SELECT loan_id FROM repayment_schedules);

-- Update wallet balances to match their transactions.
-- The totals are worked out once for all wallets, then joined.
UPDATE wallets w
SET balance = totals.balance
FROM (
    SELECT wallet_id,
           SUM(CASE transaction_type WHEN 'CREDIT' THEN amount ELSE -amount END) AS balance
    FROM wallet_transactions
    GROUP BY wallet_id
) AS totals
WHERE w.wallet_id = totals.wallet_id;

-- Update the planner's statistics now the tables are much bigger
ANALYZE;

-- How many rows each table now has
SELECT 'customers' AS table_name, count(*) AS row_count FROM customers
UNION ALL SELECT 'wallets', count(*) FROM wallets
UNION ALL SELECT 'properties', count(*) FROM properties
UNION ALL SELECT 'wallet_transactions', count(*) FROM wallet_transactions
UNION ALL SELECT 'loan_applications', count(*) FROM loan_applications
UNION ALL SELECT 'loans', count(*) FROM loans
UNION ALL SELECT 'repayment_schedules', count(*) FROM repayment_schedules
ORDER BY row_count DESC;
