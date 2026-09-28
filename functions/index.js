const crypto = require("crypto");
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const {
  shouldSendJoinApply,
  shouldSendJoinResult,
  resultInboxItemId,
  officersFromRows,
  notifyAccountIds,
  loginAccountIdOf,
  joinPushPayload,
  joinResultPayload,
} = require("./join_notify");

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
    const itemId = String(event.params.itemId || "");
    const type = String(data.type || "");
    const joinApply = type === "push_join_request" || type === "joinRequest";
    const joinResult =
      type === "push_join_result" ||
      type === "joinApproved" ||
      type === "joinResult";
    if (itemId.startsWith("jr_")) {
      console.log("join fcm owned by fanoutJoinRequest", userId, itemId);
      return;
    }
    if (joinApply && (!itemId.startsWith("jr_") || itemId.endsWith("_ok") || itemId.endsWith("_no"))) {
      console.log("skip join inbox not jr_", userId, itemId);
      return;
    }
    if (joinResult && !(itemId.endsWith("_ok") || itemId.endsWith("_no"))) {
      console.log("skip join result inbox not jr_", userId, itemId);
      return;
    }
    const tokenSnap = await getFirestore().doc(`fcm_tokens/${userId}`).get();
    const token = tokenSnap.data()?.token;
    if (!token) {
      console.log("no FCM token", userId);
      return;
    }

    const title = data.title || "라운더";
    const body = data.body || "";

    try {
      await sendFcmToUser({
        userId,
        title,
        body,
        type,
        clubId: String(data.clubId || ""),
      });
    } catch (err) {
      console.error("FCM send failed", userId, err);
    }
  }
);

async function sendFcmToUser({ userId, title, body, type, clubId }) {
  const tokenSnap = await getFirestore().doc(`fcm_tokens/${userId}`).get();
  const token = tokenSnap.data()?.token;
  if (!token) {
    console.log("no FCM token", userId);
    return false;
  }
  await getMessaging().send({
    token,
    notification: { title: title || "라운더", body: body || "" },
    data: {
      type: String(type || ""),
      clubId: String(clubId || ""),
    },
    android: {
      priority: "high",
      notification: { channelId: "rounder_default" },
    },
    apns: {
      payload: { aps: { sound: "default", badge: 1 } },
    },
  });
  console.log("fcm sent", userId, type, clubId);
  return true;
}

async function writeJoinInbox({ uid, itemId, payload }) {
  const ref = getFirestore().doc(`push_inbox/${uid}/items/${itemId}`);
  const existing = await ref.get();
  if (existing.exists) await ref.delete();
  await ref.set({
    title: payload.title,
    body: payload.body,
    type: payload.type,
    clubId: payload.clubId,
    createdAt: new Date(),
  });
}

async function resolveJoinClub(clubId) {
  const clubSnap = await getFirestore().doc(`clubs/${clubId}`).get();
  const club = clubSnap.data() || {};
  return {
    clubName: String(club.name || "").trim() || "모임",
    creatorId: String(
      club.creatorId || club.creator_id || club.host_user_id || "",
    ).trim(),
  };
}

async function resolveJoinOfficerIds(clubId, creatorId) {
  let members = [];
  let memberships = [];
  try {
    const memSnap = await getFirestore().collection(`clubs/${clubId}/members`).get();
    members = memSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  } catch (err) {
    console.error("join fanout members skip", clubId, err);
  }
  try {
    const memsSnap = await getFirestore()
      .collection("user_memberships")
      .where("club_id", "==", clubId)
      .get();
    memberships = memsSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  } catch (err) {
    console.error("join fanout memberships skip", clubId, err);
  }
  const officers = officersFromRows({ members, memberships });
  return notifyAccountIds({ officers, creatorId, clubId });
}

exports.fanoutJoinRequest = onDocumentWritten(
  {
    document: "clubs/{clubId}/join_requests/{requestId}",
    region: REGION,
  },
  async (event) => {
    const clubId = String(event.params.clubId || "");
    const requestId = String(event.params.requestId || "");
    const before = event.data?.before?.data() || null;
    const after = event.data?.after?.data() || null;
    if (!after) return;
    const beforeStatus = String(before?.status || "");
    const afterStatus = String(after.status || "pending");
    const { clubName, creatorId } = await resolveJoinClub(clubId);

    if (
      shouldSendJoinApply({
        requestId,
        clubId,
        beforeStatus,
        afterStatus,
      })
    ) {
      const userName =
        String(after.user_name || after.userName || "").trim() || "회원";
      const targets = await resolveJoinOfficerIds(clubId, creatorId);
      if (!targets.length) {
        console.log("no join officer", clubId, requestId);
      } else {
        const payload = joinPushPayload({ userName, clubName, clubId });
        for (const uid of targets) {
          await writeJoinInbox({ uid, itemId: requestId, payload });
          await sendFcmToUser({
            userId: uid,
            title: payload.title,
            body: payload.body,
            type: payload.type,
            clubId,
          });
          console.log("join apply fcm", uid, requestId, clubId, clubName);
        }
      }
    }

    if (
      shouldSendJoinResult({
        requestId,
        clubId,
        beforeStatus,
        afterStatus,
      })
    ) {
      const applicant = loginAccountIdOf({
        clubId,
        memberOrUserId: after.user_id || after.userId || "",
        creatorId,
      });
      if (!applicant) {
        console.log("no join applicant login", clubId, requestId);
        return;
      }
      const approved = afterStatus === "approved";
      const payload = joinResultPayload({
        clubName,
        clubId,
        approved,
        role: after.assigned_role || after.role || "",
      });
      const itemId = resultInboxItemId(requestId, approved);
      await writeJoinInbox({ uid: applicant, itemId, payload });
      await sendFcmToUser({
        userId: applicant,
        title: payload.title,
        body: payload.body,
        type: payload.type,
        clubId,
      });
      console.log("join result fcm", applicant, itemId, clubId, afterStatus);
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

function seoulMinute() {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Seoul",
    minute: "2-digit",
  }).formatToParts(new Date());
  return Number(parts.find((p) => p.type === "minute")?.value || "0");
}

function seoulYmd() {
  return new Date().toLocaleDateString("en-CA", { timeZone: "Asia/Seoul" });
}

function digits(value) {
  return String(value || "").replace(/\D/g, "");
}

function canonicalPhone(phone) {
  let d = digits(phone);
  if (d.startsWith("82") && d.length >= 11) d = "0" + d.slice(2);
  if (d.length === 10 && d.startsWith("10")) d = "0" + d;
  return d;
}

function onceSched(d) {
  if (d && d.kind === "dues") return `dues|${d.clubId || ""}`;
  return (d && d.scheduleId) || "";
}

function alimtalkOnceId(scheduleId, sendOn, phone) {
  const p = canonicalPhone(phone);
  return `${scheduleId || ""}_${sendOn || ""}_${p}`.replace(/\//g, "_");
}

const ALADDIN_CLUB_ID = "c_1789270673471";
const LEFTOVER_NAMES = new Set(["장창현"]);
const LEFTOVER_UIDS = new Set(["kakao_5049673364"]);

function canonicalUserId(userId, clubId) {
  const raw = String(userId || "").trim();
  if (!raw) return "";
  if (/^m[g]?\d+$/.test(raw)) return "";
  const prefix = clubId ? `m_${clubId}_` : "";
  if (prefix && raw.startsWith(prefix)) {
    const suffix = raw.slice(prefix.length);
    if (/^m[g]?\d+$/.test(suffix)) return "";
    return suffix;
  }
  const roster = raw.match(/^m_(c_\d+|c\d+|seed_c\d+)_(.+)$/);
  if (roster) {
    if (/^m[g]?\d+$/.test(roster[2])) return "";
    return roster[2];
  }
  return raw;
}

function isLeftoverRecipient(d) {
  const name = String(d.memberName || "").trim();
  const raw = String(d.userId || "");
  const uid = canonicalUserId(raw, d.clubId);
  const stolen =
    LEFTOVER_NAMES.has(name) ||
    LEFTOVER_UIDS.has(uid) ||
    raw.includes("kakao_5049673364");
  if (!stolen) return false;
  return String(d.clubId || "") !== ALADDIN_CLUB_ID;
}

function sendDedupKey(d, phone) {
  const isDues = d.kind === "dues";
  const sched = isDues ? `dues|${d.clubId || ""}` : (d.scheduleId || "");
  return `${sched}|${d.sendOn || ""}|${canonicalPhone(phone)}`;
}

async function resolvePushUserId(d) {
  const raw = String(d.userId || "").trim();
  const canon = canonicalUserId(raw, d.clubId);
  const candidates = [];
  if (canon) candidates.push(canon);
  if (raw && raw !== canon) candidates.push(raw);
  const db = getFirestore();
  for (const id of candidates) {
    const snap = await db.doc(`fcm_tokens/${id}`).get();
    if (snap.data()?.token) return id;
  }
  return canon || raw;
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

const GUARDED_TEMPLATES = new Set([D1_TEMPLATE, DUES_TEMPLATE]);

async function solapiJson(method, rel) {
  const apiKey = (process.env.SOLAPI_API_KEY || "").trim();
  const apiSecret = (process.env.SOLAPI_API_SECRET || "").trim();
  if (!apiKey || !apiSecret) return null;
  const res = await fetch(`https://api.solapi.com${rel}`, {
    method,
    headers: solapiHeaders(apiKey, apiSecret),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    console.error("solapi", method, rel, res.status, body);
    return null;
  }
  return body;
}

async function claimAlimtalkOnce(scheduleId, sendOn, phone) {
  const id = alimtalkOnceId(scheduleId, sendOn, phone);
  if (!scheduleId || !sendOn || canonicalPhone(phone).length < 10) return false;
  const ref = getFirestore().collection("d1_alimtalk_once").doc(id);
  try {
    return await getFirestore().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (snap.exists) return false;
      tx.set(ref, {
        scheduleId: String(scheduleId),
        sendOn: String(sendOn),
        phone: canonicalPhone(phone),
        claimedAt: new Date(),
      });
      return true;
    });
  } catch (err) {
    console.error("d1 once claim", err);
    return null;
  }
}

async function releaseAlimtalkOnce(scheduleId, sendOn, phone) {
  const id = alimtalkOnceId(scheduleId, sendOn, phone);
  if (!id || canonicalPhone(phone).length < 10) return;
  try {
    await getFirestore().collection("d1_alimtalk_once").doc(id).delete();
  } catch (err) {
    console.error("d1 once release", err);
  }
}

async function listScheduledGroups() {
  const now = Date.now();
  const start = new Date(now - 3 * 24 * 3600 * 1000).toISOString();
  const end = new Date(now + 7 * 24 * 3600 * 1000).toISOString();
  const groups = [];
  let startKey = "";
  for (let page = 0; page < 5; page += 1) {
    const q = new URLSearchParams({ startDate: start, endDate: end, limit: "100" });
    if (startKey) q.set("startKey", startKey);
    const body = await solapiJson("GET", `/messages/v4/groups?${q.toString()}`);
    if (!body) break;
    const list = body.groupList || {};
    for (const g of Object.values(list)) {
      if (g && g.status === "SCHEDULED" && g.groupId) groups.push(g);
    }
    if (!body.nextKey) break;
    startKey = String(body.nextKey);
  }
  return groups;
}

async function scheduledGroupTarget(groupId) {
  const body = await solapiJson(
    "GET",
    `/messages/v4/groups/${encodeURIComponent(groupId)}/messages?limit=20`,
  );
  if (!body) return null;
  const raw = body.messageList || {};
  const msgs = Array.isArray(raw) ? raw : Object.values(raw);
  if (!msgs.length) return null;
  let template = "";
  let phone = "";
  for (const m of msgs) {
    const t =
      (m && m.kakaoOptions && m.kakaoOptions.templateId) ||
      (m && m.kakaoTemplateId) ||
      "";
    if (!GUARDED_TEMPLATES.has(String(t))) return null;
    if (!template) template = String(t);
    if (template !== String(t)) return null;
    const p = canonicalPhone(m && m.to);
    if (p.length < 10) return null;
    if (!phone) phone = p;
    if (phone !== p) return null;
  }
  return { template, phone };
}

async function cancelScheduledGroup(groupId) {
  const cancelled = await solapiJson(
    "DELETE",
    `/messages/v4/groups/${encodeURIComponent(groupId)}/schedule`,
  );
  if (!cancelled) return false;
  await solapiJson("DELETE", `/messages/v4/groups/${encodeURIComponent(groupId)}`);
  return true;
}

async function lockQueuePhone(phone) {
  const snap = await getFirestore()
    .collection("d1_queue")
    .where("sendOn", "==", seoulYmd())
    .get();
  for (const doc of snap.docs) {
    const d = doc.data() || {};
    if (canonicalPhone(d.phone) !== phone) continue;
    await claimAlimtalkOnce(onceSched(d), d.sendOn, phone);
    await doc.ref.set(
      { alimtalkScheduled: true, alimtalkSent: true },
      { merge: true },
    );
  }
}

async function dedupeScheduledAlimtalk() {
  const groups = await listScheduledGroups();
  const buckets = new Map();
  for (const g of groups) {
    const info = await scheduledGroupTarget(g.groupId);
    if (!info) continue;
    const key = `${info.template}|${info.phone}`;
    if (!buckets.has(key)) buckets.set(key, []);
    buckets.get(key).push(g);
  }
  for (const [key, list] of buckets) {
    if (list.length < 2) continue;
    list.sort((a, b) =>
      String(a.dateCreated || "").localeCompare(String(b.dateCreated || "")),
    );
    for (const g of list.slice(1)) {
      const ok = await cancelScheduledGroup(g.groupId);
      console.log("d1 duplicate cancel", key, g.groupId, ok);
    }
    const phone = key.split("|")[1];
    if (phone) await lockQueuePhone(phone);
  }
}

async function flushDueD1Alimtalk() {
  if (seoulHour() < 10) return;
  // 10:00 정각은 앱 솔라피 예약과 겹친다. 예약 안 된 건 10:10 이후만 보조.
  if (seoulHour() === 10 && seoulMinute() < 10) return;
  // 10:20이 지나면 오후에 따라 보내지 않는다.
  if (seoulHour() > 10 || seoulMinute() > 20) return;
  const snap = await getFirestore()
    .collection("d1_queue")
    .where("sendOn", "==", seoulYmd())
    .get();
  const claimed = new Set();
  for (const doc of snap.docs) {
    const d = doc.data();
    if (d.alimtalkSent === true || d.alimtalkScheduled === true) {
      const phone = digits(d.phone);
      if (phone.length >= 10) claimed.add(sendDedupKey(d, phone));
    }
  }
  for (const doc of snap.docs) {
    const d = doc.data();
    if (d.alimtalkSent === true || d.alimtalkScheduled === true) continue;
    if (isLeftoverRecipient(d)) {
      console.log("d1 alimtalk leftover skip", doc.id);
      await doc.ref.set({ alimtalkSent: true }, { merge: true });
      continue;
    }
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
    const key = sendDedupKey(d, phone);
    if (claimed.has(key)) {
      await doc.ref.set({ alimtalkSent: true, alimtalkScheduled: true }, { merge: true });
      continue;
    }
    claimed.add(key);
    const onceOk = await claimAlimtalkOnce(onceSched(d), d.sendOn, phone);
    if (onceOk !== true) {
      if (onceOk === false) {
        await doc.ref.set({ alimtalkSent: true, alimtalkScheduled: true }, { merge: true });
      }
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
      await releaseAlimtalkOnce(onceSched(d), d.sendOn, phone);
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
      if (isLeftoverRecipient(d)) {
        await doc.ref.set({ pushSent: true }, { merge: true });
        continue;
      }
      const isDues = d.kind === "dues";
      const typeId =
        d.pushType || (isDues ? "push_dues_request" : "push_d1_reminder");
      if (!(await hqPushEnabled(typeId))) {
        continue;
      }
      const pushUserId = await resolvePushUserId(d);
      if (!pushUserId) continue;
      await inboxPush(
        pushUserId,
        d.title || (isDues ? "회비 납부 안내" : "내일 라운딩 안내"),
        d.body || "",
        typeId,
        d.clubId || ""
      );
      // 문서를 지우면 알림톡 재시도가 끊긴다. 푸시만 표시한다.
      await doc.ref.set({ pushSent: true }, { merge: true });
    }
    // 알림톡은 여기 보내지 않는다. 10시 예약분과 같은 분에 두 통이 간다.
  }
);

exports.flushD1Alimtalk = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "Asia/Seoul",
    region: REGION,
  },
  async () => {
    await dedupeScheduledAlimtalk();
    await flushDueD1Alimtalk();
  }
);

exports.dedupeScheduledD1Alimtalk = onSchedule(
  {
    schedule: "50-59 9 * * *",
    timeZone: "Asia/Seoul",
    region: REGION,
  },
  async () => {
    await dedupeScheduledAlimtalk();
  }
);
