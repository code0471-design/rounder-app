const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

exports.sendPushOnInbox = onDocumentCreated(
  {
    document: "push_inbox/{userId}/items/{itemId}",
    region: "asia-northeast3",
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
