'use strict';

// 계정 1개가 "내 모임"으로 잡히는 근거를 찍는다 (읽기 전용).
//
//   node scripts/check_user_clubs.js --name=장창현
//   node scripts/check_user_clubs.js --uid=kakao_123
//   node scripts/check_user_clubs.js --name=장창현 --app=oneclub
//
// 앱이 내 모임을 만드는 근거는 세 가지다.
//   1) user_memberships (user_id == 내 ID)  ← fetchMyClubs
//   2) clubs.creator_id / host_user_id == 내 ID
//   3) 명단(clubs/{id}/members, ops/bundle)에 내 ID가 있음
// 여기서 아무 것도 안 걸리는데 폰에 모임이 보이면 폰에 남은 로컬 데이터다.

const fs = require('fs');
const path = require('path');

const APPS = {
  rounder: { label: '라운더 운영', candidates: ['rounder-f6019'] },
  oneclub: { label: '원클럽', candidates: ['one-club-8d8b0', 'one-club-staging'] },
};

function defaultApp() {
  const here = process.cwd().toLowerCase();
  if (here.includes('oneclub') || here.includes('one-club')) return 'oneclub';
  return 'rounder';
}

function args() {
  const out = { app: defaultApp(), project: '', name: '', uid: '' };
  for (const raw of process.argv.slice(2)) {
    const [k, v] = raw.replace(/^--/, '').split('=');
    if (k in out) out[k] = v || '';
  }
  if (!out.name && !out.uid) throw new Error('--name=이름 또는 --uid=계정ID 를 주세요');
  return out;
}

function token() {
  const p = path.join(
    process.env.USERPROFILE || process.env.HOME || '',
    '.config',
    'configstore',
    'firebase-tools.json',
  );
  const cfg = JSON.parse(fs.readFileSync(p, 'utf8'));
  const t = cfg.tokens || {};
  const access = t.access_token || t.accessToken;
  if (!access) throw new Error('firebase 토큰이 없습니다. `firebase login` 후 다시 실행하세요.');
  return access;
}

async function req(project, method, rel, body) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${project}` +
    `/databases/(default)/documents${rel.startsWith(':') ? rel : `/${rel}`}`;
  const res = await fetch(url, {
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
  } catch (_) {
    json = {};
  }
  if (res.status === 401) {
    throw new Error('토큰이 만료됐습니다. `firebase login --reauth` 후 다시 실행하세요.');
  }
  return { ok: res.ok, status: res.status, json };
}

function val(v) {
  if (!v || typeof v !== 'object') return null;
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('timestampValue' in v) return v.timestampValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(val);
  if ('mapValue' in v) return fieldsOf(v.mapValue.fields || {});
  return null;
}

function fieldsOf(f) {
  const out = {};
  for (const k of Object.keys(f || {})) out[k] = val(f[k]);
  return out;
}

async function getDoc(project, rel) {
  const r = await req(project, 'GET', rel);
  if (!r.ok) return null;
  return { id: String(r.json.name || '').split('/').pop(), data: fieldsOf(r.json.fields) };
}

async function listDocs(project, rel) {
  const out = [];
  let pageToken = '';
  for (let i = 0; i < 30; i++) {
    const sep = rel.includes('?') ? '&' : '?';
    const r = await req(
      project,
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

function pick(data, keys) {
  for (const k of keys) {
    const v = (data || {})[k];
    if (typeof v === 'string' && v.trim()) return v.trim();
  }
  return '';
}

async function main() {
  const opt = args();
  let project = opt.project;
  if (!project) {
    for (const candidate of APPS[opt.app].candidates) {
      const clubs = await listDocs(candidate, 'clubs');
      if (clubs.length) {
        project = candidate;
        break;
      }
    }
    project = project || APPS[opt.app].candidates[0];
  }
  console.log(`=== ${APPS[opt.app].label} (${project}) — 읽기만 합니다`);

  const users = await listDocs(project, 'users');
  let uid = opt.uid;
  if (!uid) {
    const hits = users.filter((u) => pick(u.data, ['name']) === opt.name);
    if (!hits.length) {
      console.log(`users 에 '${opt.name}' 이름이 없습니다. 후보:`);
      for (const u of users) console.log(`  ${u.id}\t${pick(u.data, ['name'])}`);
      return;
    }
    if (hits.length > 1) {
      console.log(`'${opt.name}' 계정이 ${hits.length}개입니다:`);
      for (const h of hits) console.log(`  ${h.id}`);
    }
    uid = hits[0].id;
  }
  const me = users.find((u) => u.id === uid);
  console.log(`계정 ${uid} 이름 '${pick(me && me.data, ['name']) || '-'}'\n`);

  const clubs = await listDocs(project, 'clubs');
  const memberships = await listDocs(project, 'user_memberships');
  const mine = memberships.filter((m) => pick(m.data, ['user_id', 'userId']) === uid);

  console.log(`user_memberships 내 것 ${mine.length}건 / 전체 ${memberships.length}건`);
  for (const m of mine) {
    const clubId = pick(m.data, ['club_id', 'clubId']);
    const club = clubs.find((c) => c.id === clubId);
    console.log(
      `  ${clubId} ${club ? pick(club.data, ['name']) : '(모임 문서 없음)'}` +
        ` role=${pick(m.data, ['role']) || '-'}`,
    );
  }

  // user_id 가 비었거나 이상한 멤버십 — 모든 사람에게 붙을 수 있다
  const broken = memberships.filter((m) => !pick(m.data, ['user_id', 'userId']));
  if (broken.length) {
    console.log(`\nX user_id 없는 멤버십 ${broken.length}건: ${broken.map((b) => b.id).join(', ')}`);
  }

  console.log('\n모임별 근거 (m=멤버십, c=생성자, r=명단)');
  for (const club of clubs) {
    const name = pick(club.data, ['name']) || '(이름 없음)';
    const creator = pick(club.data, [
      'host_user_id',
      'hostUserId',
      'creator_id',
      'creatorId',
    ]);
    const hasMembership = mine.some(
      (m) => pick(m.data, ['club_id', 'clubId']) === club.id,
    );
    const isCreator = creator === uid;

    const sub = await listDocs(project, `clubs/${club.id}/members`);
    const bundle = await getDoc(project, `clubs/${club.id}/ops/bundle`);
    const bundleRows = ((bundle && bundle.data.members) || []).filter(
      (m) => m && typeof m === 'object',
    );
    const rosterIds = new Set();
    for (const d of sub) {
      rosterIds.add(d.id);
      const fid = pick(d.data, ['id']);
      const u = pick(d.data, ['user_id', 'userId']);
      if (fid) rosterIds.add(fid);
      if (u) rosterIds.add(u);
    }
    for (const m of bundleRows) {
      const fid = pick(m, ['id']);
      if (fid) rosterIds.add(fid);
    }
    const inRoster =
      rosterIds.has(uid) || [...rosterIds].some((id) => id.endsWith(`_${uid}`));

    const marks =
      `${hasMembership ? 'm' : '-'}${isCreator ? 'c' : '-'}${inRoster ? 'r' : '-'}`;
    const mineNow = hasMembership || isCreator || inRoster;
    console.log(
      `  [${marks}] ${mineNow ? '내 모임' : '남의 모임'}  ${name} ${club.id}` +
        `  명단 ${rosterIds.size}명`,
    );
  }

  console.log(
    '\n근거가 하나도 없는데 폰에 내 모임으로 보이면 서버가 아니라 폰에 남은 로컬 데이터입니다.',
  );
}

main().catch((e) => {
  console.error(String((e && e.message) || e));
  process.exit(1);
});
