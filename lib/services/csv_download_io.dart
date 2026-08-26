import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _downloadsChannel = MethodChannel('rounder/csv_download');

Future<void> downloadCsvFile({
  required String filename,
  required String csv,
}) async {
  final excelName = filename.toLowerCase().endsWith('.csv')
      ? '${filename.substring(0, filename.length - 4)}.xls'
      : filename;
  final bytes = utf8.encode(csv);

  if (Platform.isAndroid) {
    try {
      await _downloadsChannel.invokeMethod<String>(
        'saveToDownloads',
        {'filename': excelName, 'bytes': bytes},
      );
    } catch (_) {}
  }

  final dir = await getTemporaryDirectory();
  // FileProvider는 한글 파일명에서 깨질 수 있어 공유용은 ASCII 이름을 쓴다.
  final file = File('${dir.path}/member_roster.xls');
  await file.writeAsBytes(bytes, flush: true);

  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile(
          file.path,
          mimeType: 'application/vnd.ms-excel',
          name: excelName,
        ),
      ],
    ),
  );
}
