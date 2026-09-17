const crypto = require("crypto");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

const D1_TEMPLATE = "KA01TP260819170856743YpkKVjb5WfS";
const DUES_TEMPLATE = "KA01TP260819171813223rmS1ByutYaw";
const DEFAULT_PFID = "KA01PF260819163601284VyeVGcfZZWg";

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

function seoulHour() {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Seoul",
    hour: "2-digit",
    hourCycle: "h23",
  }).formatToParts(new Date());
  return Number(parts.find((p) => p.type === "hour")?.value || "0");
}

function seoulYmd() {
  return new Date().toLocaleDateString("en-CA", { timeZone: "Asia/Seoul" });
}

function digits(value) {
  return String(value || "").replace(/\D/g, "");
}

function solapiHeaders(apiKey, apiSecret) {
  const date = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
  const salt = crypto.randomBytes(16).toString("hex");
  const signature = crypto
    .createHmac("sha256", apiSecret)
    .update(date + salt)
    .digest("hex");
  return {
    Authorization:
      `HMAC-SHA256 apiKey=${apiKey}, date=${date}, salt=${salt}, signature=${signature}`,
    "Content-Type": "application/json",
  };
}

async function hqAlimtalkEnabled(typeId) {
  const snap = await getFirestore().doc("_meta/hq_alimtalk").get();
  const types = snap.data()?.types;
  if (!Array.isArray(types)) return true;
  const hit = types.find((t) => t && t.id === typeId);
  if (!hit) return true;
  return hit.enabled !== false;
}

async function lookupMemberPhone(clubId, userId) {
  if (!clubId || !userId) return "";
  try {
    const bundle = await getFirestore()
      .doc(`clubs/${clubId}/ops/bundle`)
      .get();
    const members = bundle.data()?.members;
    if (!Array.isArray(members)) return "";
    const hit = members.find((m) => {
      if (!m || typeof m !== "object") return false;
      const id = String(m.id || "");
      return (
        id === userId ||
        id === `m_${clubId}_${userId}` ||
        id.endsWith(`_${userId}`)
      );
    });
    return digits(hit?.phone);
  } catch (err) {
    console.error("d1 phone lookup skip", clubId, err);
    return "";
  }
}

async function sendSolapiAlimtalk({ to, templateId, variables }) {
  const apiKey = (process.env.SOLAPI_API_KEY || "").trim();
  const apiSecret = (process.env.SOLAPI_API_SECRET || "").trim();
  const pfId = (process.env.SOLAPI_KAKAO_PF_ID || DEFAULT_PFID).trim();
  if (!apiKey || !apiSecret) {
    return { ok: false, reason: "no-solapi-secrets" };
  }
  const phone = digits(to);
  if (phone.length < 10) return { ok: false, reason: "no-phone" };
  const res = await fetch("https://api.solapi.com/messages/v4/send-many/detail", {
    method: "POST",
    headers: solapiHeaders(apiKey, apiSecret),
    body: JSON.stringify({
      messages: [
        {
          to: phone,
          kakaoOptions: {
            pfId,
            templateId,
            variables,
            disableSms: true,
          },
        },
      ],
    }),
  });
  const body = await res.json().catch(() => ({}));
  if (res.ok) return { ok: true };
  console.error("solapi d1 fail", res.status, body);
  return { ok: false, reason: body.errorCode || String(res.status) };
}

async function flushDueD1Alimtalk() {
  if (seoulHour() < 10) return;
  const snap = await getFirestore()
    .collection("d1_queue")
    .where("sendOn", "==", seoulYmd())
    .get();
  for (const doc of snap.docs) {
    const d = doc.data();
    if (d.alimtalkSent === true || d.alimtalkScheduled === true) continue;
    const isDues = d.kind === "dues";
    const typeId = isDues ? "atk_dues_request" : "atk_d1_reminder";
    if (!(await hqAlimtalkEnabled(typeId))) {
      console.log("d1 alimtalk hq off", typeId, doc.id);
      continue;
    }
    let phone = digits(d.phone);
    if (phone.length < 10) {
      phone = await lookupMemberPhone(d.clubId, d.userId);
    }
    if (phone.length < 10) {
      console.log("d1 alimtalk no phone", doc.id);
      continue;
    }
    const sent = await sendSolapiAlimtalk({
      to: phone,
      templateId: isDues
        ? process.env.SOLAPI_TEMPLATE_ID_DUES_REQUEST || DUES_TEMPLATE
        : process.env.SOLAPI_TEMPLATE_ID_D1 || D1_TEMPLATE,
      variables: isDues
        ? {
            "#{이름}": d.memberName || "회원",
            "#{모임명}": d.clubName || "",
            "#{금액}": String(d.amount || ""),
            "#{기한}": d.dueText || "-",
          }
        : {
            "#{이름}": d.memberName || "회원",
            "#{모임명}": d.clubName || "",
            "#{일정명}": d.scheduleTitle || "",
            "#{일시}": d.whenText || "",
            "#{장소}": d.place || "장소 미정",
          },
    });
    if (sent.ok) {
      await doc.ref.set({ alimtalkSent: true }, { merge: true });
    } else {
      console.log("d1 alimtalk pending", doc.id, sent.reason);
    }
  }
}

exports.sendD1Reminders = onSchedule(
  {
    schedule: "0 10 * * *",
    timeZone: "Asia/Seoul",
    region: REGION,
  },
  async () => {
    const snap = await getFirestore()
      .collection("d1_queue")
      .where("sendOn", "==", seoulYmd())
      .get();
    for (const doc of snap.docs) {
      const d = doc.data();
      if (!d.userId) continue;
      if (d.pushSent === true) continue;
      const isDues = d.kind === "dues";
      const typeId =
        d.pushType || (isDues ? "push_dues_request" : "push_d1_reminder");
      if (!(await hqPushEnabled(typeId))) {
        continue;
      }
      await inboxPush(
        d.userId,
        d.title || (isDues ? "회비 납부 안내" : "내일 라운딩 안내"),
        d.body || "",
        typeId,
        d.clubId || ""
      );
      // 문서를 지우면 알림톡 재시도가 끊긴다. 푸시만 표시한다.
      await doc.ref.set({ pushSent: true }, { merge: true });
    }
    await flushDueD1Alimtalk();
  }
);

exports.flushD1Alimtalk = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "Asia/Seoul",
    region: REGION,
  },
  async () => {
    await flushDueD1Alimtalk();
  }
);
