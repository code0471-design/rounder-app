// Converts a SHA-1 certificate fingerprint into the base64 key hash that
// Kakao Developers expects for the Android platform.
//
// Play Console shows SHA-1 as colon-separated hex; paste it as the argument.
//
// Run: dart run scripts/kakao_key_hash.dart AB:CD:12:...

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run scripts/kakao_key_hash.dart <SHA-1 hex>');
    exit(64);
  }

  final hex = args.join().replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  if (hex.length != 40) {
    stderr.writeln('Expected 40 hex characters (SHA-1), got ${hex.length}.');
    exit(65);
  }

  final bytes = <int>[
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ];

  stdout.writeln(base64.encode(bytes));
}
