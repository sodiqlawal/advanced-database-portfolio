-- RentMadeEasy isolation levels: session B, the top-up (Portfolio 3)
-- Start this in window 2 only when session A tells you to:
--   \i /portfolio/portfolio-3-transactions-concurrency/04_isolation_session_b.sql

SET search_path TO rme;
\pset pager off

\echo ''
\echo '=== Part 1: Ngozi tops up 5,000 while the audit is running'
BEGIN;

UPDATE wallets SET balance = balance + 5000 WHERE wallet_id = 2;

INSERT INTO wallet_transactions (wallet_id, transaction_type, amount, reference, description)
VALUES (2, 'CREDIT', 5000, 'TOP-0015', 'Wallet top-up');

COMMIT;
SELECT wallet_id, balance FROM wallets WHERE wallet_id = 2;

\prompt '>>> Go to window 1 (session A) and press Enter THERE first. Press Enter here only after A says: Go to session B. ' go

\echo ''
\echo '=== Part 2: the same top-up while the audit is running'
BEGIN;

UPDATE wallets SET balance = balance + 5000 WHERE wallet_id = 2;

INSERT INTO wallet_transactions (wallet_id, transaction_type, amount, reference, description)
VALUES (2, 'CREDIT', 5000, 'TOP-0015', 'Wallet top-up');

COMMIT;
SELECT wallet_id, balance FROM wallets WHERE wallet_id = 2;

\echo '>>> Session B is done. Go to session A and press Enter there.'
