'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  shouldFanoutJoinRequest,
  requestIdFor,
  notifyAccountIds,
  officersFromRows,
  loginAccountIdOf,
  joinPushPayload,
} = require('./join_notify');

const ARENA = 'c_1786973797931';
const INCHEON = 'c_1789296617949';
const AHN = 'kakao_5044456654';
const JANG = 'kakao_5049673364';

test('신청 문서 id 가 그 모임 jr_ 가 아니면 푸시하지 않는다', () => {
  assert.equal(
    shouldFanoutJoinRequest({
      requestId: requestIdFor(ARENA, JANG),
      clubId: ARENA,
      status: 'pending',
    }),
    true,
  );
  assert.equal(
    shouldFanoutJoinRequest({
      requestId: requestIdFor(ARENA, JANG),
      clubId: INCHEON,
      status: 'pending',
    }),
    false,
  );
  assert.equal(
    shouldFanoutJoinRequest({
      requestId: requestIdFor(INCHEON, JANG),
      clubId: INCHEON,
      status: 'approved',
    }),
    false,
  );
});

test('A 신청 푸시함은 A 모임명, B 는 B 모임명. itemId 가 섞이지 않는다', () => {
  const arena = joinPushPayload({
    userName: '장창현',
    clubName: '아레나 골프회',
    clubId: ARENA,
  });
  const incheon = joinPushPayload({
    userName: '장창현',
    clubName: '인천 미용인 골프회',
    clubId: INCHEON,
  });
  assert.equal(arena.clubId, ARENA);
  assert.equal(incheon.clubId, INCHEON);
  assert.match(arena.body, /아레나 골프회/);
  assert.match(incheon.body, /인천 미용인 골프회/);
  assert.equal(arena.body.includes('인천'), false);
  assert.equal(incheon.body.includes('아레나'), false);
  assert.equal(requestIdFor(ARENA, JANG), `jr_${ARENA}_${JANG}`);
  assert.equal(requestIdFor(INCHEON, JANG), `jr_${INCHEON}_${JANG}`);
  assert.notEqual(requestIdFor(ARENA, JANG), requestIdFor(INCHEON, JANG));
});

test('수신자는 로그인 계정. 총무 없으면 회장, 없으면 생성자', () => {
  assert.equal(
    loginAccountIdOf({
      clubId: ARENA,
      memberOrUserId: `m_${ARENA}_${AHN}`,
      creatorId: AHN,
    }),
    AHN,
  );
  assert.equal(
    loginAccountIdOf({
      clubId: ARENA,
      memberOrUserId: `m_creator_${ARENA}`,
      creatorId: AHN,
    }),
    AHN,
  );
  assert.equal(
    loginAccountIdOf({
      clubId: ARENA,
      memberOrUserId: `m_creator_${ARENA}`,
      creatorId: '',
    }),
    '',
  );

  const officers = officersFromRows({
    members: [{ id: AHN, userId: AHN, role: '회장·총무' }],
    memberships: [{ user_id: AHN, role: '회장' }],
  });
  assert.deepEqual(
    notifyAccountIds({ officers, creatorId: AHN, clubId: INCHEON }),
    [AHN],
  );

  assert.deepEqual(
    notifyAccountIds({
      officers: [{ userId: AHN, role: '회장' }],
      creatorId: AHN,
      clubId: ARENA,
    }),
    [AHN],
  );
  assert.deepEqual(
    notifyAccountIds({
      officers: [],
      creatorId: AHN,
      clubId: ARENA,
    }),
    [AHN],
  );
});
