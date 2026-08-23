import '../models/club_model.dart';

/// ClubProvider 전체 상태 스냅샷
class ClubDataBundle {
  final int selectedClubIndex;
  final Set<String> freshClubIds;
  final List<Club> myClubs;
  final List<Club> allClubs;
  final List<JoinRequest> joinRequests;
  final List<Member> members;
  final List<ActivityItem> activities;
  final List<Announcement> announcements;
  final List<AppNotification> appNotifications;
  final List<DuesSetting> duesSettings;
  final List<DuesPayment> duesPayments;
  final List<PaymentRequest> paymentRequests;
  final List<Transaction> transactions;
  final List<RoundSchedule> schedules;
  final List<RoundPhoto> photos;
  final Map<String, GroupAssignment> groupAssignments;
  final List<AdApplication> adApplications;
  final List<AdNotification> adNotifications;
  final List<SponsorApplication> sponsorApplications;
  final Map<String, List<MembershipPointEvent>> pointEvents;
  final List<AwardRecord> awardRecords;
  final List<ThankYouMessage> thankYouMessages;
  final List<WaitingEntry> waitingList;
  final Map<String, ClubAlimtalkSettings> alimtalkSettings;

  const ClubDataBundle({
    required this.selectedClubIndex,
    required this.freshClubIds,
    required this.myClubs,
    required this.allClubs,
    required this.joinRequests,
    required this.members,
    required this.activities,
    required this.announcements,
    required this.appNotifications,
    required this.duesSettings,
    required this.duesPayments,
    required this.paymentRequests,
    required this.transactions,
    required this.schedules,
    required this.photos,
    required this.groupAssignments,
    required this.adApplications,
    required this.adNotifications,
    required this.sponsorApplications,
    required this.pointEvents,
    required this.awardRecords,
    required this.thankYouMessages,
    required this.waitingList,
    required this.alimtalkSettings,
  });
}

class ClubDataCodec {
  static const currentVersion = 7;

  static String? _dt(DateTime? d) => d?.toIso8601String();
  static DateTime? _parseDt(dynamic v) =>
      v == null ? null : DateTime.parse(v as String);
  static DateTime _parseDtReq(dynamic v) => DateTime.parse(v as String);

  /// 라운딩 날짜는 달력 일자만 의미 있음 (시·타임존으로 하루 밀림 방지).
  static String _dateOnly(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static DateTime _parseRoundDate(dynamic v) {
    final s = v as String;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (m != null) {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    }
    final d = DateTime.parse(s).toLocal();
    return DateTime(d.year, d.month, d.day);
  }

  static Map<String, dynamic> encode(ClubDataBundle b) => {
        'version': currentVersion,
        'selectedClubIndex': b.selectedClubIndex,
        'freshClubIds': b.freshClubIds.toList(),
        'myClubs': b.myClubs.map(_encodeClub).toList(),
        'allClubs': b.allClubs.map(_encodeClub).toList(),
        'joinRequests': b.joinRequests.map(_encodeJoinRequest).toList(),
        'members': b.members.map(_encodeMember).toList(),
        'activities': b.activities.map(_encodeActivity).toList(),
        'announcements': b.announcements.map(_encodeAnnouncement).toList(),
        'appNotifications': b.appNotifications.map(_encodeAppNotification).toList(),
        'duesSettings': b.duesSettings.map(_encodeDuesSetting).toList(),
        'duesPayments': b.duesPayments.map(_encodeDuesPayment).toList(),
        'paymentRequests': b.paymentRequests.map(_encodePaymentRequest).toList(),
        'transactions': b.transactions.map(_encodeTransaction).toList(),
        'schedules': b.schedules.map(_encodeSchedule).toList(),
        'photos': b.photos.map(_encodePhoto).toList(),
        'groupAssignments': b.groupAssignments.map(
          (k, v) => MapEntry(k, _encodeGroupAssignment(v)),
        ),
        'adApplications': b.adApplications.map(_encodeAdApplication).toList(),
        'adNotifications': b.adNotifications.map(_encodeAdNotification).toList(),
        'sponsorApplications':
            b.sponsorApplications.map(_encodeSponsorApplication).toList(),
        'pointEvents': b.pointEvents.map(
          (k, v) => MapEntry(k, v.map(_encodePointEvent).toList()),
        ),
        'awardRecords': b.awardRecords.map(_encodeAwardRecord).toList(),
        'thankYouMessages': b.thankYouMessages.map(_encodeThankYou).toList(),
        'waitingList': b.waitingList.map(_encodeWaiting).toList(),
        'alimtalkSettings': b.alimtalkSettings.map(
          (k, v) => MapEntry(k, _encodeAlimtalkSettings(v)),
        ),
      };

  static ClubDataBundle decode(Map<String, dynamic> json) {
    return ClubDataBundle(
      selectedClubIndex: json['selectedClubIndex'] as int? ?? 0,
      freshClubIds: (json['freshClubIds'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toSet(),
      myClubs: _list(json['myClubs'], _decodeClub),
      allClubs: _list(json['allClubs'], _decodeClub),
      joinRequests: _list(json['joinRequests'], _decodeJoinRequest),
      members: _list(json['members'], _decodeMember),
      activities: _list(json['activities'], _decodeActivity),
      announcements: _list(json['announcements'], _decodeAnnouncement),
      appNotifications: _list(json['appNotifications'], _decodeAppNotification),
      duesSettings: _list(json['duesSettings'], _decodeDuesSetting),
      duesPayments: _list(json['duesPayments'], _decodeDuesPayment),
      paymentRequests: _list(json['paymentRequests'], _decodePaymentRequest),
      transactions: _list(json['transactions'], _decodeTransaction),
      schedules: _list(json['schedules'], _decodeSchedule),
      photos: _list(json['photos'], _decodePhoto),
      groupAssignments: _map(json['groupAssignments'], _decodeGroupAssignment),
      adApplications: _list(json['adApplications'], _decodeAdApplication),
      adNotifications: _list(json['adNotifications'], _decodeAdNotification),
      sponsorApplications:
          _list(json['sponsorApplications'], _decodeSponsorApplication),
      pointEvents: _pointMap(json['pointEvents']),
      awardRecords: _list(json['awardRecords'], _decodeAwardRecord),
      thankYouMessages: _list(json['thankYouMessages'], _decodeThankYou),
      waitingList: _list(json['waitingList'], _decodeWaiting),
      alimtalkSettings: _alimtalkSettingsMap(json['alimtalkSettings']),
    );
  }

  static Map<String, ClubAlimtalkSettings> _alimtalkSettingsMap(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map(
      (k, v) => MapEntry(
        k as String,
        _decodeAlimtalkSettings(v as Map<String, dynamic>),
      ),
    );
  }

  static Map<String, dynamic> _encodeAlimtalkSettings(ClubAlimtalkSettings s) =>
      {
        'clubId': s.clubId,
        'promptOnScheduleUpload': s.promptOnScheduleUpload,
        'promptOnGroupFinalize': s.promptOnGroupFinalize,
        'promptOnScheduleChange': s.promptOnScheduleChange,
        'typeOverrides': s.typeOverrides,
      };

  static ClubAlimtalkSettings _decodeAlimtalkSettings(
      Map<String, dynamic> j) {
    final rawOverrides = j['typeOverrides'];
    final overrides = <String, bool>{};
    if (rawOverrides is Map) {
      rawOverrides.forEach((k, v) {
        if (v is bool) overrides['$k'] = v;
      });
    }
    return ClubAlimtalkSettings(
      clubId: j['clubId'] as String,
      promptOnScheduleUpload: j['promptOnScheduleUpload'] as bool? ?? true,
      promptOnGroupFinalize: j['promptOnGroupFinalize'] as bool? ?? true,
      promptOnScheduleChange: j['promptOnScheduleChange'] as bool? ?? true,
      typeOverrides: overrides,
    );
  }

  static List<T> _list<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) decode,
  ) =>
      (raw as List<dynamic>? ?? [])
          .map((e) => decode(Map<String, dynamic>.from(e as Map)))
          .toList();

  static Map<String, GroupAssignment> _map(
    dynamic raw,
    GroupAssignment Function(Map<String, dynamic>) decode,
  ) {
    final map = raw as Map<String, dynamic>? ?? {};
    return map.map(
      (k, v) => MapEntry(k, decode(Map<String, dynamic>.from(v as Map))),
    );
  }

  static Map<String, List<MembershipPointEvent>> _pointMap(dynamic raw) {
    final map = raw as Map<String, dynamic>? ?? {};
    return map.map((k, v) => MapEntry(
          k,
          (v as List<dynamic>)
              .map((e) => _decodePointEvent(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList(),
        ));
  }

  // ── Club ──
  static Map<String, dynamic> _encodeClub(Club c) => {
        'id': c.id,
        'name': c.name,
        'imageUrl': c.imageUrl,
        'myRole': c.myRole,
        'memberCount': c.memberCount,
        'nextRoundDate': _dt(c.nextRoundDate),
        'nextRoundCourse': c.nextRoundCourse,
        'creatorId': c.creatorId,
        'region': c.region,
        'industry': c.industry,
        'teamCount': c.teamCount,
        'description': c.description,
        'createdAt': _dt(c.createdAt),
      };

  static Club _decodeClub(Map<String, dynamic> j) => Club(
        id: j['id'] as String,
        name: j['name'] as String,
        imageUrl: j['imageUrl'] as String?,
        myRole: j['myRole'] as String,
        memberCount: j['memberCount'] as int,
        nextRoundDate: _parseDt(j['nextRoundDate']),
        nextRoundCourse: j['nextRoundCourse'] as String?,
        creatorId: j['creatorId'] as String? ?? '',
        region: j['region'] as String? ?? '서울',
        industry: j['industry'] as String? ?? '기타',
        teamCount: j['teamCount'] as int? ?? 4,
        description: j['description'] as String? ?? '',
        createdAt: _parseDt(j['createdAt']),
      );

  // ── JoinRequest ──
  static Map<String, dynamic> _encodeJoinRequest(JoinRequest r) => {
        'id': r.id,
        'clubId': r.clubId,
        'userId': r.userId,
        'userName': r.userName,
        'userGender': r.userGender,
        'userHandicap': r.userHandicap,
        'message': r.message,
        'referrerId': r.referrerId,
        'referrerName': r.referrerName,
        'status': r.status.name,
        'requestedAt': _dt(r.requestedAt),
        'reviewedBy': r.reviewedBy,
        'reviewedAt': _dt(r.reviewedAt),
      };

  static JoinRequest _decodeJoinRequest(Map<String, dynamic> j) =>
      JoinRequest(
        id: j['id'] as String,
        clubId: j['clubId'] as String,
        userId: j['userId'] as String,
        userName: j['userName'] as String,
        userGender: j['userGender'] as String,
        userHandicap: (j['userHandicap'] as num?)?.toDouble(),
        message: j['message'] as String? ?? '',
        referrerId: j['referrerId'] as String?,
        referrerName: j['referrerName'] as String?,
        status: JoinRequestStatus.values.byName(j['status'] as String),
        requestedAt: _parseDtReq(j['requestedAt']),
        reviewedBy: j['reviewedBy'] as String?,
        reviewedAt: _parseDt(j['reviewedAt']),
      );

  // ── Member ──
  static Map<String, dynamic> _encodeMember(Member m) => {
        'id': m.id,
        'name': m.name,
        'gender': m.gender,
        'birthDate': _dt(m.birthDate),
        'photoUrl': m.photoUrl,
        'phone': m.phone,
        'bio': m.bio,
        'memberType': m.memberType,
        'role': m.role,
        'handicap': m.handicap,
        'joinDate': _dt(m.joinDate),
        'address': m.address,
        'memo': m.memo,
        'status': m.status,
        'referrerId': m.referrerId,
        'referrerName': m.referrerName,
      };

  static Member _decodeMember(Map<String, dynamic> j) => Member(
        id: j['id'] as String,
        name: j['name'] as String,
        gender: j['gender'] as String,
        birthDate: _parseDt(j['birthDate']),
        photoUrl: j['photoUrl'] as String?,
        phone: j['phone'] as String?,
        bio: j['bio'] as String?,
        memberType: j['memberType'] as String,
        role: j['role'] as String,
        handicap: (j['handicap'] as num?)?.toDouble(),
        joinDate: _parseDt(j['joinDate']),
        address: j['address'] as String?,
        memo: j['memo'] as String?,
        status: j['status'] as String? ?? '활성',
        referrerId: j['referrerId'] as String?,
        referrerName: j['referrerName'] as String?,
      );

  // ── ActivityItem ──
  static Map<String, dynamic> _encodeActivity(ActivityItem a) => {
        'id': a.id,
        'memberId': a.memberId,
        'memberName': a.memberName,
        'memberPhotoUrl': a.memberPhotoUrl,
        'activityType': a.activityType,
        'description': a.description,
        'timestamp': _dt(a.timestamp),
      };

  static ActivityItem _decodeActivity(Map<String, dynamic> j) => ActivityItem(
        id: j['id'] as String,
        memberId: j['memberId'] as String,
        memberName: j['memberName'] as String,
        memberPhotoUrl: j['memberPhotoUrl'] as String?,
        activityType: j['activityType'] as String,
        description: j['description'] as String,
        timestamp: _parseDtReq(j['timestamp']),
      );

  // ── Announcement ──
  static Map<String, dynamic> _encodeAnnouncement(Announcement a) => {
        'id': a.id,
        'title': a.title,
        'content': a.content,
        'isPinned': a.isPinned,
        'createdAt': _dt(a.createdAt),
        'clubId': a.clubId,
        'authorId': a.authorId,
        'authorName': a.authorName,
        'comments': a.comments
            .map((c) => {
                  'id': c.id,
                  'authorId': c.authorId,
                  'authorName': c.authorName,
                  'text': c.text,
                  'createdAt': _dt(c.createdAt),
                })
            .toList(),
      };

  static Announcement _decodeAnnouncement(Map<String, dynamic> j) =>
      Announcement(
        id: j['id'] as String,
        title: j['title'] as String,
        content: j['content'] as String?,
        isPinned: j['isPinned'] as bool? ?? false,
        createdAt: _parseDtReq(j['createdAt']),
        clubId: j['clubId'] as String?,
        authorId: j['authorId'] as String?,
        authorName: j['authorName'] as String?,
        comments: (j['comments'] as List<dynamic>? ?? [])
            .map((c) {
              final m = Map<String, dynamic>.from(c as Map);
              return AnnouncementComment(
                id: m['id'] as String,
                authorId: m['authorId'] as String,
                authorName: m['authorName'] as String,
                text: m['text'] as String,
                createdAt: _parseDtReq(m['createdAt']),
              );
            })
            .toList(),
      );

  // ── AppNotification ──
  static Map<String, dynamic> _encodeAppNotification(AppNotification n) => {
        'id': n.id,
        'type': n.type.name,
        'clubId': n.clubId,
        'clubName': n.clubName,
        'title': n.title,
        'body': n.body,
        'isAdmin': n.isAdmin,
        'isRead': n.isRead,
        'createdAt': _dt(n.createdAt),
        'targetId': n.targetId,
        'targetUserId': n.targetUserId,
      };

  static AppNotification _decodeAppNotification(Map<String, dynamic> j) =>
      AppNotification(
        id: j['id'] as String,
        type: AppNotificationType.values.byName(j['type'] as String),
        clubId: j['clubId'] as String,
        clubName: j['clubName'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        isAdmin: j['isAdmin'] as bool? ?? false,
        isRead: j['isRead'] as bool? ?? false,
        createdAt: _parseDtReq(j['createdAt']),
        targetId: j['targetId'] as String?,
        targetUserId: j['targetUserId'] as String?,
      );

  // ── DuesSetting ──
  static Map<String, dynamic> _encodeDuesSetting(DuesSetting d) => {
        'id': d.id,
        'type': d.type.name,
        'amount': d.amount,
        'title': d.title,
        'description': d.description,
        'createdAt': _dt(d.createdAt),
        'isActive': d.isActive,
        'clubId': d.clubId,
        'startMonth': d.startMonth,
        'endMonth': d.endMonth,
        'startYear': d.startYear,
        'endYear': d.endYear,
        'year': d.year,
        'dueDate': _dt(d.dueDate),
        'dueDayOfMonth': d.dueDayOfMonth,
        'amountHistory': d.amountHistory
            .map((c) => {
                  'amount': c.amount,
                  'effectiveYear': c.effectiveYear,
                  'effectiveMonth': c.effectiveMonth,
                  'changedAt': _dt(c.changedAt),
                })
            .toList(),
      };

  static DuesSetting _decodeDuesSetting(Map<String, dynamic> j) {
    final rawHistory = j['amountHistory'] as List?;
    return DuesSetting(
      id: j['id'] as String,
      type: DuesType.values.byName(j['type'] as String),
      amount: j['amount'] as int,
      title: j['title'] as String,
      description: j['description'] as String?,
      createdAt: _parseDtReq(j['createdAt']),
      isActive: j['isActive'] as bool? ?? true,
      clubId: j['clubId'] as String?,
      startMonth: j['startMonth'] as int?,
      endMonth: j['endMonth'] as int?,
      startYear: j['startYear'] as int?,
      endYear: j['endYear'] as int?,
      year: j['year'] as int?,
      dueDate: _parseDt(j['dueDate']),
      dueDayOfMonth: j['dueDayOfMonth'] as int?,
      amountHistory: rawHistory == null || rawHistory.isEmpty
          ? null
          : rawHistory
              .map((raw) {
                final c = raw as Map<String, dynamic>;
                return DuesAmountChange(
                  amount: c['amount'] as int,
                  effectiveYear: c['effectiveYear'] as int,
                  effectiveMonth: c['effectiveMonth'] as int,
                  changedAt: _parseDtReq(c['changedAt']),
                );
              })
              .toList(),
    );
  }

  // ── DuesPayment ──
  static Map<String, dynamic> _encodeDuesPayment(DuesPayment p) => {
        'id': p.id,
        'memberId': p.memberId,
        'memberName': p.memberName,
        'duesSettingId': p.duesSettingId,
        'amount': p.amount,
        'paidAt': _dt(p.paidAt),
        'memo': p.memo,
        'recordedBy': p.recordedBy,
        'skipsBalance': p.skipsBalance,
      };

  static DuesPayment _decodeDuesPayment(Map<String, dynamic> j) =>
      DuesPayment(
        id: j['id'] as String,
        memberId: j['memberId'] as String,
        memberName: j['memberName'] as String,
        duesSettingId: j['duesSettingId'] as String,
        amount: j['amount'] as int,
        paidAt: _parseDtReq(j['paidAt']),
        memo: j['memo'] as String?,
        recordedBy: j['recordedBy'] as String,
        skipsBalance: j['skipsBalance'] as bool? ?? false,
      );

  // ── PaymentRequest ──
  static Map<String, dynamic> _encodePaymentRequest(PaymentRequest p) => {
        'id': p.id,
        'memberId': p.memberId,
        'memberName': p.memberName,
        'duesSettingId': p.duesSettingId,
        'duesTitle': p.duesTitle,
        'amount': p.amount,
        'year': p.year,
        'month': p.month,
        'memo': p.memo,
        'status': p.status.name,
        'requestedAt': _dt(p.requestedAt),
        'reviewedBy': p.reviewedBy,
        'reviewedAt': _dt(p.reviewedAt),
        'clubId': p.clubId,
      };

  static PaymentRequest _decodePaymentRequest(Map<String, dynamic> j) =>
      PaymentRequest(
        id: j['id'] as String,
        memberId: j['memberId'] as String,
        memberName: j['memberName'] as String,
        duesSettingId: j['duesSettingId'] as String,
        duesTitle: j['duesTitle'] as String,
        amount: j['amount'] as int,
        year: j['year'] as int?,
        month: j['month'] as int?,
        memo: j['memo'] as String?,
        status: PaymentRequestStatus.values.byName(j['status'] as String),
        requestedAt: _parseDtReq(j['requestedAt']),
        reviewedBy: j['reviewedBy'] as String?,
        reviewedAt: _parseDt(j['reviewedAt']),
        clubId: j['clubId'] as String?,
      );

  // ── Transaction ──
  static Map<String, dynamic> _encodeTransaction(Transaction t) => {
        'id': t.id,
        'type': t.type.name,
        'amount': t.amount,
        'category': t.category,
        'title': t.title,
        'memo': t.memo,
        'date': _dt(t.date),
        'recordedBy': t.recordedBy,
        'source': t.source.name,
        'duesPaymentId': t.duesPaymentId,
        'clubId': t.clubId,
      };

  static Transaction _decodeTransaction(Map<String, dynamic> j) =>
      Transaction(
        id: j['id'] as String,
        type: TxType.values.byName(j['type'] as String),
        amount: j['amount'] as int,
        category: j['category'] as String,
        title: j['title'] as String,
        memo: j['memo'] as String?,
        date: _parseDtReq(j['date']),
        recordedBy: j['recordedBy'] as String,
        source: TxSource.values.byName(j['source'] as String),
        duesPaymentId: j['duesPaymentId'] as String?,
        clubId: j['clubId'] as String?,
      );

  // ── RoundSchedule ──
  static Map<String, dynamic> _encodeSchedule(RoundSchedule s) => {
        'id': s.id,
        'clubId': s.clubId,
        'title': s.title,
        // 날짜만 저장 — UTC/로컬 변환으로 하루 밀려 중복 앨범 생기는 것 방지
        'roundDate': _dateOnly(s.roundDate),
        'teeTime': s.teeTime,
        'courseName': s.courseName,
        'courseAddress': s.courseAddress,
        'teamCount': s.teamCount,
        'maxCapacity': s.maxCapacity,
        'notice': s.notice,
        'status': s.status.name,
        'createdBy': s.createdBy,
        'responses': s.responses.map(_encodeAttendanceResponse).toList(),
        'companionIds': s.companionIds,
        'reviewMemo': s.reviewMemo,
        'rsvpDeadline': _dt(s.rsvpDeadline),
        'deadlineNotified': s.deadlineNotified,
      };

  static RoundSchedule _decodeSchedule(Map<String, dynamic> j) {
    final teamCount = j['teamCount'] as int;
    final rawCap = j['maxCapacity'] as int?;
    // 구버전 테스트값(팀수×4보다 작은 maxCapacity)은 무시 → 팀수×4 규칙
    final maxCapacity =
        (rawCap != null && rawCap >= teamCount * 4) ? rawCap : null;
    return RoundSchedule(
      id: j['id'] as String,
      clubId: j['clubId'] as String,
      title: j['title'] as String,
      roundDate: _parseRoundDate(j['roundDate']),
      teeTime: j['teeTime'] as String,
      courseName: j['courseName'] as String,
      courseAddress: j['courseAddress'] as String?,
      teamCount: teamCount,
      maxCapacity: maxCapacity,
      notice: j['notice'] as String?,
      status: ScheduleStatus.values.byName(j['status'] as String),
      createdBy: j['createdBy'] as String,
      responses: (j['responses'] as List<dynamic>? ?? [])
          .map((e) => _decodeAttendanceResponse(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
      companionIds: (j['companionIds'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      reviewMemo: j['reviewMemo'] as String?,
      rsvpDeadline: _parseDt(j['rsvpDeadline']),
      deadlineNotified: j['deadlineNotified'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> _encodeAttendanceResponse(
          AttendanceResponse r) =>
      {
        'memberId': r.memberId,
        'memberName': r.memberName,
        'response': r.response,
        'memo': r.memo,
        'companionMemberIds': r.companionMemberIds,
        'respondedAt': _dt(r.respondedAt),
      };

  static AttendanceResponse _decodeAttendanceResponse(Map<String, dynamic> j) =>
      AttendanceResponse(
        memberId: j['memberId'] as String,
        memberName: j['memberName'] as String,
        response: j['response'] as String,
        memo: j['memo'] as String?,
        companionMemberIds: (j['companionMemberIds'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        respondedAt: _parseDtReq(j['respondedAt']),
      );

  // ── RoundPhoto ──
  static Map<String, dynamic> _encodePhoto(RoundPhoto p) => {
        'id': p.id,
        'scheduleId': p.scheduleId,
        'clubId': p.clubId,
        'uploaderId': p.uploaderId,
        'uploaderName': p.uploaderName,
        'imageUrl': p.imageUrl,
        'caption': p.caption,
        'takenAt': _dt(p.takenAt),
      };

  static RoundPhoto _decodePhoto(Map<String, dynamic> j) => RoundPhoto(
        id: j['id'] as String,
        scheduleId: j['scheduleId'] as String,
        clubId: j['clubId'] as String,
        uploaderId: j['uploaderId'] as String,
        uploaderName: j['uploaderName'] as String,
        imageUrl: j['imageUrl'] as String,
        caption: j['caption'] as String?,
        takenAt: _parseDtReq(j['takenAt']),
      );

  // ── GroupAssignment ──
  static Map<String, dynamic> _encodeGroupAssignment(GroupAssignment g) => {
        'scheduleId': g.scheduleId,
        'teamCount': g.teamCount,
        'perGroup': g.perGroup,
        'isFinalized': g.isFinalized,
        'finalizedAt': _dt(g.finalizedAt),
        'mode': g.mode.name,
        'selectedOptions': g.selectedOptions.map((o) => o.name).toList(),
        'groups': g.groups
            .map((grp) => {
                  'groupNumber': grp.groupNumber,
                  'slots': grp.slots
                      .map((s) => {
                            'memberId': s.memberId,
                            'memberName': s.memberName,
                            'gender': s.gender,
                            'handicap': s.handicap,
                            'memberType': s.memberType,
                            'referrerId': s.referrerId,
                          })
                      .toList(),
                })
            .toList(),
      };

  static GroupAssignment _decodeGroupAssignment(Map<String, dynamic> j) {
    final modeName = j['mode'] as String?;
    final mode = modeName != null &&
            GroupAssignmentMode.values.any((m) => m.name == modeName)
        ? GroupAssignmentMode.values.byName(modeName)
        : GroupAssignmentMode.hybrid;
    final options = (j['selectedOptions'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .where((name) => AutoAssignOption.values.any((o) => o.name == name))
        .map((name) => AutoAssignOption.values.byName(name))
        .toList();

    return GroupAssignment(
      scheduleId: j['scheduleId'] as String,
      teamCount: j['teamCount'] as int,
      perGroup: j['perGroup'] as int,
      isFinalized: j['isFinalized'] as bool? ?? false,
      finalizedAt: _parseDt(j['finalizedAt']),
      mode: mode,
      selectedOptions: options,
      groups: (j['groups'] as List<dynamic>? ?? [])
          .map((g) {
            final gm = Map<String, dynamic>.from(g as Map);
            return AssignGroup(
              groupNumber: gm['groupNumber'] as int,
              slots: (gm['slots'] as List<dynamic>? ?? [])
                  .map((s) {
                    final sm = Map<String, dynamic>.from(s as Map);
                    return GroupSlot(
                      memberId: sm['memberId'] as String?,
                      memberName: sm['memberName'] as String?,
                      gender: sm['gender'] as String?,
                      handicap: (sm['handicap'] as num?)?.toDouble(),
                      memberType: sm['memberType'] as String?,
                      referrerId: sm['referrerId'] as String?,
                    );
                  })
                  .toList(),
            );
          })
          .toList(),
    );
  }

  // ── AdApplication ──
  static Map<String, dynamic> _encodeAdApplication(AdApplication a) => {
        'id': a.id,
        'clubId': a.clubId,
        'clubName': a.clubName,
        'applicantId': a.applicantId,
        'applicantName': a.applicantName,
        'slotType': a.slotType.name,
        'startMonth': _dt(a.startMonth),
        'durationMonths': a.durationMonths,
        'status': a.status.name,
        'appliedAt': _dt(a.appliedAt),
        'title': a.title,
        'description': a.description,
        'rejectReason': a.rejectReason,
        'reviewedAt': _dt(a.reviewedAt),
        'paidAt': _dt(a.paidAt),
        'paidAmount': a.paidAmount,
        'bannerImageUrl': a.bannerImageUrl,
        'detailImageUrl': a.detailImageUrl,
        'landingUrl': a.landingUrl,
      };

  static AdApplication _decodeAdApplication(Map<String, dynamic> j) =>
      AdApplication(
        id: j['id'] as String,
        clubId: j['clubId'] as String,
        clubName: j['clubName'] as String,
        applicantId: j['applicantId'] as String,
        applicantName: j['applicantName'] as String,
        slotType: AdSlotType.values.byName(j['slotType'] as String),
        startMonth: _parseDtReq(j['startMonth']),
        durationMonths: j['durationMonths'] as int,
        status: AdStatus.values.byName(j['status'] as String),
        appliedAt: _parseDtReq(j['appliedAt']),
        title: j['title'] as String,
        description: j['description'] as String,
        rejectReason: j['rejectReason'] as String?,
        reviewedAt: _parseDt(j['reviewedAt']),
        paidAt: _parseDt(j['paidAt']),
        paidAmount: j['paidAmount'] as int?,
        bannerImageUrl: j['bannerImageUrl'] as String?,
        detailImageUrl: j['detailImageUrl'] as String?,
        landingUrl: j['landingUrl'] as String?,
      );

  // ── AdNotification ──
  static Map<String, dynamic> _encodeAdNotification(AdNotification n) => {
        'id': n.id,
        'recipientId': n.recipientId,
        'title': n.title,
        'body': n.body,
        'sentAt': _dt(n.sentAt),
        'isRead': n.isRead,
        'adApplicationId': n.adApplicationId,
      };

  static AdNotification _decodeAdNotification(Map<String, dynamic> j) =>
      AdNotification(
        id: j['id'] as String,
        recipientId: j['recipientId'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        sentAt: _parseDtReq(j['sentAt']),
        isRead: j['isRead'] as bool? ?? false,
        adApplicationId: j['adApplicationId'] as String?,
      );

  // ── SponsorApplication ──
  static Map<String, dynamic> _encodeSponsorApplication(
          SponsorApplication s) =>
      {
        'id': s.id,
        'clubId': s.clubId,
        'clubName': s.clubName,
        'applicantId': s.applicantId,
        'applicantName': s.applicantName,
        'sponsorName': s.sponsorName,
        'description': s.description,
        'landingUrl': s.landingUrl,
        'representativeName': s.representativeName,
        'amount': s.amount,
        'durationMonths': s.durationMonths,
        'startMonth': _dt(s.startMonth),
        'status': s.status.name,
        'appliedAt': _dt(s.appliedAt),
        'rejectReason': s.rejectReason,
        'reviewedAt': _dt(s.reviewedAt),
        'paidAt': _dt(s.paidAt),
        'paidAmount': s.paidAmount,
        'badgeImageUrl': s.badgeImageUrl,
      };

  static SponsorApplication _decodeSponsorApplication(Map<String, dynamic> j) =>
      SponsorApplication(
        id: j['id'] as String,
        clubId: j['clubId'] as String,
        clubName: j['clubName'] as String,
        applicantId: j['applicantId'] as String,
        applicantName: j['applicantName'] as String,
        sponsorName: j['sponsorName'] as String,
        description: j['description'] as String,
        landingUrl: j['landingUrl'] as String? ?? '',
        representativeName: j['representativeName'] as String?,
        amount: j['amount'] as int,
        durationMonths: j['durationMonths'] as int,
        startMonth: _parseDtReq(j['startMonth']),
        status: SponsorStatus.values.byName(j['status'] as String),
        appliedAt: _parseDtReq(j['appliedAt']),
        rejectReason: j['rejectReason'] as String?,
        reviewedAt: _parseDt(j['reviewedAt']),
        paidAt: _parseDt(j['paidAt']),
        paidAmount: j['paidAmount'] as int?,
        badgeImageUrl: j['badgeImageUrl'] as String?,
      );

  // ── MembershipPointEvent ──
  static Map<String, dynamic> _encodePointEvent(MembershipPointEvent e) => {
        'type': e.type.name,
        'points': e.points,
        'desc': e.desc,
        'date': _dt(e.date),
      };

  static MembershipPointEvent _decodePointEvent(Map<String, dynamic> j) =>
      MembershipPointEvent(
        type: MembershipPointType.values.byName(j['type'] as String),
        points: j['points'] as int,
        desc: j['desc'] as String,
        date: _parseDtReq(j['date']),
      );

  // ── AwardRecord ──
  static Map<String, dynamic> _encodeAwardRecord(AwardRecord r) => {
        'id': r.id,
        'scheduleId': r.scheduleId,
        'scheduleName': r.scheduleName,
        'awardName': r.awardName,
        'awardIcon': r.awardIcon,
        'winnerIds': r.winnerIds,
        'winnerNames': r.winnerNames,
        'winnerNote': r.winnerNote,
        'recordedAt': _dt(r.recordedAt),
      };

  static AwardRecord _decodeAwardRecord(Map<String, dynamic> j) =>
      AwardRecord(
        id: j['id'] as String,
        scheduleId: j['scheduleId'] as String,
        scheduleName: j['scheduleName'] as String,
        awardName: j['awardName'] as String,
        awardIcon: j['awardIcon'] as String,
        winnerIds: (j['winnerIds'] as List<dynamic>).cast<String>(),
        winnerNames: (j['winnerNames'] as List<dynamic>).cast<String>(),
        winnerNote: j['winnerNote'] as String?,
        recordedAt: _parseDtReq(j['recordedAt']),
      );

  // ── ThankYouMessage ──
  static Map<String, dynamic> _encodeThankYou(ThankYouMessage t) => {
        'id': t.id,
        'senderId': t.senderId,
        'senderName': t.senderName,
        'sponsorName': t.sponsorName,
        'message': t.message,
        'createdAt': _dt(t.createdAt),
      };

  static ThankYouMessage _decodeThankYou(Map<String, dynamic> j) =>
      ThankYouMessage(
        id: j['id'] as String,
        senderId: j['senderId'] as String,
        senderName: j['senderName'] as String,
        sponsorName: j['sponsorName'] as String,
        message: j['message'] as String,
        createdAt: _parseDtReq(j['createdAt']),
      );

  // ── WaitingEntry ──
  static Map<String, dynamic> _encodeWaiting(WaitingEntry w) => {
        'id': w.id,
        'scheduleId': w.scheduleId,
        'memberId': w.memberId,
        'memberName': w.memberName,
        'registeredAt': _dt(w.registeredAt),
        'status': w.status.name,
        'notifiedAt': _dt(w.notifiedAt),
      };

  static WaitingEntry _decodeWaiting(Map<String, dynamic> j) => WaitingEntry(
        id: j['id'] as String,
        scheduleId: j['scheduleId'] as String,
        memberId: j['memberId'] as String,
        memberName: j['memberName'] as String,
        registeredAt: _parseDtReq(j['registeredAt']),
        status: WaitingStatus.values.byName(j['status'] as String),
        notifiedAt: _parseDt(j['notifiedAt']),
      );
}
