# ROUNDER — 단일 프로젝트 루트

**이 폴더(`flutter_app`)가 유일한 Flutter 소스 루트입니다.**

## 경로 (Canonical)

```
C:\Users\AKH\OneDrive\바탕 화면\라운더\webapp_backup_iut9q6c9 (3)\flutter_app
```

- `pubspec.yaml` · `lib/` · `assets/` · `scripts/` — 모두 이 폴더 기준
- Cursor / VS Code는 **이 폴더를 직접 열거나** 상위 `ROUNDER.code-workspace` 사용

## 무시할 폴더 (레거시·중복)

| 경로 | 상태 |
|------|------|
| `webapp_backup_iut9q6c9 (3)/` (상위 래퍼) | Cursor 백업용 껍데기 — **코드 수정 X** |
| `바탕 화면\ROUNDER\ROUNDER_APP CODE\flutter_app` | 구버전 git 복사본 — **사용 X** |
| `바탕 화면\ROUNDER\flutter_app` | 동기화 대기 (비어 있음) |

## 미리보기

```powershell
# flutter_app 폴더에서
powershell -ExecutionPolicy Bypass -File scripts/hot_preview.ps1
```

또는 Cursor **`Ctrl+Shift+B`**

→ http://127.0.0.1:8888/

## Hot Reload

- 저장 시 자동 핫 리로드 (`.vscode/settings.json`)
- 반영 안 되면 **`Ctrl+Shift+R`** 또는 미리보기 서버 재시작
