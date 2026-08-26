import 'package:archive/archive.dart';

/// Office 모바일도 여는 실제 .xlsx (CSV를 .xls로 바꿔 저장하면 거부됨).
const excelXlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

List<int> xlsxFromRows(List<List<String>> rows) {
  final archive = Archive();
  void addXml(String path, String xml) {
    archive.addFile(ArchiveFile.string(path, xml));
  }

  addXml('[Content_Types].xml', _contentTypes.trim());
  addXml('_rels/.rels', _rels.trim());
  addXml('xl/workbook.xml', _workbook.trim());
  addXml('xl/_rels/workbook.xml.rels', _workbookRels.trim());
  addXml('xl/worksheets/sheet1.xml', _sheetXml(rows));
  return ZipEncoder().encodeBytes(archive);
}

String _sheetXml(List<List<String>> rows) {
  final buf = StringBuffer()
    ..write(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetData>',
    );
  for (var r = 0; r < rows.length; r++) {
    final rowNum = r + 1;
    buf.write('<row r="$rowNum">');
    final cells = rows[r];
    for (var c = 0; c < cells.length; c++) {
      final ref = '${_colName(c)}$rowNum';
      buf.write(
        '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">'
        '${_xmlEscape(cells[c])}'
        '</t></is></c>',
      );
    }
    buf.write('</row>');
  }
  buf.write('</sheetData></worksheet>');
  return buf.toString();
}

String _colName(int index) {
  var n = index + 1;
  final chars = StringBuffer();
  while (n > 0) {
    n--;
    chars.writeCharCode(65 + (n % 26));
    n ~/= 26;
  }
  return chars.toString().split('').reversed.join();
}

String _xmlEscape(String value) {
  final cleaned = value.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
  return cleaned
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

const _contentTypes = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>
''';

const _rels = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>
''';

const _workbook = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="명단" sheetId="1" r:id="rId1"/></sheets>
</workbook>
''';

const _workbookRels = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>
''';
