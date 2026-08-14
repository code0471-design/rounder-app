# App Review Reply — Guideline 5.6 (Social login rebuild)

## What changed
We removed development-only test account shortcuts and non-functional social buttons.
The App Store build now uses real OAuth only:

1. Kakao Login (Kakao SDK)
2. Google Sign-In
3. Sign in with Apple (required on iOS)

There is no phone/SMS login and no hidden demo bypass in the production UI.

## How to review (recommended)
Please use **Sign in with Apple** on the login screen.
A new reviewer account is created automatically on first sign-in.
You can then create/join a club and review home, schedule, members, and finance.

Kakao may require a Korean Kakao account and may not be available on all review devices.
Google requires Google Sign-In / Firebase OAuth client configuration for this bundle ID.

## Demo notes for App Store Connect fields
- Sign-in required: Yes
- Username / Password: N/A (use Sign in with Apple)
- Notes: paste the “How to review” section above

## Developer checklist before resubmit
1. Apple Developer → App ID `com.golfrounder.golfRounder` → enable **Sign In with Apple**
2. Kakao Developers → native app key → set `KAKAO_NATIVE_APP_KEY` (xcconfig + dart-define)
3. Firebase / Google Cloud → iOS OAuth client for bundle ID → `GOOGLE_IOS_CLIENT_ID` (+ server client ID)
4. Register iOS app in Firebase (current ios firebase_options is still placeholder)
5. Codemagic build with dart-defines, upload build, reply in App Review, resubmit
