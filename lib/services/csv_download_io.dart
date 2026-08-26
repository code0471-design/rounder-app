import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadCsvFile({
  required String filename,
  required String csv,
}) async {
  // 카톡은 text/csv 첨부를 자주 무시한다. Excel이 여는 .xls + 엑셀 MIME으로 보낸다.
  final excelName = filename.toLowerCase().endsWith('.csv')
      ? '${filename.substring(0, filename.length - 4)}.xls'
      : filename;

  Directory dir;
  try {
    dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
  } catch (_) {
    dir = await getTemporaryDirectory();
  }
  final file = File('${dir.path}/$excelName');
  await file.writeAsString(csv, flush: true);

  // title/subject(텍스트)를 같이 넣으면 카톡이 파일 없이 끝나기도 한다.
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
