-- RentMadeEasy lost update and its fix: session B (Portfolio 3)
-- Start this in window 2 only when session A tells you to:
--   \i /portfolio/portfolio-3-transactions-concurrency/03_lost_update_session_b.sql

SET search_path TO rme;
\pset pager off

\echo ''
\echo '=== Part 1: the lost update (no locking)'
BEGIN;

SELECT balance AS bal FROM wallets WHERE wallet_id = 4 \gset
\echo 'Session B read the balance:' :bal

\prompt '>>> Go to session A and press Enter there. When A tells you, press Enter here. ' go

-- Session A has already saved 13,000, but B still uses the 8,000 it read:
-- 8,000 + 3,000 = 11,000 overwrites A's top-up
UPDATE wallets SET balance = :bal + 3000 WHERE wallet_id = 4;

INSERT INTO wallet_transactions (wallet_id, transaction_type, amount, reference, description)
VALUES (4, 'CREDIT', 3000, 'TOP-0014', 'Wallet top-up');

COMMIT;

\echo 'Result: both top-ups are in the history, but the balance only has one'
SELECT w.wallet_id,
       w.balance,
       SUM(CASE t.transaction_type WHEN 'CREDIT' THEN t.amount ELSE -t.amount END) AS from_history
FROM wallets w
JOIN wallet_transactions t ON t.wallet_id = w.wallet_id
WHERE w.wallet_id = 4
GROUP BY w.wallet_id, w.balance;

\prompt '>>> Go to session A and press Enter there. When A tells you, press Enter here. ' go

\echo ''
\echo '=== Part 2: the fix (SELECT ... FOR UPDATE)'
BEGIN;

\echo 'Session B is waiting for session A to release the lock...'
SELECT balance AS bal FROM wallets WHERE wallet_id = 4 FOR UPDATE \gset
\echo 'Session B got the lock and read the balance:' :bal

-- B now starts from A's saved 13,000: 13,000 + 3,000 = 16,000
UPDATE wallets SET balance = :bal + 3000 WHERE wallet_id = 4;

INSERT INTO wallet_transactions (wallet_id, transaction_type, amount, reference, description)
VALUES (4, 'CREDIT', 3000, 'TOP-0014', 'Wallet top-up');

COMMIT;

\echo 'Result: both top-ups are kept and the balance matches the history'
SELECT w.wallet_id,
       w.balance,
       SUM(CASE t.transaction_type WHEN 'CREDIT' THEN t.amount ELSE -t.amount END) AS from_history
FROM wallets w
JOIN wallet_transactions t ON t.wallet_id = w.wallet_id
WHERE w.wallet_id = 4
GROUP BY w.wallet_id, w.balance;
