# App Store Review — Guideline 5.6 + phone demo path

## Must resubmit a new build
Reply alone is **not enough**. The binary under review must include the
disclosed App Store Review phone OTP path. Upload a new build, then reply.

Expected version: check `pubspec.yaml` (e.g. `1.0.0+56`).

## Disclosed demo credentials (also paste into App Store Connect Review Notes)

- Name: `App Review`
- Phone: `010-0000-0000`
- Verification code: `0000`
  (Tap “Get code” / 인증번호 받기 first, then enter `0000`. No Kakao/SMS is sent for this number.)

## Review steps
1. Sign in with Apple (preferred).
2. On the name/phone screen, enter name `App Review` and phone `010-0000-0000`.
3. Tap send code, enter `0000`, complete.
4. Create or join a club; review Home, Schedule, Members, Finance.

## Resolution Center reply (English)

```text
Hello App Review Team,

Thank you for the Guideline 5.6 feedback.

We do not intentionally hide any features. There is no private/hidden mode and no undisclosed functionality.

After Sign in with Apple, all users (including reviewers) register a name and phone number for club contact and Kakao Alimtalk. This is a normal onboarding step, not a hidden feature.

We have uploaded a new build that includes a **disclosed App Review demo path** (also in Review Notes):

1. Sign in with Apple
2. Name: App Review
3. Phone: 010-0000-0000
4. Tap send verification code, then enter: 0000

You can then access the full app (club create/join, schedule, members, finance).

Please re-review this new build. We fully comply with the App Store Review Guidelines and Developer Code of Conduct.

Best regards,
```

## Korean short note for Royce
회신만 보내지 말고, 이 코드가 들어있는 **새 IPA를 TestFlight/심사에 올린 뒤** 위 영문을 회신하세요.
Review Notes에도 Phone `010-0000-0000` / Code `0000`를 넣으세요.
