"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { recipientsForClub, addDays } = require("./dues_remind");

const ARENA = "c_1786973797931";
const VOLCANO = "c_1790768750847";
const EAGLE = "c_1789200750074";
const ALADDIN = "c_1789270673471";
const JANG = "kakao_5049673364";
const ROYCE = "kakao_5044456654";

const tomorrow = { year: 2026, month: 10, day: 25 };

function monthly(id, day) {
  return {
    id,
    type: "monthly",
    isActive: true,
    dueDayOfMonth: day,
    amount: 100000,
    createdAt: "2026-01-01T00:00:00.000",
  };
}

test("내일 납부일인 미납 정회원에게만, 모임당 한 통", () => {
  const people = recipientsForClub({
    id: ALADDIN,
    name: "7080 골프모임",
    members: [
      { id: `m_${ALADDIN}_${ROYCE}`, name: "안경헌", memberType: "정회원", status: "활성", phone: "010-4511-0471" },
      { id: `m_${ALADDIN}_${JANG}`, name: "장창현", memberType: "정회원", status: "활성", phone: "821040620830" },
      { id: "guest", name: "게스트", memberType: "게스트", status: "활성", phone: "010-1111-2222" },
      { id: "left", name: "탈퇴", memberType: "정회원", status: "탈퇴", phone: "010-3333-4444" },
    ],
    settings: [monthly("ds", 25), monthly("ds-copy", 25)],
    payments: [],
  }, tomorrow);
  assert.deepEqual(people.map((p) => p.phone), ["01045110471", "01040620830"]);
  assert.equal(people[0].clubName, "7080 골프모임");
  assert.equal(people[0].dueText, "2026.10.25");
});

test("이미 낸 사람과 납부일이 아닌 모임은 빠진다", () => {
  const paid = recipientsForClub({
    id: VOLCANO,
    name: "볼케이노~~",
    members: [
      { id: `m_${VOLCANO}_${ROYCE}`, name: "안경헌", memberType: "정회원", status: "활성", phone: "01045110471" },
      { id: `m_${VOLCANO}_${JANG}`, name: "장창현", memberType: "정회원", status: "활성", phone: "01040620830" },
    ],
    settings: [monthly("ds", 25)],
    payments: [{
      duesSettingId: "ds",
      memberId: ROYCE,
      paidAt: "2026-10-20T01:00:00.000Z",
    }],
  }, tomorrow);
  assert.deepEqual(paid.map((p) => p.name), ["장창현"]);

  const later = recipientsForClub({
    id: ARENA,
    name: "아레나 골프회",
    members: [
      { id: `m_creator_${ARENA}`, name: "안경헌", memberType: "정회원", status: "활성", phone: "01045110471" },
    ],
    settings: [monthly("ds1", 27)],
    payments: [],
  }, tomorrow);
  assert.equal(later.length, 0);
});

test("장창현은 볼케이노 회원이면 받고, 아레나 명단 찌꺼기면 안 받는다", () => {
  const volcano = recipientsForClub({
    id: VOLCANO,
    name: "볼케이노~~",
    members: [
      { id: `m_${VOLCANO}_${JANG}`, name: "장창현", memberType: "정회원", status: "활성", phone: "01040620830" },
    ],
    settings: [monthly("ds", 25)],
    payments: [],
  }, tomorrow);
  assert.equal(volcano.length, 1);

  const arena = recipientsForClub({
    id: ARENA,
    name: "아레나 골프회",
    members: [
      { id: `m_${ARENA}_${JANG}`, name: "장창현", memberType: "정회원", status: "활성", phone: "01040620830" },
      { id: "m_creator_" + ARENA, name: "안경헌", memberType: "정회원", status: "활성", phone: "01045110471" },
    ],
    settings: [monthly("ds1", 25)],
    payments: [],
  }, tomorrow);
  assert.deepEqual(arena.map((p) => p.name), ["안경헌"]);
});

test("명단에 없는 이글 회원은 만들지 않는다", () => {
  const eagle = recipientsForClub({
    id: EAGLE,
    name: "이글",
    members: [
      { id: "m_creator_" + EAGLE, name: "김경희", memberType: "정회원", status: "활성", phone: "01034792627" },
    ],
    settings: [monthly("ds1", 25)],
    payments: [],
  }, tomorrow);
  assert.deepEqual(eagle.map((p) => p.name), ["김경희"]);
});

test("발송 다음 날이 납부일이다", () => {
  assert.deepEqual(addDays({ year: 2026, month: 10, day: 24 }, 1), {
    year: 2026,
    month: 10,
    day: 25,
  });
});
