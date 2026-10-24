// RentMadeEasy consistency (Portfolio 5)
// Shows how many nodes must confirm a write before it counts as saved, and
// what MongoDB does when too many nodes are down:
//   1. node3 is stopped. A top-up is saved three times with a different write
//      concern each time: w: 1, w: "majority" and w: 3
//   2. node2 is stopped as well. node1 is alone, so it steps down and refuses
//      writes, but it can still answer reads (CAP: consistency over availability)
//   3. node2 and node3 are started again and the set recovers
// The file waits at each step until you have stopped or started the nodes in a
// second terminal.
// Run inside mongosh on node1 (node1 stays up the whole time):
//   docker exec -it rme-node1 mongosh "mongodb://rme-node1,rme-node2,rme-node3/rentmadeeasy?replicaSet=rs5"
//   load("/portfolio/portfolio-5-distributed-cloud/04_consistency.js")

// Undo this file's top-ups if it was run before, so it can be run again
["TOP-0015", "TOP-0016", "TOP-0017"].forEach((ref) => {
  if (db.wallet_transactions.deleteOne({ reference: ref }).deletedCount === 1) {
    db.customers.updateOne({ _id: 4 }, { $inc: { "wallet.balance": NumberDecimal("-1000.00") } });
  }
});

// node1 is asked for the state of the set, because it keeps running throughout
const node1 = new Mongo("mongodb://rme-node1:27017/?directConnection=true");
function members() {
  return node1.getDB("admin").adminCommand({ replSetGetStatus: 1 }).members.map((m) => ({ name: m.name, state: m.stateStr, health: m.health }));
}
function health(name) {
  return members().find((m) => m.name === name).health;
}

// A top-up of 1,000 for Funke, saved with the write concern given.
// wtimeout is how long the primary waits for the other nodes to confirm.
function topUp(reference, writeConcern) {
  const session = db.getMongo().startSession();
  const sdb = session.getDatabase("rentmadeeasy");
  const start = Date.now();
  let result = "saved and confirmed";
  session.startTransaction({ writeConcern: writeConcern });
  sdb.customers.updateOne({ _id: 4 }, { $inc: { "wallet.balance": NumberDecimal("1000.00") } });
  sdb.wallet_transactions.insertOne({
    customer_id: NumberInt(4),
    transaction_type: "CREDIT",
    amount: NumberDecimal("1000.00"),
    reference: reference,
    description: "Wallet top-up",
    created_at: new Date()
  });
  try {
    session.commitTransaction();
  } catch (e) {
    result = "error: " + e.errmsg;
  }
  session.endSession();
  printjson({ reference: reference, write_concern: writeConcern, result: result, took_ms: Date.now() - start });
}

print("--- Before: all three nodes are up");
printjson(members());

// 1. One node down
print("");
print(">>> In a second terminal, run:  docker stop rme-node3");
print("    Waiting for node3 to stop...");
while (health("rme-node3:27017") === 1) sleep(200);
print("node3 is down. Two of the three nodes are left.");
print("");
print("--- w: 1 waits for the primary only");
topUp("TOP-0015", { w: 1 });
print("--- w: majority waits for 2 of the 3 nodes (node1 and node2)");
topUp("TOP-0016", { w: "majority" });
print("--- w: 3 waits for all 3 nodes, but node3 is down, so it gives up after 3 seconds");
topUp("TOP-0017", { w: 3, wtimeout: 3000 });

// The w: 3 top-up was not rolled back. The error only means that not every
// node confirmed it in time. It is still on node1 and node2.
print("--- Is TOP-0017 saved anyway?");
printjson({
  TOP_0017_saved: db.wallet_transactions.countDocuments({ reference: "TOP-0017" }) === 1,
  funke_balance: db.customers.findOne({ _id: 4 }).wallet.balance
});

// 2. Two nodes down
print("");
print(">>> In the second terminal, run:  docker stop rme-node2");
print("    Waiting for node2 to stop...");
while (health("rme-node2:27017") === 1) sleep(200);
print("node2 is down. node1 is alone, so it cannot reach a majority. Waiting for it to step down...");
while (node1.getDB("admin").hello().isWritablePrimary) sleep(200);
printjson(members());

print("--- Writing to node1 while it is alone");
try {
  node1.getDB("rentmadeeasy").wallet_transactions.insertOne({
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

print("--- Reading from node1 while it is alone");
const node1Read = new Mongo("mongodb://rme-node1:27017/?directConnection=true&readPreference=secondaryPreferred").getDB("rentmadeeasy");
printjson({ funke_balance: node1Read.customers.findOne({ _id: 4 }).wallet.balance });

// 3. Recovery
print("");
print(">>> In the second terminal, run:  docker start rme-node2 rme-node3");
print("    Waiting for both nodes to come back...");
while (health("rme-node2:27017") !== 1 || health("rme-node3:27017") !== 1) sleep(200);
print("Both nodes are back. Waiting for a primary...");
while (!members().find((m) => m.state === "PRIMARY")) sleep(200);
printjson(members());

// node3 was down for all three top-ups. It copied them when it came back.
const node3 = new Mongo("mongodb://rme-node3:27017/?directConnection=true&readPreference=secondaryPreferred").getDB("rentmadeeasy");
while (node3.wallet_transactions.countDocuments({ reference: { $in: ["TOP-0015", "TOP-0016", "TOP-0017"] } }) < 3) sleep(200);
print("--- Reading straight from node3");
printjson({
  node3_top_ups: node3.wallet_transactions.find({ reference: { $in: ["TOP-0015", "TOP-0016", "TOP-0017"] } }).toArray().map((t) => t.reference),
  funke_balance_on_node3: node3.customers.findOne({ _id: 4 }).wallet.balance
});
