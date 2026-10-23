-- RentMadeEasy transactions that fail and roll back (Portfolio 3)
-- Two payments go wrong part of the way through. In both, PostgreSQL
-- undoes every change the transaction made, so no money is created or lost.
-- Nothing is saved, so this file can be run as many times as you like:
--   \i /portfolio/portfolio-3-transactions-concurrency/02_rollback.sql

SET search_path TO rme;
\pset pager off

-- Failure 1: the same top-up is recorded twice
-- Funke (wallet 4) has 8,000. The payment provider resends the notification
-- for a top-up that was already recorded as TOP-0012. The balance is raised
-- first, then recording the transaction fails because the reference is UNIQUE.

\echo '--- Failure 1: Funke''s balance before'
SELECT wallet_id, balance FROM wallets WHERE wallet_id = 4;

BEGIN;

-- 1. Add the money to the balance (this works)
UPDATE wallets SET balance = balance + 104000 WHERE wallet_id = 4;

\echo '--- Inside the transaction the balance has already gone up'
SELECT wallet_id, balance FROM wallets WHERE wallet_id = 4;

-- 2. Record the top-up (this fails: TOP-0012 already exists)
INSERT INTO wallet_transactions (wallet_id, transaction_type, amount, reference, description)
VALUES (4, 'CREDIT', 104000, 'TOP-0012', 'Wallet top-up');

-- After an error PostgreSQL refuses any more statements until the transaction ends
ROLLBACK;

\echo '--- After ROLLBACK the 104,000 from step 1 is gone too'
SELECT wallet_id, balance FROM wallets WHERE wallet_id = 4;

-- Failure 2: not enough money in the wallet
-- Ngozi (wallet 2) has 2,000 but instalment 4 of her loan (schedule 7) is
-- 181,500. Taking the money out would leave -179,500, which breaks the rule
-- CHECK (balance >= 0) on wallets.

\echo '--- Failure 2: Ngozi''s wallet and instalment 4 before'
SELECT wallet_id, balance FROM wallets WHERE wallet_id = 2;
SELECT schedule_id, amount_due, status FROM repayment_schedules WHERE schedule_id = 7;

BEGIN;

-- 1. Take the money out of the wallet (this fails the CHECK)
UPDATE wallets SET balance = balance - 181500 WHERE wallet_id = 2;

-- 2-4 are never reached, so no debit, repayment or PAID status is saved
INSERT INTO wallet_transactions (wallet_id, transaction_type, amount, reference, description)
VALUES (2, 'DEBIT', 181500, 'RPY-0011', 'Loan 2 instalment 4');

UPDATE repayment_schedules SET status = 'PAID' WHERE schedule_id = 7;

ROLLBACK;

\echo '--- After ROLLBACK: nothing changed'
SELECT wallet_id, balance FROM wallets WHERE wallet_id = 2;
SELECT schedule_id, amount_due, status FROM repayment_schedules WHERE schedule_id = 7;
SELECT count(*) AS saved_rpy_0011 FROM wallet_transactions WHERE reference = 'RPY-0011';

\echo '--- Both balances still match their transaction history'
SELECT w.wallet_id,
       w.balance,
       SUM(CASE t.transaction_type WHEN 'CREDIT' THEN t.amount ELSE -t.amount END) AS from_history
FROM wallets w
JOIN wallet_transactions t ON t.wallet_id = w.wallet_id
WHERE w.wallet_id IN (2, 4)
GROUP BY w.wallet_id, w.balance
ORDER BY w.wallet_id;
