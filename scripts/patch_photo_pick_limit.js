// schedule_screen.dart 는 Cursor StrReplace / PowerShell 치환 금지 파일이다.
// UTF-8 로 읽고 EOL 을 감지해 패치한다.
//
// 목적: 사진 20장 제한을 이 호출부에도 적용한다.
// pickRoundPhotoDataUrls 가 (목록, 초과여부) 튜플을 돌려주도록 바뀌었으므로
// 구조분해로 받고, 초과면 원클럽과 같은 얼럿을 띄운다.
const fs = require('fs');
const path = require('path');

const file = path.join(
  __dirname,
  '..',
  'lib',
  'screens',
  'schedule',
  'schedule_screen.dart',
);

let src = fs.readFileSync(file, 'utf8');
const eol = src.includes('\r\n') ? '\r\n' : '\n';
const nl = (s) => s.split('\n').join(eol);

function replaceExactly(search, replace, expected) {
  const s = nl(search);
  const parts = src.split(s);
  const found = parts.length - 1;
  if (found !== expected) {
    throw new Error(
      `expected ${expected} match(es) but found ${found} for:\n${search}`,
    );
  }
  src = parts.join(nl(replace));
}

replaceExactly(
  `    List<String> dataUrls;
    try {
      dataUrls = await pickRoundPhotoDataUrls();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 불러오지 못했습니다')),
      );
      return;
    }
    if (dataUrls.isEmpty || !context.mounted) return;`,
  `    List<String> dataUrls;
    var exceeded = false;
    try {
      (dataUrls, exceeded) = await pickRoundPhotoDataUrls();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 불러오지 못했습니다')),
      );
      return;
    }
    if (dataUrls.isEmpty || !context.mounted) return;
    // 20장 초과 안내. 예전엔 제한도 안내도 없어 계속 선택됐다.
    if (exceeded) {
      await showRoundPhotoLimitAlert(context);
      if (!context.mounted) return;
    }`,
  1,
);

fs.writeFileSync(file, src, 'utf8');
console.log('patched schedule_screen.dart (photo pick limit)');
