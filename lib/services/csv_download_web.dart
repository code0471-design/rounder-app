// ignore: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;

Future<void> downloadCsvFile({
  required String filename,
  required String csv,
}) async {
  final excelName = filename.toLowerCase().endsWith('.csv')
      ? '${filename.substring(0, filename.length - 4)}.xls'
      : filename;
  final bytes = utf8.encode(csv);
  final blob = html.Blob([bytes], 'application/vnd.ms-excel');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', excelName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
