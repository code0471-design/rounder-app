'use strict';

const fs = require('fs');
const path = require('path');

const PROJECT = 'rounder-f6019';

const fbApi = require(path.join(
  process.env.APPDATA,
  'npm',
  'node_modules',
  'firebase-tools',
  'lib',
  'api',
));

function loadTokens() {
  return JSON.parse(
    fs.readFileSync(
      path.join(
        process.env.USERPROFILE || '',
        '.config',
        'configstore',
        'firebase-tools.json',
      ),
      'utf8',
    ),
  ).tokens || {};
}

async function token() {
  const t = loadTokens();
  const body = new URLSearchParams({
    grant_type: 'refresh_token',
    refresh_token: t.refresh_token,
    client_id: fbApi.clientId(),
    client_secret: fbApi.clientSecret(),
  });
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  const json = await res.json();
  if (!json.access_token) throw new Error(`oauth ${json.error || json.status}`);
  return json.access_token;
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
  if ('mapValue' in v) {
    const o = {};
    for (const k of Object.keys(v.mapValue.fields || {})) {
      o[k] = val(v.mapValue.fields[k]);
    }
    return o;
  }
  return null;
}

function toFs(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') {
    return Number.isInteger(v)
      ? { integerValue: String(v) }
      : { doubleValue: v };
  }
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toFs) } };
  if (typeof v === 'object') {
    const fields = {};
    for (const k of Object.keys(v)) fields[k] = toFs(v[k]);
    return { mapValue: { fields } };
  }
  return { stringValue: String(v) };
}

function fieldsOf(j) {
  const o = {};
  for (const k of Object.keys((j && j.fields) || {})) o[k] = val(j.fields[k]);
  return o;
}

let _tok;
async function req(method, rel, body) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${PROJECT}` +
    `/databases/(default)/documents${rel.startsWith(':') ? rel : `/${rel}`}`;
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${_tok}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  if (res.status === 404) return null;
  if (!res.ok) {
    throw new Error(`${method} ${rel} ${res.status} ${text.slice(0, 300)}`);
  }
  return text ? JSON.parse(text) : {};
}

async function listAll(colPath) {
  const out = [];
  let pageToken;
  do {
    let url =
      `https://firestore.googleapis.com/v1/projects/${PROJECT}` +
      `/databases/(default)/documents/${colPath}?pageSize=300`;
    if (pageToken) url += `&pageToken=${encodeURIComponent(pageToken)}`;
    const res = await fetch(url, { headers: { Authorization: `Bearer ${_tok}` } });
    const json = await res.json();
    if (!res.ok) {
      if (res.status === 404) return out;
      throw new Error(`LIST ${colPath} ${res.status}`);
    }
    out.push(...(json.documents || []));
    pageToken = json.nextPageToken;
  } while (pageToken);
  return out;
}

function parseDate(raw) {
  if (!raw) return null;
  const d = new Date(raw);
  return Number.isNaN(d.getTime()) ? null : d;
}

function earlier(a, b) {
  if (!a) return b;
  if (!b) return a;
  return a.getTime() <= b.getTime() ? a : b;
}

function createdAtFromClubId(clubId) {
  if (!String(clubId).startsWith('c_')) return null;
  const ms = Number(String(clubId).slice(2));
  if (!Number.isFinite(ms) || ms < 1e12 || ms > 4e12) return null;
  const d = new Date(ms);
  if (d.getFullYear() < 2020 || d.getFullYear() > 2100) return null;
  return d;
}

function ymd(d) {
  if (!d) return '-';
  const x = new Date(d);
  const y = x.getFullYear();
  const m = String(x.getMonth() + 1).padStart(2, '0');
  const day = String(x.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function isCreator(memberId, club) {
  if (memberId === `m_creator_${club.id}`) return true;
  const cid = (club.creatorId || '').trim();
  if (!cid) return false;
  return memberId === cid || memberId === `m_${club.id}_${cid}`;
}

function sameInstant(a, b) {
  if (!a && !b) return true;
  if (!a || !b) return false;
  return a.getTime() === b.getTime();
}

(async () => {
  _tok = await token();
  const apply = process.argv.includes('--apply');
  const clubs = (await listAll('clubs')).map((d) => {
    const f = fieldsOf(d);
    const id = d.name.split('/').pop();
    return {
      id,
      name: f.name || '',
      creatorId: f.creator_id || f.creatorId || f.host_user_id || '',
      createdAt: parseDate(f.created_at || f.createdAt),
      sample: f.is_sample === true,
    };
  }).filter((c) => c.id.startsWith('c_') && !c.sample);

  const memberships = (await listAll('user_memberships')).map((d) => {
    const f = fieldsOf(d);
    return {
      userId: f.user_id || '',
      clubId: f.club_id || '',
      joinedAt: parseDate(f.joined_at || f.created_at),
    };
  });

  console.log(apply ? 'APPLY join dates' : 'DRY-RUN join dates', clubs.length, 'clubs');

  for (const club of clubs) {
    const fromId = createdAtFromClubId(club.id);
    const created = earlier(club.createdAt, fromId) || club.createdAt || fromId;
    if (!created) continue;

    const opsRaw = await req('GET', `clubs/${club.id}/ops/bundle`);
    const ops = opsRaw ? fieldsOf(opsRaw) : {};
    const members = Array.isArray(ops.members) ? ops.members : [];
    const activities = Array.isArray(ops.activities) ? ops.activities : [];
    const memberDocs = await listAll(`clubs/${club.id}/members`);

    const evidence = {};
    const addEv = (id, d) => {
      if (!id || !d) return;
      evidence[id] = earlier(evidence[id], d);
    };
    for (const a of activities) {
      if (a.activityType !== 'join') continue;
      addEv(a.memberId, parseDate(a.timestamp));
    }
    for (const mem of memberships) {
      if (mem.clubId !== club.id) continue;
      addEv(mem.userId, mem.joinedAt);
      addEv(`m_${club.id}_${mem.userId}`, mem.joinedAt);
      if (mem.userId === club.creatorId) addEv(`m_creator_${club.id}`, created);
    }

    const nextMembers = members.map((m) => {
      const id = m.id || '';
      const cur = parseDate(m.joinDate || m.join_date);
      const next = isCreator(id, club)
        ? created
        : earlier(cur, evidence[id] || evidence[id.replace(`m_${club.id}_`, '')]);
      return { ...m, joinDate: next ? next.toISOString() : m.joinDate };
    });

    const changed = [];
    for (const before of members) {
      const after = nextMembers.find((m) => m.id === before.id);
      const a = parseDate(before.joinDate || before.join_date);
      const b = parseDate(after && after.joinDate);
      if (!sameInstant(a, b)) {
        changed.push(`${before.name || before.id} ${ymd(a)} → ${ymd(b)}`);
      }
    }
    if (!club.createdAt || (fromId && club.createdAt.getTime() > fromId.getTime() + 1000)) {
      changed.push(`club.createdAt ${ymd(club.createdAt)} → ${ymd(created)}`);
    }

    console.log(
      `\n${club.name} ${club.id} open=${ymd(created)} creator=${club.creatorId}`,
    );
    for (const m of nextMembers) {
      const before = members.find((x) => x.id === m.id);
      console.log(
        ' ',
        m.name,
        m.id,
        m.role,
        'join',
        ymd(parseDate(before && (before.joinDate || before.join_date))),
        '→',
        ymd(parseDate(m.joinDate)),
        isCreator(m.id, club) ? '(host)' : '',
      );
    }
    if (changed.length) console.log('  FIX', changed.join(' | '));

    if (!apply || !changed.length) continue;

    if (fromId && (!club.createdAt || club.createdAt.getTime() > fromId.getTime() + 1000)) {
      await req(
        'PATCH',
        `clubs/${club.id}?updateMask.fieldPaths=created_at`,
        { fields: { created_at: { timestampValue: created.toISOString() } } },
      );
    }
    if (opsRaw && members.length) {
      await req(
        'PATCH',
        `clubs/${club.id}/ops/bundle?updateMask.fieldPaths=members`,
        { fields: { members: toFs(nextMembers) } },
      );
    }
    for (const doc of memberDocs) {
      const id = doc.name.split('/').pop();
      const f = fieldsOf(doc);
      const row = nextMembers.find(
        (m) => m.id === id || m.id === `m_creator_${club.id}` && id === club.creatorId
          || m.id === `m_${club.id}_${id}`,
      );
      const next = row ? parseDate(row.joinDate) : (isCreator(id, club) ? created : null);
      if (!next) continue;
      const cur = parseDate(f.join_date || f.joinDate);
      if (sameInstant(cur, next)) continue;
      await req(
        'PATCH',
        `clubs/${club.id}/members/${id}?updateMask.fieldPaths=join_date`,
        { fields: { join_date: { stringValue: next.toISOString() } } },
      );
    }
  }
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
