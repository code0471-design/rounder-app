# Club List Dashboard — Code Review Points

모듈화된 Firestore 연동 구조와 **모임 목록 대시보드**를 검수할 때 확인할 체크리스트입니다.

---

## 1. 아키텍처 레이어 분리

| 레이어 | 경로 | 검수 포인트 |
|--------|------|-------------|
| **Core** | `lib/core/` | Firestore 경로(`firestore_paths.dart`), 공통 예외(`data_exception.dart`)가 UI/Provider에 import되지 않는지 |
| **Data** | `lib/data/` | Mapper ↔ Firestore 필드명(snake_case) 매핑이 실제 DB 스키마와 일치하는지 |
| **Repository** | `lib/data/repositories/` | UI가 `Firestore*` 구현체를 직접 참조하지 않고 **추상 Repository**만 사용하는지 |
| **Domain Service** | `lib/domain/services/` | 정산·회비 로직(`finance/`)이 `Widget`/`BuildContext`를 import하지 않는지 |
| **Feature** | `lib/features/clubs/` | Controller는 Repository/Service만 호출, Screen은 Controller만 구독하는지 |
| **DI** | `lib/di/app_dependencies.dart` | 싱글톤 wiring이 한 곳에만 있는지 (main/splash에서 개별 new 금지) |

---

## 2. 앱 시작 시 데이터 부트스트랩

**흐름:** `main()` → `Firebase.initializeApp` → `AppDependencies.instance.init()` → (로그인 후) `bootstrapForUser(userId)`

- [ ] `splash_screen.dart`에서 Firestore 실패 시 **앱 진입은 유지**하는지 (try/catch, mock 폴백)
- [ ] `AppDataBootstrapService.loadForUser`가 clubs → members → finance 순으로 호출되는지
- [ ] 부트스트랩 중 중복 호출(스플래시 + 클럽 목록 진입)이 없는지

---

## 3. Firestore 스키마 가정 (실 DB와 대조)

```
clubs/{clubId}
  ├── members/{memberId}
  ├── dues_settings/{settingId}
  ├── dues_payments/{paymentId}
  └── transactions/{transactionId}

user_memberships/{docId}   // userId → clubId 목록
```

- [ ] 컬렉션/필드명이 Firebase Console 실제 문서와 일치하는지
- [ ] Mapper의 nullable 처리(누락 필드, 타임스탬프)가 크래시 없이 동작하는지
- [ ] Security Rules로 읽기 권한이 테스트 계정에 허용되는지

---

## 4. Club List Dashboard UI

**파일:** `lib/features/clubs/presentation/club_list_dashboard_screen.dart`  
**Controller:** `lib/features/clubs/application/club_list_controller.dart`

- [ ] 로딩 / 빈 목록 / 오류 / 목록 4가지 상태 UI가 모두 있는지
- [ ] 지역·업종 필터 변경 시 `ClubDiscoveryService`(순수 함수)만 사용하는지
- [ ] 검색어 debounce 또는 submit 방식이 UX와 맞는지
- [ ] 카드 탭 시 기존 `ClubProvider.selectClub`와 **동기화** 필요 여부 (현재 스켈레톤: `/club-room`만 push)
- [ ] `ChangeNotifierProvider<ClubListController>`가 `main.dart`에 등록되어 있는지

---

## 5. 정산·회비 Service Layer (UI 비혼입)

**파일:**
- `lib/domain/services/finance/dues_ledger_service.dart`
- `lib/domain/services/finance/balance_ledger_service.dart`

- [ ] 금액 계산이 `int`/`double` 혼용 없이 일관적인지
- [ ] `ClubProvider`의 `unpaidSlotsForDuesSetting` 등과 **로직 중복**이 없는지 (마이그레이션 계획)
- [ ] Service는 Repository snapshot 또는 domain model만 받는지 (Firestore `DocumentSnapshot` 직접 사용 금지)
- [ ] 단위 테스트 추가 가능 구조인지 (`test/domain/` 참고)

---

## 6. 기존 ClubProvider와의 공존

현재 런타임은 **ClubProvider(mock + SharedPreferences)** 와 **Firestore Repository** 가 병행합니다.

- [ ] 목록 화면 데이터 소스가 Firestore Controller인지, Provider mock인지 **명확한지**
- [ ] 클럽 상세/회비 화면 진입 시 `ClubProvider`와 Firestore 데이터 불일치 가능성 문서화
- [ ] 점진적 마이그레이션 순서(목록 → 상세 → 회비)가 합의되었는지

---

## 7. 에러 처리·관측

- [ ] `DataException` 메시지가 사용자에게 노출될 때 민감 정보(경로, uid)가 포함되지 않는지
- [ ] 네트워크 오류 vs 권한 오류 vs 파싱 오류 구분이 필요한지
- [ ] (선택) Crashlytics / 로그 훅 연결 지점

---

## 8. 테스트·빌드

```bash
flutter analyze
flutter test test/domain/club_discovery_service_test.dart
```

- [ ] analyze 에러 0
- [ ] `ClubDiscoveryService` 필터 단위 테스트 통과
- [ ] (추후) `DuesLedgerService`, `BalanceLedgerService` 테스트

---

## 9. 검수 시 우선순위 (PM 관점)

1. **Firestore 실데이터 1건**으로 목록이 뜨는지 (또는 빈 목록 + 오류 UI)
2. **회비/잔액 숫자**가 Service Layer와 화면 표시가 분리되어 있는지
3. **오프라인·Firestore 실패** 시 앱이 죽지 않는지
4. 레이어 간 import 방향 위반 여부 (Domain → Data 역참조 등)

---

## 10. 알려진 스켈레톤 한계 (후속 작업)

- 클럽 카드 탭 → `ClubProvider` 동기화 미구현
- `ClubListController`와 `ClubProvider` 이중 상태
- Finance Service를 Finance Screen에 아직 미연결
- iOS/Web `firebase_options.dart` placeholder
