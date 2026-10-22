-- RentMadeEasy indexes (Portfolio 2)
-- One index for each slow step found in 03_explain_before.sql.
-- PostgreSQL only creates indexes for primary keys and UNIQUE columns,
-- so foreign keys such as wallet_id and customer_id have none yet.
-- Run after 03_explain_before.sql:
--   \i /portfolio/portfolio-2-query-optimisation/04_indexes.sql

SET search_path TO rme;
\pset pager off

-- Q1. Wallet statement
-- Finds one wallet's transactions already in created_at order,
-- so PostgreSQL can read the newest 20 and stop.
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet_created
    ON wallet_transactions (wallet_id, created_at);

-- Q2. Overdue instalments
-- A partial index: it only stores OVERDUE rows (about 1 in 10),
-- in due_date order, so it is small and already sorted for the query.
CREATE INDEX IF NOT EXISTS idx_repayment_schedules_overdue_due
    ON repayment_schedules (due_date)
    WHERE status = 'OVERDUE';

-- Q3. Customer loan history
-- Finds a customer's applications without reading all of them.
CREATE INDEX IF NOT EXISTS idx_loan_applications_customer
    ON loan_applications (customer_id);

-- Q4. Repayments due this month
-- Finds the instalments in a date range.
CREATE INDEX IF NOT EXISTS idx_repayment_schedules_due
    ON repayment_schedules (due_date);

-- Q5. Applications waiting for review
-- A partial index of PENDING applications in applied_at order,
-- so the oldest 20 can be read straight from the front of the index.
CREATE INDEX IF NOT EXISTS idx_loan_applications_pending_applied
    ON loan_applications (applied_at)
    WHERE status = 'PENDING';

-- Update the planner's statistics
ANALYZE;

-- The new indexes and how much space each one takes
SELECT tablename AS table_name,
       indexname AS index_name,
       pg_size_pretty(pg_relation_size((schemaname || '.' || indexname)::regclass)) AS index_size
FROM pg_indexes
WHERE schemaname = 'rme'
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;
