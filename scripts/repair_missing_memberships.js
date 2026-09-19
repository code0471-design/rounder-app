'use strict';

// 명단에는 있는데 user_memberships 가 없는 사람을 채운다.
//
//   node scripts/repair_missing_memberships.js            (계획만 출력)
//   node scripts/repair_missing_memberships.js --apply
//
// 앱은 "내 모임"을 user_memberships 로 판단한다. 예전 빌드가 명단 행을 `m1`
// 같은 데모 id 로 저장해 멤버십이 안 생긴 사람은 자기 모임을 서버에서 못 찾는다.
//
// 명단 문서는 건드리지 않는다. 문서 id 를 바꾸면 회비·시상이 붙어 있는
// 회원 ID 가 끊기고 명단이 두 줄로 보인다. 여기서는 멤버십만 만든다.

const fs = require('fs');
const path = require('path');

const PROJECT = process.argv.includes('--oneclub')
  ? 'one-club-8d8b0'
  : 'rounder-f6019';
const APPLY = process.argv.includes('--apply');

function token() {
  const p = path.join(
    process.env.USERPROFILE || process.env.HOME || '',
    '.config',
    'configstore',
    'firebase-tools.json',
  );
  const t = JSON.parse(fs.readFileSync(p, 'utf8')).tokens || {};
  const access = t.access_token || t.accessToken;
  if (!access) throw new Error('`firebase login` 후 다시 실행하세요.');
  return access;
}

const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

async function api(method, rel, body) {
  const res = await fetch(`${BASE}${rel}`, {
    method,
    headers: {
      Authorization: `Bearer ${token()}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = {};
  try {
    json = text ? JSON.parse(text) : {};
  } catch (_) {}
  if (res.status === 401) throw new Error('`firebase login --reauth` 필요');
  return { ok: res.ok, status: res.status, json };
}

function val(v) {
  if (!v || typeof v !== 'object') return null;
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('timestampValue' in v) return v.timestampValue;
  return null;
}

function fieldsOf(f) {
  const out = {};
  for (const k of Object.keys(f || {})) out[k] = val(f[k]);
  return out;
}

async function listDocs(rel) {
  const out = [];
  let pageToken = '';
  for (let i = 0; i < 30; i++) {
    const sep = rel.includes('?') ? '&' : '?';
    const r = await api(
      'GET',
      `${rel}${sep}pageSize=300${pageToken ? `&pageToken=${pageToken}` : ''}`,
    );
    if (!r.ok) break;
    for (const d of r.json.documents || []) {
      out.push({ id: String(d.name).split('/').pop(), data: fieldsOf(d.fields) });
    }
    pageToken = r.json.nextPageToken || '';
    if (!pageToken) break;
  }
  return out;
}

const digits = (s) => String(s || '').replace(/[^0-9]/g, '');
const pick = (d, keys) => {
  for (const k of keys) {
    const v = (d || {})[k];
    if (typeof v === 'string' && v.trim()) return v.trim();
  }
  return '';
};

async function main() {
  console.log(`=== ${PROJECT} ${APPLY ? '(적용)' : '(계획만)'}`);
  const users = await listDocs('/users');
  const byPhone = new Map();
  const userIds = new Set();
  for (const u of users) {
    userIds.add(u.id);
    const p = digits(pick(u.data, ['phone', 'phone_number', 'phoneNumber']));
    if (p.length >= 10 && !byPhone.has(p)) byPhone.set(p, u.id);
  }

  const clubs = await listDocs('/clubs');
  const memberships = await listDocs('/user_memberships');
  const have = new Set(
    memberships.map(
      (m) =>
        `${pick(m.data, ['user_id', 'userId'])}|${pick(m.data, ['club_id', 'clubId'])}`,
    ),
  );

  const todo = [];
  for (const club of clubs) {
    const clubName = pick(club.data, ['name']) || club.id;
    const creator = pick(club.data, [
      'host_user_id',
      'hostUserId',
      'creator_id',
      'creatorId',
    ]);
    const roster = await listDocs(`/clubs/${club.id}/members`);

    const wanted = new Map(); // uid -> role
    if (creator && userIds.has(creator)) wanted.set(creator, '회장');

    for (const row of roster) {
      const role = pick(row.data, ['role']) || '정회원';
      let uid = '';
      if (userIds.has(row.id)) uid = row.id;
      if (!uid) {
        const f = pick(row.data, ['user_id', 'userId', 'id']);
        if (userIds.has(f)) uid = f;
      }
      if (!uid) {
        const p = digits(pick(row.data, ['phone', 'phone_number']));
        if (p.length >= 10 && byPhone.has(p)) uid = byPhone.get(p);
      }
      if (!uid) {
        console.log(
          `  ? ${clubName}: 명단 ${row.id} (${pick(row.data, ['name']) || '-'}) 는 계정을 못 찾음`,
        );
        continue;
      }
      if (!wanted.has(uid)) wanted.set(uid, role);
    }

    for (const [uid, role] of wanted) {
      if (have.has(`${uid}|${club.id}`)) continue;
      const who = users.find((u) => u.id === uid);
      todo.push({
        clubId: club.id,
        clubName,
        uid,
        role,
        name: pick(who && who.data, ['name']) || '-',
      });
    }
  }

  if (!todo.length) {
    console.log('채울 멤버십 없음.');
    return;
  }
  for (const t of todo) {
    console.log(`  + ${t.clubName} ← ${t.name} (${t.uid}) role=${t.role}`);
  }
  if (!APPLY) {
    console.log('\n--apply 를 붙이면 위 멤버십을 만듭니다.');
    return;
  }

  for (const t of todo) {
    const docId = `${t.uid}_${t.clubId}`;
    const r = await api(
      'PATCH',
      `/user_memberships/${docId}?updateMask.fieldPaths=user_id` +
        `&updateMask.fieldPaths=club_id&updateMask.fieldPaths=role` +
        `&updateMask.fieldPaths=status&updateMask.fieldPaths=joined_at`,
      {
        fields: {
          user_id: { stringValue: t.uid },
          club_id: { stringValue: t.clubId },
          role: { stringValue: t.role },
          status: { stringValue: '활성' },
          joined_at: { timestampValue: new Date().toISOString() },
        },
      },
    );
    console.log(`  ${r.ok ? 'OK' : `FAIL ${r.status}`} ${docId}`);
  }
}

main().catch((e) => {
  console.error(String((e && e.message) || e));
  process.exit(1);
});
