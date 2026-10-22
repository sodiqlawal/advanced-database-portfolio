-- RentMadeEasy sample data (Portfolio 1)
-- Run after 01_schema.sql.
-- Run: \i /portfolio/portfolio-1-database-design/02_seed.sql

SET search_path TO rme;

-- 8 customers. Ngozi and Funke were referred by Adebayo; Halima by Ibrahim.
INSERT INTO customers (first_name, last_name, email, phone, date_of_birth, created_at) VALUES
('Adebayo', 'Ogunleye', 'adebayo.ogunleye@mail.com', '08031000001', '1990-04-12', '2026-03-20'),
('Ngozi',   'Nwosu',    'ngozi.nwosu@mail.com',      '08031000002', '1994-08-23', '2026-05-15'),
('Ibrahim', 'Musa',     'ibrahim.musa@mail.com',     '08031000003', '1988-01-30', '2026-06-10'),
('Funke',   'Adeyemi',  'funke.adeyemi@mail.com',    '08031000004', '1992-11-05', '2026-09-01'),
('Emeka',   'Obi',      'emeka.obi@mail.com',        '08031000005', '1996-06-17', '2026-08-02'),
('Halima',  'Bello',    'halima.bello@mail.com',     '08031000006', '1991-02-09', '2026-10-10'),
('Segun',   'Afolabi',  'segun.afolabi@mail.com',    '08031000007', '1985-09-14', '2026-08-25'),
('Chioma',  'Ike',      'chioma.ike@mail.com',       '08031000008', '1998-12-01', '2026-10-20');

UPDATE customers SET referred_by = 1 WHERE customer_id IN (2, 4);
UPDATE customers SET referred_by = 3 WHERE customer_id = 6;

INSERT INTO landlords (full_name, phone, bank_name, account_number) VALUES
('Olumide Bakare', '08051000001', 'Access Bank', '0012345671'),
('Grace Udoh',     '08051000002', 'Zenith Bank', '2012345672'),
('Sani Garba',     '08051000003', 'First Bank',  '3012345673'),
('Kemi Oladipo',   '08051000004', 'UBA',         '1012345674');

INSERT INTO properties (landlord_id, address, city, property_type, annual_rent) VALUES
(1, '14 Herbert Macaulay Way, Yaba',     'Lagos', 'MINI_FLAT',    1200000),
(1, '7 Adeniran Ogunsanya St, Surulere', 'Lagos', 'SELF_CONTAIN',  650000),
(2, '22 Admiralty Way, Lekki',           'Lagos', 'FLAT',         3500000),
(3, '5 Allen Avenue, Ikeja',             'Lagos', 'FLAT',         2400000),
(3, '31 Diya Street, Gbagada',           'Lagos', 'MINI_FLAT',    1500000),
(4, '9 Abraham Adesanya Rd, Ajah',       'Lagos', 'SELF_CONTAIN',  800000);

INSERT INTO loan_products (name, monthly_interest_rate, min_amount, max_amount, max_tenure_months) VALUES
('Rent Monthly', 0.0350,  200000,  3000000, 12),
('Rent Quick',   0.0400,  100000,  1000000,  6),
('Rent Premium', 0.0300, 1000000, 10000000, 12);

-- One wallet per customer. Balances match the transactions further down.
INSERT INTO wallets (customer_id, account_number, balance) VALUES
(1, '9000000001',  8000),
(2, '9000000002',  2000),
(3, '9000000003', 50000),
(4, '9000000004',  8000),
(5, '9000000005',     0),
(6, '9000000006',     0),
(7, '9000000007', 50000),
(8, '9000000008',     0);

-- 6 applications: 4 approved, 1 rejected, 1 still pending
INSERT INTO loan_applications (customer_id, property_id, product_id, requested_amount, tenure_months, status, applied_at) VALUES
(1, 2, 2,  600000, 3, 'APPROVED', '2026-05-28 09:30'),
(2, 1, 1,  900000, 6, 'APPROVED', '2026-06-27 14:10'),
(3, 5, 3, 1200000, 6, 'APPROVED', '2026-06-28 11:45'),
(4, 6, 2,  300000, 3, 'APPROVED', '2026-09-12 16:20'),
(5, 3, 3, 3000000, 12, 'REJECTED', '2026-08-10 10:00'),
(6, 4, 1, 2000000, 6, 'PENDING',  '2026-10-18 13:05');

-- Loans for the 4 approved applications
INSERT INTO loans (application_id, principal, monthly_interest_rate, tenure_months, status, disbursed_at) VALUES
(1,  600000, 0.0400, 3, 'COMPLETED', '2026-06-01 12:00'),
(2,  900000, 0.0350, 6, 'ACTIVE',    '2026-07-01 11:00'),
(3, 1200000, 0.0300, 6, 'ACTIVE',    '2026-07-01 14:00'),
(4,  300000, 0.0400, 3, 'ACTIVE',    '2026-09-15 10:00');

-- Monthly amount = (principal / months) + (principal x monthly rate)
-- Loan 1:  600,000 / 3 + 600,000 x 0.04  = 200,000 + 24,000 = 224,000
-- Loan 2:  900,000 / 6 + 900,000 x 0.035 = 150,000 + 31,500 = 181,500
-- Loan 3: 1,200,000 / 6 + 1,200,000 x 0.03 = 200,000 + 36,000 = 236,000
-- Loan 4:  300,000 / 3 + 300,000 x 0.04  = 100,000 + 12,000 = 112,000
INSERT INTO repayment_schedules (loan_id, installment_number, due_date, amount_due, status) VALUES
-- Loan 1 (Adebayo): fully paid
(1, 1, '2026-07-01', 224000, 'PAID'),
(1, 2, '2026-08-01', 224000, 'PAID'),
(1, 3, '2026-09-01', 224000, 'PAID'),
-- Loan 2 (Ngozi): paid up to date
(2, 1, '2026-08-01', 181500, 'PAID'),
(2, 2, '2026-09-01', 181500, 'PAID'),
(2, 3, '2026-10-01', 181500, 'PAID'),
(2, 4, '2026-11-01', 181500, 'PENDING'),
(2, 5, '2026-12-01', 181500, 'PENDING'),
(2, 6, '2027-01-01', 181500, 'PENDING'),
-- Loan 3 (Ibrahim): missed the October instalment
(3, 1, '2026-08-01', 236000, 'PAID'),
(3, 2, '2026-09-01', 236000, 'PAID'),
(3, 3, '2026-10-01', 236000, 'OVERDUE'),
(3, 4, '2026-11-01', 236000, 'PENDING'),
(3, 5, '2026-12-01', 236000, 'PENDING'),
(3, 6, '2027-01-01', 236000, 'PENDING'),
-- Loan 4 (Funke): first instalment paid
(4, 1, '2026-10-15', 112000, 'PAID'),
(4, 2, '2026-11-15', 112000, 'PENDING'),
(4, 3, '2026-12-15', 112000, 'PENDING');

-- Wallet transactions in date order. Customers fund their wallet (CREDIT),
-- then the instalment is taken from it (DEBIT).
INSERT INTO wallet_transactions (wallet_id, transaction_type, amount, reference, description, created_at) VALUES
(1, 'CREDIT', 250000, 'TOP-0001', 'Wallet top-up',            '2026-06-29 09:15'),  -- 1
(1, 'DEBIT',  224000, 'RPY-0001', 'Loan 1 instalment 1',      '2026-06-30 10:00'),  -- 2
(1, 'CREDIT', 200000, 'TOP-0002', 'Wallet top-up',            '2026-07-30 08:40'),  -- 3
(2, 'CREDIT', 181500, 'TOP-0003', 'Wallet top-up',            '2026-07-30 19:20'),  -- 4
(3, 'CREDIT', 236000, 'TOP-0004', 'Wallet top-up',            '2026-07-31 09:00'),  -- 5
(1, 'DEBIT',  224000, 'RPY-0002', 'Loan 1 instalment 2',      '2026-07-31 10:00'),  -- 6
(2, 'DEBIT',  181500, 'RPY-0003', 'Loan 2 instalment 1',      '2026-07-31 10:00'),  -- 7
(3, 'DEBIT',  236000, 'RPY-0004', 'Loan 3 instalment 1',      '2026-07-31 10:00'),  -- 8
(2, 'CREDIT', 200000, 'TOP-0005', 'Wallet top-up',            '2026-08-29 11:00'),  -- 9
(1, 'CREDIT', 230000, 'TOP-0006', 'Wallet top-up',            '2026-08-30 12:05'),  -- 10
(1, 'DEBIT',  224000, 'RPY-0005', 'Loan 1 instalment 3',      '2026-08-31 10:00'),  -- 11
(2, 'DEBIT',  181500, 'RPY-0006', 'Loan 2 instalment 2',      '2026-08-31 10:00'),  -- 12
(3, 'CREDIT', 236000, 'TOP-0007', 'Wallet top-up',            '2026-08-31 16:30'),  -- 13
(3, 'DEBIT',  236000, 'RPY-0007', 'Loan 3 instalment 2',      '2026-09-01 10:00'),  -- 14
(7, 'CREDIT',  50000, 'TOP-0008', 'Wallet top-up',            '2026-09-02 12:00'),  -- 15
(2, 'CREDIT', 165000, 'TOP-0009', 'Wallet top-up',            '2026-09-30 07:50'),  -- 16
(2, 'DEBIT',  181500, 'RPY-0008', 'Loan 2 instalment 3',      '2026-09-30 10:00'),  -- 17
(3, 'CREDIT',  50000, 'TOP-0010', 'Wallet top-up (not enough for instalment 3)', '2026-10-05 13:10'),  -- 18
(4, 'CREDIT', 120000, 'TOP-0011', 'Wallet top-up',            '2026-10-13 18:00'),  -- 19
(4, 'DEBIT',  112000, 'RPY-0009', 'Loan 4 instalment 1',      '2026-10-14 10:00');  -- 20

-- Each repayment links the instalment it paid to the wallet debit that paid it
INSERT INTO repayments (schedule_id, transaction_id, amount, paid_at) VALUES
(1,   2, 224000, '2026-06-30 10:00'),
(2,   6, 224000, '2026-07-31 10:00'),
(4,   7, 181500, '2026-07-31 10:00'),
(10,  8, 236000, '2026-07-31 10:00'),
(3,  11, 224000, '2026-08-31 10:00'),
(5,  12, 181500, '2026-08-31 10:00'),
(11, 14, 236000, '2026-09-01 10:00'),
(6,  17, 181500, '2026-09-30 10:00'),
(16, 20, 112000, '2026-10-14 10:00');
