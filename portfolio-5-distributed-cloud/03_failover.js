// RentMadeEasy failover (Portfolio 5)
// Shows what happens when the primary's server goes down:
//   1. node1 crashes (docker kill switches it off at once, like a power cut),
//      and the other two nodes elect a new primary
//   2. a top-up still works on the new primary
//   3. node1 is started again, copies the top-up it missed, and takes back
//      the primary role because it has the higher priority
// The file waits at each step until you have stopped or started node1 in a
// second terminal, and measures how long each change took.
// Run inside mongosh on node3 (not node1, because node1 will be stopped):
//   docker exec -it rme-node3 mongosh "mongodb://rme-node1,rme-node2,rme-node3/rentmadeeasy?replicaSet=rs5"
//   load("/portfolio/portfolio-5-distributed-cloud/03_failover.js")

// Undo this file's top-up if it was run before, so it can be run again
if (db.wallet_transactions.deleteOne({ reference: "TOP-0014" }).deletedCount === 1) {
  db.customers.updateOne({ _id: 4 }, { $inc: { "wallet.balance": NumberDecimal("-2000.00") } });
}

// node3 is asked for the state of the set, because it keeps running throughout
const node3 = new Mongo("mongodb://rme-node3:27017/?directConnection=true").getDB("admin");
function members() {
  return node3.adminCommand({ replSetGetStatus: 1 }).members.map((m) => ({ name: m.name, state: m.stateStr, health: m.health }));
}
function primaryName() {
  const primary = members().find((m) => m.state === "PRIMARY");
  return primary ? primary.name : "none";
}

print("--- Before: node1 is the primary");
printjson(members());

// 1. Crash node1
print("");
print(">>> In a second terminal, run:  docker kill rme-node1");
print("    Waiting for node1 to stop...");
while (members().find((m) => m.name === "rme-node1:27017").health === 1) sleep(200);
const stopped = Date.now();
print("node1 is down. Waiting for the other nodes to elect a new primary...");
while (primaryName() === "none" || primaryName() === "rme-node1:27017") sleep(200);
print("New primary elected after " + ((Date.now() - stopped) / 1000).toFixed(1) + " seconds: " + primaryName());
printjson(members());

// 2. A payment while node1 is down
// The shell is connected to the whole replica set, so it finds the new primary by itself
const session = db.getMongo().startSession();
const sdb = session.getDatabase("rentmadeeasy");
session.startTransaction({ writeConcern: { w: "majority" } });
sdb.customers.updateOne({ _id: 4 }, { $inc: { "wallet.balance": NumberDecimal("2000.00") } });
sdb.wallet_transactions.insertOne({
  customer_id: NumberInt(4),
  transaction_type: "CREDIT",
  amount: NumberDecimal("2000.00"),
  reference: "TOP-0014",
  description: "Wallet top-up",
  created_at: new Date()
});
session.commitTransaction();
session.endSession();
print("--- Top-up TOP-0014 committed on " + db.hello().primary + " while node1 is down");
printjson({ funke_balance: db.customers.findOne({ _id: 4 }).wallet.balance });

// 3. Start node1 again
print("");
print(">>> In the second terminal, run:  docker start rme-node1");
print("    Waiting for node1 to come back...");
while (members().find((m) => m.name === "rme-node1:27017").health !== 1) sleep(200);
const started = Date.now();
print("node1 is back. Waiting for it to catch up and take back the primary role...");
while (primaryName() !== "rme-node1:27017") sleep(200);
print("node1 is primary again after " + ((Date.now() - started) / 1000).toFixed(1) + " seconds");
printjson(members());

// node1 was down when TOP-0014 was saved. It copied it from the others when it came back.
const node1 = new Mongo("mongodb://rme-node1:27017/?directConnection=true").getDB("rentmadeeasy");
print("--- Reading straight from node1");
printjson({
  node1_has_TOP_0014: node1.wallet_transactions.countDocuments({ reference: "TOP-0014" }) === 1,
  funke_balance_on_node1: node1.customers.findOne({ _id: 4 }).wallet.balance
});
