/**
 * Local test-data seeder — inserts a sample event + internship into Firestore
 * so the push triggers (onEventCreated / onInternshipCreated) fire and you get
 * a notification on your phone.
 *
 * Run from the project root (NOT inside the deployed functions):
 *
 *   # one-time auth so the Admin SDK can reach Firestore as you:
 *   gcloud auth application-default login
 *
 *   # then seed, passing the student's universityId so it targets them:
 *   node functions/seed.js <universityId>
 *
 * (Find the universityId in Firestore under users/{your-student-uid}.)
 *
 * Alternatively, point at a service-account key instead of gcloud:
 *   SERVICE_ACCOUNT=/path/to/key.json node functions/seed.js <universityId>
 */
const { initializeApp, cert, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");

const universityId = process.argv[2];
if (!universityId) {
  console.error("Usage: node functions/seed.js <universityId>");
  process.exit(1);
}

const credential = process.env.SERVICE_ACCOUNT
  ? cert(require(process.env.SERVICE_ACCOUNT))
  : applicationDefault();

initializeApp({ credential, projectId: "uniship-4c1a1" });
const db = getFirestore();

function inDays(n) {
  return Timestamp.fromDate(new Date(Date.now() + n * 24 * 60 * 60 * 1000));
}

async function main() {
  const stamp = new Date().toLocaleTimeString();

  const event = await db.collection("events").add({
    title: `Test event · ${stamp}`,
    type: "workshop",
    universityId, // so the push targets this university's students
    targetBranches: ["all"],
    minGpa: null,
    date: inDays(2),
    expiresAt: inDays(2),
    createdAt: FieldValue.serverTimestamp(),
  });
  console.log("Seeded event:", event.id);

  const internship = await db.collection("internships").add({
    role: `Test internship · ${stamp}`,
    companyName: "UniShip QA",
    universityId,
    deadline: inDays(7),
    createdAt: FieldValue.serverTimestamp(),
  });
  console.log("Seeded internship:", internship.id);

  console.log(
    "\nDone. With the app fully closed, you should get two notifications shortly."
  );
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
