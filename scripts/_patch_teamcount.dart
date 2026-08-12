import "dart:convert";
import "dart:io";

void main() {
  final f = File("lib/screens/schedule/schedule_screen.dart");
  var t = f.readAsStringSync(encoding: utf8);
  final crlf = t.contains("\r\n");
  t = t.replaceAll("\r\n", "\n");

  const needle = """class _ScheduleFormSheetState extends State<_ScheduleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noticeCtrl = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay _teeTime = const TimeOfDay(hour: 7, minute: 30);
  int _teamCount = 4;
  bool _saving = false;

  @override
  void dispose() {""";

  const repl = """class _ScheduleFormSheetState extends State<_ScheduleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noticeCtrl = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay _teeTime = const TimeOfDay(hour: 7, minute: 30);
  int _teamCount = 4;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final clubTeams = widget.provider.selectedClub.teamCount;
    if (clubTeams > 0) _teamCount = clubTeams;
  }

  @override
  void dispose() {""";

  if (!t.contains(needle)) {
    print("MISS");
    exit(1);
  }
  t = t.replaceFirst(needle, repl);
  if (crlf) t = t.replaceAll("\n", "\r\n");
  f.writeAsStringSync(t, encoding: utf8);
  print("OK hangul=${t.contains('일정')} teamInit=${t.contains('clubTeams')}");
}