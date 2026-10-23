// RentMadeEasy business queries in MongoDB (Portfolio 4)
// The same five queries as Portfolio 2, written for the document model,
// followed by a graph query on the referral network and two query plans.
// Run inside mongosh, after 01_load.js:
//   load("/portfolio/portfolio-4-nosql/02_queries.js")

// Q1. Wallet statement
// Support looks up a customer by email and sees their 20 latest wallet transactions.
// The transactions are in their own collection, so this takes two reads
// (in SQL it was one query joining three tables).
print("--- Q1. Wallet statement for adebayo.ogunleye@mail.com");
const adebayo = db.customers.findOne({ email: "adebayo.ogunleye@mail.com" });
printjson(
  db.wallet_transactions
    .find(
      { customer_id: adebayo._id },
      { _id: 0, created_at: 1, transaction_type: 1, amount: 1, reference: 1, description: 1 }
    )
    .sort({ created_at: -1 })
    .limit(20)
    .toArray()
);

// Q2. Overdue instalments
// The collections team's list of the 20 oldest overdue instalments, with the
// customer's phone number. The name and phone are already in the application,
// so no join is needed (in SQL it joined four tables).
// The first $match uses the index on loan.schedule.status to pick only the
// applications that have an overdue instalment. $unwind then turns each
// instalment into its own result, and the second $match keeps the overdue ones.
print("--- Q2. Overdue instalments, oldest first");
const q2 = [
  { $match: { "loan.schedule.status": "OVERDUE" } },
  { $unwind: "$loan.schedule" },
  { $match: { "loan.schedule.status": "OVERDUE" } },
  { $sort: { "loan.schedule.due_date": 1 } },
  { $limit: 20 },
  {
    $project: {
      _id: 0,
      name: "$customer.name",
      phone: "$customer.phone",
      application_id: "$_id",
      installment_number: "$loan.schedule.installment_number",
      due_date: "$loan.schedule.due_date",
      amount_due: "$loan.schedule.amount_due"
    }
  }
];
printjson(db.applications.aggregate(q2).toArray());

// Q3. Customer loan history
// Every loan a customer has had, with how many instalments are paid and overdue.
// Each loan and its schedule are one document, so the counts are worked out
// inside the document with $filter and $size (in SQL it joined four tables
// and used GROUP BY).
print("--- Q3. Loan history for ibrahim.musa@mail.com");
const ibrahim = db.customers.findOne({ email: "ibrahim.musa@mail.com" });
printjson(
  db.applications
    .aggregate([
      { $match: { "customer.customer_id": ibrahim._id, loan: { $exists: true } } },
      { $sort: { "loan.disbursed_at": 1 } },
      {
        $project: {
          _id: 0,
          application_id: "$_id",
          principal: "$loan.principal",
          status: "$loan.status",
          disbursed_at: "$loan.disbursed_at",
          paid: { $size: { $filter: { input: "$loan.schedule", cond: { $eq: ["$$this.status", "PAID"] } } } },
          overdue: { $size: { $filter: { input: "$loan.schedule", cond: { $eq: ["$$this.status", "OVERDUE"] } } } },
          total_instalments: { $size: "$loan.schedule" }
        }
      }
    ])
    .toArray()
);

// Q4. Repayments due this month
// Finance's total of instalments due in October 2026, by status.
// The same date range as Portfolio 2, so an index on the date can be used.
print("--- Q4. Instalments due in October 2026");
const october = { $gte: new Date("2026-10-01T00:00:00Z"), $lt: new Date("2026-11-01T00:00:00Z") };
printjson(
  db.applications
    .aggregate([
      { $match: { "loan.schedule.due_date": october } },
      { $unwind: "$loan.schedule" },
      { $match: { "loan.schedule.due_date": october } },
      {
        $group: {
          _id: "$loan.schedule.status",
          instalments: { $sum: 1 },
          total_amount: { $sum: "$loan.schedule.amount_due" }
        }
      },
      { $sort: { _id: 1 } },
      { $project: { _id: 0, status: "$_id", instalments: 1, total_amount: 1 } }
    ])
    .toArray()
);

// Q5. Applications waiting for review
// The loan officers' queue: the 20 oldest pending applications. The customer's
// name is in the application, so no join is needed.
print("--- Q5. Oldest pending applications");
const q5 = () =>
  db.applications
    .find(
      { status: "PENDING" },
      { _id: 1, "customer.name": 1, requested_amount: 1, applied_at: 1 }
    )
    .sort({ applied_at: 1 })
    .limit(20);
printjson(q5().toArray());

// Graph query: the referral network
// Each customer document stores who referred them (referred_by), which makes
// the customers a graph. $graphLookup follows these links as many levels deep
// as they go. In SQL this needs a recursive query (WITH RECURSIVE).
db.customers.createIndex({ referred_by: 1 });

print("--- Graph 1. Everyone each referrer brought in, at any level");
printjson(
  db.customers
    .aggregate([
      { $match: { referred_by: { $exists: false } } },
      {
        $graphLookup: {
          from: "customers",
          startWith: "$_id",
          connectFromField: "_id",
          connectToField: "referred_by",
          as: "network",
          depthField: "level"
        }
      },
      { $match: { "network.0": { $exists: true } } },
      {
        $project: {
          _id: 0,
          referrer: { $concat: ["$first_name", " ", "$last_name"] },
          referred: {
            $map: {
              input: "$network",
              in: { name: { $concat: ["$$this.first_name", " ", "$$this.last_name"] }, level: { $add: ["$$this.level", 1] } }
            }
          }
        }
      },
      { $sort: { referrer: 1 } }
    ])
    .toArray()
);

print("--- Graph 2. The chain of people above Halima, followed upwards");
printjson(
  db.customers
    .aggregate([
      { $match: { email: "halima.bello@mail.com" } },
      {
        $graphLookup: {
          from: "customers",
          startWith: "$referred_by",
          connectFromField: "referred_by",
          connectToField: "_id",
          as: "referred_by_chain",
          depthField: "level"
        }
      },
      {
        $project: {
          _id: 0,
          customer: { $concat: ["$first_name", " ", "$last_name"] },
          referred_by_chain: {
            $map: {
              input: "$referred_by_chain",
              in: { name: { $concat: ["$$this.first_name", " ", "$$this.last_name"] }, level: { $add: ["$$this.level", 1] } }
            }
          }
        }
      }
    ])
    .toArray()
);

// Query plans
// explain("executionStats") is MongoDB's version of EXPLAIN ANALYZE.
// winningPlan is the plan MongoDB chose, read from the inside out like a
// PostgreSQL plan. IXSCAN means an index was used; COLLSCAN would mean every
// document in the collection was read.
print("--- Query plan for Q2 (the first $match, which finds applications with an overdue instalment)");
const q2Plan = db.applications.find({ "loan.schedule.status": "OVERDUE" }).explain("executionStats");
printjson(q2Plan.queryPlanner.winningPlan);
printjson({
  documents_returned: q2Plan.executionStats.nReturned,
  index_keys_examined: q2Plan.executionStats.totalKeysExamined,
  documents_examined: q2Plan.executionStats.totalDocsExamined,
  documents_in_collection: db.applications.countDocuments()
});

print("--- Query plan for Q5");
const q5Plan = q5().explain("executionStats");
printjson(q5Plan.queryPlanner.winningPlan);
printjson({
  documents_returned: q5Plan.executionStats.nReturned,
  index_keys_examined: q5Plan.executionStats.totalKeysExamined,
  documents_examined: q5Plan.executionStats.totalDocsExamined,
  documents_in_collection: db.applications.countDocuments()
});
