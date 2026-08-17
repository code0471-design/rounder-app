const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const REGION = "asia-northeast3";

async function inboxPush(userId, title, body, type, clubId) {
  await getFirestore().collection(`push_inbox/${userId}/items`).add({
    title: title || "라운더",
    body: body || "",
    type: type || "",
    clubId: clubId || "",
    createdAt: new Date(),
  });
}

async function fanoutAllTokens(title, body, type) {
  const tokens = await getFirestore().collection("fcm_tokens").get();
  let n = 0;
  for (const doc of tokens.docs) {
    await inboxPush(doc.id, title, body, type, "");
    n += 1;
  }
  return n;
}

async function hqPushEnabled(typeId) {
  const snap = await getFirestore().doc("_meta/hq_push").get();
  const types = snap.data()?.types;
  if (!Array.isArray(types)) return true;
  const hit = types.find((t) => t && t.id === typeId);
  if (!hit) return true;
  return hit.enabled !== false;
}

exports.sendPushOnInbox = onDocumentCreated(
  {
    document: "push_inbox/{userId}/items/{itemId}",
    region: REGION,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const userId = event.params.userId;
    const tokenSnap = await getFirestore().doc(`fcm_tokens/${userId}`).get();
    const token = tokenSnap.data()?.token;
    if (!token) {
      console.log("no FCM token", userId);
      return;
    }

    const title = data.title || "라운더";
    const body = data.body || "";

    try {
      await getMessaging().send({
        token,
        notification: { title, body },
        data: {
          type: String(data.type || ""),
          clubId: String(data.clubId || ""),
        },
        android: {
          priority: "high",
          notification: { channelId: "rounder_default" },
        },
        apns: {
          payload: { aps: { sound: "default", badge: 1 } },
        },
      });
    } catch (err) {
      console.error("FCM send failed", userId, err);
    }
  }
);

exports.sendHqBroadcast = onDocumentCreated(
  {
    document: "hq_broadcasts/{id}",
    region: REGION,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    if (!data.sendNow) return;
    const n = await fanoutAllTokens(
      data.title,
      data.body,
      "hq_broadcast"
    );
    await event.data.ref.update({ status: "sent", sentCount: n });
  }
);

exports.processScheduledBroadcasts = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "Asia/Seoul",
    region: REGION,
  },
  async () => {
    const now = new Date();
    const snap = await getFirestore()
      .collection("hq_broadcasts")
      .where("status", "==", "scheduled")
      .get();
    for (const doc of snap.docs) {
      const when = doc.data().when?.toDate?.() || new Date(0);
      if (when > now) continue;
      const n = await fanoutAllTokens(
        doc.data().title,
        doc.data().body,
        "hq_broadcast"
      );
      await doc.ref.update({ status: "sent", sentCount: n });
    }
  }
);

exports.sendD1Reminders = onSchedule(
  {
    schedule: "0 10 * * *",
    timeZone: "Asia/Seoul",
    region: REGION,
  },
  async () => {
    if (!(await hqPushEnabled("push_d1_reminder"))) {
      console.log("D-1 reminder disabled by HQ");
      return;
    }
    const today = new Date().toLocaleDateString("en-CA", {
      timeZone: "Asia/Seoul",
    });
    const snap = await getFirestore()
      .collection("d1_queue")
      .where("sendOn", "==", today)
      .get();
    for (const doc of snap.docs) {
      const d = doc.data();
      if (!d.userId) continue;
      await inboxPush(
        d.userId,
        d.title || "내일 라운딩 안내",
        d.body || "",
        "push_d1_reminder",
        d.clubId || ""
      );
      await doc.ref.delete();
    }
  }
);
