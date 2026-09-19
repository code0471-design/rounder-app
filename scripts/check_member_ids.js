'use strict';

// 회원 ID 점검 (읽기 전용). set/delete/patch 없음.
//
//   node scripts/check_member_ids.js                  그 폴더 기준(라운더/원클럽 자동)
//   node scripts/check_member_ids.js --app=oneclub    원클럽 강제
//   node scripts/check_member_ids.js --project=<id>   프로젝트 직접 지정
//   node scripts/check_member_ids.js --club=c_123     한 모임만
//   node scripts/check_member_ids.js --all            이상 없는 모임도 다 출력
//
// 보는 것: 방장 ID / 명단 ID / 회비·시상·참석·포인트가 가리키는 ID.
// 이름(라벨)만 있고 ID가 없으면 개명·R 같은 이름 변경에서 사람이 끊긴다.

const fs = require('fs');
const path = require('path');

const APPS = {
  rounder: { label: '라운더 운영', candidates: ['rounder-f6019'] },
  oneclub: { label: '원클럽', candidates: ['one-club-8d8b0', 'one-club-staging'] },
};

const SEED_NAMES = ['홍길동', '이민준', '박민준'];
const GENERIC_NAMES = ['회원', '카카오 회원', 'Google 회원', 'Apple 회원'];

/// 라운더 폴더에서 돌리면 라운더, 원클럽 폴더에서 돌리면 원클럽.
function defaultApp() {
  const here = process.cwd().toLowerCase();
  if (here.includes('oneclub') || here.includes('one-club')) return 'oneclub';
  return 'rounder';
}

function args() {
  const out = { app: defaultApp(), project: '', club: '', all: false };
  for (const raw of process.argv.slice(2)) {
    const [k, v] = raw.replace(/^--/, '').split('=');
    if (k === 'all') out.all = true;
    else if (k in out) out[k] = v || '';
  }
  if (!APPS[out.app]) throw new Error(`--app 은 rounder 또는 oneclub`);
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
  for (let i = 0; i < 20; i++) {
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

async function queryByField(project, collectionId, field, value) {
  const r = await req(project, 'POST', ':runQuery', {
    structuredQuery: {
      from: [{ collectionId }],
      where: {
        fieldFilter: {
          field: { fieldPath: field },
          op: 'EQUAL',
          value: { stringValue: value },
        },
      },
      limit: 300,
    },
  });
  if (!r.ok) return [];
  return (r.json || [])
    .filter((row) => row && row.document)
    .map((row) => ({
      id: String(row.document.name).split('/').pop(),
      data: fieldsOf(row.document.fields),
    }));
}

function isPlaceholderName(name) {
  const t = String(name || '').trim();
  return (
    !t ||
    t === '-' ||
    /^[A-Za-z]$/.test(t) ||
    SEED_NAMES.includes(t) ||
    GENERIC_NAMES.includes(t)
  );
}

function pick(data, keys) {
  for (const k of keys) {
    const v = data[k];
    if (typeof v === 'string' && v.trim()) return v.trim();
  }
  return '';
}

function shorten(list, max = 4) {
  const arr = [...list];
  if (arr.length <= max) return arr.join(', ');
  return `${arr.slice(0, max).join(', ')} 외 ${arr.length - max}건`;
}

async function pickProject(app, override) {
  if (override) return override;
  for (const candidate of APPS[app].candidates) {
    const clubs = await listDocs(candidate, 'clubs');
    if (clubs.length) return candidate;
  }
  return APPS[app].candidates[0];
}

/// 모임 1개 점검 결과 { name, id, host, lines: [{level, text}] }
async function checkClub(project, club) {
  const id = club.id;
  const data = club.data;
  const lines = [];
  const bad = (text) => lines.push({ level: 'bad', text });
  const warn = (text) => lines.push({ level: 'warn', text });
  const info = (text) => lines.push({ level: 'info', text });

  const hostName = pick(data, ['host_name', 'hostName']);
  const hostId = pick(data, ['host_user_id', 'hostUserId', 'creator_id', 'creatorId']);

  // 명단: 하위문서 + 앱 번들 + (원클럽) 상위 members
  const subRows = await listDocs(project, `clubs/${id}/members`);
  const bundle = await getDoc(project, `clubs/${id}/ops/bundle`);
  const bundleRows = ((bundle && bundle.data.members) || []).filter(
    (m) => m && typeof m === 'object',
  );
  const topRows = await queryByField(project, 'members', 'club_id', id);

  const rosterIds = new Set();
  const nameById = new Map();
  const addRow = (rowId, row, origin) => {
    const ids = [rowId, pick(row, ['id']), pick(row, ['user_id', 'userId'])].filter(Boolean);
    for (const one of ids) rosterIds.add(one);
    const nm = pick(row, ['name', 'display_name', 'displayName']);
    for (const one of ids) if (nm && !nameById.has(one)) nameById.set(one, nm);
    return { ids, name: nm, origin, rowId, row };
  };

  const rows = [
    ...subRows.map((d) => addRow(d.id, d.data, '하위문서')),
    ...bundleRows.map((m) => addRow(pick(m, ['id']), m, '앱번들')),
    ...topRows.map((d) => addRow(d.id, d.data, '상위members')),
  ];

  info(
    `명단 ${rosterIds.size}명 (하위문서 ${subRows.length}, 앱번들 ${bundleRows.length}` +
      `${topRows.length ? `, 상위members ${topRows.length}` : ''})`,
  );

  // 1. 방장이 ID로 붙어 있는가
  if (!hostId) {
    bad(`방장 ID 없음 (host_name='${hostName || '-'}' 뿐 — 개명하면 방장이 사라집니다)`);
  } else if (!rosterIds.has(hostId)) {
    bad(`방장 ${hostId} 가 명단에 없습니다 (표시 이름 '${hostName || '-'}')`);
  }
  if (hostId && isPlaceholderName(hostName)) {
    warn(`방장 표시 이름이 '${hostName || '빈칸'}' 입니다 (ID ${hostId} 는 있음)`);
  }

  // 2. 멤버십 문서(권한 판정)
  if (hostId) {
    const membership = await getDoc(project, `user_memberships/${hostId}_${id}`);
    if (!membership) {
      warn(`user_memberships/${hostId}_${id} 없음 (방장 권한이 기기마다 달라질 수 있습니다)`);
    }
  }

  // 3. 명단 행 자체의 ID 문제
  for (const r of rows) {
    if (!r.ids.length) {
      bad(`${r.origin} 에 ID 없는 명단 줄이 있습니다 (이름 '${r.name || '빈칸'}')`);
      continue;
    }
    const docId = r.rowId;
    const fieldId = pick(r.row, ['id']);
    if (docId && fieldId && docId !== fieldId && r.origin === '하위문서') {
      warn(`명단 ID 불일치: 문서 ${docId} vs id 필드 ${fieldId}`);
    }
  }

  // 4. 같은 이름이 여러 ID로 들어간 경우 (개명·중복가입 흔적)
  const byName = new Map();
  for (const [memberId, nm] of nameById.entries()) {
    if (isPlaceholderName(nm)) continue;
    if (!byName.has(nm)) byName.set(nm, new Set());
    byName.get(nm).add(memberId);
  }
  for (const [nm, ids] of byName.entries()) {
    if (ids.size > 1) warn(`'${nm}' 이름이 ID ${ids.size}개에 붙어 있습니다: ${shorten(ids)}`);
  }

  // 5. 회비·시상·참석·포인트가 가리키는 ID 확인
  const overflow = (bundle && bundle.data.overflowYears) || {};
  const ledgerYears = Array.isArray(overflow.led) ? overflow.led : [];
  const scheduleYears = Array.isArray(overflow.sch) ? overflow.sch : [];

  const buckets = [bundle ? bundle.data : {}];
  for (const y of ledgerYears) {
    const doc = await getDoc(project, `clubs/${id}/ops/led_${y}`);
    if (doc) buckets.push(doc.data);
  }
  for (const y of scheduleYears) {
    const doc = await getDoc(project, `clubs/${id}/ops/sch_${y}`);
    if (doc) buckets.push(doc.data);
  }

  const orphan = new Map(); // 라벨 -> Set(id)
  const staleLabel = new Map(); // 라벨 -> Set('기록이름→명단이름')
  const noteOrphan = (label, memberId) => {
    if (!memberId || rosterIds.has(memberId)) return;
    if (!orphan.has(label)) orphan.set(label, new Set());
    orphan.get(label).add(memberId);
  };
  const noteLabel = (label, memberId, recordName) => {
    const live = nameById.get(memberId);
    if (!live || !recordName || live === recordName) return;
    if (isPlaceholderName(recordName)) return;
    if (!staleLabel.has(label)) staleLabel.set(label, new Set());
    staleLabel.get(label).add(`${recordName}→${live}`);
  };

  for (const bucket of buckets) {
    for (const p of bucket.duesPayments || []) {
      if (!p || typeof p !== 'object') continue;
      noteOrphan('회비 납부', p.memberId);
      noteLabel('회비 납부', p.memberId, p.memberName);
    }
    for (const p of bucket.paymentRequests || []) {
      if (!p || typeof p !== 'object') continue;
      noteOrphan('입금 확인 요청', p.memberId);
      noteLabel('입금 확인 요청', p.memberId, p.memberName);
    }
    for (const a of bucket.awardRecords || []) {
      if (!a || typeof a !== 'object') continue;
      const ids = Array.isArray(a.winnerIds) ? a.winnerIds : [];
      const names = Array.isArray(a.winnerNames) ? a.winnerNames : [];
      if (!ids.length && names.length) {
        if (!orphan.has('시상')) orphan.set('시상', new Set());
        orphan.get('시상').add(`(ID 없이 이름만: ${names.join('/')})`);
      }
      ids.forEach((wid, i) => {
        noteOrphan('시상', wid);
        noteLabel('시상', wid, names[i]);
      });
    }
    for (const s of bucket.schedules || []) {
      if (!s || typeof s !== 'object') continue;
      for (const r of s.responses || []) {
        if (!r || typeof r !== 'object') continue;
        noteOrphan('참석 응답', r.memberId);
        noteLabel('참석 응답', r.memberId, r.memberName);
      }
    }
    for (const w of bucket.waitingList || []) {
      if (!w || typeof w !== 'object') continue;
      noteOrphan('대기 등록', w.memberId);
      noteLabel('대기 등록', w.memberId, w.memberName);
    }
    const points = bucket.pointEvents;
    if (points && typeof points === 'object') {
      for (const key of Object.keys(points)) noteOrphan('랭킹 포인트', key);
    }
    const scores = bucket.roundScores;
    if (Array.isArray(scores)) {
      for (const rec of scores) {
        if (!rec || typeof rec !== 'object' || !rec.scores) continue;
        for (const key of Object.keys(rec.scores)) noteOrphan('스코어', key);
      }
    }
  }

  for (const [label, ids] of orphan.entries()) {
    bad(`${label} 기록이 명단에 없는 ID를 가리킵니다 (${ids.size}건): ${shorten(ids)}`);
  }
  for (const [label, pairs] of staleLabel.entries()) {
    warn(`${label} 표시 이름이 명단과 다릅니다: ${shorten(pairs)}`);
  }

  // 6. 계정 문서 이름
  if (hostId) {
    const user = await getDoc(project, `users/${hostId}`);
    if (!user) warn(`users/${hostId} 계정 문서가 없습니다`);
    else if (isPlaceholderName(pick(user.data, ['name'])))
      warn(`users/${hostId} 이름이 '${pick(user.data, ['name']) || '빈칸'}' 입니다`);
  }

  return {
    id,
    name: pick(data, ['name', 'club_name', 'title']) || '(이름 없음)',
    host: hostName || '-',
    hostId: hostId || '',
    lines,
  };
}

async function main() {
  const opt = args();
  const project = await pickProject(opt.app, opt.project);
  console.log(`=== ${APPS[opt.app].label} (${project}) 회원 ID 점검 — 읽기만 합니다`);

  let clubs = [];
  if (opt.club) {
    const one = await getDoc(project, `clubs/${opt.club}`);
    if (!one) throw new Error(`모임 ${opt.club} 없음`);
    clubs = [one];
  } else {
    clubs = await listDocs(project, 'clubs');
  }
  console.log(`모임 ${clubs.length}개\n`);

  let badTotal = 0;
  let warnTotal = 0;
  const badClubs = [];

  for (const club of clubs) {
    const r = await checkClub(project, club);
    const bad = r.lines.filter((l) => l.level === 'bad');
    const warn = r.lines.filter((l) => l.level === 'warn');
    badTotal += bad.length;
    warnTotal += warn.length;
    if (bad.length) badClubs.push(`${r.name}(${r.id})`);

    if (!opt.all && !bad.length && !warn.length) continue;
    console.log(`[${r.name}] ${r.id}`);
    console.log(`  방장 ${r.host}${r.hostId ? ` / ID ${r.hostId}` : ''}`);
    for (const l of r.lines) {
      if (l.level === 'info' && !opt.all) continue;
      const mark = l.level === 'bad' ? 'X' : l.level === 'warn' ? '!' : '-';
      console.log(`  ${mark} ${l.text}`);
    }
    console.log('');
  }

  console.log('=== 요약');
  console.log(`끊긴 연결(X) ${badTotal}건, 확인 필요(!) ${warnTotal}건`);
  if (badClubs.length) console.log(`X 있는 모임: ${badClubs.join(', ')}`);
  if (!badTotal && !warnTotal) console.log('이름이 아니라 ID로 잘 붙어 있습니다.');
}

main().catch((e) => {
  console.error(String((e && e.message) || e));
  process.exit(1);
});
