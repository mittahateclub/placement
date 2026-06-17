/**
 * WhatsApp-style push for UniShip.
 *
 * When a new event / internship / test / practice set is posted, send an FCM
 * notification to the students it concerns so they hear about it even with the
 * app closed. Device tokens are written to `users/{uid}.fcmTokens` by the app
 * (see PushService); the targeting mirrors the in-app feeds.
 */
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");

initializeApp();
const db = getFirestore();

const STUDENT_ROLES = new Set(["student", "user", null, undefined, ""]);
const isStudent = (u) => STUDENT_ROLES.has(u.role);

/** First parseable CGPA from a profile (mirrors cgpaFromProfile in the app). */
function cgpaFromProfile(data) {
  for (const entry of data.educationEntries || []) {
    if (entry && entry.cgpa != null) {
      const v = parseFloat(String(entry.cgpa).replace(/[^0-9.]/g, ""));
      if (!Number.isNaN(v)) return v;
    }
  }
  return null;
}

/** Mirrors eventTargetsStudent: branch + minGpa gating, inclusive of unknowns. */
function eventTargetsStudent(event, user) {
  const branches = event.targetBranches;
  const branch = user.branch;
  if (
    Array.isArray(branches) &&
    branches.length > 0 &&
    !branches.includes("all") &&
    branch &&
    !branches.map((b) => b.toLowerCase()).includes(String(branch).toLowerCase())
  ) {
    return false;
  }
  const minGpa = event.minGpa != null ? Number(event.minGpa) : null;
  const gpa = cgpaFromProfile(user);
  if (minGpa != null && gpa != null && gpa < minGpa) return false;
  return true;
}

/**
 * Load candidate students. When `universityId` is given we query just that
 * cohort; otherwise (global events) we scan all users. `filter` does any
 * finer-grained per-student gating.
 */
async function targetStudents(universityId, filter) {
  let query = db.collection("users");
  if (universityId) query = query.where("universityId", "==", universityId);
  const snap = await query.get();

  // token -> [uids] so we can prune dead tokens from the right docs later.
  const tokenOwners = new Map();
  for (const doc of snap.docs) {
    const u = doc.data();
    if (!isStudent(u)) continue;
    if (filter && !filter(u)) continue;
    for (const t of u.fcmTokens || []) {
      if (!tokenOwners.has(t)) tokenOwners.set(t, []);
      tokenOwners.get(t).push(doc.id);
    }
  }
  return tokenOwners;
}

/** Send to every collected token in batches, then prune invalid ones. */
async function pushTo(tokenOwners, notification, data) {
  const tokens = [...tokenOwners.keys()];
  if (tokens.length === 0) {
    logger.info("No target tokens; nothing to send.");
    return;
  }

  const messaging = getMessaging();
  const stale = [];
  for (let i = 0; i < tokens.length; i += 500) {
    const batch = tokens.slice(i, i + 500);
    const res = await messaging.sendEachForMulticast({
      tokens: batch,
      notification,
      data: data || {},
      android: { priority: "high", notification: { channelId: "reminders" } },
      apns: { payload: { aps: { sound: "default" } } },
    });
    res.responses.forEach((r, idx) => {
      if (r.success) return;
      const code = r.error && r.error.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-argument" ||
        code === "messaging/invalid-registration-token"
      ) {
        stale.push(batch[idx]);
      }
    });
  }

  if (stale.length) {
    await Promise.all(
      stale.flatMap((t) =>
        (tokenOwners.get(t) || []).map((uid) =>
          db.collection("users").doc(uid).set(
            { fcmTokens: FieldValue.arrayRemove([t]) },
            { merge: true }
          )
        )
      )
    );
    logger.info(`Pruned ${stale.length} stale token(s).`);
  }
}

// ── Triggers ───────────────────────────────────────────────────────────────

exports.onEventCreated = onDocumentCreated("events/{id}", async (e) => {
  const ev = e.data && e.data.data();
  if (!ev) return;
  const owners = await targetStudents(ev.universityId || null, (u) =>
    eventTargetsStudent(ev, u)
  );
  await pushTo(
    owners,
    { title: "New event posted", body: ev.title || "Tap to view in UniShip." },
    { type: "event", nav: "college" }
  );
});

exports.onInternshipCreated = onDocumentCreated("internships/{id}", async (e) => {
  const it = e.data && e.data.data();
  if (!it) return;
  const owners = await targetStudents(it.universityId || null, null);
  const role = it.role || it.title || "an internship";
  await pushTo(
    owners,
    { title: "New internship posted", body: `${role}${it.companyName ? " · " + it.companyName : ""}` },
    { type: "internship", nav: "college" }
  );
});

exports.onPracticeCreated = onDocumentCreated("practice/{id}", async (e) => {
  const p = e.data && e.data.data();
  if (!p) return;
  const owners = await targetStudents(p.universityId || null, null);
  await pushTo(
    owners,
    { title: "New practice set posted", body: p.title || "Tap to practise in UniShip." },
    { type: "practice" }
  );
});

// Tests are often created unapproved, then approved later — fire on the
// transition into approved=true (not just creation).
exports.onTestApproved = onDocumentWritten("tests/{id}", async (e) => {
  const before = e.data && e.data.before && e.data.before.data();
  const after = e.data && e.data.after && e.data.after.data();
  if (!after) return; // deleted
  const wasApproved = before ? before.approved === true : false;
  if (after.approved !== true || wasApproved) return;
  const owners = await targetStudents(after.universityId || null, null);
  await pushTo(
    owners,
    { title: "New test posted", body: after.title || "A new assessment is available." },
    { type: "test" }
  );
});
