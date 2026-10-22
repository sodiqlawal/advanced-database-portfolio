-- RentMadeEasy database schema (Portfolio 1)
-- PostgreSQL 16
-- Run: \i /portfolio/portfolio-1-database-design/01_schema.sql

DROP SCHEMA IF EXISTS rme CASCADE;
CREATE SCHEMA rme;
SET search_path TO rme;

-- Customers (tenants). referred_by points to another customer who referred them.
CREATE TABLE customers (
    customer_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name     VARCHAR(60)  NOT NULL,
    last_name      VARCHAR(60)  NOT NULL,
    email          VARCHAR(160) NOT NULL UNIQUE,
    phone          VARCHAR(15)  NOT NULL UNIQUE,
    date_of_birth  DATE         NOT NULL,
    referred_by    INT REFERENCES customers (customer_id),
    created_at     TIMESTAMP    NOT NULL DEFAULT now(),
    CHECK (referred_by <> customer_id)
);

CREATE TABLE landlords (
    landlord_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name       VARCHAR(120) NOT NULL,
    phone           VARCHAR(15)  NOT NULL UNIQUE,
    bank_name       VARCHAR(80)  NOT NULL,
    account_number  CHAR(10)     NOT NULL
);

CREATE TABLE properties (
    property_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    landlord_id    INT NOT NULL REFERENCES landlords (landlord_id),
    address        VARCHAR(200) NOT NULL,
    city           VARCHAR(60)  NOT NULL,
    property_type  VARCHAR(20)  NOT NULL
                   CHECK (property_type IN ('SELF_CONTAIN', 'MINI_FLAT', 'FLAT', 'DUPLEX')),
    annual_rent    NUMERIC(14,2) NOT NULL CHECK (annual_rent > 0)
);

-- Each customer has exactly one wallet (UNIQUE on customer_id)
CREATE TABLE wallets (
    wallet_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id     INT NOT NULL UNIQUE REFERENCES customers (customer_id),
    account_number  CHAR(10) NOT NULL UNIQUE,
    balance         NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (balance >= 0)
);

-- Every money movement in or out of a wallet
CREATE TABLE wallet_transactions (
    transaction_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    wallet_id         INT NOT NULL REFERENCES wallets (wallet_id),
    transaction_type  VARCHAR(10) NOT NULL CHECK (transaction_type IN ('CREDIT', 'DEBIT')),
    amount            NUMERIC(14,2) NOT NULL CHECK (amount > 0),
    reference         VARCHAR(40) NOT NULL UNIQUE,  -- stops the same payment being recorded twice
    description       VARCHAR(200),
    created_at        TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE loan_products (
    product_id             INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                   VARCHAR(60) NOT NULL UNIQUE,
    monthly_interest_rate  NUMERIC(5,4) NOT NULL CHECK (monthly_interest_rate > 0),
    min_amount             NUMERIC(14,2) NOT NULL CHECK (min_amount > 0),
    max_amount             NUMERIC(14,2) NOT NULL,
    max_tenure_months      INT NOT NULL CHECK (max_tenure_months BETWEEN 1 AND 12),
    CHECK (max_amount >= min_amount)
);

CREATE TABLE loan_applications (
    application_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id       INT NOT NULL REFERENCES customers (customer_id),
    property_id       INT NOT NULL REFERENCES properties (property_id),
    product_id        INT NOT NULL REFERENCES loan_products (product_id),
    requested_amount  NUMERIC(14,2) NOT NULL CHECK (requested_amount > 0),
    tenure_months     INT NOT NULL CHECK (tenure_months BETWEEN 1 AND 12),
    status            VARCHAR(10) NOT NULL DEFAULT 'PENDING'
                      CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    applied_at        TIMESTAMP NOT NULL DEFAULT now()
);

-- A loan is created from one approved application (UNIQUE makes it 1:1).
-- The interest rate is copied from the product so later price changes
-- do not affect existing loans.
CREATE TABLE loans (
    loan_id                INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    application_id         INT NOT NULL UNIQUE REFERENCES loan_applications (application_id),
    principal              NUMERIC(14,2) NOT NULL CHECK (principal > 0),
    monthly_interest_rate  NUMERIC(5,4)  NOT NULL,
    tenure_months          INT NOT NULL,
    status                 VARCHAR(10) NOT NULL DEFAULT 'ACTIVE'
                           CHECK (status IN ('ACTIVE', 'COMPLETED', 'DEFAULTED')),
    disbursed_at           TIMESTAMP NOT NULL DEFAULT now()
);

-- One row per monthly instalment of a loan
CREATE TABLE repayment_schedules (
    schedule_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    loan_id             INT NOT NULL REFERENCES loans (loan_id),
    installment_number  INT NOT NULL,
    due_date            DATE NOT NULL,
    amount_due          NUMERIC(14,2) NOT NULL CHECK (amount_due > 0),
    status              VARCHAR(10) NOT NULL DEFAULT 'PENDING'
                        CHECK (status IN ('PENDING', 'PAID', 'OVERDUE')),
    UNIQUE (loan_id, installment_number)
);

-- A payment made for an instalment, taken from the customer's wallet
CREATE TABLE repayments (
    repayment_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    schedule_id     INT NOT NULL REFERENCES repayment_schedules (schedule_id),
    transaction_id  INT NOT NULL UNIQUE REFERENCES wallet_transactions (transaction_id),
    amount          NUMERIC(14,2) NOT NULL CHECK (amount > 0),
    paid_at         TIMESTAMP NOT NULL DEFAULT now()
);

-- Trigger: an application must fit the product limits and cannot be more
-- than the property's annual rent. A CHECK constraint cannot do this
-- because the limits are stored in other tables.
CREATE FUNCTION check_application() RETURNS trigger AS $$
DECLARE
    prod  loan_products%ROWTYPE;
    rent  NUMERIC(14,2);
BEGIN
    SELECT * INTO prod FROM loan_products WHERE product_id = NEW.product_id;
    SELECT annual_rent INTO rent FROM properties WHERE property_id = NEW.property_id;

    IF NEW.requested_amount < prod.min_amount OR NEW.requested_amount > prod.max_amount THEN
        RAISE EXCEPTION 'Amount must be between % and % for %',
            prod.min_amount, prod.max_amount, prod.name;
    END IF;

    IF NEW.tenure_months > prod.max_tenure_months THEN
        RAISE EXCEPTION 'Maximum tenure for % is % months', prod.name, prod.max_tenure_months;
    END IF;

    IF NEW.requested_amount > rent THEN
        RAISE EXCEPTION 'Amount cannot be more than the annual rent (%)', rent;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_application
BEFORE INSERT OR UPDATE ON loan_applications
FOR EACH ROW EXECUTE FUNCTION check_application();
