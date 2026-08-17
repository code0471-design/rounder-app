# Android release 빌드 기준선 (Play 업로드용)

Play Console은 debug 서명 AAB를 거부한다. 아래 조건이 모두 맞아야 업로드 가능한
`app-release.aab`가 나온다. 하나라도 바꾸면 빌드가 깨진 이력이 있으므로 변경 전 확인.

## Codemagic

- 워크플로: **Android release AAB** (`android-release` in `codemagic.yaml`)
  - Default Workflow(UI 에디터)는 debug AAB를 만들므로 사용하지 않는다.
- 앱 설정은 **codemagic.yaml** 모드여야 한다 (Workflow Editor 아님).
- `environment.android_signing`의 이름은 Codemagic 키스토어의
  **reference name**(`rounder_upload`)과 정확히 일치해야 한다.

## 키스토어

- PKCS12(`.jks`, `-storetype PKCS12`)는 **keystore password와 key password가 동일**해야 한다.
  다르면 `signReleaseBundle` 단계에서
  `Get Key failed: Given final block not properly padded`로 실패한다.
- alias: `rounder_upload`
- 키스토어 파일과 비밀번호는 저장소에 커밋하지 않는다 (`.gitignore`에 `*.jks`, `key.properties`).

## Gradle

- `android/app/build.gradle.kts`
  - `signingConfigs.release`는 CI에서 `CM_KEYSTORE_PATH` / `CM_KEYSTORE_PASSWORD` /
    `CM_KEY_ALIAS` / `CM_KEY_PASSWORD`를 읽고, 로컬에서는 `key.properties`를 읽는다.
  - `buildTypes.release`는 항상 `signingConfigs.release`를 쓴다 (debug 서명으로 되돌리지 말 것).
  - `compileSdk = 36`
- `android/build.gradle.kts`
  - `subprojects { project.evaluationDependsOn(":app") }`가 있어 **`afterEvaluate`를 쓰면
    "Cannot run Project.afterEvaluate(Action) when the project is already evaluated"로 실패**한다.
    플러그인 설정 변경은 `pluginManager.withPlugin(...)` 안에서 한다.
  - Groovy `apply(from = ...)` 스크립트는 Kotlin DSL 루트에서 컴파일 에러를 냈으므로 쓰지 않는다.

## 의존성

- `pubspec.yaml`의 `dependency_overrides: app_links: 6.3.3`
  - `portone_flutter`가 끌어오는 `app_links` 6.4.x는 AAR 메타데이터로 compileSdk 36을 요구해
  플러그인 모듈 빌드를 깨뜨렸다. 이 override를 제거하려면 `portone_flutter` 업그레이드가 먼저다.

## 배포

- Play는 **내부 테스트** 트랙만 사용 중. 프로덕션 공개는 별도 결정 후.
- 버전은 `pubspec.yaml`의 `version:` (현재 `1.0.0+10`). 업로드마다 빌드번호를 올린다.

## 소셜 로그인 (Android)

패키지명은 `com.golfrounder.golf`. 키·해시를 지우거나 다른 카카오 앱에만 등록하면
Play 설치본 로그인이 다시 깨진다. **추가만 하고 기존 값은 삭제하지 않는다.**

### 카카오

앱이 실제로 쓰는 네이티브 앱 키는 플랫폼마다 다르다.

| 플랫폼 | 코드 기본값 (`SocialAuthConfig`) | Kakao Developers 카드 |
| --- | --- | --- |
| Android | `a4b6744dd621da26f0cf3244e9ea8fb5` | **Default Native AppKey** |
| iOS | `3f68f1701188818915ef76bcc764b687` | **ROUNDER-Android** (이름과 달리 iOS 키) |

Android 로그인은 **Default Native AppKey** 카드의 플랫폼 설정과만 대조된다.
키 해시는 그 카드에 있어야 하고, 안전하게 두 카드에 동일하게 넣는다.

등록할 키 해시 (끝 `=` 포함, SHA-1 콜론 형식이 아님):

```
1nklI6FD4lBPValaJJD+8F6l3AE=
Bpfr1O3+zJITsveWaEuTtQi+Avc=
Ev3W4BqTAqrPw31BhNYIciJ6T4w=
```

| 키 해시 | 출처 |
| --- | --- |
| `1nklI6FD4lBPValaJJD+8F6l3AE=` | Play **앱 서명 키** SHA-1 |
| `Bpfr1O3+zJITsveWaEuTtQi+Avc=` | Play **업로드 키** SHA-1 |
| `Ev3W4BqTAqrPw31BhNYIciJ6T4w=` | 기기에서 `KakaoSdk.origin`이 보낸 값. Play 설치본이 실제로 통과한 해시 |

세 번째 값이 필요한 이유: 카카오 Android SDK는 현재 서명 키가 아니라
`signingCertificateHistory`의 **첫 인증서**로 키 해시를 만든다. Play 앱 서명 키
SHA-1만 등록하면 `Android keyHash validation failed`가 난다.

SHA-1 → 키 해시 변환:

```
dart run scripts/kakao_key_hash.dart D6:79:25:23:A1:43:E2:50:4F:55:A9:5A:24:90:FE:F0:5E:A5:DC:01
```

카카오 콘솔에 해시를 추가하면 **앱 재빌드 없이** 바로 적용된다.
같은 앱에서 카카오 로그인 활성화는 ON, 닉네임 동의항목은 사용. 이메일은 비즈 앱
심사 전이면 필수로 두지 않는다.

### 구글

Firebase 프로젝트 `rounder-staging`의 Android 앱에 SHA-1을 등록한 뒤
`google-services.json`을 다시 받아 `android/app/google-services.json`에 넣고
**재빌드**해야 한다. json에 `oauth_client` + `certificate_hash`가 없으면
구글 로그인이 취소된 것처럼 보인다.

Play Console 앱 무결성 → 앱 서명에서 확인한 SHA-1:

```
D6:79:25:23:A1:43:E2:50:4F:55:A9:5A:24:90:FE:F0:5E:A5:DC:01
06:97:EB:D4:ED:FE:CC:92:13:B2:F7:96:68:4B:93:B5:08:BE:02:F7
12:FD:D6:E0:1A:93:02:AA:CF:C3:7D:41:84:D6:08:72:22:7A:4F:8C
```

세 번째는 카카오 기기 해시와 같은 인증서다. Firebase에도 넣어 둔다.

서버 클라이언트 ID (idToken용)는 `SocialAuthConfig.googleServerClientId`:
`909216389322-3jp0348rm4d575jpl3rv0ngaj8proea6.apps.googleusercontent.com`

### 로그인 깨졌을 때

1. 카카오: 스낵바는 사용자 문구만 보인다. 로그에 `keyHash=` / `appKey…`가 남는다.
   로그의 `keyHash`를 Default Native AppKey 카드에 추가하면 된다.
2. 구글: Firebase SHA-1 → json 재다운로드 → 앱 재빌드 순서가 빠지면 실패한다.
