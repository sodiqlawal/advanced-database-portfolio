// RentMadeEasy document model in MongoDB (Portfolio 4)
// Loads the same data as the Portfolio 1 seed, reshaped into three collections:
//   customers            one document per customer, with the wallet embedded
//   wallet_transactions  one document per credit or debit, pointing to the customer
//   applications         one document per rent application; an approved one holds
//                        its loan, and the loan holds its repayment schedule
// Drops and reloads the collections, so it can be run again.
// Run inside mongosh:
//   load("/portfolio/portfolio-4-nosql/01_load.js")

// Transactions in MongoDB need a replica set. Start a one-node set the first time.
try {
  rs.status();
} catch (e) {
  rs.initiate({ _id: "rs0", members: [{ _id: 0, host: "localhost:27017" }] });
}
while (!db.hello().isWritablePrimary) sleep(500);

// Money is stored as Decimal128, like NUMERIC(14,2), so naira and kobo stay exact
const money = (v) => NumberDecimal(Number(v).toFixed(2));
const at = (s) => new Date(s.replace(" ", "T") + ":00Z");
const day = (s) => new Date(s + "T00:00:00Z");

db.customers.drop();
db.wallet_transactions.drop();
db.applications.drop();

// Customers: the wallet is embedded because each customer has exactly one,
// and it is always read with the customer
db.createCollection("customers", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["_id", "first_name", "last_name", "email", "phone", "wallet"],
      properties: {
        email: { bsonType: "string", pattern: "^.+@.+$" },
        referred_by: { bsonType: "int" },
        wallet: {
          bsonType: "object",
          required: ["account_number", "balance"],
          properties: {
            account_number: { bsonType: "string", pattern: "^[0-9]{10}$" },
            balance: { bsonType: "decimal", minimum: NumberDecimal("0") }
          }
        }
      }
    }
  }
});

const customer = (id, first, last, email, phone, dob, created, account, balance, referredBy) => {
  const doc = {
    _id: NumberInt(id),
    first_name: first,
    last_name: last,
    email: email,
    phone: phone,
    date_of_birth: day(dob),
    created_at: day(created),
    wallet: { account_number: account, balance: money(balance) }
  };
  if (referredBy) doc.referred_by = NumberInt(referredBy);
  return doc;
};

db.customers.insertMany([
  customer(1, "Adebayo", "Ogunleye", "adebayo.ogunleye@mail.com", "08031000001", "1990-04-12", "2026-03-20", "9000000001", 8000),
  customer(2, "Ngozi", "Nwosu", "ngozi.nwosu@mail.com", "08031000002", "1994-08-23", "2026-05-15", "9000000002", 2000, 1),
  customer(3, "Ibrahim", "Musa", "ibrahim.musa@mail.com", "08031000003", "1988-01-30", "2026-06-10", "9000000003", 50000),
  customer(4, "Funke", "Adeyemi", "funke.adeyemi@mail.com", "08031000004", "1992-11-05", "2026-09-01", "9000000004", 8000, 1),
  customer(5, "Emeka", "Obi", "emeka.obi@mail.com", "08031000005", "1996-06-17", "2026-08-02", "9000000005", 0),
  customer(6, "Halima", "Bello", "halima.bello@mail.com", "08031000006", "1991-02-09", "2026-10-10", "9000000006", 0, 3),
  customer(7, "Segun", "Afolabi", "segun.afolabi@mail.com", "08031000007", "1985-09-14", "2026-08-25", "9000000007", 50000),
  customer(8, "Chioma", "Ike", "chioma.ike@mail.com", "08031000008", "1998-12-01", "2026-10-20", "9000000008", 0)
]);

db.customers.createIndex({ email: 1 }, { unique: true });
db.customers.createIndex({ phone: 1 }, { unique: true });
db.customers.createIndex({ "wallet.account_number": 1 }, { unique: true });

// Wallet transactions: kept in their own collection, not embedded in the
// customer, because a wallet's history keeps growing (300,000 rows in Portfolio 2)
// and a MongoDB document cannot be larger than 16 MB
db.createCollection("wallet_transactions", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["customer_id", "transaction_type", "amount", "reference", "created_at"],
      properties: {
        transaction_type: { enum: ["CREDIT", "DEBIT"] },
        amount: { bsonType: "decimal", minimum: NumberDecimal("0"), exclusiveMinimum: true }
      }
    }
  }
});

const txn = (customerId, type, amount, reference, description, created, paidFor) => {
  const doc = {
    customer_id: NumberInt(customerId),
    transaction_type: type,
    amount: money(amount),
    reference: reference,
    description: description,
    created_at: at(created)
  };
  // A debit records which instalment it paid, like the repayments table in SQL
  if (paidFor) doc.paid_for = { application_id: NumberInt(paidFor[0]), installment_number: NumberInt(paidFor[1]) };
  return doc;
};

db.wallet_transactions.insertMany([
  txn(1, "CREDIT", 250000, "TOP-0001", "Wallet top-up", "2026-06-29 09:15"),
  txn(1, "DEBIT", 224000, "RPY-0001", "Loan 1 instalment 1", "2026-06-30 10:00", [1, 1]),
  txn(1, "CREDIT", 200000, "TOP-0002", "Wallet top-up", "2026-07-30 08:40"),
  txn(2, "CREDIT", 181500, "TOP-0003", "Wallet top-up", "2026-07-30 19:20"),
  txn(3, "CREDIT", 236000, "TOP-0004", "Wallet top-up", "2026-07-31 09:00"),
  txn(1, "DEBIT", 224000, "RPY-0002", "Loan 1 instalment 2", "2026-07-31 10:00", [1, 2]),
  txn(2, "DEBIT", 181500, "RPY-0003", "Loan 2 instalment 1", "2026-07-31 10:00", [2, 1]),
  txn(3, "DEBIT", 236000, "RPY-0004", "Loan 3 instalment 1", "2026-07-31 10:00", [3, 1]),
  txn(2, "CREDIT", 200000, "TOP-0005", "Wallet top-up", "2026-08-29 11:00"),
  txn(1, "CREDIT", 230000, "TOP-0006", "Wallet top-up", "2026-08-30 12:05"),
  txn(1, "DEBIT", 224000, "RPY-0005", "Loan 1 instalment 3", "2026-08-31 10:00", [1, 3]),
  txn(2, "DEBIT", 181500, "RPY-0006", "Loan 2 instalment 2", "2026-08-31 10:00", [2, 2]),
  txn(3, "CREDIT", 236000, "TOP-0007", "Wallet top-up", "2026-08-31 16:30"),
  txn(3, "DEBIT", 236000, "RPY-0007", "Loan 3 instalment 2", "2026-09-01 10:00", [3, 2]),
  txn(7, "CREDIT", 50000, "TOP-0008", "Wallet top-up", "2026-09-02 12:00"),
  txn(2, "CREDIT", 165000, "TOP-0009", "Wallet top-up", "2026-09-30 07:50"),
  txn(2, "DEBIT", 181500, "RPY-0008", "Loan 2 instalment 3", "2026-09-30 10:00", [2, 3]),
  txn(3, "CREDIT", 50000, "TOP-0010", "Wallet top-up (not enough for instalment 3)", "2026-10-05 13:10"),
  txn(4, "CREDIT", 120000, "TOP-0011", "Wallet top-up", "2026-10-13 18:00"),
  txn(4, "DEBIT", 112000, "RPY-0009", "Loan 4 instalment 1", "2026-10-14 10:00", [4, 1])
]);

db.wallet_transactions.createIndex({ reference: 1 }, { unique: true });
db.wallet_transactions.createIndex({ customer_id: 1, created_at: -1 });

// Applications: one document holds everything about a rent request. The
// property, landlord and product are copied in as they were on the day of the
// application. An approved application holds its loan, and the loan holds its
// schedule, which has at most 12 instalments, so the document stays small.
db.createCollection("applications", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["_id", "customer", "property", "product", "requested_amount", "tenure_months", "status", "applied_at"],
      properties: {
        status: { enum: ["PENDING", "APPROVED", "REJECTED"] },
        tenure_months: { bsonType: "int", minimum: 1, maximum: 12 },
        requested_amount: { bsonType: "decimal", minimum: NumberDecimal("0"), exclusiveMinimum: true },
        loan: {
          bsonType: "object",
          required: ["principal", "status", "schedule"],
          properties: {
            status: { enum: ["ACTIVE", "COMPLETED", "DEFAULTED"] },
            schedule: {
              bsonType: "array",
              maxItems: 12,
              items: {
                bsonType: "object",
                required: ["installment_number", "due_date", "amount_due", "status"],
                properties: { status: { enum: ["PENDING", "PAID", "OVERDUE"] } }
              }
            }
          }
        }
      }
    }
  }
});

const landlords = {
  1: { landlord_id: NumberInt(1), full_name: "Olumide Bakare", phone: "08051000001", bank_name: "Access Bank", account_number: "0012345671" },
  2: { landlord_id: NumberInt(2), full_name: "Grace Udoh", phone: "08051000002", bank_name: "Zenith Bank", account_number: "2012345672" },
  3: { landlord_id: NumberInt(3), full_name: "Sani Garba", phone: "08051000003", bank_name: "First Bank", account_number: "3012345673" },
  4: { landlord_id: NumberInt(4), full_name: "Kemi Oladipo", phone: "08051000004", bank_name: "UBA", account_number: "1012345674" }
};
const property = (id, landlordId, address, type, rent) => ({
  property_id: NumberInt(id), address: address, city: "Lagos", property_type: type, annual_rent: money(rent), landlord: landlords[landlordId]
});
const properties = {
  1: property(1, 1, "14 Herbert Macaulay Way, Yaba", "MINI_FLAT", 1200000),
  2: property(2, 1, "7 Adeniran Ogunsanya St, Surulere", "SELF_CONTAIN", 650000),
  3: property(3, 2, "22 Admiralty Way, Lekki", "FLAT", 3500000),
  4: property(4, 3, "5 Allen Avenue, Ikeja", "FLAT", 2400000),
  5: property(5, 3, "31 Diya Street, Gbagada", "MINI_FLAT", 1500000),
  6: property(6, 4, "9 Abraham Adesanya Rd, Ajah", "SELF_CONTAIN", 800000)
};
const products = {
  1: { product_id: NumberInt(1), name: "Rent Monthly", monthly_interest_rate: NumberDecimal("0.0350") },
  2: { product_id: NumberInt(2), name: "Rent Quick", monthly_interest_rate: NumberDecimal("0.0400") },
  3: { product_id: NumberInt(3), name: "Rent Premium", monthly_interest_rate: NumberDecimal("0.0300") }
};

const customerSummary = (id) => {
  const c = db.customers.findOne({ _id: id });
  return { customer_id: c._id, name: c.first_name + " " + c.last_name, phone: c.phone };
};

// Each instalment: [due date, status, reference of the debit that paid it, paid at]
const schedule = (amount, rows) =>
  rows.map((r, i) => {
    const doc = { installment_number: NumberInt(i + 1), due_date: day(r[0]), amount_due: money(amount), status: r[1] };
    if (r[2]) doc.payment = { reference: r[2], amount: money(amount), paid_at: at(r[3]) };
    return doc;
  });

const application = (id, customerId, propertyId, productId, requested, months, status, applied, loan) => {
  const doc = {
    _id: NumberInt(id),
    customer: customerSummary(customerId),
    property: properties[propertyId],
    product: products[productId],
    requested_amount: money(requested),
    tenure_months: NumberInt(months),
    status: status,
    applied_at: at(applied)
  };
  if (loan) doc.loan = loan;
  return doc;
};

const loan = (principal, rate, months, status, disbursed, sched) => ({
  principal: money(principal),
  monthly_interest_rate: NumberDecimal(rate),
  tenure_months: NumberInt(months),
  status: status,
  disbursed_at: at(disbursed),
  schedule: sched
});

db.applications.insertMany([
  application(1, 1, 2, 2, 600000, 3, "APPROVED", "2026-05-28 09:30",
    loan(600000, "0.0400", 3, "COMPLETED", "2026-06-01 12:00", schedule(224000, [
      ["2026-07-01", "PAID", "RPY-0001", "2026-06-30 10:00"],
      ["2026-08-01", "PAID", "RPY-0002", "2026-07-31 10:00"],
      ["2026-09-01", "PAID", "RPY-0005", "2026-08-31 10:00"]
    ]))),
  application(2, 2, 1, 1, 900000, 6, "APPROVED", "2026-06-27 14:10",
    loan(900000, "0.0350", 6, "ACTIVE", "2026-07-01 11:00", schedule(181500, [
      ["2026-08-01", "PAID", "RPY-0003", "2026-07-31 10:00"],
      ["2026-09-01", "PAID", "RPY-0006", "2026-08-31 10:00"],
      ["2026-10-01", "PAID", "RPY-0008", "2026-09-30 10:00"],
      ["2026-11-01", "PENDING"],
      ["2026-12-01", "PENDING"],
      ["2027-01-01", "PENDING"]
    ]))),
  application(3, 3, 5, 3, 1200000, 6, "APPROVED", "2026-06-28 11:45",
    loan(1200000, "0.0300", 6, "ACTIVE", "2026-07-01 14:00", schedule(236000, [
      ["2026-08-01", "PAID", "RPY-0004", "2026-07-31 10:00"],
      ["2026-09-01", "PAID", "RPY-0007", "2026-09-01 10:00"],
      ["2026-10-01", "OVERDUE"],
      ["2026-11-01", "PENDING"],
      ["2026-12-01", "PENDING"],
      ["2027-01-01", "PENDING"]
    ]))),
  application(4, 4, 6, 2, 300000, 3, "APPROVED", "2026-09-12 16:20",
    loan(300000, "0.0400", 3, "ACTIVE", "2026-09-15 10:00", schedule(112000, [
      ["2026-10-15", "PAID", "RPY-0009", "2026-10-14 10:00"],
      ["2026-11-15", "PENDING"],
      ["2026-12-15", "PENDING"]
    ]))),
  application(5, 5, 3, 3, 3000000, 12, "REJECTED", "2026-08-10 10:00"),
  application(6, 6, 4, 1, 2000000, 6, "PENDING", "2026-10-18 13:05")
]);

db.applications.createIndex({ "customer.customer_id": 1 });
db.applications.createIndex({ status: 1, applied_at: 1 });
db.applications.createIndex({ "loan.schedule.status": 1, "loan.schedule.due_date": 1 });

print("--- Documents loaded");
printjson({
  customers: db.customers.countDocuments(),
  wallet_transactions: db.wallet_transactions.countDocuments(),
  applications: db.applications.countDocuments(),
  loans: db.applications.countDocuments({ loan: { $exists: true } })
});

print("--- One customer, with the wallet inside the document");
printjson(db.customers.findOne({ _id: 3 }));

print("--- One application: the property, landlord, loan and schedule in a single document");
printjson(db.applications.findOne({ _id: 3 }));

print("--- The validator rejects a negative wallet balance, like the CHECK constraint in SQL");
try {
  db.customers.insertOne(customer(99, "Test", "User", "test@mail.com", "08030000099", "2000-01-01", "2026-10-23", "9000000099", -500));
} catch (e) {
  print("Rejected: " + e.errmsg);
}
