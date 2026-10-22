# Advanced Database Systems Portfolio – RentMadeEasy

**Course:** MIT 8103 Advanced Database Systems
**Session:** 2026/2027, First Semester

## Case study: RentMadeEasy

**Organisation:** RentMadeEasy is a simulated Nigerian fintech company that helps tenants pay their rent. Most landlords in Nigeria ask for a full year's rent upfront. RentMadeEasy pays the landlord the yearly rent, and the tenant pays it back to RentMadeEasy in monthly instalments with interest.

**Users of the database:**
- **Customers (tenants)** apply for rent loans, fund their wallet and make repayments.
- **Landlords** own the properties. They receive the rent once a loan is approved.
- **RentMadeEasy staff** review applications and track repayments and overdue accounts.

**Major data stored:**
- Customers and their referrals
- Landlords and their properties
- Wallets and wallet transactions (credits and debits)
- Loan products (interest rate, limits, maximum term)
- Loan applications, loans, repayment schedules and repayments

**Key operations the database supports:**
- Register a customer and create their wallet
- Apply for a rent loan on a property and approve or reject it
- Generate a monthly repayment schedule for a loan
- Fund a wallet and repay an instalment from it
- Find overdue instalments and customers who are behind on payments
- Check that wallet balances match the transaction history

## Portfolio structure

| Folder | Activity |
|---|---|
| [portfolio-1-database-design](portfolio-1-database-design/) | Database design and modelling |
| portfolio-2-query-optimisation | Query processing and optimisation |
| portfolio-3-transactions-concurrency | Transactions and concurrency |
| portfolio-4-nosql | NoSQL and advanced data models |
| portfolio-5-distributed-cloud | Distributed and cloud databases |

## Conventions

**Files and folders**
- Each activity has its own folder named `portfolio-<number>-<topic>`, with a `README.md` explaining what was done and how it was tested.
- SQL files are numbered in the order they should be run, e.g. `01_schema.sql`, `02_seed.sql`.
- Screenshots go in a `screenshots/` folder inside each activity, named by step, e.g. `01-schema-created.png`.

**Database naming**
- Table and column names use lowercase `snake_case`, and table names are plural (`customers`, `loan_applications`).
- Primary keys are named `<entity>_id` with no abbreviations (`customer_id`, `loan_id`, `schedule_id`), and foreign keys use the same name as the key they point to.
- Money columns use `NUMERIC(14,2)`, so naira and kobo values are stored exactly.

## Running the database

You need Docker installed.

```bash
docker compose up -d
docker exec -it rme-postgres psql -U rme -d rentmadeeasy
```

Inside `psql`, load the schema:

```sql
\i /portfolio/portfolio-1-database-design/01_schema.sql
```
