#!/usr/bin/env node
/**
 * 빌드 전에 Firebase 네이티브 설정을 환경(staging/prod)에 맞게 교체한다.
 *
 * 모바일에서는 google-services.json / GoogleService-Info.plist 가 Dart 쪽
 * DefaultFirebaseOptions 보다 먼저 기본 Firebase 앱을 초기화한다. 즉
 * `--dart-define=APP_ENV=prod` 만 넘기고 이 스크립트를 돌리지 않으면
 * 운영 빌드가 스테이징 프로젝트에 쓴다.
 *
 *   node tool/select_firebase_env.js --env staging
 *   node tool/select_firebase_env.js --env prod
 *   node tool/select_firebase_env.js --verify
 */

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const CONFIG_DIR = path.join(ROOT, 'firebase_config');
const ANDROID_DEST = path.join(ROOT, 'android', 'app', 'google-services.json');
const IOS_DEST = path.join(ROOT, 'ios', 'Runner', 'GoogleService-Info.plist');
const IOS_INFO_PLIST = path.join(ROOT, 'ios', 'Runner', 'Info.plist');

const ENVS = ['staging', 'prod'];

function fail(msg) {
  console.error('[select_firebase_env] ERROR: ' + msg);
  process.exit(1);
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function loadManifest(env) {
  const file = path.join(CONFIG_DIR, env, 'env.json');
  if (!fs.existsSync(file)) fail(file + ' 가 없습니다.');
  return readJson(file);
}

function androidProjectId(file) {
  if (!fs.existsSync(file)) return null;
  const j = readJson(file);
  return (j.project_info && j.project_info.project_id) || null;
}

/** plist 에서 <key>NAME</key><string>VALUE</string> 추출 */
function plistString(text, key) {
  const re = new RegExp(
    '<key>' + key + '</key>\\s*<string>([^<]*)</string>'
  );
  const m = text.match(re);
  return m ? m[1] : null;
}

function iosProjectId(file) {
  if (!fs.existsSync(file)) return null;
  return plistString(fs.readFileSync(file, 'utf8'), 'PROJECT_ID');
}

/** Info.plist 의 Google 로그인 client ID / URL scheme 을 환경에 맞춘다. */
function patchInfoPlist(manifest) {
  const iosClient = manifest.googleIosClientId;
  const serverClient = manifest.googleServerClientId;
  const reversed =
    'com.googleusercontent.apps.' +
    iosClient.replace('.apps.googleusercontent.com', '');

  const before = fs.readFileSync(IOS_INFO_PLIST, 'utf8');
  let text = before;

  text = text.replace(
    /(<key>GIDClientID<\/key>\s*<string>)[^<]*(<\/string>)/,
    (_m, a, b) => a + iosClient + b
  );
  text = text.replace(
    /(<key>GIDServerClientID<\/key>\s*<string>)[^<]*(<\/string>)/,
    (_m, a, b) => a + serverClient + b
  );
  text = text.replace(
    /<string>com\.googleusercontent\.apps\.[^<]*<\/string>/g,
    '<string>' + reversed + '</string>'
  );

  if (text !== before) {
    fs.writeFileSync(IOS_INFO_PLIST, text, 'utf8');
    console.log('  Info.plist   Google client ID -> ' + iosClient);
  } else {
    console.log('  Info.plist   변경 없음');
  }
}

function apply(env) {
  const manifest = loadManifest(env);
  const expected = manifest.projectId;

  const srcAndroid = path.join(CONFIG_DIR, env, 'google-services.json');
  const srcIos = path.join(CONFIG_DIR, env, 'GoogleService-Info.plist');
  for (const src of [srcAndroid, srcIos]) {
    if (!fs.existsSync(src)) {
      fail(src + ' 가 없습니다. Firebase Console 에서 받아 넣으세요.');
    }
  }

  if (androidProjectId(srcAndroid) !== expected) {
    fail(srcAndroid + ' 의 project_id 가 ' + expected + ' 가 아닙니다.');
  }
  if (iosProjectId(srcIos) !== expected) {
    fail(srcIos + ' 의 PROJECT_ID 가 ' + expected + ' 가 아닙니다.');
  }

  if (env === 'prod') {
    const missing = ['googleIosClientId', 'googleServerClientId'].filter(
      (k) => !manifest[k]
    );
    if (missing.length) {
      fail(
        '운영 빌드에 필요한 값이 비어 있습니다: ' +
          missing.join(', ') +
          '\n  운영 Firebase Console > Authentication > Sign-in method 에서' +
          '\n  Google 공급자를 켜고 firebase_config/prod/env.json 을 채운 뒤' +
          '\n  GoogleService-Info.plist / google-services.json 도 다시 받아 넣으세요.' +
          '\n  (지금 그대로 빌드하면 구글 로그인이 스테이징 프로젝트를 향합니다)'
      );
    }
  }

  fs.copyFileSync(srcAndroid, ANDROID_DEST);
  fs.copyFileSync(srcIos, IOS_DEST);
  console.log(
    '[select_firebase_env] ' + env.toUpperCase() + ' (' + expected + ') 적용'
  );
  console.log('  android/app/google-services.json');
  console.log('  ios/Runner/GoogleService-Info.plist');
  patchInfoPlist(manifest);
}

function verify() {
  const a = androidProjectId(ANDROID_DEST);
  const i = iosProjectId(IOS_DEST);
  console.log('[select_firebase_env] 현재 적용 상태');
  console.log('  android/app/google-services.json   : ' + a);
  console.log('  ios/Runner/GoogleService-Info.plist: ' + i);
  if (a !== i) fail('Android 와 iOS 가 서로 다른 프로젝트를 가리킵니다.');
  return a;
}

function main() {
  const argv = process.argv.slice(2);
  const envIdx = argv.indexOf('--env');
  const env = envIdx >= 0 ? argv[envIdx + 1] : null;

  if (argv.includes('--verify') || !env) {
    verify();
    return;
  }
  if (!ENVS.includes(env)) {
    fail('--env 는 staging 또는 prod 여야 합니다 (받은 값: ' + env + ')');
  }
  apply(env);
  verify();
}

main();
