# Portfolio 1: Database Design and Modelling

This activity designs the relational database for RentMadeEasy (see the [main README](../README.md) for the case study).

## Files

| File | Purpose |
|---|---|
| `01_schema.sql` | Creates the 10 tables, keys, constraints and the application check trigger |
| `02_seed.sql` | Inserts sample data: 8 customers, 6 applications, 4 loans and their repayments |

## ER diagram

```mermaid
erDiagram
    CUSTOMERS |o--o{ CUSTOMERS : refers
    CUSTOMERS ||--|| WALLETS : owns
    WALLETS ||--o{ WALLET_TRANSACTIONS : records
    CUSTOMERS ||--o{ LOAN_APPLICATIONS : submits
    LANDLORDS ||--o{ PROPERTIES : owns
    PROPERTIES ||--o{ LOAN_APPLICATIONS : "applied for"
    LOAN_PRODUCTS ||--o{ LOAN_APPLICATIONS : "applied under"
    LOAN_APPLICATIONS ||--o| LOANS : "becomes"
    LOANS ||--|{ REPAYMENT_SCHEDULES : "is paid in"
    REPAYMENT_SCHEDULES ||--o{ REPAYMENTS : "paid by"
    WALLET_TRANSACTIONS ||--o| REPAYMENTS : funds

    CUSTOMERS {
        int customer_id PK
        varchar first_name
        varchar last_name
        varchar email UK
        varchar phone UK
        date date_of_birth
        int referred_by FK
        timestamp created_at
    }
    LANDLORDS {
        int landlord_id PK
        varchar full_name
        varchar phone UK
        varchar bank_name
        char account_number
    }
    PROPERTIES {
        int property_id PK
        int landlord_id FK
        varchar address
        varchar city
        varchar property_type
        numeric annual_rent
    }
    WALLETS {
        int wallet_id PK
        int customer_id FK, UK
        char account_number UK
        numeric balance
    }
    WALLET_TRANSACTIONS {
        int transaction_id PK
        int wallet_id FK
        varchar transaction_type
        numeric amount
        varchar reference UK
        varchar description
        timestamp created_at
    }
    LOAN_PRODUCTS {
        int product_id PK
        varchar name UK
        numeric monthly_interest_rate
        numeric min_amount
        numeric max_amount
        int max_tenure_months
    }
    LOAN_APPLICATIONS {
        int application_id PK
        int customer_id FK
        int property_id FK
        int product_id FK
        numeric requested_amount
        int tenure_months
        varchar status
        timestamp applied_at
    }
    LOANS {
        int loan_id PK
        int application_id FK, UK
        numeric principal
        numeric monthly_interest_rate
        int tenure_months
        varchar status
        timestamp disbursed_at
    }
    REPAYMENT_SCHEDULES {
        int schedule_id PK
        int loan_id FK
        int installment_number
        date due_date
        numeric amount_due
        varchar status
    }
    REPAYMENTS {
        int repayment_id PK
        int schedule_id FK
        int transaction_id FK, UK
        numeric amount
        timestamp paid_at
    }
```

**Key:** PK = primary key, FK = foreign key, UK = unique.

### Relationships

| Relationship | Type | How it is enforced |
|---|---|---|
| A customer can refer many customers | One-to-many, to itself | `customers.referred_by` references `customers.customer_id` |
| A customer has exactly one wallet | One-to-one | `wallets.customer_id` is a foreign key and `UNIQUE` |
| A wallet has many transactions | One-to-many | `wallet_transactions.wallet_id` foreign key |
| A landlord owns many properties | One-to-many | `properties.landlord_id` foreign key |
| A customer submits many applications | One-to-many | `loan_applications.customer_id` foreign key |
| A property and a loan product can each appear in many applications | One-to-many | `property_id` and `product_id` foreign keys |
| An approved application becomes at most one loan | One-to-one (optional) | `loans.application_id` is a foreign key and `UNIQUE` |
| A loan is paid in many monthly instalments | One-to-many | `repayment_schedules.loan_id` foreign key, `UNIQUE (loan_id, installment_number)` |
| An instalment is paid by one or more repayments | One-to-many | `repayments.schedule_id` foreign key |
| Each repayment is funded by exactly one wallet debit | One-to-one | `repayments.transaction_id` is a foreign key and `UNIQUE` |

`loan_applications` links customers, properties and loan products. It resolves the many-to-many relationship between customers and properties: one customer can apply for several properties over time, and one property can be applied for by different tenants.
