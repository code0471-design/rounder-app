"use strict";

const ARENA_CLUB_ID = "c_1786973797931";
const JANG_USER_ID = "kakao_5049673364";

function pad(n) {
  return String(n).padStart(2, "0");
}

function ymd(parts) {
  return `${parts.year}-${pad(parts.month)}-${pad(parts.day)}`;
}

function dueLabel(parts) {
  return `${parts.year}.${pad(parts.month)}.${pad(parts.day)}`;
}

function seoulParts(date) {
  const text = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
  const [year, month, day] = text.split("-").map(Number);
  return { year, month, day };
}

function addDays(parts, days) {
  const dt = new Date(Date.UTC(parts.year, parts.month - 1, parts.day + days));
  return {
    year: dt.getUTCFullYear(),
    month: dt.getUTCMonth() + 1,
    day: dt.getUTCDate(),
  };
}

function lastDay(year, month) {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

function calendarFrom(value) {
  if (!value) return null;
  if (typeof value === "string") {
    const hit = value.match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (!hit) return null;
    return { year: Number(hit[1]), month: Number(hit[2]), day: Number(hit[3]) };
  }
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return seoulParts(value);
  }
  if (typeof value === "object" && value._seconds) {
    return seoulParts(new Date(value._seconds * 1000));
  }
  return null;
}

function canonicalPhone(phone) {
  let d = String(phone || "").replace(/\D/g, "");
  if (d.startsWith("82") && d.length >= 11) d = `0${d.slice(2)}`;
  if (d.length === 10 && d.startsWith("10")) d = `0${d}`;
  return d;
}

function activeMonth(setting, year, month) {
  const created = calendarFrom(setting.createdAt);
  const startYear = Number(setting.startYear) || (created ? created.year : year);
  const startMonth = Number(setting.startMonth) || 1;
  const key = year * 12 + month;
  const startKey = startYear * 12 + startMonth;
  if (setting.endYear == null && setting.endMonth == null) return key >= startKey;
  if (setting.endYear != null) {
    const endMonth = Number(setting.endMonth) || 12;
    return key >= startKey && key <= Number(setting.endYear) * 12 + endMonth;
  }
  if (year < startYear) return false;
  const start = Number(setting.startMonth) || 1;
  const end = Number(setting.endMonth) || 12;
  return month >= start && month <= end;
}

function dueOn(setting, tomorrow) {
  if (!setting || setting.isActive === false) return null;
  if (setting.type === "monthly") {
    const day = Number(setting.dueDayOfMonth);
    if (!day) return null;
    const dueDay = Math.min(day, lastDay(tomorrow.year, tomorrow.month));
    if (dueDay !== tomorrow.day) return null;
    if (!activeMonth(setting, tomorrow.year, tomorrow.month)) return null;
    return { year: tomorrow.year, month: tomorrow.month, day: dueDay };
  }
  const due = calendarFrom(setting.dueDate);
  if (!due) return null;
  if (due.year !== tomorrow.year || due.month !== tomorrow.month || due.day !== tomorrow.day) {
    return null;
  }
  return due;
}

function memberKey(clubId, id) {
  const raw = String(id || "").trim();
  const prefix = `m_${clubId}_`;
  if (raw.startsWith(prefix)) return raw.slice(prefix.length);
  if (raw === `m_creator_${clubId}`) return raw;
  return raw;
}

function sameMember(clubId, memberId, paymentMemberId) {
  const a = String(memberId || "");
  const b = String(paymentMemberId || "");
  if (!a || !b) return false;
  if (a === b) return true;
  const ka = memberKey(clubId, a);
  const kb = memberKey(clubId, b);
  return ka === b || kb === a || (ka && ka === kb);
}

function hasPaid(payments, clubId, member, setting, due) {
  const settingId = setting && setting.id;
  const yearOnly = setting && setting.type !== "monthly";
  for (const payment of payments || []) {
    if (!payment || String(payment.duesSettingId || "") !== String(settingId)) continue;
    if (!sameMember(clubId, member.id, payment.memberId)) continue;
    const paid = calendarFrom(payment.paidAt);
    if (!paid) continue;
    if (paid.year !== due.year) continue;
    if (yearOnly || paid.month === due.month) return true;
  }
  return false;
}

function pushUserId(club, member) {
  const explicit = String((member && (member.userId || member.user_id)) || "").trim();
  if (explicit) return explicit;
  const id = String((member && member.id) || "").trim();
  if (id === `m_creator_${club.id}`) {
    return String(club.creatorId || "").trim();
  }
  const prefix = `m_${club.id}_`;
  if (id.startsWith(prefix)) return id.slice(prefix.length);
  const roster = id.match(/^m_(c_\d+|c\d+|seed_c\d+)_(.+)$/);
  if (roster) return roster[2];
  return id;
}

function isRegular(member) {
  return member && member.status === "활성" && member.memberType === "정회원";
}

function isArenaLeftover(clubId, member) {
  if (clubId !== ARENA_CLUB_ID) return false;
  const name = String((member && member.name) || "").trim();
  const id = String((member && member.id) || "");
  return name === "장창현" || id.includes(JANG_USER_ID);
}

const SCHEDULED_GROUP_LOOKBACK_DAYS = 400;

/// 솔라피 예약은 만든 날이 아니라 예약일에 나간다.
/// 최근 며칠만 보면 몇 달 전 회비 예약이 납부일 전날에 그대로 발송된다.
function scheduledGroupSearchStart(nowMs) {
  return new Date(nowMs - SCHEDULED_GROUP_LOOKBACK_DAYS * 24 * 3600 * 1000);
}

function recipientsForClub(club, tomorrow) {
  const settings = (Array.isArray(club.settings) ? club.settings : [])
    .slice()
    .sort((a, b) => (a && a.type === "monthly" ? 0 : 1) - (b && b.type === "monthly" ? 0 : 1));
  const members = Array.isArray(club.members) ? club.members : [];
  const payments = Array.isArray(club.payments) ? club.payments : [];
  const seen = new Set();
  const out = [];
  for (const setting of settings) {
    const due = dueOn(setting, tomorrow);
    if (!due) continue;
    for (const member of members) {
      if (!isRegular(member)) continue;
      if (isArenaLeftover(club.id, member)) continue;
      if (hasPaid(payments, club.id, member, setting, due)) continue;
      const phone = canonicalPhone(member.phone);
      if (phone.length < 10) continue;
      const slot = setting.type === "monthly" ? `monthly|${phone}` : `${setting.id}|${phone}`;
      if (seen.has(slot)) continue;
      seen.add(slot);
      out.push({
        phone,
        userId: pushUserId(club, member),
        name: String(member.name || "").trim() || "회원",
        amount: String(setting.amount ?? ""),
        dueText: dueLabel(due),
        clubName: String(club.name || "").trim(),
        clubId: club.id,
        settingId: String(setting.id || ""),
      });
    }
  }
  return out;
}

module.exports = {
  ARENA_CLUB_ID,
  seoulParts,
  addDays,
  ymd,
  canonicalPhone,
  recipientsForClub,
  scheduledGroupSearchStart,
};
