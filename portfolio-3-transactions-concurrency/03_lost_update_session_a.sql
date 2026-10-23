-- RentMadeEasy lost update and its fix: session A (Portfolio 3)
-- Two top-ups reach Funke's wallet (wallet 4, 8,000) at the same moment:
-- 5,000 in session A and 3,000 in session B. Like a real app, each session
-- reads the balance, adds its amount, and writes the new total back.
-- Part 1 shows one top-up being lost. Part 2 fixes it with SELECT ... FOR UPDATE.
--
-- Open two psql windows. Start this file first, in window 1:
--   \i /portfolio/portfolio-3-transactions-concurrency/03_lost_update_session_a.sql
-- and follow the messages. Session B is 03_lost_update_session_b.sql.

SET search_path TO rme;
\pset pager off

-- Start from 8,000 every time, so the file can be run again
DELETE FROM wallet_transactions WHERE reference IN ('TOP-0013', 'TOP-0014');
UPDATE wallets SET balance = 8000 WHERE wallet_id = 4;

\echo ''
\echo '=== Part 1: the lost update (no locking)'
BEGIN;

-- Read the balance and keep it in :bal, like the app holding it in a variable
SELECT balance AS bal FROM wallets WHERE wallet_id = 4 \gset
\echo 'Session A read the balance:' :bal

\prompt '>>> Now start session B in window 2. When B tells you, press Enter here. ' go

-- Write the total worked out from the old balance: 8,000 + 5,000
UPDATE wallets SET balance = :bal + 5000 WHERE wallet_id = 4;

INSERT INTO wallet_transactions (wallet_id, transaction_type, amount, reference, description)
VALUES (4, 'CREDIT', 5000, 'TOP-0013', 'Wallet top-up');

COMMIT;

\echo 'Session A saved the balance:'
SELECT wallet_id, balance FROM wallets WHERE wallet_id = 4;

\prompt '>>> Go to session B and press Enter there. When B tells you, press Enter here. ' go

-- Undo Part 1 so Part 2 starts from 8,000 again
DELETE FROM wallet_transactions WHERE reference IN ('TOP-0013', 'TOP-0014');
UPDATE wallets SET balance = 8000 WHERE wallet_id = 4;

\echo ''
\echo '=== Part 2: the fix (SELECT ... FOR UPDATE)'
\echo 'Balance reset to 8,000'
BEGIN;

-- FOR UPDATE locks the row. Any other session that tries to lock it waits
-- until this transaction ends.
SELECT balance AS bal FROM wallets WHERE wallet_id = 4 FOR UPDATE \gset
\echo 'Session A read and locked the balance:' :bal

\prompt '>>> Go to session B and press Enter there. B will wait. Then come back and press Enter here. ' go

UPDATE wallets SET balance = :bal + 5000 WHERE wallet_id = 4;

INSERT INTO wallet_transactions (wallet_id, transaction_type, amount, reference, description)
VALUES (4, 'CREDIT', 5000, 'TOP-0013', 'Wallet top-up');

-- COMMIT releases the lock, and session B carries on straight away
COMMIT;

\echo 'Session A saved the balance and released the lock:'
SELECT wallet_id, balance FROM wallets WHERE wallet_id = 4;
\echo '>>> Session A is done. Look at window 2 for the final result.'
