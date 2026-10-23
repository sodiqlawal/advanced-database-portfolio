-- RentMadeEasy transaction that commits (Portfolio 3)
-- Ibrahim (customer 3, wallet 3) missed his October instalment
-- (schedule 12, 236,000). He tops up his wallet and pays it.
-- Paying an instalment changes four tables, so all four changes are put in
-- one transaction: either they all happen or none of them do.
-- Run once, after the Portfolio 1 and 2 files:
--   \i /portfolio/portfolio-3-transactions-concurrency/01_commit.sql
-- To run it again, reload the Portfolio 1 schema and seed first.

SET search_path TO rme;
\pset pager off

\echo '--- Before: Ibrahim''s wallet and instalment 3'
SELECT wallet_id, balance FROM wallets WHERE wallet_id = 3;
SELECT schedule_id, amount_due, status FROM repayment_schedules WHERE schedule_id = 12;

-- Transaction 1: top up the wallet with 186,000 (50,000 + 186,000 = 236,000)
\echo '--- Transaction 1: top-up'
BEGIN;

UPDATE wallets SET balance = balance + 186000 WHERE wallet_id = 3;

INSERT INTO wallet_transactions (wallet_id, transaction_type, amount, reference, description)
VALUES (3, 'CREDIT', 186000, 'TOP-0012', 'Wallet top-up');

COMMIT;

-- Transaction 2: pay instalment 3 from the wallet
\echo '--- Transaction 2: repayment'
BEGIN;

-- 1. Take the money out of the wallet
UPDATE wallets SET balance = balance - 236000 WHERE wallet_id = 3;

-- 2. Record the money leaving the wallet
INSERT INTO wallet_transactions (wallet_id, transaction_type, amount, reference, description)
VALUES (3, 'DEBIT', 236000, 'RPY-0010', 'Loan 3 instalment 3');

-- 3. Link the payment to the instalment
INSERT INTO repayments (schedule_id, transaction_id, amount)
SELECT 12, transaction_id, 236000
FROM wallet_transactions
WHERE reference = 'RPY-0010';

-- 4. Mark the instalment as paid
UPDATE repayment_schedules SET status = 'PAID' WHERE schedule_id = 12;

COMMIT;

\echo '--- After: the wallet is empty and instalment 3 is paid'
SELECT wallet_id, balance FROM wallets WHERE wallet_id = 3;
SELECT schedule_id, amount_due, status FROM repayment_schedules WHERE schedule_id = 12;

SELECT r.repayment_id, r.schedule_id, r.amount, t.reference, t.transaction_type
FROM repayments r
JOIN wallet_transactions t ON t.transaction_id = r.transaction_id
WHERE r.schedule_id = 12;

\echo '--- The balance still matches the transaction history'
SELECT w.balance,
       SUM(CASE t.transaction_type WHEN 'CREDIT' THEN t.amount ELSE -t.amount END) AS from_history
FROM wallets w
JOIN wallet_transactions t ON t.wallet_id = w.wallet_id
WHERE w.wallet_id = 3
GROUP BY w.balance;
