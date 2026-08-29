# App Store Review — demo phone path (Guideline 2.1 / 5.6)

## Must upload a new build
Reply alone is not enough if the binary does not match Review Notes.
Expected version: check `pubspec.yaml` (e.g. `1.0.0+57`).

## Important
This app has **no username/password login**.
Demo access is: **Sign in with Apple** → name/phone screen → demo phone + code.

## Review Notes (paste into App Store Connect)

```text
DEMO ACCESS (no username/password — social login only)

1) On the login screen, tap “Sign in with Apple” and complete Apple ID sign-in.
2) On the next screen (name + phone), enter:
   - Name: App Review
   - Phone: 010-0000-0000   (eleven digits: 010 0000 0000)
3) Tap the button to send verification code (인증번호 받기).
4) Enter verification code: 0000
5) You will enter the app and can create/join a club; review Home, Schedule, Members, Finance.

Notes:
- Do NOT look for a username/password field.
- Kakao Alimtalk is not sent for 010-0000-0000; code 0000 works offline for App Review only.
- Phone may also be typed as 01000000000.
```

## Resolution Center reply (Guideline 2.1)

```text
Hello App Review Team,

Thank you for the Guideline 2.1 feedback.

ROUNDER does not use username/password login. Access is via Sign in with Apple (or Kakao/Google), then a name/phone registration step for club contact.

Please use this disclosed App Review demo path (also in Review Notes) on the new build:

1. Tap “Sign in with Apple” on the login screen (there is no username/password field).
2. On the name/phone screen enter:
   - Name: App Review
   - Phone: 010-0000-0000  (please use all zeros: 010-0000-0000)
3. Tap send verification code, then enter: 0000

This demo phone does not require Kakao delivery; code 0000 is accepted for App Review so you can access full features (club create/join, schedule, members, finance).

We apologize for the earlier confusion if the phone was entered as 010-0000-000 (one digit short). The correct number is 010-0000-0000.

Please re-review the new build.

Best regards,
```
