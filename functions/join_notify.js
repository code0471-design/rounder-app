'use strict';

function isLoginAccountId(id) {
  const t = String(id || '').trim();
  return (
    t.startsWith('kakao_') ||
    t.startsWith('google_') ||
    t.startsWith('apple_')
  );
}

function loginAccountIdOf({ clubId, memberOrUserId, creatorId }) {
  const raw = String(memberOrUserId || '').trim();
  if (!raw) return '';
  if (isLoginAccountId(raw)) return raw;
  const c = String(clubId || '').trim();
  if (c) {
    const prefix = `m_${c}_`;
    if (raw.startsWith(prefix) && raw.length > prefix.length) {
      const folded = raw.slice(prefix.length);
      return isLoginAccountId(folded) ? folded : '';
    }
    if (raw === `m_creator_${c}`) {
      const cid = String(creatorId || '').trim();
      return isLoginAccountId(cid) ? cid : '';
    }
  }
  if (raw.startsWith('m_creator_')) {
    const cid = String(creatorId || '').trim();
    return isLoginAccountId(cid) ? cid : '';
  }
  return '';
}

function splitRoles(role) {
  return String(role || '')
    .split(/[·,/|]/)
    .map((s) => s.trim())
    .filter(Boolean);
}

function hasRole(role, want) {
  return splitRoles(role).includes(want);
}

function requestIdFor(clubId, userId) {
  const c = String(clubId || '').trim();
  const u = String(userId || '').trim();
  if (!c || !u) return '';
  return `jr_${c}_${u}`;
}

function shouldFanoutJoinRequest({ requestId, clubId, status }) {
  const id = String(requestId || '').trim();
  const c = String(clubId || '').trim();
  const st = String(status || 'pending').trim();
  if (st && st !== 'pending') return false;
  if (!id.startsWith('jr_') || id.endsWith('_ok') || id.endsWith('_no')) {
    return false;
  }
  if (!c || !id.startsWith(`jr_${c}_`)) return false;
  return true;
}

function officersFromRows({ members, memberships }) {
  const byId = new Map();
  const add = (userId, role) => {
    const uid = String(userId || '').trim();
    if (!uid) return;
    const nextRole = String(role || '');
    const prev = byId.get(uid);
    if (!prev) {
      byId.set(uid, { userId: uid, role: nextRole });
      return;
    }
    if (hasRole(nextRole, '총무') && !hasRole(prev.role, '총무')) {
      byId.set(uid, { userId: uid, role: nextRole });
    }
  };
  for (const m of members || []) {
    add(m.userId || m.user_id || m.id, m.role);
  }
  for (const m of memberships || []) {
    add(m.user_id || m.userId, m.role);
  }
  return [...byId.values()];
}

function notifyAccountIds({ officers, creatorId, clubId }) {
  const seen = new Set();
  const pick = (pred) => {
    const out = [];
    for (const o of officers || []) {
      const uid = loginAccountIdOf({
        clubId,
        memberOrUserId: o.userId,
        creatorId,
      });
      if (!uid || !pred(o.role) || seen.has(uid)) continue;
      seen.add(uid);
      out.push(uid);
    }
    return out;
  };
  const treasurers = pick((role) => hasRole(role, '총무'));
  if (treasurers.length) return treasurers;
  const presidents = pick((role) => hasRole(role, '회장'));
  if (presidents.length) return presidents;
  const creator = loginAccountIdOf({
    clubId,
    memberOrUserId: creatorId || '',
    creatorId,
  });
  return creator ? [creator] : [];
}

function joinPushPayload({ userName, clubName, clubId }) {
  const name = String(userName || '').trim() || '회원';
  const club = String(clubName || '').trim() || '모임';
  return {
    title: '가입 신청',
    body: `${name}님이 ${club} 가입을 신청했습니다`,
    type: 'push_join_request',
    clubId: String(clubId || ''),
  };
}

function resultInboxItemId(requestId, approved) {
  const id = String(requestId || '').trim();
  if (!id) return '';
  return approved ? `${id}_ok` : `${id}_no`;
}

function joinResultPayload({ clubName, clubId, approved, role }) {
  const club = String(clubName || '').trim() || '모임';
  const assigned = String(role || '').trim();
  return {
    title: approved ? '가입 승인' : '가입 거절',
    body: approved
      ? `${club} 가입이 승인되었습니다${assigned ? ` (${assigned})` : ''}`
      : `${club} 가입이 거절되었습니다`,
    type: 'push_join_result',
    clubId: String(clubId || ''),
  };
}

function shouldSendJoinApply({ requestId, clubId, beforeStatus, afterStatus }) {
  if (
    !shouldFanoutJoinRequest({
      requestId,
      clubId,
      status: afterStatus,
    })
  ) {
    return false;
  }
  return String(beforeStatus || '') !== 'pending';
}

function shouldSendJoinResult({ requestId, clubId, beforeStatus, afterStatus }) {
  const id = String(requestId || '').trim();
  const c = String(clubId || '').trim();
  const after = String(afterStatus || '');
  if (!id.startsWith(`jr_${c}_`)) return false;
  if (after !== 'approved' && after !== 'rejected') return false;
  return String(beforeStatus || '') !== after;
}

module.exports = {
  isLoginAccountId,
  loginAccountIdOf,
  requestIdFor,
  shouldFanoutJoinRequest,
  shouldSendJoinApply,
  shouldSendJoinResult,
  resultInboxItemId,
  officersFromRows,
  notifyAccountIds,
  joinPushPayload,
  joinResultPayload,
};
