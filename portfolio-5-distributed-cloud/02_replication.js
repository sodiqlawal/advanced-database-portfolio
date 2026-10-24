// RentMadeEasy replication (Portfolio 5)
// Funke tops up 5,000. The write goes to the primary, then the file reads it
// back from each of the three nodes on its own, to show that every node has
// a copy. It also shows that a secondary refuses writes.
// Run inside mongosh, connected with the replica set address:
//   docker exec -it rme-node1 mongosh "mongodb://rme-node1,rme-node2,rme-node3/rentmadeeasy?replicaSet=rs5"
//   load("/portfolio/portfolio-5-distributed-cloud/02_replication.js")

// Start from Funke's loaded balance every time, so the file can be run again
db.wallet_transactions.deleteMany({ reference: "TOP-0013" });
db.customers.updateOne({ _id: 4 }, { $set: { "wallet.balance": NumberDecimal("8000.00") } });

print("--- The current primary: " + db.hello().primary);

// 1. Write on the primary
// w: "majority" means the commit only returns once most nodes (2 of 3) have the write
const session = db.getMongo().startSession();
const sdb = session.getDatabase("rentmadeeasy");
session.startTransaction({ writeConcern: { w: "majority" } });
sdb.customers.updateOne({ _id: 4 }, { $inc: { "wallet.balance": NumberDecimal("5000.00") } });
sdb.wallet_transactions.insertOne({
  customer_id: NumberInt(4),
  transaction_type: "CREDIT",
  amount: NumberDecimal("5000.00"),
  reference: "TOP-0013",
  description: "Wallet top-up",
  created_at: new Date()
});
session.commitTransaction();
session.endSession();
print("--- Top-up TOP-0013 committed on the primary");

// 2. Read it back from each node on its own
// directConnection=true talks to one node only. readPreference=secondaryPreferred
// allows reading from a secondary. Copying to secondaries happens in the
// background, so the file waits until each node has the top-up and shows how long that took.
print("--- Reading from each node on its own");
["rme-node1:27017", "rme-node2:27017", "rme-node3:27017"].forEach((host) => {
  const node = new Mongo("mongodb://" + host + "/?directConnection=true&readPreference=secondaryPreferred").getDB("rentmadeeasy");
  const start = Date.now();
  while (node.wallet_transactions.findOne({ reference: "TOP-0013" }) === null) sleep(10);
  printjson({
    node: host,
    role: node.hello().isWritablePrimary ? "PRIMARY" : "SECONDARY",
    has_TOP_0013: true,
    funke_balance: node.customers.findOne({ _id: 4 }).wallet.balance,
    waited_ms: Date.now() - start
  });
});

// 3. Try to write straight to a secondary
print("--- Writing straight to node2, a secondary");
const node2 = new Mongo("mongodb://rme-node2:27017/?directConnection=true").getDB("rentmadeeasy");
try {
  node2.wallet_transactions.insertOne({
    customer_id: NumberInt(4),
    transaction_type: "CREDIT",
    amount: NumberDecimal("1000.00"),
    reference: "TOP-9999",
    description: "Should be refused",
    created_at: new Date()
  });
} catch (e) {
  print("Refused: " + e.errmsg);
}

// 4. How far each node has got through the oplog
// optimeDate is the time of the last write each node has applied.
// The same time on all three means they are fully in step. The primary learns
// the other nodes' progress from heartbeats sent every 2 seconds, so wait for
// the next heartbeat first.
sleep(2500);
print("--- The last write each node has applied");
printjson(rs.status().members.map((m) => ({ name: m.name, state: m.stateStr, last_applied: m.optimeDate })));
