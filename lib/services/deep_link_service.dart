import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/invite_links.dart';
import '../models/club_model.dart';
import '../models/user_model.dart';
import '../navigation/app_navigator.dart';
import '../providers/auth_provider.dart';
import '../providers/club_provider.dart';
import '../screens/club_room/club_room_screen.dart';
import '../screens/invite/invite_landing_screen.dart';

/// 알림톡/푸시 앱링크 진입
///
/// 솔라피 버튼 URL (검수 템플릿별):
/// - 모임 초대 → `rounder://invite?token=#{토큰}&club=#{클럽ID}&name=#{모임명}&inviter=#{초대자}`
/// - 일정 등록 / 변경 / 취소 / D-1 → `rounder://schedule`
/// - 조편성 확정 → `rounder://group`
/// - 회비 납부요청 / 납부 독촉 → `rounder://dues`
/// - 공통 폴백 → `rounder://open`
///
/// (가입 승인/거절 알림톡은 초대 즉시가입으로 대체 — 사용 안 함)
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  Uri? _pending;
  bool _started = false;
  bool _ready = false;

  /// 일정 탭 / 재무 탭 인덱스 (ClubRoomScreen과 동일)
  static const scheduleTab = 1;
  static const financeTab = 4;

  Future<void> start() async {
    if (_started || kIsWeb) return;
    _started = true;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        debugPrint('[DeepLink] initial: $initial');
        _pending = initial;
      }
    } catch (e) {
      debugPrint('[DeepLink] getInitialLink fail: $e');
    }

    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('[DeepLink] stream: $uri');
        handle(uri);
      },
      onError: (Object e) => debugPrint('[DeepLink] stream error: $e'),
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
    _ready = false;
  }

  /// 로그인·휴대폰 등록 후 `/main` 진입 시 호출
  void onAppReady() {
    _ready = true;
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    // 스플래시→메인 전환 직후 한 프레임 뒤 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      handle(pending);
    });
  }

  /// 로그인/회원가입 전에 초대 링크만 기억
  void queue(Uri uri) {
    if (uri.scheme != 'rounder' && !InviteLinks.isInviteHttps(uri)) return;
    _pending = uri;
    debugPrint('[DeepLink] queued host=${uri.host} path=${uri.path}');
  }

  void handle(Uri uri) {
    if (uri.scheme != 'rounder' && !InviteLinks.isInviteHttps(uri)) {
      debugPrint('[DeepLink] ignore scheme=${uri.scheme}');
      return;
    }

    final ctx = AppNavigator.context;
    if (!_ready || ctx == null || AppNavigator.state == null) {
      _pending = uri;
      debugPrint('[DeepLink] queued host=${uri.host}');
      return;
    }

    unawaited(_navigate(ctx, uri));
  }

  Future<void> _navigate(BuildContext context, Uri uri) async {
    final host = uri.host.toLowerCase();
    final q = uri.queryParameters;

    if (InviteLinks.isInviteUri(uri)) {
      await _openInvite(context, q);
      return;
    }

    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      _pending = uri;
      AppNavigator.state?.pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }
    if (auth.needsPhoneNumber) {
      _pending = uri;
      AppNavigator.state
          ?.pushNamedAndRemoveUntil('/phone-required', (_) => false);
      return;
    }

    final clubs = context.read<ClubProvider>();
    final clubId = (q['club'] ?? q['clubId'] ?? '').trim();
    final scheduleId = (q['id'] ?? q['schedule'] ?? q['scheduleId'] ?? '').trim();

    switch (host) {
      case 'dues':
        await _openClubRoom(
          context,
          clubs,
          clubId: clubId,
          initialTab: financeTab,
        );
        return;
      case 'join':
      case 'home':
      case 'club':
        await _openClubRoom(
          context,
          clubs,
          clubId: clubId,
          initialTab: 0,
        );
        return;
      case 'schedule':
        await _openClubRoom(
          context,
          clubs,
          clubId: clubId,
          initialTab: scheduleTab,
          openScheduleId: scheduleId.isEmpty ? null : scheduleId,
        );
        return;
      case 'group':
        await _openClubRoom(
          context,
          clubs,
          clubId: clubId,
          initialTab: scheduleTab,
          openScheduleId: scheduleId.isEmpty ? null : scheduleId,
          openGroupAssignment: true,
        );
        return;
      case 'open':
      case '':
        _popToMain();
        return;
      default:
        debugPrint('[DeepLink] unknown host=$host → main');
        _popToMain();
    }
  }

  Future<void> _openInvite(
    BuildContext context,
    Map<String, String> q,
  ) async {
    final token = (q['token'] ?? '').trim();
    final clubId = (q['club'] ?? q['clubId'] ?? '').trim();
    final auth = context.read<AuthProvider>();
    final known = token.isEmpty ? null : auth.findToken(token);

    final clubName = (q['name'] ?? q['clubName'] ?? known?.clubName ?? '').trim();
    final inviter =
        (q['inviter'] ?? q['inviterName'] ?? known?.inviterName ?? '').trim();
    final resolvedClubId =
        (clubId.isNotEmpty ? clubId : known?.clubId ?? '').trim();
    final typeRaw = (q['type'] ?? '').trim().toLowerCase();
    final inviteType = (typeRaw == 'guest' ||
            known?.inviteType == InviteMemberType.guest)
        ? InviteMemberType.guest
        : InviteMemberType.regular;
    final referrerId =
        (q['referrer'] ?? q['referrerId'] ?? known?.referrerId ?? '').trim();
    final referrerName = (q['referrerName'] ?? known?.referrerName ?? '').trim();
    final guestName = (q['guest'] ?? q['guestName'] ?? known?.guestName ?? '')
        .trim();

    if (resolvedClubId.isEmpty && clubName.isEmpty) {
      debugPrint('[DeepLink] invite missing club — fall back to main');
      if (auth.isLoggedIn && !auth.needsPhoneNumber) {
        _popToMain();
      } else if (!auth.isLoggedIn) {
        AppNavigator.state?.pushNamedAndRemoveUntil('/login', (_) => false);
      }
      return;
    }

    final nav = AppNavigator.state;
    if (nav == null) return;

    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => InviteLandingScreen(
          clubId: resolvedClubId.isNotEmpty ? resolvedClubId : 'unknown',
          clubName: clubName.isNotEmpty ? clubName : '모임',
          inviterName: inviter.isNotEmpty ? inviter : '회원',
          token: token.isNotEmpty ? token : 'link',
          inviteType: inviteType,
          referrerId: referrerId.isEmpty ? null : referrerId,
          referrerName: referrerName.isEmpty ? null : referrerName,
          guestName: guestName.isEmpty ? null : guestName,
        ),
      ),
    );
  }

  Future<void> _openClubRoom(
    BuildContext context,
    ClubProvider clubs, {
    required String clubId,
    required int initialTab,
    String? openScheduleId,
    bool openGroupAssignment = false,
  }) async {
    final club = _resolveClub(clubs, clubId);
    if (club == null) {
      debugPrint('[DeepLink] no club to open (clubId=$clubId)');
      _popToMain();
      if (AppNavigator.context != null) {
        ScaffoldMessenger.of(AppNavigator.context!).showSnackBar(
          const SnackBar(
            content: Text('해당 모임을 찾을 수 없습니다. 내 모임에서 확인해 주세요.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    clubs.selectClubById(club.id);
    final selected = clubs.myClubs.firstWhere(
      (c) => c.id == club.id,
      orElse: () => club,
    );

    _popToMain();
    final nav = AppNavigator.state;
    if (nav == null) return;

    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => ClubRoomScreen(
          club: selected,
          initialTab: initialTab,
          openScheduleId: openScheduleId,
          openGroupAssignment: openGroupAssignment,
          openNearestSchedule:
              initialTab == scheduleTab || openGroupAssignment,
        ),
      ),
    );
  }

  Club? _resolveClub(ClubProvider clubs, String clubId) {
    if (clubs.myClubs.isEmpty) return null;
    if (clubId.isNotEmpty) {
      for (final c in clubs.myClubs) {
        if (c.id == clubId) return c;
      }
    }
    return clubs.selectedClubOrNull ?? clubs.myClubs.first;
  }

  void _popToMain() {
    final nav = AppNavigator.state;
    if (nav == null) return;
    var reachedMain = false;
    nav.popUntil((route) {
      if (route.settings.name == '/main') {
        reachedMain = true;
        return true;
      }
      return route.isFirst;
    });
    if (!reachedMain) {
      nav.pushNamedAndRemoveUntil('/main', (_) => false);
    }
  }
}
