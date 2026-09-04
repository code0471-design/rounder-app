/**
 * 헤더 로고(공 + ROUNDER)에서 공만 살짝 줄인다. 글자 크기·위치는 그대로.
 *
 * 원본 PNG 한 장에 공과 글자가 같이 있어서, 공 영역만 잘라 축소한 뒤
 * 원래 공이 있던 자리(가로 구간 중앙 · 세로 중앙)에 다시 붙인다.
 *
 * Usage:
 *   node scripts/shrink_header_logo_ball.js            # 측정만
 *   node scripts/shrink_header_logo_ball.js --write    # 실제 저장
 *   node scripts/shrink_header_logo_ball.js --scale 0.8 --write
 */
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const ASSETS = path.join(__dirname, '..', 'assets', 'images');

const args = process.argv.slice(2);
const scaleArg = args.indexOf('--scale');
const BALL_SCALE = scaleArg >= 0 ? parseFloat(args[scaleArg + 1]) : 0.86;
const WRITE = args.includes('--write');

/** 알파가 있는 픽셀의 바운딩 박스와, 가로 방향 잉크 구간들. */
async function inkMap(file) {
  const img = sharp(file);
  const meta = await img.metadata();
  const { width, height } = meta;
  const raw = await img.ensureAlpha().raw().toBuffer();

  const colInk = new Array(width).fill(false);
  for (let x = 0; x < width; x++) {
    for (let y = 0; y < height; y++) {
      if (raw[(y * width + x) * 4 + 3] > 24) {
        colInk[x] = true;
        break;
      }
    }
  }

  const runs = [];
  let start = -1;
  for (let x = 0; x < width; x++) {
    if (colInk[x] && start < 0) start = x;
    if (!colInk[x] && start >= 0) {
      runs.push([start, x - 1]);
      start = -1;
    }
  }
  if (start >= 0) runs.push([start, width - 1]);

  return { width, height, raw, runs };
}

/** 지정한 가로 구간 안에서 잉크가 있는 세로 범위. */
function rowRange(raw, width, height, x0, x1) {
  let top = -1;
  let bottom = -1;
  for (let y = 0; y < height; y++) {
    let ink = false;
    for (let x = x0; x <= x1; x++) {
      if (raw[(y * width + x) * 4 + 3] > 24) {
        ink = true;
        break;
      }
    }
    if (ink) {
      if (top < 0) top = y;
      bottom = y;
    }
  }
  return { top, bottom };
}

async function shrinkBall(name) {
  const file = path.join(ASSETS, name);
  if (!fs.existsSync(file)) {
    console.log(`skip (파일 없음): ${name}`);
    return;
  }

  const { width, height, raw, runs } = await inkMap(file);
  if (runs.length < 2) {
    console.log(
      `skip (투명 배경이 아니라 공/글자 분리 불가): ${name} runs=${runs.length}`,
    );
    return;
  }

  // 첫 구간 = 공, 두 번째 구간부터 = 글자
  const [ballX0, ballX1] = runs[0];
  const textX0 = runs[1][0];
  const { top: ballY0, bottom: ballY1 } = rowRange(
    raw,
    width,
    height,
    ballX0,
    ballX1,
  );

  const ballW = ballX1 - ballX0 + 1;
  const ballH = ballY1 - ballY0 + 1;
  const newW = Math.max(1, Math.round(ballW * BALL_SCALE));
  const newH = Math.max(1, Math.round(ballH * BALL_SCALE));

  console.log(
    `${name}: ${width}x${height} | 공 x${ballX0}-${ballX1} y${ballY0}-${ballY1} ` +
      `(${ballW}x${ballH}) -> ${newW}x${newH} | 글자 x${textX0}~`,
  );

  if (!WRITE) return;

  const smallBall = await sharp(file)
    .extract({ left: ballX0, top: ballY0, width: ballW, height: ballH })
    .resize({ width: newW, height: newH, fit: 'fill' })
    .png()
    .toBuffer();

  const textPart = await sharp(file)
    .extract({ left: textX0, top: 0, width: width - textX0, height })
    .png()
    .toBuffer();

  const out = await sharp({
    create: {
      width,
      height,
      channels: 4,
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    },
  })
    .composite([
      {
        input: smallBall,
        left: ballX0 + Math.round((ballW - newW) / 2),
        top: Math.round((height - newH) / 2),
      },
      { input: textPart, left: textX0, top: 0 },
    ])
    .png()
    .toBuffer();

  fs.writeFileSync(file, out);
  console.log(`  저장 완료: ${name}`);
}

(async () => {
  await shrinkBall('rounder_logo_transparent.png');
  if (!WRITE) console.log('\n(측정만 했습니다. 저장하려면 --write)');
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
