-- RentMadeEasy execution plans AFTER adding indexes (Portfolio 2)
-- The same EXPLAIN ANALYZE queries as 03_explain_before.sql, run again after
-- 04_indexes.sql, so the plans and times can be compared.
-- Run it twice and use the second run: the first run also includes the time
-- to read the tables from disk into memory.
--   \i /portfolio/portfolio-2-query-optimisation/05_explain_after.sql

SET search_path TO rme;
\pset pager off

\echo '--- Q1. Wallet statement for customer837'
EXPLAIN ANALYZE
SELECT t.created_at, t.transaction_type, t.amount, t.reference, t.description
FROM customers c
JOIN wallets w             ON w.customer_id = c.customer_id
JOIN wallet_transactions t ON t.wallet_id = w.wallet_id
WHERE c.email = 'customer837@mail.com'
ORDER BY t.created_at DESC
LIMIT 20;

\echo '--- Q2. Overdue instalments, oldest first'
EXPLAIN ANALYZE
SELECT c.first_name, c.last_name, c.phone, rs.loan_id, rs.installment_number, rs.due_date, rs.amount_due
FROM repayment_schedules rs
JOIN loans l             ON l.loan_id = rs.loan_id
JOIN loan_applications a ON a.application_id = l.application_id
JOIN customers c         ON c.customer_id = a.customer_id
WHERE rs.status = 'OVERDUE'
ORDER BY rs.due_date
LIMIT 20;

\echo '--- Q3. Loan history for customer837'
EXPLAIN ANALYZE
SELECT l.loan_id, l.principal, l.status, l.disbursed_at,
       COUNT(*) FILTER (WHERE rs.status = 'PAID')    AS paid,
       COUNT(*) FILTER (WHERE rs.status = 'OVERDUE') AS overdue,
       COUNT(*) AS total_instalments
FROM customers c
JOIN loan_applications a    ON a.customer_id = c.customer_id
JOIN loans l                ON l.application_id = a.application_id
JOIN repayment_schedules rs ON rs.loan_id = l.loan_id
WHERE c.email = 'customer837@mail.com'
GROUP BY l.loan_id
ORDER BY l.disbursed_at;

\echo '--- Q4. Instalments due in October 2026'
EXPLAIN ANALYZE
SELECT status, COUNT(*) AS instalments, SUM(amount_due) AS total_amount
FROM repayment_schedules
WHERE due_date >= DATE '2026-10-01'
  AND due_date <  DATE '2026-11-01'
GROUP BY status
ORDER BY status;

\echo '--- Q5. Oldest pending applications'
EXPLAIN ANALYZE
SELECT a.application_id, c.first_name, c.last_name, a.requested_amount, a.applied_at
FROM loan_applications a
JOIN customers c ON c.customer_id = a.customer_id
WHERE a.status = 'PENDING'
ORDER BY a.applied_at
LIMIT 20;
