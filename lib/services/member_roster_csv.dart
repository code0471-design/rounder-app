import '../models/club_model.dart';
import '../screens/admin/admin_models.dart';
import 'xlsx_from_rows.dart';

/// Excel이 한글을 깨지 않도록 UTF-8 BOM을 붙인 CSV.
String withExcelBom(String csv) => '\uFEFF$csv';

String csvEscape(String value) {
  final needsQuote = value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r');
  final escaped = value.replaceAll('"', '""');
  return needsQuote ? '"$escaped"' : escaped;
}

String toCsv(List<List<String>> rows) {
  return rows.map((row) => row.map(csvEscape).join(',')).join('\r\n');
}

String _ymd(DateTime? d) {
  if (d == null) return '';
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

List<List<String>> clubMemberRosterRows(List<Member> members) => [
      [
        '이름',
        '성별',
        '연락처',
        '직책',
        '구분',
        '핸디캡',
        '생년월일',
        '나이',
        '주소',
        '가입일',
        '소개자',
        '메모',
        '상태',
      ],
      ...members.map(
        (m) => [
          m.name,
          m.gender,
          m.phone ?? '',
          m.role,
          m.memberType,
          m.handicap?.toString() ?? '',
          _ymd(m.birthDate),
          m.birthDate == null ? '' : '${m.age}',
          m.address ?? '',
          _ymd(m.joinDate),
          m.referrerName ?? '',
          m.memo ?? '',
          m.status,
        ],
      ),
    ];

List<List<String>> adminMemberRosterRows(List<AdminMember> members) => [
      [
        '이름',
        '닉네임',
        '연락처',
        '성별',
        '가입일',
        '상태',
        '모임수',
        '이메일',
        '최근로그인',
      ],
      ...members.map(
        (m) => [
          m.name,
          m.nickname,
          m.phone,
          m.gender,
          m.joinDate,
          m.statusLabel,
          '${m.clubCount}',
          m.email ?? '',
          m.lastLogin ?? '',
        ],
      ),
    ];

String clubMemberRosterCsv(List<Member> members) =>
    withExcelBom(toCsv(clubMemberRosterRows(members)));

List<int> clubMemberRosterXlsx(List<Member> members) =>
    xlsxFromRows(clubMemberRosterRows(members));

String adminMemberRosterCsv(List<AdminMember> members) =>
    withExcelBom(toCsv(adminMemberRosterRows(members)));

List<int> adminMemberRosterXlsx(List<AdminMember> members) =>
    xlsxFromRows(adminMemberRosterRows(members));

String safeFileStem(String name) {
  final trimmed = name.trim().isEmpty ? '명단' : name.trim();
  return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
