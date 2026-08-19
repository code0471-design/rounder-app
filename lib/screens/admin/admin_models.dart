// ════════════════════════════════════════════════════════════
//  ROUNDER Admin — shared models / catalogs
// ════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import 'admin_theme.dart';

// ────────────────────────────────────────────────────────────
class AdminClub {
  final String id;
  final String name;
  final String host;
  final int memberCount;
  final String createdDate;
  final String status; // pending | active | ended | blinded
  final String region;
  final String? description;
  final int maxMembers;

  const AdminClub({
    required this.id,
    required this.name,
    required this.host,
    required this.memberCount,
    required this.createdDate,
    required this.status,
    required this.region,
    this.description,
    this.maxMembers = 20,
  });

  String get statusLabel => switch (status) {
        'pending' => '검수중',
        'active' => '활성',
        'ended' => '종료',
        'blinded' => '블라인드',
        _ => status,
      };

  Color get statusColor => switch (status) {
        'pending' => AdminColors.statusWarn,
        'active' => AdminColors.statusOk,
        'ended' => AdminColors.statusDanger,
        'blinded' => AdminColors.statusDanger,
        _ => AdminColors.statusInfo,
      };

  AdminClub copyWith({
    String? id,
    String? name,
    String? host,
    int? memberCount,
    String? createdDate,
    String? status,
    String? region,
    String? description,
    int? maxMembers,
  }) =>
      AdminClub(
        id: id ?? this.id,
        name: name ?? this.name,
        host: host ?? this.host,
        memberCount: memberCount ?? this.memberCount,
        createdDate: createdDate ?? this.createdDate,
        status: status ?? this.status,
        region: region ?? this.region,
        description: description ?? this.description,
        maxMembers: maxMembers ?? this.maxMembers,
      );
}

class AdminMember {
  final String id;
  final String name;
  final String phone;
  final String nickname;
  final String gender;
  final String joinDate;
  final String status; // normal | blocked
  final int clubCount;
  final String? email;
  final String? lastLogin;

  const AdminMember({
    required this.id,
    required this.name,
    required this.phone,
    required this.nickname,
    required this.gender,
    required this.joinDate,
    required this.status,
    required this.clubCount,
    this.email,
    this.lastLogin,
  });

  String get statusLabel => status == 'blocked' ? '차단' : '정상';

  Color get statusColor =>
      status == 'blocked' ? AdminColors.statusDanger : AdminColors.statusOk;

  AdminMember copyWith({
    String? id,
    String? name,
    String? phone,
    String? nickname,
    String? gender,
    String? joinDate,
    String? status,
    int? clubCount,
    String? email,
    String? lastLogin,
  }) =>
      AdminMember(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        nickname: nickname ?? this.nickname,
        gender: gender ?? this.gender,
        joinDate: joinDate ?? this.joinDate,
        status: status ?? this.status,
        clubCount: clubCount ?? this.clubCount,
        email: email ?? this.email,
        lastLogin: lastLogin ?? this.lastLogin,
      );
}

// ────────────────────────────────────────────────────────────
class AlimtalkTemplate {
  final String id;
  final String name;
  final String preview;
  final String category;
  final String? solapiTemplateId;

  const AlimtalkTemplate({
    required this.id,
    required this.name,
    required this.preview,
    required this.category,
    this.solapiTemplateId,
  });
}

/// 플랫폼 알림 정책 1행 (어드민 알림관리 표)
class NotificationPolicyRow {
  final int no;
  final String event;
  final String channel;
  final String audience;
  final String timing;

  const NotificationPolicyRow({
    required this.no,
    required this.event,
    required this.channel,
    required this.audience,
    required this.timing,
  });
}

/// 푸시 발송 대상 (본사 기준 3종)
enum PushAudienceKind {
  /// 게스트를 제외한 모임의 모든 회원
  allMembers,

  /// 해당 일정 참석 응답한 회원 (참석 게스트 포함)
  attendees,

  /// 이벤트 발생 시 관련 1명 (승인·거절·독촉·가입신청 수신자 등)
  specificMember,
}

/// 푸시 발송 시간 (본사 기준)
enum PushTimingKind {
  /// 등록·처리·확정·취소 등 이벤트 발생 즉시
  immediate,

  /// 라운딩 D-1 오전 10시
  d1At10,
}

extension PushAudienceKindX on PushAudienceKind {
  String get label => switch (this) {
        PushAudienceKind.allMembers => '전체회원',
        PushAudienceKind.attendees => '참석회원',
        PushAudienceKind.specificMember => '해당 회원',
      };

  String get description => switch (this) {
        PushAudienceKind.allMembers => '게스트를 제외한 모임의 모든 회원',
        PushAudienceKind.attendees => '해당 일정에 참석하기로 한 회원 (참석 게스트 포함)',
        PushAudienceKind.specificMember =>
          '이벤트 발생 시 관련 회원 1명 (가입 승인·거절·회비 독촉·가입신청 수신 등)',
      };
}

extension PushTimingKindX on PushTimingKind {
  String get label => switch (this) {
        PushTimingKind.immediate => '등록 즉시',
        PushTimingKind.d1At10 => 'D-1 10시',
      };

  String get description => switch (this) {
        PushTimingKind.immediate => '등록·처리·확정·취소 등 이벤트 발생 시 바로 발송',
        PushTimingKind.d1At10 => '라운딩 하루 전 오전 10시에 자동 발송',
      };
}

/// 본사에서 설정하는 푸시 알림 종류 1건
class HqPushType {
  final String id;
  final String name;
  final String channel; // 푸시 | 푸시·알림톡
  final PushAudienceKind audience;
  final PushTimingKind timing;
  /// 해당 회원일 때 구체 수신자 설명 (UI 보조)
  final String audienceDetail;
  final String defaultTitle;
  final String defaultBody;
  final bool enabled;

  const HqPushType({
    required this.id,
    required this.name,
    required this.channel,
    required this.audience,
    required this.timing,
    this.audienceDetail = '',
    required this.defaultTitle,
    required this.defaultBody,
    this.enabled = true,
  });

  HqPushType copyWith({
    String? name,
    String? channel,
    PushAudienceKind? audience,
    PushTimingKind? timing,
    String? audienceDetail,
    String? defaultTitle,
    String? defaultBody,
    bool? enabled,
  }) =>
      HqPushType(
        id: id,
        name: name ?? this.name,
        channel: channel ?? this.channel,
        audience: audience ?? this.audience,
        timing: timing ?? this.timing,
        audienceDetail: audienceDetail ?? this.audienceDetail,
        defaultTitle: defaultTitle ?? this.defaultTitle,
        defaultBody: defaultBody ?? this.defaultBody,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'channel': channel,
        'audience': audience.name,
        'timing': timing.name,
        'audienceDetail': audienceDetail,
        'defaultTitle': defaultTitle,
        'defaultBody': defaultBody,
        'enabled': enabled,
      };

  factory HqPushType.fromJson(Map<String, dynamic> j) {
    PushAudienceKind aud = PushAudienceKind.allMembers;
    for (final v in PushAudienceKind.values) {
      if (v.name == j['audience']) aud = v;
    }
    PushTimingKind tim = PushTimingKind.immediate;
    for (final v in PushTimingKind.values) {
      if (v.name == j['timing']) tim = v;
    }
    return HqPushType(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      channel: j['channel'] as String? ?? '푸시',
      audience: aud,
      timing: tim,
      audienceDetail: j['audienceDetail'] as String? ?? '',
      defaultTitle: j['defaultTitle'] as String? ?? '',
      defaultBody: j['defaultBody'] as String? ?? '',
      enabled: j['enabled'] as bool? ?? true,
    );
  }
}

/// 본사에서 설정하는 자동 알림톡 종류 1건
class HqAlimtalkType {
  final String id;
  final String name;
  final PushAudienceKind audience;
  final PushTimingKind timing;
  final String audienceDetail;
  final String preview;
  final bool enabled;

  const HqAlimtalkType({
    required this.id,
    required this.name,
    required this.audience,
    required this.timing,
    this.audienceDetail = '',
    required this.preview,
    this.enabled = true,
  });

  HqAlimtalkType copyWith({
    String? name,
    PushAudienceKind? audience,
    PushTimingKind? timing,
    String? audienceDetail,
    String? preview,
    bool? enabled,
  }) =>
      HqAlimtalkType(
        id: id,
        name: name ?? this.name,
        audience: audience ?? this.audience,
        timing: timing ?? this.timing,
        audienceDetail: audienceDetail ?? this.audienceDetail,
        preview: preview ?? this.preview,
        // false도 반영되도록 ?? 대신 명시 체크
        enabled: enabled != null ? enabled : this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'audience': audience.name,
        'timing': timing.name,
        'audienceDetail': audienceDetail,
        'preview': preview,
        'enabled': enabled,
      };

  factory HqAlimtalkType.fromJson(Map<String, dynamic> j) {
    PushAudienceKind aud = PushAudienceKind.allMembers;
    for (final v in PushAudienceKind.values) {
      if (v.name == j['audience']) aud = v;
    }
    PushTimingKind tim = PushTimingKind.immediate;
    for (final v in PushTimingKind.values) {
      if (v.name == j['timing']) tim = v;
    }
    return HqAlimtalkType(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      audience: aud,
      timing: tim,
      audienceDetail: j['audienceDetail'] as String? ?? '',
      preview: j['preview'] as String? ?? '',
      enabled: j['enabled'] as bool? ?? true,
    );
  }
}

/// 본사 → 앱 가입 회원 전체 발송 건
class HqBroadcastJob {
  final String id;
  final String title;
  final String body;
  final DateTime when;
  final bool sendNow;
  final String status; // draft | scheduled | sending | sent

  const HqBroadcastJob({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
    required this.sendNow,
    required this.status,
  });

  HqBroadcastJob copyWith({String? status}) => HqBroadcastJob(
        id: id,
        title: title,
        body: body,
        when: when,
        sendNow: sendNow,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'when': when.toIso8601String(),
        'sendNow': sendNow,
        'status': status,
      };

  factory HqBroadcastJob.fromJson(Map<String, dynamic> j) {
    DateTime when = DateTime.now();
    final raw = j['when'];
    if (raw is String) when = DateTime.tryParse(raw) ?? when;
    return HqBroadcastJob(
      id: j['id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
      when: when,
      sendNow: j['sendNow'] as bool? ?? true,
      status: j['status'] as String? ?? 'draft',
    );
  }
}

// ────────────────────────────────────────────────────────────
//  Dashboard Stats
// ────────────────────────────────────────────────────────────
class DashboardStats {
  final int totalMembers;
  final int activeClubs;
  final int todaySignups;
  final int todayNewClubs;
  final List<int> weeklySignups;
  final List<int> weeklyClubs;

  const DashboardStats({
    required this.totalMembers,
    required this.activeClubs,
    required this.todaySignups,
    required this.todayNewClubs,
    required this.weeklySignups,
    required this.weeklyClubs,
  });
}

/// 알림톡 템플릿·알림 정책 (정적). 회원/모임 데이터는 [AdminController].
abstract final class AdminCatalog {
  /// 첨부 알림관리 표 기준 정책
  static const List<NotificationPolicyRow> notificationPolicies = [
    NotificationPolicyRow(
      no: 1,
      event: '가입신청',
      channel: '푸시',
      audience: '해당 회원(총무)',
      timing: '등록 즉시',
    ),
    NotificationPolicyRow(
      no: 2,
      event: '가입 승인/거절',
      channel: '푸시',
      audience: '해당 회원',
      timing: '등록 즉시',
    ),
    NotificationPolicyRow(
      no: 3,
      event: '일정확정 참석권유',
      channel: '푸시·알림톡',
      audience: '전체회원',
      timing: '등록 즉시',
    ),
    NotificationPolicyRow(
      no: 4,
      event: 'D-1 리마인더',
      channel: '푸시·알림톡',
      audience: '참석회원',
      timing: 'D-1 10시',
    ),
    NotificationPolicyRow(
      no: 5,
      event: '회비 납부요청',
      channel: '푸시·알림톡',
      audience: '전체회원',
      timing: '등록 즉시',
    ),
    NotificationPolicyRow(
      no: 6,
      event: '일정취소 알림',
      channel: '푸시·알림톡',
      audience: '참석회원',
      timing: '등록 즉시',
    ),
    NotificationPolicyRow(
      no: 7,
      event: '모임 초대',
      channel: '알림톡',
      audience: '외부 초대자',
      timing: '등록 즉시',
    ),
    NotificationPolicyRow(
      no: 8,
      event: '납부 독촉',
      channel: '푸시',
      audience: '해당 회원',
      timing: '등록 즉시',
    ),
  ];

  /// 본사 푸시 알림 종류 (채널에 푸시 포함)
  static const List<HqPushType> hqPushTypes = [
    HqPushType(
      id: 'push_join_request',
      name: '가입신청',
      channel: '푸시',
      audience: PushAudienceKind.specificMember,
      timing: PushTimingKind.immediate,
      audienceDetail: '수신 담당 총무(없으면 방장)',
      defaultTitle: '새 가입 신청',
      defaultBody: '{{모임명}}에 {{신청자}}님이 가입을 신청했습니다.',
    ),
    HqPushType(
      id: 'push_join_result',
      name: '가입 승인/거절',
      channel: '푸시',
      audience: PushAudienceKind.specificMember,
      timing: PushTimingKind.immediate,
      audienceDetail: '신청자 본인',
      defaultTitle: '가입 신청 결과',
      defaultBody: '{{이름}}님, {{모임명}} 가입 신청이 {{결과}}되었습니다.',
    ),
    HqPushType(
      id: 'push_schedule_confirm',
      name: '일정확정 참석권유',
      channel: '푸시·알림톡',
      audience: PushAudienceKind.allMembers,
      timing: PushTimingKind.immediate,
      audienceDetail: '정회원 전원 (등록자 본인 포함, 게스트 제외)',
      defaultTitle: '라운딩이 확정되었습니다',
      defaultBody: '{{모임명}} 라운딩이 확정되었습니다. 참석 여부를 알려주세요.',
    ),
    HqPushType(
      id: 'push_d1_reminder',
      name: 'D-1 리마인더',
      channel: '푸시·알림톡',
      audience: PushAudienceKind.attendees,
      timing: PushTimingKind.d1At10,
      defaultTitle: '내일 라운딩 안내',
      defaultBody: '내일 {{모임명}} 라운딩이 있습니다. 늦지 않게 준비해 주세요.',
    ),
    HqPushType(
      id: 'push_dues_request',
      name: '회비 납부요청',
      channel: '푸시·알림톡',
      audience: PushAudienceKind.allMembers,
      timing: PushTimingKind.immediate,
      defaultTitle: '회비 납부 안내',
      defaultBody: '{{모임명}} 회비 납부를 안내드립니다. 납부 기한: {{기한}}',
    ),
    HqPushType(
      id: 'push_schedule_cancel',
      name: '일정취소 알림',
      channel: '푸시·알림톡',
      audience: PushAudienceKind.attendees,
      timing: PushTimingKind.immediate,
      defaultTitle: '라운딩이 취소되었습니다',
      defaultBody: '{{모임명}} 라운딩이 취소되었습니다. 사유: {{사유}}',
    ),
    HqPushType(
      id: 'push_dues_nudge',
      name: '납부 독촉',
      channel: '푸시',
      audience: PushAudienceKind.specificMember,
      timing: PushTimingKind.immediate,
      audienceDetail: '미납 회원(총무 수동 발송)',
      defaultTitle: '회비 납부 독촉',
      defaultBody: '{{이름}}님, {{모임명}} 회비 미납 안내드립니다. 확인 후 납부해 주세요.',
    ),
  ];

  /// 본사 자동 알림톡 종류 (푸시 관리와 동일 UX)
  static const List<HqAlimtalkType> hqAlimtalkTypes = [
    HqAlimtalkType(
      id: 'atk_schedule_upload',
      name: '일정 등록 참석 안내',
      audience: PushAudienceKind.allMembers,
      timing: PushTimingKind.immediate,
      audienceDetail: '정회원 전원 (등록자 본인 포함, 게스트 제외)',
      preview:
          '{{모임명}} 라운딩이 등록되었습니다.\n📅 일시: {{일시}}\n📍 장소: {{장소}}\n참석 여부를 알려주세요.',
    ),
    HqAlimtalkType(
      id: 'atk_group_finalize',
      name: '조편성 확정',
      audience: PushAudienceKind.attendees,
      timing: PushTimingKind.immediate,
      audienceDetail: '참석 회원 (정회원·게스트 포함)',
      preview: '{{모임명}} 조편성이 확정되었습니다.\n조 편성을 확인해 주세요.',
    ),
    HqAlimtalkType(
      id: 'atk_schedule_change',
      name: '일정 변경 재참석 안내',
      audience: PushAudienceKind.allMembers,
      timing: PushTimingKind.immediate,
      audienceDetail: '전체 정회원 + 참석 게스트',
      preview:
          '{{모임명}} 라운딩 일정이 변경되었습니다.\n📅 일시: {{일시}}\n📍 장소: {{장소}}\n다시 참석 여부를 알려주세요.',
    ),
    HqAlimtalkType(
      id: 'atk_schedule_confirm',
      name: '일정확정 참석권유',
      audience: PushAudienceKind.allMembers,
      timing: PushTimingKind.immediate,
      preview:
          '{{모임명}} 라운딩이 확정되었습니다!\n📅 일시: {{일시}}\n📍 장소: {{장소}}\n참석 여부를 알려주세요.',
    ),
    HqAlimtalkType(
      id: 'atk_d1_reminder',
      name: 'D-1 리마인더',
      audience: PushAudienceKind.attendees,
      timing: PushTimingKind.d1At10,
      preview:
          '내일 {{모임명}} 라운딩이 있습니다.\n📅 일시: {{일시}}\n📍 장소: {{장소}}\n늦지 않게 준비해 주세요.',
    ),
    HqAlimtalkType(
      id: 'atk_dues_request',
      name: '회비 납부요청',
      audience: PushAudienceKind.allMembers,
      timing: PushTimingKind.immediate,
      preview:
          '{{이름}}님, {{모임명}} 회비 납부를 안내드립니다.\n납부 금액: {{금액}}원\n납부 기한: {{기한}}',
    ),
    HqAlimtalkType(
      id: 'atk_schedule_cancel',
      name: '일정취소 알림',
      audience: PushAudienceKind.attendees,
      timing: PushTimingKind.immediate,
      preview: '{{모임명}} 라운딩이 취소되었습니다.\n사유: {{사유}}\n다음 기회에 뵙겠습니다.',
    ),
    HqAlimtalkType(
      id: 'atk_dues_nudge',
      name: '납부 독촉',
      audience: PushAudienceKind.specificMember,
      timing: PushTimingKind.immediate,
      audienceDetail: '미납 회원(총무 수동 발송)',
      preview: '{{이름}}님, {{모임명}} 회비가 미납 상태입니다.\n빠른 납부 부탁드립니다.',
    ),
  ];

  static const List<AlimtalkTemplate> templates = [
    AlimtalkTemplate(
      id: 'T001',
      name: '가입신청 안내(총무)',
      category: '회원',
      preview:
          '{{모임명}}에 {{신청자}}님이 가입을 신청했습니다.\n앱에서 승인/거절을 처리해 주세요.',
    ),
    AlimtalkTemplate(
      id: 'T002',
      name: '가입 승인/거절',
      category: '회원',
      preview:
          '{{이름}}님, {{모임명}} 가입 신청이 {{결과}}되었습니다.',
    ),
    AlimtalkTemplate(
      id: 'T003',
      name: '일정확정 참석권유',
      category: '모임',
      preview:
          '{{모임명}} 라운딩이 확정되었습니다!\n📅 일시: {{일시}}\n📍 장소: {{장소}}\n참석 여부를 알려주세요.',
    ),
    AlimtalkTemplate(
      id: 'T004',
      name: 'D-1 리마인더',
      category: '모임',
      preview:
          '내일 {{모임명}} 라운딩이 있습니다.\n📅 일시: {{일시}}\n📍 장소: {{장소}}\n늦지 않게 준비해 주세요.',
    ),
    AlimtalkTemplate(
      id: 'T005',
      name: '회비 납부요청',
      category: '재무',
      preview:
          '{{이름}}님, {{모임명}} 회비 납부를 안내드립니다.\n납부 금액: {{금액}}원\n납부 기한: {{기한}}',
    ),
    AlimtalkTemplate(
      id: 'T006',
      name: '일정취소 알림',
      category: '모임',
      preview:
          '{{모임명}} 라운딩이 취소되었습니다.\n사유: {{사유}}\n다음 기회에 뵙겠습니다.',
    ),
    AlimtalkTemplate(
      id: 'T007',
      name: '모임 초대',
      category: '초대',
      preview:
          '{{초대자}}님이 {{모임명}}에 초대하였습니다.\n초대 링크로 참여해 주세요.',
    ),
    AlimtalkTemplate(
      id: 'T008',
      name: '납부 독촉',
      category: '재무',
      preview:
          '{{이름}}님, {{모임명}} 회비가 미납 상태입니다.\n빠른 납부 부탁드립니다.',
    ),
  ];

  static const List<String> weekDays = ['월', '화', '수', '목', '금', '토', '일'];
}
