# MIT 8103 Advanced Database Systems: Portfolio Documentation

**Student:** Sodiq Lawal
**Student ID:** 301922416
**Matriculation number:** 2026/A/MIT/0386
**Session:** 2026/2027, First Semester
**GitHub repository:** https://github.com/sodiqlawal/advanced-database-portfolio

## 1. Selected organisation: RentMadeEasy

RentMadeEasy is a simulated Nigerian fintech company that helps tenants pay their rent. Most landlords ask for a full year's rent upfront. RentMadeEasy pays the landlord the yearly rent, and the tenant pays it back in monthly instalments with interest.

| | |
|---|---|
| **Users** | Customers (tenants), landlords, and RentMadeEasy staff (loan officers, collections, finance) |
| **Major data** | Customers and referrals, landlords and properties, wallets and wallet transactions, loan products, loan applications, loans, repayment schedules and repayments |
| **Key operations** | Register a customer and create their wallet, apply for a rent loan and approve it, generate a repayment schedule, fund a wallet and repay from it, find overdue instalments, check that balances match the transaction history |

The same case study and sample data (8 customers, 6 applications, 4 loans) are used in all five activities. Everything runs in Docker: PostgreSQL 16 for Portfolios 1–3, and MongoDB 7.0 for Portfolios 4–5.

## 2. Summary of the five activities

### Portfolio 1: Database design and modelling

A relational schema of **10 tables**, with an ER diagram (Mermaid), primary, foreign and unique keys, `CHECK` constraints, and a trigger that checks each loan application against its product's limits and the property's rent. Normalisation is shown step by step, from a single spreadsheet-style table (UNF) to 3NF, with two deliberate exceptions explained: the stored wallet balance (kept for speed and checked against the history) and the interest rate copied into each loan (the rate agreed on the day, not a duplicate).

**Evidence:** 14 constraint tests. 13 invalid inserts were rejected by the right constraint or trigger, and a valid application was accepted.

### Portfolio 2: Query processing and optimisation

Five real queries (wallet statement, overdue list, loan history, monthly totals, review queue) were measured with `EXPLAIN ANALYZE` on generated data (50,000 customers, 300,000 transactions). Five indexes were then added, including two **partial indexes**.

| Query | Before | After |
|---|---|---|
| Q1 wallet statement | 42.8 ms | 0.96 ms |
| Q5 review queue | 13.5 ms | 0.55 ms |
| Q4 monthly totals | 7.8 ms | 14.7 ms (no improvement) |

Q4 did not improve because the October rows were spread across 83% of the table's pages (a correlation of only 0.27), so an index could not avoid reading most of the table. The analysis also covers the storage and write costs of indexes.

### Portfolio 3: Transactions and concurrency

- **Commit:** a top-up and a repayment changing four tables together.
- **Rollback:** a duplicate payment reference (atomicity) and a payment that would make a balance negative (consistency).
- **Concurrency:** two top-ups to the same wallet at once lost 5,000 (the **lost update**). `SELECT ... FOR UPDATE` fixed it by making the second session wait.
- **Isolation:** an audit in `READ COMMITTED` saw a top-up committed in the middle of it and reported a mismatch that did not exist (a non-repeatable read), while `REPEATABLE READ` kept one snapshot for the whole audit and agreed.

### Portfolio 4: NoSQL and advanced data models

The same data was modelled in MongoDB as **3 collections instead of 10 tables**. Wallets, schedules and payments are embedded, and wallet transactions are referenced because they keep growing. The design uses `$jsonSchema` validators and `Decimal128` for money. The five Portfolio 2 queries were rewritten as aggregation pipelines, with query plans, and `$graphLookup` was used on the referral network. Payments were shown as multi-document transactions that commit and abort.

**Conclusion:** PostgreSQL should stay the main database for money, and MongoDB suits the loan application documents (polyglot persistence).

### Portfolio 5: Distributed and cloud databases

A **three-server MongoDB replica set** was built and tested:

| Test | Result |
|---|---|
| Replication | A top-up reached all three servers within 3–6 ms. A secondary refused a direct write. |
| Failover | The primary was crashed (`docker kill`). A new primary was elected in **8.7 s**, a payment still succeeded, and the old primary rejoined with that payment and took its role back in 11.1 s. |
| Write concern | With one server down, `w: 1` and `w: "majority"` succeeded. `w: 3` timed out, but the write was still saved, so retries must be checked. |
| CAP | With two servers down, the last server stepped down and refused writes but still served reads. This is consistency over availability. |

Sharding (hashed `customer_id` keys) and a cloud deployment (Amazon RDS Multi-AZ for PostgreSQL, MongoDB Atlas across three availability zones) were designed and discussed.

## 3. Evidence

Each activity's folder has a `README.md` explaining how it was implemented and tested, the scripts in the order to run them, and a `screenshots/` folder. There are 40 screenshots in total. The key ones are:

| Activity | Screenshot | Shows |
|---|---|---|
| 1 | `portfolio-1-database-design/screenshots/07-er-diagram.png` | The ER diagram |
| 1 | `portfolio-1-database-design/screenshots/09-constraint-tests.png` | Invalid data rejected |
| 2 | `portfolio-2-query-optimisation/screenshots/05-explain-after-1.png` | Execution plans using the new indexes |
| 3 | `portfolio-3-transactions-concurrency/screenshots/03-lost-update-waiting.png` | A session waiting for a row lock |
| 4 | `portfolio-4-nosql/screenshots/03-transaction-2.png` | A MongoDB transaction aborted and undone |
| 5 | `portfolio-5-distributed-cloud/screenshots/03-failover-1.png` | The election after the primary crashed |

The work was committed step by step, with one commit per step and a separate commit for each README.

## 4. Individual reflection

I chose two key design trade-offs that balanced database theory with real-world requirements. First, I kept a stored `balance` column on the `wallets` table instead of calculating it from the transaction history every time. Normalisation says balances should be derived, but a calculated balance cannot enforce a `CHECK (balance >= 0)` constraint to prevent overdrafts. A stored column also provides a single row to lock with `SELECT ... FOR UPDATE` during concurrent payments, keeping lookups instant as a customer's history grows. Second, in MongoDB, I embedded repayment schedules inside each loan document because a loan has at most 12 instalments (enforced by the schema validator) that are always read together. Conversely, I kept wallet transactions in their own collection because they grow indefinitely and would eventually breach MongoDB's 16 MB document size limit.

The biggest surprise was testing query optimisation in Portfolio 2. I expected adding an index on `repayment_schedules(due_date)` to speed up Q4, but the query actually got slower, jumping from 7.8 ms to 14.7 ms. Checking `EXPLAIN ANALYZE` revealed why: October instalments were physically scattered across 1,046 of the table's 1,256 pages (83%), with a physical correlation of just 0.27. PostgreSQL had to scan nearly every page anyway, so traversing the index first was wasted work. Another eye-opener was testing write concerns in Portfolio 5. When `rme-node3` was down, a top-up with `w: 3` timed out after 3,040 ms and reported an error. However, the write was already committed on `node1` and `node2`; only the offline third node failed to acknowledge it.

These experiments changed how I approach backend engineering. In production, I would never assume a write concern timeout means a write failed; RentMadeEasy must verify payment references first to prevent double-crediting customers on retries. I also learned never to update balances by reading and writing them back in application memory; using `SELECT ... FOR UPDATE` or an atomic `balance = balance + x` in a single `UPDATE` is essential to prevent the lost updates I observed in Portfolio 3. Additionally, I will only keep an index when `EXPLAIN ANALYZE` shows it reduces the pages the query reads, avoiding needless write overhead. The concept I still find hardest and want to practise more is distributed replica set failover behaviour during complex network partitions.

## 5. References

- Elmasri, R. and Navathe, S. B. (2016) *Fundamentals of Database Systems*. 7th edn. Pearson.
- PostgreSQL Global Development Group (2024) *PostgreSQL 16 Documentation*: chapters on Indexes, Using EXPLAIN, and Transaction Isolation. Available at: https://www.postgresql.org/docs/16/
- MongoDB, Inc. (2024) *MongoDB Manual (version 7.0)*: Data Modeling, Transactions, Replication, Write Concern, Read Concern and Sharding. Available at: https://www.mongodb.com/docs/v7.0/
- Brewer, E. (2000) 'Towards robust distributed systems', keynote at the *ACM Symposium on Principles of Distributed Computing (PODC)*.
- Gilbert, S. and Lynch, N. (2002) 'Brewer's conjecture and the feasibility of consistent, available, partition-tolerant web services', *ACM SIGACT News*, 33(2), pp. 51–59.
- Nigeria Data Protection Act 2023.
- Docker Inc. *Docker Compose documentation*. Available at: https://docs.docker.com/compose/
- Mermaid. *Entity Relationship Diagrams*. Available at: https://mermaid.js.org/syntax/entityRelationshipDiagram.html

## 6. AI use declaration

| | |
|---|---|
| **AI tool used** | Claude |
| **What it was used for** | Generating sample data for seeding, drafting the README files and this documentation and to help fix grammatical errors and rephrase sentences to make them sound more professional etc |
| **How I reviewed and verified the output** | I ran every script myself on my own Docker databases and took the screenshots from those runs, so all the results in this portfolio come from my runs. I checked that each result matched what the README says, asked for changes where something was unclear or wrong, and made the decisions about what to include. I can explain every file, and I am practising each part hands-on to make sure I understand it fully. |

The case study, the choice of examples and the final content are my responsibility, as the brief requires.
