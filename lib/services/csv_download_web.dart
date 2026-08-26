// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'xlsx_from_rows.dart';

Future<void> downloadCsvFile({
  required String filename,
  required List<int> bytes,
}) async {
  final excelName = filename.toLowerCase().endsWith('.xlsx')
      ? filename
      : filename.replaceAll(RegExp(r'\.(csv|xls)$', caseSensitive: false), '') +
          '.xlsx';
  final blob = html.Blob(
    [Uint8List.fromList(bytes)],
    excelXlsxMime,
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', excelName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
