import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'xlsx_from_rows.dart';

const _downloadsChannel = MethodChannel('rounder/csv_download');

Future<void> downloadCsvFile({
  required String filename,
  required List<int> bytes,
}) async {
  final excelName = _asXlsxName(filename);

  if (Platform.isAndroid) {
    try {
      await _downloadsChannel.invokeMethod<String>(
        'saveToDownloads',
        {
          'filename': excelName,
          'bytes': Uint8List.fromList(bytes),
        },
      );
    } catch (_) {}
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/member_roster.xlsx');
  await file.writeAsBytes(bytes, flush: true);

  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile(
          file.path,
          mimeType: excelXlsxMime,
          name: excelName,
        ),
      ],
    ),
  );
}

String _asXlsxName(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.xlsx')) return filename;
  if (lower.endsWith('.xls')) {
    return '${filename.substring(0, filename.length - 4)}.xlsx';
  }
  if (lower.endsWith('.csv')) {
    return '${filename.substring(0, filename.length - 4)}.xlsx';
  }
  return '$filename.xlsx';
}
