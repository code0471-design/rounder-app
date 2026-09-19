'use strict';

// 지금 명단에 있는 번호로 `member_phone_index` 를 채운다.
//
//   node scripts/backfill_member_phone_index.js           (계획만)
//   node scripts/backfill_member_phone_index.js --apply
//
// 색인 문서 id = 숫자만 남긴 전화번호. 값은 { clubs: { 모임id: 명단행id } }.
// 앱은 로그인할 때 이 문서 하나만 읽어서 "번호로 명단에 올라 있는 모임"을 찾는다.
// 명단이 바뀔 때는 앱이 알아서 갱신하므로 이 스크립트는 최초 1회용이다.

const fs = require('fs');
const path = require('path');

const PROJECT = 'rounder-f6019';
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

const digitsOf = (s) => {
  const d = String(s == null ? '' : s).replace(/[^0-9]/g, '');
  return d.length >= 10 ? d : '';
};

async function main() {
  console.log(`=== ${PROJECT} 번호 색인 ${APPLY ? '(적용)' : '(계획만)'}`);
  const clubs = await listDocs('/clubs');
  const index = new Map(); // digits -> { clubId: memberId }

  for (const club of clubs) {
    const rows = [];
    for (const d of await listDocs(`/clubs/${club.id}/members`)) {
      rows.push({ id: d.data.id || d.id, phone: d.data.phone });
    }
    const r = await api('GET', `/clubs/${club.id}/ops/bundle`);
    if (r.ok) {
      const bundle = fieldsOf(r.json.fields);
      for (const m of bundle.members || []) {
        if (m && typeof m === 'object') rows.push({ id: m.id, phone: m.phone });
      }
    }

    let hits = 0;
    for (const row of rows) {
      const digits = digitsOf(row.phone);
      const memberId = String(row.id || '').trim();
      if (!digits || !memberId) continue;
      if (!index.has(digits)) index.set(digits, {});
      index.get(digits)[club.id] = memberId;
      hits++;
    }
    console.log(`  ${club.data.name || club.id}: 번호 있는 명단 ${hits}건`);
  }

  console.log(`\n색인할 번호 ${index.size}개`);
  if (!APPLY) {
    console.log('--apply 를 붙이면 씁니다.');
    return;
  }

  let ok = 0;
  for (const [digits, clubMap] of index) {
    const fields = {};
    for (const [clubId, memberId] of Object.entries(clubMap)) {
      fields[clubId] = { stringValue: memberId };
    }
    const mask = Object.keys(clubMap)
      .map((c) => `updateMask.fieldPaths=clubs.${c}`)
      .concat('updateMask.fieldPaths=updated_at')
      .join('&');
    const r = await api('PATCH', `/member_phone_index/${digits}?${mask}`, {
      fields: {
        clubs: { mapValue: { fields } },
        updated_at: { timestampValue: new Date().toISOString() },
      },
    });
    if (r.ok) ok++;
    else console.log(`  FAIL ${digits} ${r.status}`);
  }
  console.log(`완료: ${ok}/${index.size}`);
}

main().catch((e) => {
  console.error(String((e && e.message) || e));
  process.exit(1);
});
