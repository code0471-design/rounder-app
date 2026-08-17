// Builds Android launcher icon sources from assets/icons/app_icon.png.
//
// The source artwork has a white rounded square baked in, which shows up as a
// square inside the launcher mask on Android adaptive icons. This isolates the
// emblem (green ring + ball) onto a transparent canvas sized for the adaptive
// icon safe zone, plus an opaque square variant for legacy launchers.
//
// Run: dart run scripts/make_android_icons.dart

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _source = 'assets/icons/app_icon.png';
const _foregroundOut = 'assets/icons/app_icon_foreground.png';
const _legacyOut = 'assets/icons/app_icon_android.png';

const _canvas = 1024;

/// Adaptive icon foreground. flutter_launcher_icons wraps this drawable in a
/// 16% inset, so the emblem ends up at roughly 78% of the launcher's visible
/// circle — large enough to read, small enough to survive any mask shape.
const _foregroundScale = 0.76;

/// Legacy square icon can fill more of the canvas.
const _legacyScale = 0.74;

bool _isRing(img.Pixel p) {
  final r = p.r.toDouble();
  final g = p.g.toDouble();
  final b = p.b.toDouble();
  // Brand ring is dark green (#1B4D3E): green dominant, all channels dark.
  return r < 110 && g < 130 && b < 120 && g >= r && g > 30;
}

void main() {
  final source = img.decodePng(File(_source).readAsBytesSync());
  if (source == null) {
    stderr.writeln('Could not decode $_source');
    exit(1);
  }

  var minX = source.width, minY = source.height, maxX = -1, maxY = -1;
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      if (!_isRing(source.getPixel(x, y))) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0) {
    stderr.writeln('Could not locate the green ring in $_source');
    exit(1);
  }

  final centerX = (minX + maxX) / 2;
  final centerY = (minY + maxY) / 2;
  // Pad slightly so the ring's antialiased edge is not clipped.
  final radius = (math.max(maxX - minX, maxY - minY) / 2) + 3;

  final size = (radius * 2).round();
  final emblem = img.Image(width: size, height: size, numChannels: 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = x - size / 2;
      final dy = y - size / 2;
      if (math.sqrt(dx * dx + dy * dy) > radius) continue;
      final sx = (centerX + dx).round();
      final sy = (centerY + dy).round();
      if (sx < 0 || sy < 0 || sx >= source.width || sy >= source.height) {
        continue;
      }
      final p = source.getPixel(sx, sy);
      emblem.setPixelRgba(x, y, p.r, p.g, p.b, 255);
    }
  }

  _write(emblem, _foregroundOut, _foregroundScale, background: null);
  _write(emblem, _legacyOut, _legacyScale,
      background: img.ColorRgba8(255, 255, 255, 255));

  stdout.writeln('ring bounds: ($minX,$minY)-($maxX,$maxY)');
  stdout.writeln('wrote $_foregroundOut and $_legacyOut');
}

void _write(img.Image emblem, String path, double scale, {img.Color? background}) {
  final canvas = img.Image(width: _canvas, height: _canvas, numChannels: 4);
  if (background != null) {
    img.fill(canvas, color: background);
  }
  final target = (_canvas * scale).round();
  final scaled = img.copyResize(
    emblem,
    width: target,
    height: target,
    interpolation: img.Interpolation.cubic,
  );
  final offset = ((_canvas - target) / 2).round();
  img.compositeImage(canvas, scaled, dstX: offset, dstY: offset);
  File(path).writeAsBytesSync(img.encodePng(canvas));
}
