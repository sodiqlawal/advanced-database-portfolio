// RentMadeEasy payments as MongoDB transactions (Portfolio 4)
// Paying an instalment changes three collections: the wallet balance in
// customers, a new debit in wallet_transactions, and the instalment in
// applications. A change to one document is always atomic in MongoDB, but a
// change across several documents needs a transaction, like BEGIN ... COMMIT
// in Portfolio 3. MongoDB only allows this on a replica set.
// Run inside mongosh, after 01_load.js:
//   load("/portfolio/portfolio-4-nosql/03_transaction.js")

// Start from the loaded data every time, so the file can be run again:
// Ibrahim back to 50,000 with instalment 3 overdue, and no new transactions
db.wallet_transactions.deleteMany({ reference: { $in: ["TOP-0012", "RPY-0010", "RPY-0011"] } });
db.customers.updateOne({ _id: 3 }, { $set: { "wallet.balance": NumberDecimal("50000.00") } });
db.applications.updateOne(
  { _id: 3, "loan.schedule.installment_number": 3 },
  { $set: { "loan.schedule.$.status": "OVERDUE" }, $unset: { "loan.schedule.$.payment": "" } }
);

// Shows one instalment from an application's schedule
function showInstalment(applicationId, installmentNumber) {
  printjson(
    db.applications
      .aggregate([
        { $match: { _id: applicationId } },
        { $unwind: "$loan.schedule" },
        { $match: { "loan.schedule.installment_number": installmentNumber } },
        { $project: { _id: 0, application_id: "$_id", instalment: "$loan.schedule" } }
      ])
      .toArray()
  );
}

// Shows a wallet balance next to the total of its transaction history
function checkBalance(customerId) {
  const balance = db.customers.findOne({ _id: customerId }).wallet.balance;
  const history = db.wallet_transactions
    .aggregate([
      { $match: { customer_id: customerId } },
      {
        $group: {
          _id: "$customer_id",
          total: { $sum: { $cond: [{ $eq: ["$transaction_type", "CREDIT"] }, "$amount", { $multiply: ["$amount", -1] }] } }
        }
      }
    ])
    .toArray()[0].total;
  printjson({ customer_id: customerId, balance: balance, from_history: history });
}

// 1. A payment that commits
print("=== 1. Commit: Ibrahim tops up and pays his overdue instalment");
print("--- Before");
printjson(db.customers.findOne({ _id: 3 }, { _id: 1, first_name: 1, "wallet.balance": 1 }));
showInstalment(3, 3);

const session = db.getMongo().startSession();
const sdb = session.getDatabase("rentmadeeasy");

// Transaction 1: top up 186,000 (50,000 + 186,000 = 236,000)
session.startTransaction();
try {
  sdb.customers.updateOne({ _id: 3 }, { $inc: { "wallet.balance": NumberDecimal("186000.00") } });
  sdb.wallet_transactions.insertOne({
    customer_id: NumberInt(3),
    transaction_type: "CREDIT",
    amount: NumberDecimal("186000.00"),
    reference: "TOP-0012",
    description: "Wallet top-up",
    created_at: new Date()
  });
  session.commitTransaction();
  print("Transaction 1 (top-up) committed");
} catch (e) {
  session.abortTransaction();
  print("Transaction 1 aborted: " + e.errmsg);
}

// Transaction 2: pay instalment 3
session.startTransaction();
try {
  // Take the money out of the wallet
  sdb.customers.updateOne({ _id: 3 }, { $inc: { "wallet.balance": NumberDecimal("-236000.00") } });

  // Record the debit, pointing to the instalment it paid
  sdb.wallet_transactions.insertOne({
    customer_id: NumberInt(3),
    transaction_type: "DEBIT",
    amount: NumberDecimal("236000.00"),
    reference: "RPY-0010",
    description: "Loan 3 instalment 3",
    created_at: new Date(),
    paid_for: { application_id: NumberInt(3), installment_number: NumberInt(3) }
  });

  // Mark the instalment as paid. The $ in "loan.schedule.$" means the
  // array element that matched the filter, here instalment 3.
  sdb.applications.updateOne(
    { _id: 3, "loan.schedule.installment_number": 3 },
    {
      $set: {
        "loan.schedule.$.status": "PAID",
        "loan.schedule.$.payment": { reference: "RPY-0010", amount: NumberDecimal("236000.00"), paid_at: new Date() }
      }
    }
  );

  session.commitTransaction();
  print("Transaction 2 (repayment) committed");
} catch (e) {
  session.abortTransaction();
  print("Transaction 2 aborted: " + e.errmsg);
}

print("--- After: the wallet is empty and instalment 3 is paid");
printjson(db.customers.findOne({ _id: 3 }, { _id: 1, first_name: 1, "wallet.balance": 1 }));
showInstalment(3, 3);
print("--- The balance still matches the transaction history");
checkBalance(3);

// 2. A payment that is aborted
// Ngozi has 2,000 but instalment 4 of her loan is 181,500. This time the
// wallet is changed last, so two steps succeed before the failure.
print("");
print("=== 2. Abort: Ngozi tries to pay 181,500 with 2,000 in her wallet");
print("--- Before");
printjson(db.customers.findOne({ _id: 2 }, { _id: 1, first_name: 1, "wallet.balance": 1 }));
showInstalment(2, 4);

session.startTransaction();
try {
  sdb.wallet_transactions.insertOne({
    customer_id: NumberInt(2),
    transaction_type: "DEBIT",
    amount: NumberDecimal("181500.00"),
    reference: "RPY-0011",
    description: "Loan 2 instalment 4",
    created_at: new Date(),
    paid_for: { application_id: NumberInt(2), installment_number: NumberInt(4) }
  });
  print("Step 1: debit RPY-0011 recorded (inside the transaction)");

  sdb.applications.updateOne(
    { _id: 2, "loan.schedule.installment_number": 4 },
    { $set: { "loan.schedule.$.status": "PAID" } }
  );
  print("Step 2: instalment 4 marked PAID (inside the transaction)");

  // The validator does not allow a negative balance, so this fails
  sdb.customers.updateOne({ _id: 2 }, { $inc: { "wallet.balance": NumberDecimal("-181500.00") } });
  print("Step 3: balance reduced");

  session.commitTransaction();
} catch (e) {
  session.abortTransaction();
  print("Step 3 failed: " + e.errmsg);
  print("abortTransaction() undid steps 1 and 2");
}
session.endSession();

print("--- After: nothing changed");
printjson(db.customers.findOne({ _id: 2 }, { _id: 1, first_name: 1, "wallet.balance": 1 }));
showInstalment(2, 4);
printjson({ saved_rpy_0011: db.wallet_transactions.countDocuments({ reference: "RPY-0011" }) });
print("--- The balance still matches the transaction history");
checkBalance(2);
