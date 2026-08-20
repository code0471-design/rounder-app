// ════════════════════════════════════════════════════════════
//  ROUNDER — Club Model (확장)
// ════════════════════════════════════════════════════════════

/// 지역 목록 (시·도 + 주요 구·시 단위, 지역다양함 맨 위)
const List<String> kRegions = [
  '전체',
  '지역다양함',
  // 서울 구
  '서울 강남구', '서울 서초구', '서울 송파구', '서울 강동구',
  '서울 마포구', '서울 용산구', '서울 성동구', '서울 광진구',
  '서울 강서구', '서울 양천구', '서울 영등포구', '서울 구로구',
  '서울 동작구', '서울 관악구', '서울 금천구',
  '서울 종로구', '서울 중구', '서울 동대문구', '서울 중랑구',
  '서울 성북구', '서울 강북구', '서울 도봉구', '서울 노원구',
  '서울 은평구', '서울 서대문구',
  // 경기 시·구
  '경기 수원', '경기 성남', '경기 고양', '경기 용인',
  '경기 부천', '경기 안산', '경기 화성', '경기 광명',
  '경기 평택', '경기 시흥', '경기 파주', '경기 김포',
  '경기 의정부', '경기 남양주', '경기 하남', '경기 구리',
  '경기 광주', '경기 안양', '경기 군포', '경기 의왕',
  '경기 과천', '경기 오산', '경기 안성', '경기 이천',
  '경기 여주', '경기 양평', '경기 가평', '경기 포천',
  '경기 동두천', '경기 양주', '경기 연천',
  // 인천 구
  '인천 남동구', '인천 부평구', '인천 서구', '인천 미추홀구',
  '인천 연수구', '인천 계양구', '인천 동구', '인천 중구',
  '인천 강화군', '인천 옹진군',
  '강원 춘천시', '강원 원주시', '강원 강릉시', '강원 동해시', '강원 태백시',
  '강원 속초시', '강원 삼척시',
  '충북 청주시', '충북 충주시', '충북 제천시',
  '충남 천안시', '충남 공주시', '충남 보령시', '충남 아산시', '충남 서산시',
  '충남 논산시', '충남 당진시',
  '대전', '세종',
  '전북 전주시', '전북 군산시', '전북 익산시', '전북 정읍시', '전북 남원시',
  '전남 목포시', '전남 여수시', '전남 순천시', '전남 나주시', '전남 광양시',
  '광주',
  '경북 포항시', '경북 경주시', '경북 구미시', '경북 안동시', '경북 김천시',
  '경남 창원시', '경남 진주시', '경남 김해시', '경남 양산시', '경남 거제시',
  // 대구 구
  '대구',
  '대구 수성구', '대구 달서구', '대구 동구', '대구 서구',
  '대구 남구', '대구 북구', '대구 중구', '대구 달성군',
  // 울산 구
  '울산',
  '울산 남구', '울산 북구', '울산 동구', '울산 중구', '울산 울주군',
  // 부산 구
  '부산',
  '부산 해운대구', '부산 수영구', '부산 남구', '부산 동구',
  '부산 서구', '부산 북구', '부산 사하구', '부산 사상구',
  '부산 금정구', '부산 동래구', '부산 연제구', '부산 부산진구',
  '부산 중구', '부산 영도구', '부산 강서구', '부산 기장군',
  '제주 제주시', '제주 서귀포시',
];

/// 시·도 단위 필터 목록 (모임 찾기 드롭다운용)
const List<String> kRegionGroups = [
  '전체', '지역다양함',
  '서울', '경기', '인천',
  '강원', '충청', '전라', '경상', '제주',
];

/// 업종 목록
const List<String> kIndustries = [
  '미용', '의료/의사', '교회/종교', '법조', '교육',
  '부동산', '금융', '요식업', '건설/건축', 'IT/테크',
  '지역모임', '직장모임', '동창모임', '가족모임', '기타',
];

// ────────────────────────────────────────────────────────────
//  모임 아바타 — 업종 기반 이모지 + 약칭 레이블
//  · clubIndustryEmoji(industry)  → 이모지 문자열
//  · clubIndustryLabel(industry)  → 짧은 한글 레이블 (최대 3글자)
//  전체 앱에서 공유하는 단일 소스 — 여러 화면에서 import해서 사용
// ────────────────────────────────────────────────────────────
String clubIndustryEmoji(String industry) {
  if (industry.contains('미용'))       return '💇';
  if (industry.contains('의료') ||
      industry.contains('의사'))       return '⚕️';
  if (industry.contains('교회') ||
      industry.contains('종교'))       return '✝️';
  if (industry.contains('법조'))       return '⚖️';
  if (industry.contains('교육'))       return '📚';
  if (industry.contains('부동산'))     return '🏠';
  if (industry.contains('금융'))       return '💰';
  if (industry.contains('요식업'))     return '🍽️';
  if (industry.contains('건설') ||
      industry.contains('건축'))       return '🏗️';
  if (industry.contains('IT') ||
      industry.contains('테크'))       return '💻';
  if (industry.contains('지역'))       return '📍';
  if (industry.contains('직장'))       return '🏢';
  if (industry.contains('동창'))       return '🎓';
  if (industry.contains('가족'))       return '👨‍👩‍👧';
  return '⛳'; // 기타 / 골프 기본값
}

/// 아바타 안에 표시할 짧은 레이블 (이모지가 렌더링 안 되는 상황 대비)
String clubIndustryLabel(String industry) {
  if (industry.contains('미용'))       return '미용';
  if (industry.contains('의료') ||
      industry.contains('의사'))       return '의료';
  if (industry.contains('교회') ||
      industry.contains('종교'))       return '교회';
  if (industry.contains('법조'))       return '법조';
  if (industry.contains('교육'))       return '교육';
  if (industry.contains('부동산'))     return '부동산';
  if (industry.contains('금융'))       return '금융';
  if (industry.contains('요식업'))     return '요식';
  if (industry.contains('건설') ||
      industry.contains('건축'))       return '건설';
  if (industry.contains('IT') ||
      industry.contains('테크'))       return 'IT';
  if (industry.contains('지역'))       return '지역';
  if (industry.contains('직장'))       return '직장';
  if (industry.contains('동창'))       return '동창';
  if (industry.contains('가족'))       return '가족';
  return '기타';
}

// ────────────────────────────────────────────────────────────
//  Club
// ────────────────────────────────────────────────────────────
class Club {
  final String id;
  final String name;
  final String? imageUrl;       // 대표 이미지 URL
  final String myRole;          // 나의 직책 (회장·부회장·총무·일반)
  final int memberCount;
  final DateTime? nextRoundDate;
  final String? nextRoundCourse;

  // ── 신규 필드 ──
  final String creatorId;       // 생성자 userId
  final String region;          // 지역 (kRegions 중 하나)
  final String industry;        // 업종 (kIndustries 중 하나, 또는 수기 입력)
  final int teamCount;          // 팀 수 (매달 변경 가능)
  final String description;     // 모임 소개 (선택)
  final DateTime createdAt;     // 생성일

  Club({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.myRole,
    required this.memberCount,
    this.nextRoundDate,
    this.nextRoundCourse,
    // 신규
    this.creatorId = '',
    this.region = '서울',
    this.industry = '기타',
    this.teamCount = 4,
    this.description = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get daysUntilNextRound {
    if (nextRoundDate == null) return -999;
    final now = DateTime.now();
    final target = DateTime(nextRoundDate!.year, nextRoundDate!.month, nextRoundDate!.day);
    final today = DateTime(now.year, now.month, now.day);
    return target.difference(today).inDays;
  }

  static const Object _unset = Object();

  Club copyWith({
    String? name,
    Object? imageUrl = _unset,
    String? myRole,
    int? memberCount,
    Object? nextRoundDate = _unset,
    Object? nextRoundCourse = _unset,
    String? region,
    String? industry,
    int? teamCount,
    String? description,
  }) {
    return Club(
      id: id,
      name: name ?? this.name,
      imageUrl: identical(imageUrl, _unset)
          ? this.imageUrl
          : imageUrl as String?,
      myRole: myRole ?? this.myRole,
      memberCount: memberCount ?? this.memberCount,
      nextRoundDate: identical(nextRoundDate, _unset)
          ? this.nextRoundDate
          : nextRoundDate as DateTime?,
      nextRoundCourse: identical(nextRoundCourse, _unset)
          ? this.nextRoundCourse
          : nextRoundCourse as String?,
      creatorId: creatorId,
      region: region ?? this.region,
      industry: industry ?? this.industry,
      teamCount: teamCount ?? this.teamCount,
      description: description ?? this.description,
      createdAt: createdAt,
    );
  }
}

// ────────────────────────────────────────────────────────────
//  JoinRequest  (가입 신청)
// ────────────────────────────────────────────────────────────
enum JoinRequestStatus { pending, approved, rejected }

class JoinRequest {
  final String id;
  final String clubId;
  final String userId;
  final String userName;
  final String userGender;
  final double? userHandicap;
  final String message;          // 신청 메시지 (선택)
  final String? referrerId;      // 소개자(추천인) memberId
  final String? referrerName;    // 소개자 이름 (표시용)
  final JoinRequestStatus status;
  final DateTime requestedAt;
  final String? reviewedBy;      // 승인/거절한 관리자 이름
  final DateTime? reviewedAt;

  JoinRequest({
    required this.id,
    required this.clubId,
    required this.userId,
    required this.userName,
    required this.userGender,
    this.userHandicap,
    this.message = '',
    this.referrerId,
    this.referrerName,
    this.status = JoinRequestStatus.pending,
    required this.requestedAt,
    this.reviewedBy,
    this.reviewedAt,
  });

  JoinRequest copyWith({
    JoinRequestStatus? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? referrerId,
    String? referrerName,
  }) {
    return JoinRequest(
      id: id,
      clubId: clubId,
      userId: userId,
      userName: userName,
      userGender: userGender,
      userHandicap: userHandicap,
      message: message,
      referrerId: referrerId ?? this.referrerId,
      referrerName: referrerName ?? this.referrerName,
      status: status ?? this.status,
      requestedAt: requestedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  String get statusLabel {
    switch (status) {
      case JoinRequestStatus.pending:   return '대기중';
      case JoinRequestStatus.approved:  return '승인됨';
      case JoinRequestStatus.rejected:  return '거절됨';
    }
  }
}

// ────────────────────────────────────────────────────────────
//  Member
// ────────────────────────────────────────────────────────────
class Member {
  final String id;
  final String name;
  final String gender;        // 남, 여
  final DateTime? birthDate;
  final String? photoUrl;
  final String? phone;        // 휴대폰 번호
  final String? bio;          // 본인 소개
  final String memberType;    // 정회원, 게스트
  final String role;          // 회장, 부회장, 총무, 정회원(레거시:일반), 게스트
  final double? handicap;
  final DateTime? joinDate;
  final String? address;
  final String? memo;
  final String status;        // 활성, 탈퇴
  final String? referrerId;   // 게스트 소개자 memberId
  final String? referrerName; // 게스트 소개자 이름

  Member({
    required this.id,
    required this.name,
    required this.gender,
    this.birthDate,
    this.photoUrl,
    this.phone,
    this.bio,
    required this.memberType,
    required this.role,
    this.handicap,
    this.joinDate,
    this.address,
    this.memo,
    this.status = '활성',
    this.referrerId,
    this.referrerName,
  });

  int get age {
    if (birthDate == null) return 0;
    final now = DateTime.now();
    int age = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      age--;
    }
    return age;
  }

  Member copyWith({
    String? name,
    String? gender,
    DateTime? birthDate,
    String? photoUrl,
    bool clearPhoto = false,
    String? phone,
    String? bio,
    String? memberType,
    String? role,
    double? handicap,
    DateTime? joinDate,
    String? address,
    String? memo,
    String? status,
    String? referrerId,
    String? referrerName,
  }) {
    return Member(
      id: id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      memberType: memberType ?? this.memberType,
      role: role ?? this.role,
      handicap: handicap ?? this.handicap,
      joinDate: joinDate ?? this.joinDate,
      address: address ?? this.address,
      memo: memo ?? this.memo,
      status: status ?? this.status,
      referrerId: referrerId ?? this.referrerId,
      referrerName: referrerName ?? this.referrerName,
    );
  }
}

// ────────────────────────────────────────────────────────────
//  ActivityItem
// ────────────────────────────────────────────────────────────
class ActivityItem {
  final String id;
  final String memberId;
  final String memberName;
  final String? memberPhotoUrl;
  final String activityType;  // attendance, payment, cancel, score, join
  final String description;
  final DateTime timestamp;

  ActivityItem({
    required this.id,
    required this.memberId,
    required this.memberName,
    this.memberPhotoUrl,
    required this.activityType,
    required this.description,
    required this.timestamp,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

// ────────────────────────────────────────────────────────────
//  Announcement
// ────────────────────────────────────────────────────────────
// ────────────────────────────────────────────────────────────
//  공지 댓글
// ────────────────────────────────────────────────────────────
class AnnouncementComment {
  final String id;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;

  const AnnouncementComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });
}

class Announcement {
  final String id;
  final String title;
  final String? content;
  final bool isPinned;
  final DateTime createdAt;
  final List<AnnouncementComment> comments;
  /// 소속 모임 (null = 레거시 mock 공지)
  final String? clubId;
  /// 작성자 (레거시 null 가능)
  final String? authorId;
  final String? authorName;

  Announcement({
    required this.id,
    required this.title,
    this.content,
    this.isPinned = false,
    required this.createdAt,
    List<AnnouncementComment>? comments,
    this.clubId,
    this.authorId,
    this.authorName,
  }) : comments = comments ?? [];
}

// ────────────────────────────────────────────────────────────
//  앱 알림 모델
// ────────────────────────────────────────────────────────────
enum AppNotificationType {
  joinRequest,        // 가입 신청 (관리자 수신)
  joinApproved,       // 가입 승인 (신청자 수신)
  announcement,       // 공지사항 등록
  comment,            // 내 공지에 댓글
  schedule,           // 모임 일정 공지
  paymentRequest,     // 입금 확인 요청 (총무 전용)
  attendanceChanged,  // 총무가 참석 상태를 강제 변경 (대상자 수신)
  memberKicked,       // 총무가 강퇴 처리 (대상자 수신)
  scheduleChanged,    // 일정 변경 (재참석 신청 안내)
  scheduleCancelled,  // 일정 취소/삭제
}

class AppNotification {
  final String id;
  final AppNotificationType type;
  final String clubId;
  final String clubName;
  final String title;
  final String body;
  final bool isAdmin;       // 관리자 알림 여부
  final bool isRead;
  final DateTime createdAt;
  final String? targetId;     // announcementId / scheduleId / requestId
  final String? targetUserId; // 특정 회원 전용 알림 (예: 참석 강제 변경, 강퇴)

  const AppNotification({
    required this.id,
    required this.type,
    required this.clubId,
    required this.clubName,
    required this.title,
    required this.body,
    this.isAdmin = false,
    this.isRead = false,
    required this.createdAt,
    this.targetId,
    this.targetUserId,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id, type: type, clubId: clubId, clubName: clubName,
    title: title, body: body, isAdmin: isAdmin,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt, targetId: targetId, targetUserId: targetUserId,
  );
}

// ────────────────────────────────────────────────────────────
//  AttendanceStatus
// ────────────────────────────────────────────────────────────
class AttendanceStatus {
  final int confirmed;
  final int noResponse;
  final int declined;

  AttendanceStatus({
    required this.confirmed,
    required this.noResponse,
    required this.declined,
  });

  /// 하위 호환
  int get pending => noResponse;

  int get total => confirmed + noResponse + declined;
}

// ────────────────────────────────────────────────────────────
//  Finance — 재무 관련 모델
// ────────────────────────────────────────────────────────────

/// 회비 유형
enum DuesType { monthly, annual, special }

extension DuesTypeLabel on DuesType {
  String get label {
    switch (this) {
      case DuesType.monthly: return '월회비';
      case DuesType.annual:  return '연회비';
      case DuesType.special: return '특별회비';
    }
  }
  String get icon {
    switch (this) {
      case DuesType.monthly: return '📅';
      case DuesType.annual:  return '📆';
      case DuesType.special: return '⭐';
    }
  }
}

/// 회비 금액 변경 이력 — 특정 시점부터 적용되는 금액을 기록
/// (과거 미납분은 변경 이전 금액으로, 변경 이후 월은 새 금액으로 청구하기 위함)
class DuesAmountChange {
  final int amount;
  final int effectiveYear;   // 이 금액이 적용되기 시작하는 연도
  final int effectiveMonth;  // 이 금액이 적용되기 시작하는 월 (연회비/특별회비는 1)
  final DateTime changedAt;

  const DuesAmountChange({
    required this.amount,
    required this.effectiveYear,
    required this.effectiveMonth,
    required this.changedAt,
  });

  int get _effectiveKey => effectiveYear * 12 + effectiveMonth;
}

/// 회비 설정
class DuesSetting {
  final String id;
  final DuesType type;
  final int amount;          // 금액 (원) — 현재(최신) 적용 금액
  final String title;        // 예: "2025년 월회비", "여름 워크숍 특별회비"
  final String? description;
  final DateTime createdAt;
  final bool isActive;
  /// 소속 모임. null이면 레거시 mock(공통) — 데모 모임(c1~c5)에서만 노출
  final String? clubId;

  // 월회비 전용: 납부 기간 (null이면 연중 전체)
  final int? startMonth;   // 시작 월 (1~12)
  final int? endMonth;     // 종료 월 (1~12)
  /// 월회비 시작 연도 (null이면 createdAt.year로 간주, 매년 반복)
  final int? startYear;
  /// 월회비 종료 연도. 값이 있으면 startYear~endYear 사이의 절대 구간(1년 이상 가능),
  /// null이면 매년 startMonth~endMonth가 반복되는 형태.
  final int? endYear;

  /// 연회비 전용: 청구 대상 연도 (null이면 createdAt.year)
  final int? year;

  /// 연회비·특별회비: 납부 기준일 (YYYY-MM-DD)
  final DateTime? dueDate;

  /// 월회비: 매월 납부 기준일 (1~31)
  final int? dueDayOfMonth;

  /// 금액 변경 이력 (오래된 순). 비어 있으면 [amount] 단일 금액으로 간주.
  final List<DuesAmountChange> amountHistory;

  DuesSetting({
    required this.id,
    required this.type,
    required this.amount,
    required this.title,
    this.description,
    required this.createdAt,
    this.isActive = true,
    this.clubId,
    this.startMonth,
    this.endMonth,
    this.startYear,
    this.endYear,
    this.year,
    this.dueDate,
    this.dueDayOfMonth,
    List<DuesAmountChange>? amountHistory,
  }) : amountHistory = amountHistory ??
            [
              DuesAmountChange(
                amount: amount,
                effectiveYear: year ?? createdAt.year,
                effectiveMonth: createdAt.month,
                changedAt: createdAt,
              ),
            ];

  /// 월회비 기간 텍스트 (예: "3월~11월", "2025년 3월 ~ 계속", "2025년 3월~2026년 2월")
  String? get periodText {
    if (type != DuesType.monthly) return null;
    if (startMonth == null &&
        endMonth == null &&
        startYear == null &&
        endYear == null) {
      return null;
    }
    final s = startMonth != null ? '${startMonth}월' : '1월';
    final sYear = startYear ?? createdAt.year;
    // 종료 없음(계속): endYear·endMonth 모두 null
    if (endYear == null && endMonth == null) {
      return '$sYear년 $s ~ 계속';
    }
    final e = endMonth != null ? '${endMonth}월' : '12월';
    if (endYear != null) {
      return '$sYear년 $s ~ $endYear년 $e';
    }
    return '$s~$e';
  }

  /// 납부 기준일 표시 문구
  String? get dueBasisText {
    switch (type) {
      case DuesType.monthly:
        if (dueDayOfMonth == null) return null;
        return '매월 ${dueDayOfMonth}일';
      case DuesType.annual:
      case DuesType.special:
        final d = dueDate;
        if (d == null) return null;
        return '${d.year}년 ${d.month.toString().padLeft(2, '0')}월 ${d.day.toString().padLeft(2, '0')}일';
    }
  }

  /// 해당 월이 납부 기간(월 범위)에 포함되는지 (월회비 전용, 연도 미고려)
  bool isMonthInPeriod(int month) {
    if (type != DuesType.monthly) return true;
    final s = startMonth ?? 1;
    final e = endMonth ?? 12;
    return month >= s && month <= e;
  }

  /// 해당 연/월이 실제 납부 대상 기간인지 (연도까지 고려)
  bool isActiveForYearMonth(int y, int m) {
    if (type != DuesType.monthly) return true;
    final sYear = startYear ?? createdAt.year;
    final sMonth = startMonth ?? 1;
    final key = y * 12 + m;
    final startKey = sYear * 12 + sMonth;
    // 종료 없음: 시작 연월 이후 계속
    if (endYear == null && endMonth == null) {
      return key >= startKey;
    }
    if (endYear != null) {
      final eMonth = endMonth ?? 12;
      return key >= startKey && key <= endYear! * 12 + eMonth;
    }
    // endYear null + endMonth 있음 → 매년 시작월~종료월 반복
    if (y < sYear) return false;
    return isMonthInPeriod(m);
  }

  /// 특정 연/월에 적용되는 금액 (변경 이력 기준 — 미납분은 과거 금액 유지)
  int amountForPeriod({required int year, int month = 1}) {
    if (amountHistory.isEmpty) return amount;
    final targetKey = year * 12 + month;
    DuesAmountChange? applicable;
    // 목록은 오래된 순 → 동일 시점 항목 중 가장 나중에 추가된 값을 우선 적용
    for (final c in amountHistory) {
      if (c._effectiveKey <= targetKey) {
        if (applicable == null || c._effectiveKey >= applicable._effectiveKey) {
          applicable = c;
        }
      }
    }
    return applicable?.amount ?? amountHistory.first.amount;
  }

  DuesSetting copyWith({
    DuesType? type,
    int? amount,
    String? title,
    String? description,
    bool? isActive,
    String? clubId,
    int? startMonth,
    int? endMonth,
    int? startYear,
    int? endYear,
    int? year,
    DateTime? dueDate,
    int? dueDayOfMonth,
    List<DuesAmountChange>? amountHistory,
    bool clearStartMonth = false,
    bool clearEndMonth = false,
    bool clearStartYear = false,
    bool clearEndYear = false,
    bool clearYear = false,
    bool clearDueDate = false,
    bool clearDueDayOfMonth = false,
  }) {
    return DuesSetting(
      id: id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt,
      isActive: isActive ?? this.isActive,
      clubId: clubId ?? this.clubId,
      startMonth: clearStartMonth ? null : (startMonth ?? this.startMonth),
      endMonth: clearEndMonth ? null : (endMonth ?? this.endMonth),
      startYear: clearStartYear ? null : (startYear ?? this.startYear),
      endYear: clearEndYear ? null : (endYear ?? this.endYear),
      year: clearYear ? null : (year ?? this.year),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      dueDayOfMonth:
          clearDueDayOfMonth ? null : (dueDayOfMonth ?? this.dueDayOfMonth),
      amountHistory: amountHistory ?? this.amountHistory,
    );
  }
}

/// 총무 알림톡 발송 설정 (모임별)
///
/// · 모임에서 중지 → 이 설정만 변경 (본사 카탈로그는 건드리지 않음)
/// · 본사에서 중지 → 모든 모임에서 실효 중지 (HQ.enabled && club.enabled)
class ClubAlimtalkSettings {
  final String clubId;
  /// 일정 등록 시 참석여부 알림톡 발송 안내
  final bool promptOnScheduleUpload;
  /// 조편성 확정 시 알림톡 발송 안내
  final bool promptOnGroupFinalize;
  /// 일정(날짜·시간·장소 등) 변경 시 재참석 신청 알림톡 발송 안내
  final bool promptOnScheduleChange;
  /// 알림톡 종류 id → 모임 단위 사용 여부 (없으면 true)
  final Map<String, bool> typeOverrides;

  const ClubAlimtalkSettings({
    required this.clubId,
    this.promptOnScheduleUpload = true,
    this.promptOnGroupFinalize = true,
    this.promptOnScheduleChange = true,
    this.typeOverrides = const {},
  });

  /// 모임 로컬 사용 여부 (본사 상태는 별도)
  bool isTypeEnabledLocally(String typeId) {
    if (typeOverrides.containsKey(typeId)) {
      return typeOverrides[typeId]!;
    }
    return switch (typeId) {
      'atk_schedule_upload' => promptOnScheduleUpload,
      'atk_group_finalize' => promptOnGroupFinalize,
      'atk_schedule_change' => promptOnScheduleChange,
      _ => true,
    };
  }

  ClubAlimtalkSettings copyWith({
    bool? promptOnScheduleUpload,
    bool? promptOnGroupFinalize,
    bool? promptOnScheduleChange,
    Map<String, bool>? typeOverrides,
  }) =>
      ClubAlimtalkSettings(
        clubId: clubId,
        promptOnScheduleUpload:
            promptOnScheduleUpload ?? this.promptOnScheduleUpload,
        promptOnGroupFinalize:
            promptOnGroupFinalize ?? this.promptOnGroupFinalize,
        promptOnScheduleChange:
            promptOnScheduleChange ?? this.promptOnScheduleChange,
        typeOverrides: typeOverrides ?? this.typeOverrides,
      );

  ClubAlimtalkSettings withTypeEnabled(String typeId, bool enabled) {
    final next = Map<String, bool>.from(typeOverrides)..[typeId] = enabled;
    return copyWith(
      typeOverrides: next,
      promptOnScheduleUpload: typeId == 'atk_schedule_upload'
          ? enabled
          : promptOnScheduleUpload,
      promptOnGroupFinalize: typeId == 'atk_group_finalize'
          ? enabled
          : promptOnGroupFinalize,
      promptOnScheduleChange: typeId == 'atk_schedule_change'
          ? enabled
          : promptOnScheduleChange,
    );
  }
}

/// 홈 회계 카드 — 미납 뱃지 요약 (기준 회비명 포함)
class MonthUnpaidSummary {
  final int unpaidCount;
  /// 예: "2025년 월회비", "2025년 월회비 외 1건", "회비 2건"
  final String duesLabel;

  const MonthUnpaidSummary({
    required this.unpaidCount,
    required this.duesLabel,
  });
}

/// 납부 기록 (회원 1명 × 회비 1건)
class DuesPayment {
  final String id;
  final String memberId;
  final String memberName;
  final String duesSettingId;
  final int amount;
  final DateTime paidAt;
  final String? memo;
  final String recordedBy;   // 등록한 총무 이름
  final bool skipsBalance;   // true = 상태만 변경, 잔고 반영 안 함

  DuesPayment({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.duesSettingId,
    required this.amount,
    required this.paidAt,
    this.memo,
    required this.recordedBy,
    this.skipsBalance = false,
  });
}

// ────────────────────────────────────────────────────────────
//  PaymentRequest — 일반 회원의 입금 확인 요청
// ────────────────────────────────────────────────────────────
enum PaymentRequestStatus { pending, confirmed, rejected }

extension PaymentRequestStatusLabel on PaymentRequestStatus {
  String get label {
    switch (this) {
      case PaymentRequestStatus.pending:   return '확인 대기';
      case PaymentRequestStatus.confirmed: return '납부 완료';
      case PaymentRequestStatus.rejected:  return '반려됨';
    }
  }
  String get icon {
    switch (this) {
      case PaymentRequestStatus.pending:   return '🕐';
      case PaymentRequestStatus.confirmed: return '✅';
      case PaymentRequestStatus.rejected:  return '❌';
    }
  }
}

class PaymentRequest {
  final String id;
  final String memberId;
  final String memberName;
  final String duesSettingId;
  final String duesTitle;       // 회비명 스냅샷 (조회 편의)
  final int amount;
  final int? year;
  final int? month;             // 월회비인 경우 해당 월
  final String? memo;           // 요청자 메모 ("이체했습니다" 등)
  final PaymentRequestStatus status;
  final DateTime requestedAt;
  final String? reviewedBy;     // 처리한 총무 이름
  final DateTime? reviewedAt;
  /// 소속 모임. null이면 레거시 mock(공통) — 데모 모임(c1~c5)에서만 노출
  final String? clubId;

  PaymentRequest({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.duesSettingId,
    required this.duesTitle,
    required this.amount,
    this.year,
    this.month,
    this.memo,
    this.status = PaymentRequestStatus.pending,
    required this.requestedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.clubId,
  });

  PaymentRequest copyWith({
    PaymentRequestStatus? status,
    String? reviewedBy,
    DateTime? reviewedAt,
  }) {
    return PaymentRequest(
      id: id,
      memberId: memberId,
      memberName: memberName,
      duesSettingId: duesSettingId,
      duesTitle: duesTitle,
      amount: amount,
      year: year,
      month: month,
      memo: memo,
      status: status ?? this.status,
      requestedAt: requestedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      clubId: clubId,
    );
  }

  /// 표시용 기간 텍스트
  String get periodText {
    if (month != null && year != null) return '$year년 ${month}월';
    if (year != null) return '$year년';
    return '';
  }
}

/// 수입/지출 거래 내역
enum TxType { income, expense }

/// 거래 발생 원인 구분
enum TxSource {
  dues,           // 회비 납부 자동 등록
  carryover,      // 이월 잔액
  manual,         // 수동 등록
  ad,             // 광고비 수입 자동 등록
  sponsor,        // 후원금 수입 자동 등록
  openingBalance, // 초기 잔액 세팅 (신규 모임 온보딩)
}

extension TxSourceLabel on TxSource {
  String get label {
    switch (this) {
      case TxSource.dues:           return '회비자동';
      case TxSource.carryover:      return '이월';
      case TxSource.manual:         return '수동';
      case TxSource.ad:             return '광고자동';
      case TxSource.sponsor:        return '후원자동';
      case TxSource.openingBalance: return '초기잔액';
    }
  }
}

class Transaction {
  final String id;
  final TxType type;
  final int amount;
  final String category;     // 예: '회비', '벌금', '식비', '상품', '기타'
  final String title;
  final String? memo;
  final DateTime date;
  final String recordedBy;
  final TxSource source;     // 발생 원인 (자동/이월/수동)
  final String? duesPaymentId; // 연결된 납부 ID (dues 소스인 경우)
  /// 소속 모임. null이면 레거시 mock(공통) — 데모 모임(c1~c5)에서만 노출
  final String? clubId;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.title,
    this.memo,
    required this.date,
    required this.recordedBy,
    this.source = TxSource.manual,
    this.duesPaymentId,
    this.clubId,
  });
}

// ────────────────────────────────────────────────────────────
//  RoundSchedule — 라운드 일정
// ────────────────────────────────────────────────────────────
enum ScheduleStatus { upcoming, done, cancelled }

class RoundSchedule {
  final String id;
  final String clubId;
  final String title;          // 예: "6월 월례회"
  final DateTime roundDate;    // 라운딩 날짜
  final String teeTime;        // 티오프 시간 예: "07:30"
  final String courseName;     // 코스명
  final String? courseAddress; // 코스 주소 (선택)
  final int teamCount;         // 팀 수
  final int? maxCapacity;      // 최대 정원 (null = 팀수×4명)
  final String? notice;        // 공지 (복장 규정 등)
  final ScheduleStatus status;
  final String createdBy;      // 등록자 이름
  final List<AttendanceResponse> responses; // 참석 응답 목록
  final List<String> companionIds; // 등록 시 지정한 동반자 명단
  final String? reviewMemo; // 라운딩 후기/메모
  final DateTime? rsvpDeadline; // 참석 응답 마감 (null = 마감 없음)
  final bool deadlineNotified; // 마감 후 미응답 알림 발송 여부

  /// 참석 정원: 기본 팀수×4명.
  /// maxCapacity가 그보다 크게 명시된 경우만 오버라이드.
  /// (구버전 테스트값처럼 teamCount보다 작은 maxCapacity는 무시)
  int get effectiveCapacity {
    final byTeams = teamCount * 4;
    if (maxCapacity != null && maxCapacity! >= byTeams) return maxCapacity!;
    return byTeams;
  }

  RoundSchedule({
    required this.id,
    required this.clubId,
    required this.title,
    required this.roundDate,
    required this.teeTime,
    required this.courseName,
    this.courseAddress,
    required this.teamCount,
    this.maxCapacity,
    this.notice,
    this.status = ScheduleStatus.upcoming,
    required this.createdBy,
    List<AttendanceResponse>? responses,
    List<String>? companionIds,
    this.reviewMemo,
    this.rsvpDeadline,
    this.deadlineNotified = false,
  })  : responses = responses ?? [],
        companionIds = companionIds ?? [];

  int get daysUntil {
    final now = DateTime.now();
    final target = DateTime(roundDate.year, roundDate.month, roundDate.day);
    final today = DateTime(now.year, now.month, now.day);
    return target.difference(today).inDays;
  }

  String get dDayText {
    final d = daysUntil;
    if (d > 0) return 'D-$d';
    if (d == 0) return 'D-Day';
    return 'D+${-d}';
  }

  /// 라운딩 당일(자정 24시)이 지났는지 여부 — 날짜만 비교 (시간 무관).
  /// 당일 하루 종일은 false이며, 자정을 넘긴 다음 날부터 true가 된다.
  bool get isDateOver => daysUntil < 0;

  /// '지난 일정' 탭으로 분류되어야 하는지 여부.
  /// 취소된 일정은 제외하고, 수동으로 완료 처리되었거나(운영진 조작 여지를 위해 유지)
  /// 라운딩 날짜가 자정을 넘겨 지났으면 지난 일정으로 자동 이동한다.
  /// (지난 일정으로 이동해도 스코어/기록 입력은 별도 화면에서 계속 가능)
  bool get isPast =>
      status == ScheduleStatus.done ||
      (status == ScheduleStatus.upcoming && isDateOver);

  /// 제목 앞의 "N월"이 실제 라운딩 월과 다르면 날짜 기준으로 보정
  String get displayTitle {
    final match = RegExp(r'^(\d+)월(.*)$').firstMatch(title);
    if (match == null) return title;
    final titleMonth = int.tryParse(match.group(1)!);
    if (titleMonth == null || titleMonth == roundDate.month) return title;
    return '${roundDate.month}월${match.group(2)!}';
  }

  int get confirmedCount => responses.where((r) => r.response == '참석').length;
  int get declinedCount  => responses.where((r) => r.response == '불참').length;

  /// 미답변 인원 (전체 대상 회원 수 기준)
  int noResponseCount(int totalMembers) =>
      (totalMembers - confirmedCount - declinedCount).clamp(0, totalMembers);

  /// @deprecated 미정 옵션 제거 — noResponseCount 사용
  int get pendingCount =>
      responses.where((r) => r.response == '미정').length;

  /// 참석 응답 마감 시각이 설정되어 있고, 이미 지났는지
  bool get isRsvpClosed =>
      rsvpDeadline != null && DateTime.now().isAfter(rsvpDeadline!);

  RoundSchedule copyWith({
    String? title,
    DateTime? roundDate,
    String? teeTime,
    String? courseName,
    String? courseAddress,
    int? teamCount,
    int? maxCapacity,
    bool clearMaxCapacity = false,
    String? notice,
    ScheduleStatus? status,
    List<AttendanceResponse>? responses,
    List<String>? companionIds,
    String? reviewMemo,
    bool clearReviewMemo = false,
    DateTime? rsvpDeadline,
    bool clearRsvpDeadline = false,
    bool? deadlineNotified,
  }) {
    return RoundSchedule(
      id: id,
      clubId: clubId,
      title: title ?? this.title,
      roundDate: roundDate ?? this.roundDate,
      teeTime: teeTime ?? this.teeTime,
      courseName: courseName ?? this.courseName,
      courseAddress: courseAddress ?? this.courseAddress,
      teamCount: teamCount ?? this.teamCount,
      maxCapacity: clearMaxCapacity
          ? null
          : (maxCapacity ?? this.maxCapacity),
      notice: notice ?? this.notice,
      status: status ?? this.status,
      createdBy: createdBy,
      responses: responses ?? this.responses,
      companionIds: companionIds ?? this.companionIds,
      reviewMemo: clearReviewMemo ? null : (reviewMemo ?? this.reviewMemo),
      rsvpDeadline:
          clearRsvpDeadline ? null : (rsvpDeadline ?? this.rsvpDeadline),
      deadlineNotified: deadlineNotified ?? this.deadlineNotified,
    );
  }
}

// ────────────────────────────────────────────────────────────
//  AttendanceResponse — 개인 참석 응답
// ────────────────────────────────────────────────────────────
class AttendanceResponse {
  final String memberId;
  final String memberName;
  final String response;   // '참석' | '불참' | '미정'
  final String? memo;
  final List<String> companionMemberIds; // 함께 치고 싶은 동반자
  final DateTime respondedAt;

  AttendanceResponse({
    required this.memberId,
    required this.memberName,
    required this.response,
    this.memo,
    this.companionMemberIds = const [],
    required this.respondedAt,
  });

  AttendanceResponse copyWith({
    String? response,
    String? memo,
    List<String>? companionMemberIds,
  }) {
    return AttendanceResponse(
      memberId: memberId,
      memberName: memberName,
      response: response ?? this.response,
      memo: memo ?? this.memo,
      companionMemberIds: companionMemberIds ?? this.companionMemberIds,
      respondedAt: DateTime.now(),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  RoundPhoto — 라운딩 사진 (일정별 첨부)
// ────────────────────────────────────────────────────────────
class RoundPhoto {
  final String id;
  final String scheduleId;
  final String clubId;
  final String uploaderId;
  final String uploaderName;
  final String imageUrl;       // 실제: 파일 URL, 목업: 픽섬 URL
  final String? caption;
  final DateTime takenAt;

  RoundPhoto({
    required this.id,
    required this.scheduleId,
    required this.clubId,
    required this.uploaderId,
    required this.uploaderName,
    required this.imageUrl,
    this.caption,
    required this.takenAt,
  });

  RoundPhoto copyWith({
    String? caption,
    bool clearCaption = false,
  }) =>
      RoundPhoto(
        id: id,
        scheduleId: scheduleId,
        clubId: clubId,
        uploaderId: uploaderId,
        uploaderName: uploaderName,
        imageUrl: imageUrl,
        caption: clearCaption ? null : (caption ?? this.caption),
        takenAt: takenAt,
      );
}

// ────────────────────────────────────────────────────────────
//  GroupAssignment — 조편성 결과
// ────────────────────────────────────────────────────────────

/// 조편성 시작 방식
enum GroupAssignmentMode {
  manual, // 전체 수동 배정
  hybrid, // 일부 수동 + 나머지 자동
  auto,   // 전체 자동 배정
}

extension GroupAssignmentModeX on GroupAssignmentMode {
  String get label {
    switch (this) {
      case GroupAssignmentMode.manual:
        return '전체 수동 배정하기';
      case GroupAssignmentMode.hybrid:
        return '일부 수동 + 나머지 자동';
      case GroupAssignmentMode.auto:
        return '전체 자동 배정하기';
    }
  }

  String get description {
    switch (this) {
      case GroupAssignmentMode.manual:
        return '참가자를 직접 드래그하거나 선택해 조별로 배치합니다';
      case GroupAssignmentMode.hybrid:
        return '먼저 고정할 멤버를 수동 배치한 뒤, 빈 자리를 자동으로 채웁니다';
      case GroupAssignmentMode.auto:
        return '선택한 규칙에 따라 시스템이 전원 자동 배치합니다';
    }
  }

  String get icon {
    switch (this) {
      case GroupAssignmentMode.manual:
        return '✋';
      case GroupAssignmentMode.hybrid:
        return '⚡';
      case GroupAssignmentMode.auto:
        return '🤖';
    }
  }

  bool get usesAutoRules =>
      this == GroupAssignmentMode.hybrid || this == GroupAssignmentMode.auto;
}

/// 자동 배정 규칙 (복수 선택)
enum AutoAssignOption {
  balanceHandicap,   // ① 구력/핸디 밸런스
  pairCompanions,    // ② 동반자/지인 같은 조
  avoidLastMonth,    // ③ 지난 라운드 중복 조 제외
  balanceGender,     // ④ 남녀 비율 밸런스
  pairGuestReferrer, // ⑤ 게스트 + 소개자 같은 조
}

extension AutoAssignOptionX on AutoAssignOption {
  String get label {
    switch (this) {
      case AutoAssignOption.balanceHandicap:
        return '핸디/구력 밸런스';
      case AutoAssignOption.pairCompanions:
        return '동반자 같은 조';
      case AutoAssignOption.avoidLastMonth:
        return '직전 조 분리';
      case AutoAssignOption.balanceGender:
        return '남녀 비율 균등';
      case AutoAssignOption.pairGuestReferrer:
        return '게스트+소개자';
    }
  }

  String get description {
    switch (this) {
      case AutoAssignOption.balanceHandicap:
        return '고수와 초보가 한 조에 섞이도록 조별 핸디 합계를 균등 배분합니다';
      case AutoAssignOption.pairCompanions:
        return '참석 신청 시 함께 신청한 지인·동반자를 같은 조에 배치합니다';
      case AutoAssignOption.avoidLastMonth:
        return '직전 라운드에서 같은 조였던 멤버를 최대한 분리합니다';
      case AutoAssignOption.balanceGender:
        return '각 조별 남녀 성비가 비슷해지도록 배치합니다';
      case AutoAssignOption.pairGuestReferrer:
        return '게스트와 소개(추천)해 준 회원을 같은 조에 배치합니다';
    }
  }

  String get icon {
    switch (this) {
      case AutoAssignOption.balanceHandicap:
        return '⛳';
      case AutoAssignOption.pairCompanions:
        return '👥';
      case AutoAssignOption.avoidLastMonth:
        return '🔀';
      case AutoAssignOption.balanceGender:
        return '⚤';
      case AutoAssignOption.pairGuestReferrer:
        return '🤝';
    }
  }
}

/// 조편성 슬롯 (한 자리)
class GroupSlot {
  final String? memberId;
  final String? memberName;
  final String? gender;
  final double? handicap;
  final String? memberType;
  final String? referrerId;

  const GroupSlot({
    this.memberId,
    this.memberName,
    this.gender,
    this.handicap,
    this.memberType,
    this.referrerId,
  });

  bool get isEmpty => memberId == null;
  bool get isFilled => memberId != null;

  GroupSlot copyWith({
    String? memberId,
    String? memberName,
    String? gender,
    double? handicap,
    String? memberType,
    String? referrerId,
    bool clear = false,
  }) {
    if (clear) return const GroupSlot();
    return GroupSlot(
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      gender: gender ?? this.gender,
      handicap: handicap ?? this.handicap,
      memberType: memberType ?? this.memberType,
      referrerId: referrerId ?? this.referrerId,
    );
  }

  factory GroupSlot.fromMember(Member m) => GroupSlot(
        memberId: m.id,
        memberName: m.name,
        gender: m.gender,
        handicap: m.handicap,
        memberType: m.memberType,
        referrerId: m.referrerId,
      );

  @override
  bool operator ==(Object other) =>
      other is GroupSlot && other.memberId == memberId;

  @override
  int get hashCode => memberId.hashCode;
}

/// 한 조(팀)
class AssignGroup {
  final int groupNumber; // 1-based
  final List<GroupSlot> slots; // 보통 4개

  const AssignGroup({
    required this.groupNumber,
    required this.slots,
  });

  int get filledCount => slots.where((s) => s.isFilled).length;
  int get emptyCount  => slots.where((s) => s.isEmpty).length;
  bool get isFull     => emptyCount == 0;

  List<String> get memberIds =>
      slots.where((s) => s.isFilled).map((s) => s.memberId!).toList();

  double get avgHandicap {
    final filled = slots.where((s) => s.isFilled && s.handicap != null);
    if (filled.isEmpty) return 0;
    return filled.map((s) => s.handicap!).reduce((a, b) => a + b) /
        filled.length;
  }

  AssignGroup copyWithSlots(List<GroupSlot> newSlots) =>
      AssignGroup(groupNumber: groupNumber, slots: newSlots);
}

/// 전체 조편성
class GroupAssignment {
  final String scheduleId;
  final int teamCount;        // 총 조 수
  final int perGroup;         // 조당 인원 (보통 4)
  final List<AssignGroup> groups;
  final bool isFinalized;     // 확정 여부
  final DateTime? finalizedAt;
  final GroupAssignmentMode mode;
  final List<AutoAssignOption> selectedOptions;

  const GroupAssignment({
    required this.scheduleId,
    required this.teamCount,
    required this.perGroup,
    required this.groups,
    this.isFinalized = false,
    this.finalizedAt,
    this.mode = GroupAssignmentMode.hybrid,
    this.selectedOptions = const [],
  });

  /// 배정된 총 멤버 수
  int get assignedCount => groups.fold(0, (s, g) => s + g.filledCount);

  /// 빈 슬롯 수
  int get emptyCount => groups.fold(0, (s, g) => s + g.emptyCount);

  /// 총 슬롯 수
  int get totalSlots => teamCount * perGroup;

  /// 특정 멤버가 배정된 조 번호 (없으면 null)
  int? groupOf(String memberId) {
    for (final g in groups) {
      if (g.memberIds.contains(memberId)) return g.groupNumber;
    }
    return null;
  }

  GroupAssignment copyWith({
    int? teamCount,
    int? perGroup,
    List<AssignGroup>? groups,
    bool? isFinalized,
    DateTime? finalizedAt,
    GroupAssignmentMode? mode,
    List<AutoAssignOption>? selectedOptions,
  }) {
    return GroupAssignment(
      scheduleId: scheduleId,
      teamCount: teamCount ?? this.teamCount,
      perGroup: perGroup ?? this.perGroup,
      groups: groups ?? this.groups,
      isFinalized: isFinalized ?? this.isFinalized,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      mode: mode ?? this.mode,
      selectedOptions: selectedOptions ?? this.selectedOptions,
    );
  }

  /// 빈 조편성 생성
  static GroupAssignment empty({
    required String scheduleId,
    required int teamCount,
    int perGroup = 4,
  }) {
    return GroupAssignment(
      scheduleId: scheduleId,
      teamCount: teamCount,
      perGroup: perGroup,
      groups: List.generate(
        teamCount,
        (i) => AssignGroup(
          groupNumber: i + 1,
          slots: List.generate(perGroup, (_) => const GroupSlot()),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  제휴 광고 모델
// ════════════════════════════════════════════════════════════

/// 배너 슬롯 종류
enum AdSlotType {
  home,     // 홈 탭 배너 — 10만원/월
  schedule, // 일정 탭 배너 — 5만원/월
  member,   // 회원 탭 배너 — 3만원/월
}

extension AdSlotTypeX on AdSlotType {
  String get label {
    switch (this) {
      case AdSlotType.home:     return '홈 배너';
      case AdSlotType.schedule: return '일정 탭 배너';
      case AdSlotType.member:   return '회원 탭 배너';
    }
  }

  int get monthlyFee {
    switch (this) {
      case AdSlotType.home:     return 100000;
      case AdSlotType.schedule: return  50000;
      case AdSlotType.member:   return  30000;
    }
  }

  String get description {
    switch (this) {
      case AdSlotType.home:     return '모임 홈 화면 상단 노출';
      case AdSlotType.schedule: return '일정 탭 상단 노출';
      case AdSlotType.member:   return '회원 탭 상단 노출';
    }
  }
}

/// 광고 신청 상태
enum AdStatus {
  pending,   // 신청 완료 — 총무 검토 대기
  approved,  // 총무 승인 — 결제 대기
  rejected,  // 총무 거절
  paid,      // 결제 완료 — 이미지 업로드 대기
  active,    // 게재 중
  expired,   // 만료
  cancelled, // 취소
}

extension AdStatusX on AdStatus {
  String get label {
    switch (this) {
      case AdStatus.pending:   return '검토 대기';
      case AdStatus.approved:  return '승인 — 결제 대기';
      case AdStatus.rejected:  return '거절됨';
      case AdStatus.paid:      return '결제 완료 — 이미지 대기';
      case AdStatus.active:    return '게재 중';
      case AdStatus.expired:   return '만료';
      case AdStatus.cancelled: return '취소';
    }
  }
}

/// 광고 신청 (1건 = 1슬롯 × N개월)
class AdApplication {
  final String id;
  final String clubId;          // 광고를 게재할 모임
  final String clubName;
  final String applicantId;     // 신청자 회원 id
  final String applicantName;
  final AdSlotType slotType;    // 배너 종류
  final DateTime startMonth;    // 게재 시작 월 (day=1)
  final int durationMonths;     // 게재 개월 수
  final AdStatus status;
  final DateTime appliedAt;

  // 총무 처리
  final String? rejectReason;
  final DateTime? reviewedAt;

  // 결제
  final DateTime? paidAt;
  final int? paidAmount;        // 실제 결제금액

  // 이미지 (UI에서는 경로/URL 문자열로 표현)
  final String? bannerImageUrl;    // 배너 이미지
  final String? detailImageUrl;    // 상세페이지 이미지
  final String? landingUrl;        // 클릭 시 이동 URL

  // 광고 제목/설명
  final String title;
  final String description;

  const AdApplication({
    required this.id,
    required this.clubId,
    required this.clubName,
    required this.applicantId,
    required this.applicantName,
    required this.slotType,
    required this.startMonth,
    required this.durationMonths,
    required this.status,
    required this.appliedAt,
    required this.title,
    required this.description,
    this.rejectReason,
    this.reviewedAt,
    this.paidAt,
    this.paidAmount,
    this.bannerImageUrl,
    this.detailImageUrl,
    this.landingUrl,
  });

  DateTime get endMonth => DateTime(
        startMonth.year,
        startMonth.month + durationMonths,
        1,
      );

  int get totalFee => slotType.monthlyFee * durationMonths;

  /// 플랫폼 수수료 10%, 모임 정산 90%
  int get platformFee   => (totalFee * 0.1).round();
  int get clubRevenue   => totalFee - platformFee;

  bool isActiveOn(DateTime date) {
    if (status != AdStatus.active) return false;
    // 월 단위 비교 (시간대 차이 무관하게 안전)
    final dateYM  = date.year * 12 + date.month - 1;
    final startYM = startMonth.year * 12 + startMonth.month - 1;
    final endYM   = endMonth.year * 12 + endMonth.month - 1;
    return dateYM >= startYM && dateYM < endYM;
  }

  AdApplication copyWith({
    AdStatus? status,
    String? rejectReason,
    DateTime? reviewedAt,
    DateTime? paidAt,
    int? paidAmount,
    String? bannerImageUrl,
    String? detailImageUrl,
    String? landingUrl,
  }) {
    return AdApplication(
      id: id,
      clubId: clubId,
      clubName: clubName,
      applicantId: applicantId,
      applicantName: applicantName,
      slotType: slotType,
      startMonth: startMonth,
      durationMonths: durationMonths,
      status: status ?? this.status,
      appliedAt: appliedAt,
      title: title,
      description: description,
      rejectReason: rejectReason ?? this.rejectReason,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      paidAt: paidAt ?? this.paidAt,
      paidAmount: paidAmount ?? this.paidAmount,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      detailImageUrl: detailImageUrl ?? this.detailImageUrl,
      landingUrl: landingUrl ?? this.landingUrl,
    );
  }
}

/// 알림톡 메시지 (UI 표시용)
class AdNotification {
  final String id;
  final String recipientId;
  final String title;
  final String body;
  final DateTime sentAt;
  final bool isRead;
  final String? adApplicationId;

  const AdNotification({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.body,
    required this.sentAt,
    this.isRead = false,
    this.adApplicationId,
  });

  AdNotification copyWith({bool? isRead}) => AdNotification(
        id: id,
        recipientId: recipientId,
        title: title,
        body: body,
        sentAt: sentAt,
        isRead: isRead ?? this.isRead,
        adApplicationId: adApplicationId,
      );
}

// ════════════════════════════════════════════════════════════
//  후원(Sponsor) 시스템
//  · 광고와 달리 금액 직접 입력 + 랜딩 URL 필수
//  · 모임 홈 "공식 후원사" 섹션에 뱃지로 노출
//  · 컬러 테마: 인디고/보라 계열
// ════════════════════════════════════════════════════════════

enum SponsorStatus {
  pending,   // 검토 대기
  approved,  // 승인됨 (결제 대기)
  paid,      // 결제 완료 (활성화 대기)
  active,    // 게재 중
  expired,   // 만료
  rejected,  // 거절
}

extension SponsorStatusLabel on SponsorStatus {
  String get label {
    switch (this) {
      case SponsorStatus.pending:  return '검토 대기';
      case SponsorStatus.approved: return '승인됨';
      case SponsorStatus.paid:     return '결제 완료';
      case SponsorStatus.active:   return '후원 중';
      case SponsorStatus.expired:  return '만료';
      case SponsorStatus.rejected: return '거절';
    }
  }
}

class SponsorApplication {
  final String id;
  final String clubId;
  final String clubName;
  final String applicantId;
  final String applicantName;

  // 후원사 정보
  final String sponsorName;           // 후원사 이름 (뱃지에 표시, 예: "다다치과")
  final String description;           // 후원 내용 (총무 검토용)
  final String landingUrl;            // 클릭 시 이동할 URL (선택)
  final String? representativeName;   // 후원 담당자/대표자 이름 (선택)
  final int amount;             // 후원 금액 (직접 입력)
  final int durationMonths;     // 후원 기간 (개월)
  final DateTime startMonth;    // 게재 시작 월

  final SponsorStatus status;
  final DateTime appliedAt;
  final String? rejectReason;
  final DateTime? reviewedAt;
  final DateTime? paidAt;
  final int? paidAmount;
  final String? badgeImageUrl;  // 후원사 로고/이미지 (선택)

  const SponsorApplication({
    required this.id,
    required this.clubId,
    required this.clubName,
    required this.applicantId,
    required this.applicantName,
    required this.sponsorName,
    required this.description,
    this.landingUrl = '',
    required this.amount,
    required this.durationMonths,
    required this.startMonth,
    required this.status,
    required this.appliedAt,
    this.representativeName,
    this.rejectReason,
    this.reviewedAt,
    this.paidAt,
    this.paidAmount,
    this.badgeImageUrl,
  });

  DateTime get endMonth => DateTime(
        startMonth.year,
        startMonth.month + durationMonths,
        1,
      );

  /// 플랫폼 수수료 10%, 모임 정산 90%
  int get platformFee => (amount * 0.1).round();
  int get clubRevenue => amount - platformFee;

  bool isActiveOn(DateTime date) {
    if (status != SponsorStatus.active) return false;
    // 월 단위 비교 (시간대 차이 무관하게 안전)
    final dateYM  = date.year * 12 + date.month - 1;
    final startYM = startMonth.year * 12 + startMonth.month - 1;
    final endYM   = endMonth.year * 12 + endMonth.month - 1;
    return dateYM >= startYM && dateYM < endYM;
  }

  int get daysLeft => endMonth.difference(DateTime.now()).inDays;

  SponsorApplication copyWith({
    SponsorStatus? status,
    String? rejectReason,
    DateTime? reviewedAt,
    DateTime? paidAt,
    int? paidAmount,
    String? badgeImageUrl,
  }) {
    return SponsorApplication(
      id: id,
      clubId: clubId,
      clubName: clubName,
      applicantId: applicantId,
      applicantName: applicantName,
      sponsorName: sponsorName,
      description: description,
      landingUrl: landingUrl,
      amount: amount,
      durationMonths: durationMonths,
      startMonth: startMonth,
      status: status ?? this.status,
      appliedAt: appliedAt,
      representativeName: representativeName,
      rejectReason: rejectReason ?? this.rejectReason,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      paidAt: paidAt ?? this.paidAt,
      paidAmount: paidAmount ?? this.paidAmount,
      badgeImageUrl: badgeImageUrl ?? this.badgeImageUrl,
    );
  }
}

// ────────────────────────────────────────────────────────────
//  멤버십 포인트 시스템
// ────────────────────────────────────────────────────────────
enum MembershipPointType {
  roundAttendance,  // 라운딩 참석 +10
  duesOnTime,       // 회비 정시납부 +5
  commentActivity,  // 댓글/공지 참여 +2
  sponsorGreeting,  // 후원사 인사 +2
  noShow,           // 노쇼 -10
  bonus,            // 특별 보너스
  penalty,          // 기타 차감
}

extension MembershipPointTypeExt on MembershipPointType {
  String get label {
    switch (this) {
      case MembershipPointType.roundAttendance: return '라운딩 참석';
      case MembershipPointType.duesOnTime:      return '회비 정시납부';
      case MembershipPointType.commentActivity: return '공지 참여';
      case MembershipPointType.sponsorGreeting: return '후원사 감사인사';
      case MembershipPointType.noShow:          return '노쇼';
      case MembershipPointType.bonus:           return '보너스';
      case MembershipPointType.penalty:         return '차감';
    }
  }

  String get emoji {
    switch (this) {
      case MembershipPointType.roundAttendance: return '⛳';
      case MembershipPointType.duesOnTime:      return '💳';
      case MembershipPointType.commentActivity: return '💬';
      case MembershipPointType.sponsorGreeting: return '🎁';
      case MembershipPointType.noShow:          return '❌';
      case MembershipPointType.bonus:           return '⭐';
      case MembershipPointType.penalty:         return '⚠️';
    }
  }
}

class MembershipPointEvent {
  final MembershipPointType type;
  final int points;
  final String desc;
  final DateTime date;

  const MembershipPointEvent({
    required this.type,
    required this.points,
    required this.desc,
    required this.date,
  });
}

// ────────────────────────────────────────────────────────────
//  시상 기록
// ────────────────────────────────────────────────────────────
class AwardRecord {
  final String id;
  final String scheduleId;
  final String scheduleName;
  final String awardName;
  final String awardIcon;
  final List<String> winnerIds;
  final List<String> winnerNames;
  final String? winnerNote;
  final DateTime recordedAt;

  const AwardRecord({
    required this.id,
    required this.scheduleId,
    required this.scheduleName,
    required this.awardName,
    required this.awardIcon,
    required this.winnerIds,
    required this.winnerNames,
    this.winnerNote,
    required this.recordedAt,
  });
}

// ────────────────────────────────────────────────────────────
//  후원사 감사인사 메시지
// ────────────────────────────────────────────────────────────
class ThankYouMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String sponsorName;
  final String message;
  final DateTime createdAt;

  const ThankYouMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.sponsorName,
    required this.message,
    required this.createdAt,
  });
}

// ────────────────────────────────────────────────────────────
//  대기 등록 시스템
// ────────────────────────────────────────────────────────────
/// 대기 제안(자리 남음 알림) 수락 기한
const Duration kWaitingAcceptWindow = Duration(hours: 12);

enum WaitingStatus {
  waiting,   // 대기 중
  notified,  // 알림 발송됨 (12시간 내 수락 대기)
  accepted,  // 수락
  expired,   // 기간 초과 (다음 대기자로 넘어감)
  cancelled, // 본인 취소
}

class WaitingEntry {
  final String id;
  final String scheduleId;
  final String memberId;
  final String memberName;
  final DateTime registeredAt;
  final WaitingStatus status;
  final DateTime? notifiedAt;

  const WaitingEntry({
    required this.id,
    required this.scheduleId,
    required this.memberId,
    required this.memberName,
    required this.registeredAt,
    required this.status,
    this.notifiedAt,
  });

  String get statusLabel {
    switch (status) {
      case WaitingStatus.waiting:   return '대기 중';
      case WaitingStatus.notified:  return '알림 발송됨';
      case WaitingStatus.accepted:  return '수락 완료';
      case WaitingStatus.expired:   return '기간 만료';
      case WaitingStatus.cancelled: return '취소됨';
    }
  }
}
