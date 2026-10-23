-- RentMadeEasy isolation levels: session A, the audit (Portfolio 3)
-- A staff member checks that Ngozi's balance (wallet 2, 2,000) matches her
-- transaction history. The check is two queries: first the balance, then the
-- total from the history. Between the two, a 5,000 top-up is saved in session B.
-- Part 1 runs the audit in READ COMMITTED (the PostgreSQL default).
-- Part 2 runs it again in REPEATABLE READ.
--
-- Open two psql windows. Start this file first, in window 1:
--   \i /portfolio/portfolio-3-transactions-concurrency/04_isolation_session_a.sql
-- and follow the messages. Session B is 04_isolation_session_b.sql.

SET search_path TO rme;
\pset pager off

-- Start from 2,000 every time, so the file can be run again
DELETE FROM wallet_transactions WHERE reference = 'TOP-0015';
UPDATE wallets SET balance = 2000 WHERE wallet_id = 2;

\echo ''
\echo '=== Part 1: READ COMMITTED'
BEGIN ISOLATION LEVEL READ COMMITTED;
SHOW transaction_isolation;

\echo 'Audit step 1: the balance'
SELECT wallet_id, balance FROM wallets WHERE wallet_id = 2;

\prompt '>>> Now start session B in window 2. When B tells you, press Enter here. ' go

\echo 'Audit step 2: the total from the history'
SELECT SUM(CASE transaction_type WHEN 'CREDIT' THEN amount ELSE -amount END) AS from_history
FROM wallet_transactions
WHERE wallet_id = 2;

\echo 'Step 1 again: the same query now gives a different answer'
SELECT wallet_id, balance FROM wallets WHERE wallet_id = 2;

COMMIT;
\echo 'Problem: the audit compared 2,000 with 7,000 and reported a mismatch that does not exist.'
\echo 'Each query saw the data as it was when that query started (non-repeatable read).'

-- Undo the top-up so Part 2 starts from 2,000 again
DELETE FROM wallet_transactions WHERE reference = 'TOP-0015';
UPDATE wallets SET balance = 2000 WHERE wallet_id = 2;

\echo ''
\echo '=== Part 2: REPEATABLE READ'
\echo 'Balance reset to 2,000'
BEGIN ISOLATION LEVEL REPEATABLE READ;
SHOW transaction_isolation;

-- The first query takes a snapshot. Every later query in this transaction
-- sees the data as it was at that moment.
\echo 'Audit step 1: the balance'
SELECT wallet_id, balance FROM wallets WHERE wallet_id = 2;

\prompt '>>> Go to session B and press Enter there. When B tells you, press Enter here. ' go

\echo 'Audit step 2: the total from the history'
SELECT SUM(CASE transaction_type WHEN 'CREDIT' THEN amount ELSE -amount END) AS from_history
FROM wallet_transactions
WHERE wallet_id = 2;

\echo 'Step 1 again: still the same answer'
SELECT wallet_id, balance FROM wallets WHERE wallet_id = 2;

COMMIT;
\echo 'Fixed: the audit compared 2,000 with 2,000, both from the same moment.'

\echo ''
\echo 'After COMMIT a new transaction sees the top-up, and it still matches'
SELECT w.wallet_id,
       w.balance,
       SUM(CASE t.transaction_type WHEN 'CREDIT' THEN t.amount ELSE -t.amount END) AS from_history
FROM wallets w
JOIN wallet_transactions t ON t.wallet_id = w.wallet_id
WHERE w.wallet_id = 2
GROUP BY w.wallet_id, w.balance;
