-- RentMadeEasy constraint tests (Portfolio 1)
-- Each statement below breaks a rule on purpose, so every one should fail
-- with an ERROR. Nothing in the data is changed.
-- Run after 01_schema.sql and 02_seed.sql:
--   \i /portfolio/portfolio-1-database-design/03_constraint_tests.sql

SET search_path TO rme;

\echo '--- Test 1: UNIQUE - two customers cannot share an email'
INSERT INTO customers (first_name, last_name, email, phone, date_of_birth)
VALUES ('Tunde', 'Bakare', 'adebayo.ogunleye@mail.com', '08031000099', '1995-01-01');

\echo '--- Test 2: CHECK - a customer cannot refer themselves'
UPDATE customers SET referred_by = 5 WHERE customer_id = 5;

\echo '--- Test 3: UNIQUE - a customer cannot have a second wallet'
INSERT INTO wallets (customer_id, account_number) VALUES (1, '9000000099');

\echo '--- Test 4: CHECK - a wallet balance cannot go below zero (Adebayo has 8,000)'
UPDATE wallets SET balance = balance - 10000 WHERE wallet_id = 1;

\echo '--- Test 5: UNIQUE - the same payment reference cannot be recorded twice'
INSERT INTO wallet_transactions (wallet_id, transaction_type, amount, reference)
VALUES (1, 'CREDIT', 250000, 'TOP-0001');

\echo '--- Test 6: CHECK - transaction type must be CREDIT or DEBIT'
INSERT INTO wallet_transactions (wallet_id, transaction_type, amount, reference)
VALUES (1, 'BONUS', 5000, 'TOP-9999');

\echo '--- Test 7: FOREIGN KEY - cannot apply for a property that does not exist'
INSERT INTO loan_applications (customer_id, property_id, product_id, requested_amount, tenure_months)
VALUES (7, 99, 1, 500000, 6);

\echo '--- Test 8: FOREIGN KEY - cannot delete a customer who has a wallet and a loan (Funke)'
DELETE FROM customers WHERE customer_id = 4;

\echo '--- Test 9: UNIQUE - an application cannot become two loans'
INSERT INTO loans (application_id, principal, monthly_interest_rate, tenure_months)
VALUES (1, 600000, 0.0400, 3);

\echo '--- Test 10: UNIQUE - a loan cannot have two instalment 1s'
INSERT INTO repayment_schedules (loan_id, installment_number, due_date, amount_due)
VALUES (1, 1, '2026-07-01', 224000);

\echo '--- Test 11: TRIGGER - amount above the product maximum (Rent Quick max is 1,000,000)'
INSERT INTO loan_applications (customer_id, property_id, product_id, requested_amount, tenure_months)
VALUES (7, 4, 2, 1500000, 6);

\echo '--- Test 12: TRIGGER - tenure longer than the product allows (Rent Quick max is 6 months)'
INSERT INTO loan_applications (customer_id, property_id, product_id, requested_amount, tenure_months)
VALUES (7, 4, 2, 500000, 9);

\echo '--- Test 13: TRIGGER - amount more than the annual rent (Surulere rent is 650,000)'
INSERT INTO loan_applications (customer_id, property_id, product_id, requested_amount, tenure_months)
VALUES (7, 2, 1, 2000000, 6);

\echo '--- Test 14: A valid application IS accepted (then undone with ROLLBACK)'
BEGIN;
INSERT INTO loan_applications (customer_id, property_id, product_id, requested_amount, tenure_months)
VALUES (7, 2, 2, 600000, 6)
RETURNING application_id, customer_id, requested_amount, status;
ROLLBACK;
