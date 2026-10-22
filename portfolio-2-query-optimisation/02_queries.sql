-- RentMadeEasy business queries (Portfolio 2)
-- Five queries the RentMadeEasy team runs every day. These are measured
-- before and after adding indexes.
-- Run after 01_bulk_data.sql:
--   \i /portfolio/portfolio-2-query-optimisation/02_queries.sql

SET search_path TO rme;
\pset pager off

-- Q1. Wallet statement
-- Support looks up a customer by email and sees their 20 latest wallet transactions.
\echo '--- Q1. Wallet statement for customer837'
SELECT t.created_at, t.transaction_type, t.amount, t.reference, t.description
FROM customers c
JOIN wallets w             ON w.customer_id = c.customer_id
JOIN wallet_transactions t ON t.wallet_id = w.wallet_id
WHERE c.email = 'customer837@mail.com'
ORDER BY t.created_at DESC
LIMIT 20;

-- Q2. Overdue instalments
-- The collections team's list of the 20 oldest overdue instalments,
-- with the customer's phone number.
\echo '--- Q2. Overdue instalments, oldest first'
SELECT c.first_name, c.last_name, c.phone, rs.loan_id, rs.installment_number, rs.due_date, rs.amount_due
FROM repayment_schedules rs
JOIN loans l             ON l.loan_id = rs.loan_id
JOIN loan_applications a ON a.application_id = l.application_id
JOIN customers c         ON c.customer_id = a.customer_id
WHERE rs.status = 'OVERDUE'
ORDER BY rs.due_date
LIMIT 20;

-- Q3. Customer loan history
-- Every loan a customer has had, with how many instalments are paid and overdue.
\echo '--- Q3. Loan history for customer837'
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

-- Q4. Repayments due this month
-- Finance's total of instalments due in October 2026, by status.
\echo '--- Q4. Instalments due in October 2026'
SELECT status, COUNT(*) AS instalments, SUM(amount_due) AS total_amount
FROM repayment_schedules
WHERE due_date >= DATE '2026-10-01'
  AND due_date <  DATE '2026-11-01'
GROUP BY status
ORDER BY status;

-- Q5. Applications waiting for review
-- The loan officers' queue: the 20 oldest pending applications.
\echo '--- Q5. Oldest pending applications'
SELECT a.application_id, c.first_name, c.last_name, a.requested_amount, a.applied_at
FROM loan_applications a
JOIN customers c ON c.customer_id = a.customer_id
WHERE a.status = 'PENDING'
ORDER BY a.applied_at
LIMIT 20;
