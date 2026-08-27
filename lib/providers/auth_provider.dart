import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/firebase/firestore_paths.dart';
import '../data/repositories/mock/mock_data_store.dart';
import '../di/app_dependencies.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_bridge.dart';
import '../services/push_notification_service.dart';
import '../services/social_auth_service.dart';
import '../services/solapi_service.dart';

// ════════════════════════════════════════════════════════════
//  AuthProvider — 로그인 / 자동로그인 / 세션 관리
// ════════════════════════════════════════════════════════════
class AuthProvider extends ChangeNotifier {

  // ── SharedPreferences 키 ─────────────────────────────────
  static const _kSavedPhone    = 'saved_phone';
  static const _kAutoLogin     = 'auto_login';
  static const _kLastLoginId   = 'last_login_id';
  static const _kLastLoginName = 'last_login_name';
  static const _kLastLoginMethod = 'last_login_method';

  // ── 현재 로그인 사용자 ───────────────────────────────────
  AppUser? _currentUser;
  AppUser? get currentUser  => _currentUser;
  bool     get isLoggedIn   => _currentUser != null;

  /// 로그아웃 후에도 남겨, 다음 로그인 화면에서 안내한다.
  String? _lastLoginMethod;
  String? get lastLoginMethod => _lastLoginMethod;

  static bool isPlaceholderName(String? name) {
    final n = name?.trim() ?? '';
    if (n.isEmpty || n == '회원') return true;
    return n == '카카오 회원' || n == 'Google 회원' || n == 'Apple 회원';
  }

  String get greetingName {
    final n = _currentUser?.name.trim() ?? '';
    if (isPlaceholderName(n)) return '회원';
    return n;
  }

  /// 현재 유저 역할 (관리자 여부)
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  /// 소셜 로그인 등 — 휴대폰 번호가 없으면 필수 수집 대상
  bool get needsPhoneNumber {
    final user = _currentUser;
    if (user == null) return false;
    return _normalizePhone(user.phone).length < 10;
  }

  static bool isPhoneMissing(String? phone) =>
      (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '').length < 10;

  // ── 자동로그인 설정 ──────────────────────────────────────
  bool _autoLogin = false;
  bool get autoLogin => _autoLogin;

  // ── SMS/PASS 인증 상태 ───────────────────────────────────
  bool    _isVerifying    = false;
  bool    get isVerifying => _isVerifying;
  String? _pendingPhone;
  String? get pendingPhone => _pendingPhone;
  String  _smsCode        = '';
  bool    _smsCodeSent    = false;
  bool    get smsCodeSent => _smsCodeSent;
  bool    _passRequested  = false;
  bool    get passRequested => _passRequested;
  bool    _verifySuccess  = false;
  bool    get verifySuccess => _verifySuccess;

  // ── 회원가입 임시 데이터 ─────────────────────────────────
  String?       _signupName;
  String?       _signupPhone;
  double?       _signupHandicap;
  VerifyMethod? _signupVerifyMethod;

  // ── 초대 토큰 목록 ───────────────────────────────────────
  final List<InviteToken> _inviteTokens = [];
  List<InviteToken> get inviteTokens => List.unmodifiable(_inviteTokens);

  // ════════════════════════════════════════════════════════
  //  Mock 사용자 DB
  //
  //  ┌──────────────────────────────────────────────────────┐
  //  │  테스트 계정 (클린 슬레이트)                          │
  //  │  홍길동 : 010-1234-5678  (user_me / m1)               │
  //  │  이민준 : 010-9999-0000  (user_guest / mg1)          │
  //  └──────────────────────────────────────────────────────┘
  // ════════════════════════════════════════════════════════
  final List<AppUser> _registeredUsers = [
    AppUser(
      id:           'user_me',
      name:         '홍길동',
      phone:        '010-1234-5678',
      handicap:     12.0,
      isVerified:   true,
      isAdmin:      true,
      role:         '총무',
      verifyMethod: VerifyMethod.sms,
    ),
    AppUser(
      id:           'user_guest',
      name:         '이민준',
      phone:        '010-9999-0000',
      handicap:     18.0,
      isVerified:   true,
      isAdmin:      false,
      role:         '일반',
      verifyMethod: VerifyMethod.sms,
    ),
  ];

  // ════════════════════════════════════════════════════════
  //  자동로그인 초기화 (앱 시작 시 호출)
  // ════════════════════════════════════════════════════════

  /// SharedPreferences에서 저장된 로그인 세션 복원
  /// 반환값: true = 자동로그인 성공, false = 로그인 필요
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    _autoLogin = prefs.getBool(_kAutoLogin) ?? false;
    _lastLoginMethod = prefs.getString(_kLastLoginMethod);

    if (!_autoLogin) return false;

    final savedId = prefs.getString(_kLastLoginId);
    if (savedId == null) return false;

    var user = _registeredUsers.where((u) => u.id == savedId).firstOrNull;
    if (user == null) {
      // 소셜 로그인 등 메모리에 없는 세션 복원
      final savedName = prefs.getString(_kLastLoginName) ?? '회원';
      final savedPhone = prefs.getString(_kSavedPhone) ?? '';
      user = AppUser(
        id: savedId,
        name: savedName,
        phone: savedPhone,
        isVerified: true,
        role: '일반',
      );
      _registeredUsers.add(user);
    }

    _currentUser = user;
    // Firestore에 이미 번호가 있으면 로컬 세션 보강 (다른 기기에서 등록한 경우)
    if (needsPhoneNumber) {
      try {
        final deps = AppDependencies.instance;
        if (deps.isInitialized && !deps.isOfflineMockMode) {
          final doc = await FirebaseFirestore.instance
              .collection(FirestorePaths.users)
              .doc(user.id)
              .get();
          final remotePhone = doc.data()?['phone'] as String?;
          if (remotePhone != null && !isPhoneMissing(remotePhone)) {
            final updated = user.copyWith(phone: formatPhone(remotePhone));
            final idx = _registeredUsers.indexWhere((u) => u.id == updated.id);
            if (idx >= 0) _registeredUsers[idx] = updated;
            _currentUser = updated;
            await prefs.setString(_kSavedPhone, updated.phone);
          }
        }
      } catch (e) {
        debugPrint('[AuthProvider] hydrate phone skip: $e');
      }
    }
    await FirebaseAuthBridge.ensureSignedIn(_currentUser!);
    notifyListeners();
    return true;
  }

  Future<void> loadLastLoginMethod() async {
    final prefs = await SharedPreferences.getInstance();
    _lastLoginMethod = prefs.getString(_kLastLoginMethod);
    notifyListeners();
  }

  Future<void> _rememberLoginMethod(String method) async {
    _lastLoginMethod = method;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastLoginMethod, method);
  }

  String lastLoginHint() {
    switch (_lastLoginMethod) {
      case 'kakao':
        return '최근에 카카오로 로그인했습니다';
      case 'google':
        return '최근에 구글로 로그인했습니다';
      case 'apple':
        return '최근에 Apple로 로그인했습니다';
      case 'phone':
        return '최근에 전화번호로 로그인했습니다';
      default:
        return '';
    }
  }

  /// 자동로그인 설정 토글
  Future<void> setAutoLogin(bool value) async {
    _autoLogin = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoLogin, value);
    if (!value) {
      // 자동로그인 끄면 저장된 세션 삭제
      await prefs.remove(_kLastLoginId);
      await prefs.remove(_kSavedPhone);
    }
    notifyListeners();
  }

  List<AppUser> get registeredUsers => List.unmodifiable(_registeredUsers);

  // ════════════════════════════════════════════════════════
  //  로그인
  // ════════════════════════════════════════════════════════

  /// 전화번호로 사용자 조회
  AppUser? findUserByPhone(String phone) {
    final normalized = _normalizePhone(phone);
    try {
      return _registeredUsers.firstWhere(
        (u) => _normalizePhone(u.phone) == normalized,
      );
    } catch (_) {
      return null;
    }
  }

  /// 로그인 처리 — saveSession: 자동로그인 저장 여부
  Future<bool> loginAsync(String phone, {bool saveSession = false}) async {
    final user = findUserByPhone(phone);
    if (user == null) return false;

    _currentUser = user;

    // Staging/Firebase — Firestore rules용 Auth 세션 확보
    await FirebaseAuthBridge.ensureSignedIn(user);

    // 자동로그인 저장
    if (saveSession) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAutoLogin, true);
      await prefs.setString(_kLastLoginId, user.id);
      await prefs.setString(_kLastLoginName, user.name);
      await prefs.setString(_kSavedPhone, user.phone);
      _autoLogin = true;
    }
    await _rememberLoginMethod('phone');

    notifyListeners();
    return true;
  }

  /// 카카오 / 구글 / Apple 로그인 (신규면 계정 생성)
  ///
  /// Firestore `users.phone`을 우선 반영한다. 번호가 없으면
  /// [needsPhoneNumber]가 true가 되어 `/phone-required`로 보낸다.
  /// 빈 번호로 원격 phone을 덮어쓰지 않는다.
  Future<AppUser> loginWithSocial(
    SocialProfile profile, {
    bool saveSession = true,
  }) async {
    final memory =
        _registeredUsers.where((u) => u.id == profile.appUserId).firstOrNull;

    String remotePhone = '';
    String? remoteName;
    try {
      final deps = AppDependencies.instance;
      if (deps.isInitialized && !deps.isOfflineMockMode) {
        final doc = await FirebaseFirestore.instance
            .collection(FirestorePaths.users)
            .doc(profile.appUserId)
            .get();
        final data = doc.data();
        if (data != null) {
          remotePhone = formatPhone((data['phone'] as String?) ?? '');
          final n = (data['name'] as String?)?.trim();
          if (n != null && n.isNotEmpty && !isPlaceholderName(n)) {
            remoteName = n;
          }
        }
      }
    } catch (e) {
      debugPrint('[AuthProvider] social login hydrate phone skip: $e');
    }

    // 번호: Firestore > 메모리(이미 인증된 경우) > 빈 값
    final resolvedPhone = !isPhoneMissing(remotePhone)
        ? remotePhone
        : (memory != null && !isPhoneMissing(memory.phone) ? memory.phone : '');

    final resolvedName = () {
      if (profile.name.isNotEmpty && !isPlaceholderName(profile.name)) {
        return profile.name;
      }
      if (remoteName != null) return remoteName;
      if (memory != null &&
          memory.name.isNotEmpty &&
          !isPlaceholderName(memory.name)) {
        return memory.name;
      }
      return profile.name.isNotEmpty ? profile.name : '회원';
    }();

    final user = AppUser(
      id: profile.appUserId,
      name: resolvedName,
      phone: resolvedPhone,
      handicap: memory?.handicap,
      isVerified: !isPhoneMissing(resolvedPhone),
      isAdmin: memory?.isAdmin ?? false,
      role: memory?.role ?? '일반',
      profileImageUrl: profile.photoUrl ?? memory?.profileImageUrl,
      verifyMethod: memory?.verifyMethod,
    );

    final idx = _registeredUsers.indexWhere((u) => u.id == user.id);
    if (idx >= 0) {
      _registeredUsers[idx] = user;
    } else {
      _registeredUsers.add(user);
    }
    // ignore: unawaited_futures
    _persistPlatformUser(user);

    _currentUser = user;
    await FirebaseAuthBridge.ensureSignedIn(user);

    if (saveSession) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAutoLogin, true);
      await prefs.setString(_kLastLoginId, user.id);
      await prefs.setString(_kLastLoginName, user.name);
      await prefs.setString(_kSavedPhone, user.phone);
      _autoLogin = true;
    }

    await _rememberLoginMethod(profile.provider.name);
    notifyListeners();
    unawaited(PushNotificationService.bindUserIds([user.id]));
    return user;
  }

  /// 소셜 로그인 후 휴대폰 번호 등록 (본인인증 완료 시)
  Future<AppUser?> attachPhoneToCurrentUser({
    required String phone,
    required VerifyMethod verifyMethod,
  }) async {
    final current = _currentUser;
    if (current == null) return null;

    final formatted = formatPhone(phone);
    if (_normalizePhone(formatted).length < 10) return null;

    // 다른 계정에 이미 쓰인 번호인지 확인
    final occupied = findUserByPhone(formatted);
    if (occupied != null && occupied.id != current.id) {
      throw StateError('이미 다른 계정에 등록된 전화번호입니다.');
    }

    final updated = current.copyWith(
      phone: formatted,
      isVerified: true,
      verifyMethod: verifyMethod,
    );

    final idx = _registeredUsers.indexWhere((u) => u.id == current.id);
    if (idx >= 0) {
      _registeredUsers[idx] = updated;
    } else {
      _registeredUsers.add(updated);
    }
    _currentUser = updated;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSavedPhone, updated.phone);
    await prefs.setString(_kLastLoginId, updated.id);
    await prefs.setString(_kLastLoginName, updated.name);
    await prefs.setBool(_kAutoLogin, true);
    _autoLogin = true;

    await FirebaseAuthBridge.ensureSignedIn(updated);
    await _persistPlatformUser(updated);
    await _propagatePhoneToClubMembers(updated);

    notifyListeners();
    return updated;
  }

  /// users + 클럽 members 문서에 전화번호 반영
  Future<void> _propagatePhoneToClubMembers(AppUser user) async {
    if (_normalizePhone(user.phone).isEmpty) return;
    try {
      final deps = AppDependencies.instance;
      if (deps.isOfflineMockMode) {
        final store = deps.mockDataStore;
        store?.upsertAppUser(
          MockAppUser(
            id: user.id,
            name: user.name,
            phone: user.phone,
            gender: '남',
            createdAt: user.createdAt,
          ),
        );
        return;
      }

      // clubs/*/members 에서 동일 user id 문서 phone 보강
      final snap = await FirebaseFirestore.instance
          .collectionGroup(FirestorePaths.members)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      var writes = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final id = data['id'] as String? ?? doc.id;
        final userId = data['user_id'] as String? ?? data['userId'] as String?;
        final match = id == user.id ||
            userId == user.id ||
            doc.id == user.id ||
            doc.id.endsWith('_${user.id}');
        if (!match) continue;
        final existing = (data['phone'] as String?)?.trim() ?? '';
        if (existing.replaceAll(RegExp(r'[^0-9]'), '').length >= 10) continue;
        batch.set(doc.reference, {
          'phone': user.phone,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        writes++;
        if (writes >= 40) break; // 안전 상한
      }
      if (writes > 0) await batch.commit();
    } catch (e) {
      debugPrint('[AuthProvider] propagate phone to members failed: $e');
    }
  }

  /// 기존 동기 login (하위 호환)
  bool login(String phone) {
    final user = findUserByPhone(phone);
    if (user != null) {
      _currentUser = user;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// 로그아웃 — 자동로그인 세션 삭제
  Future<void> logoutAsync() async {
    _currentUser = null;
    _autoLogin   = false;
    _clearVerifyState();

    await SocialAuthService.signOutProviders();
    await FirebaseAuthBridge.signOut();
    await PushNotificationService.unbind();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAutoLogin);
    await prefs.remove(_kLastLoginId);
    await prefs.remove(_kLastLoginName);
    await prefs.remove(_kSavedPhone);

    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    _clearVerifyState();
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════
  //  휴대폰 인증번호 (카카오 알림톡 — 문자/PASS 미사용)
  // ════════════════════════════════════════════════════════

  String _generateOtpCode() {
    final n = Random.secure().nextInt(10000);
    return n.toString().padLeft(4, '0');
  }

  Future<void> sendSmsCode(String phone) async {
    _isVerifying = true;
    _pendingPhone = phone;
    _smsCodeSent = false;
    notifyListeners();

    final solapi = SolapiService.instance;
    final canSend = solapi.isConfigured &&
        solapi.hasKakaoChannel &&
        solapi.hasOtpTemplate;

    if (!canSend) {
      if (kDebugMode) {
        _smsCode = '1234';
        debugPrint(
          '[Auth] 알림톡 OTP 설정 없음 — 디버그 코드 1234 '
          '(Key/PFID/SOLAPI_OTP_TEMPLATE_ID 확인)',
        );
        await Future.delayed(const Duration(milliseconds: 400));
        _smsCodeSent = true;
        _isVerifying = false;
        notifyListeners();
        return;
      }
      _isVerifying = false;
      notifyListeners();
      throw StateError(
        '알림톡 인증 설정이 아직 준비되지 않았습니다. 잠시 후 다시 시도해 주세요.',
      );
    }

    final code = _generateOtpCode();
    _smsCode = code;
    final result = await solapi.sendOtpAlimtalk(to: phone, code: code);
    if (!result.success) {
      _isVerifying = false;
      notifyListeners();
      throw StateError(result.errorMessage ?? '인증번호 알림톡 발송에 실패했습니다.');
    }

    _smsCodeSent = true;
    _isVerifying = false;
    notifyListeners();
  }

  bool verifySmsCode(String inputCode) {
    final ok = inputCode.trim() == _smsCode;
    _verifySuccess = ok;
    notifyListeners();
    return ok;
  }

  // ════════════════════════════════════════════════════════
  //  PASS 앱 인증
  // ════════════════════════════════════════════════════════

  Future<bool> requestPassVerify(String name, String phone) async {
    _passRequested = true;
    _isVerifying   = true;
    _pendingPhone  = phone;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 2));
    _verifySuccess = true;
    _isVerifying   = false;
    notifyListeners();
    return true;
  }

  /// 포트원/개발용 본인인증 화면에서 이미 성공한 뒤 상태만 반영
  bool confirmPassVerified({String? phone}) {
    _passRequested = true;
    _pendingPhone = phone ?? _pendingPhone;
    _verifySuccess = true;
    _isVerifying = false;
    notifyListeners();
    return true;
  }

  // ════════════════════════════════════════════════════════
  //  회원가입
  // ════════════════════════════════════════════════════════

  void setSignupData({
    required String name,
    required String phone,
    double? handicap,
    required VerifyMethod verifyMethod,
  }) {
    _signupName         = name;
    _signupPhone        = phone;
    _signupHandicap     = handicap;
    _signupVerifyMethod = verifyMethod;
  }

  AppUser completeSignup() {
    final newUser = AppUser(
      id:           'user_${DateTime.now().millisecondsSinceEpoch}',
      name:         _signupName!,
      phone:        _signupPhone!,
      handicap:     _signupHandicap,
      isVerified:   true,
      isAdmin:      false,
      role:         '일반',
      verifyMethod: _signupVerifyMethod,
    );
    _registeredUsers.add(newUser);
    _currentUser = newUser;
    // ignore: unawaited_futures
    FirebaseAuthBridge.ensureSignedIn(newUser);
    // 어드민 회원 수: 모임 미가입 신규 유저도 카운트
    // ignore: unawaited_futures
    _persistPlatformUser(newUser);
    _clearVerifyState();
    notifyListeners();
    return newUser;
  }

  // ════════════════════════════════════════════════════════
  //  초대 토큰
  // ════════════════════════════════════════════════════════

  InviteToken createInviteToken({
    required String clubId,
    required String clubName,
    InviteMemberType inviteType = InviteMemberType.regular,
    String? guestName,
    String? referrerId,
    String? referrerName,
  }) {
    final token = InviteToken(
      token:       'inv_${DateTime.now().millisecondsSinceEpoch}',
      clubId:      clubId,
      clubName:    clubName,
      inviterName: _currentUser?.name ?? '알 수 없음',
      inviterId:   _currentUser?.id   ?? '',
      inviteType:  inviteType,
      guestName:   guestName,
      referrerId:  referrerId,
      referrerName: referrerName,
    );
    _inviteTokens.add(token);
    notifyListeners();
    return token;
  }

  InviteToken? findToken(String token) {
    try {
      return _inviteTokens.firstWhere((t) => t.token == token);
    } catch (_) {
      return null;
    }
  }

  void markTokenUsed(String token) {
    final idx = _inviteTokens.indexWhere((t) => t.token == token);
    if (idx >= 0) {
      final old = _inviteTokens[idx];
      _inviteTokens[idx] = InviteToken(
        token:       old.token,
        clubId:      old.clubId,
        clubName:    old.clubName,
        inviterName: old.inviterName,
        inviterId:   old.inviterId,
        createdAt:   old.createdAt,
        expiresAt:   old.expiresAt,
        isUsed:      true,
      );
      notifyListeners();
    }
  }

  // ════════════════════════════════════════════════════════
  //  헬퍼
  // ════════════════════════════════════════════════════════

  void _clearVerifyState() {
    _isVerifying        = false;
    _smsCodeSent        = false;
    _passRequested      = false;
    _verifySuccess      = false;
    _pendingPhone       = null;
    _smsCode            = '';
    _signupName         = null;
    _signupPhone        = null;
    _signupHandicap     = null;
    _signupVerifyMethod = null;
  }

  void resetVerify() {
    _smsCodeSent   = false;
    _passRequested = false;
    _verifySuccess = false;
    notifyListeners();
  }

  Future<void> _persistPlatformUser(AppUser user) async {
    try {
      final deps = AppDependencies.instance;
      if (deps.isOfflineMockMode) {
        final store = deps.mockDataStore;
        if (store != null) {
          store.upsertAppUser(
            MockAppUser(
              id: user.id,
              name: user.name,
              phone: user.phone,
              gender: '남',
              createdAt: DateTime.now(),
            ),
          );
        }
        return;
      }
      // 빈 phone으로 기존 번호를 지우지 않음 (소셜 재로그인 시 본사 연락처 유실 방지)
      final data = <String, dynamic>{
        'name': user.name,
        'nickname': user.name,
        'gender': '남',
        'account_status': 'normal',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (!isPhoneMissing(user.phone)) {
        data['phone'] = user.phone;
      }
      await FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .doc(user.id)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[AuthProvider] persist platform user failed: $e');
    }
  }

  String _normalizePhone(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9]'), '');

  static String formatPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 3) return digits;
    if (digits.length <= 7) {
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    }
    if (digits.length <= 11) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }
    return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7, 11)}';
  }
}
