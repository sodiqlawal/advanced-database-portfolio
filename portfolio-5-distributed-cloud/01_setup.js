// RentMadeEasy three-node replica set: setup (Portfolio 5)
// Joins the three MongoDB servers into one replica set called rs5.
// One node is the primary and takes all writes. The other two are secondaries
// and keep copies of the data by replaying the primary's operation log (oplog).
// node1 gets a higher priority, so it is chosen as primary whenever it is healthy.
// Run inside mongosh, connected straight to node1:
//   docker exec -it rme-node1 mongosh
//   load("/portfolio/portfolio-5-distributed-cloud/01_setup.js")

try {
  rs.status();
  print("The replica set is already set up");
} catch (e) {
  rs.initiate({
    _id: "rs5",
    members: [
      { _id: 0, host: "rme-node1:27017", priority: 2 },
      { _id: 1, host: "rme-node2:27017", priority: 1 },
      { _id: 2, host: "rme-node3:27017", priority: 1 }
    ]
  });
  print("Replica set rs5 created. Waiting for the election...");
}

// Wait until this node has been elected primary and both secondaries are ready
while (!db.hello().isWritablePrimary) sleep(500);
while (rs.status().members.filter((m) => m.stateStr === "SECONDARY").length < 2) sleep(500);

print("--- The members and their priorities");
printjson(rs.conf().members.map((m) => ({ host: m.host, priority: m.priority, votes: m.votes })));

print("--- The state of each member");
printjson(rs.status().members.map((m) => ({ name: m.name, state: m.stateStr, health: m.health })));
