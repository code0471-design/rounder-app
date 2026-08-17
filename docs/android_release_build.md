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
- 버전은 `pubspec.yaml`의 `version:` (현재 `1.0.0+5`). 업로드마다 빌드번호를 올린다.
