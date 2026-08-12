/**
 * Fix: schedule edit/create alimtalk prompt after sheet pop.
 * Do not gate on sheet State's `mounted` (false after Navigator.pop).
 */
const fs = require('fs');
const path = require('path');

const file = path.join(__dirname, '..', 'lib', 'screens', 'schedule', 'schedule_screen.dart');
let s = fs.readFileSync(file, 'utf8');

const oldEdit = `      widget.provider.updateSchedule(updated);
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\${updated.title} 일정이 변경되었습니다'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      final settings = widget.provider
          .alimtalkSettingsOf(widget.provider.selectedClub.id);
      if (settings.promptOnScheduleChange) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          await AlimtalkUtils.runScheduleChangeFlow(
            provider: widget.provider,
            schedule: updated,
          );
        }
      }
      return;`;

const newEdit = `      final provider = widget.provider;
      provider.updateSchedule(updated);
      setState(() => _saving = false);
      if (mounted) Navigator.pop(context);
      final messenger = AppNavigator.context != null
          ? ScaffoldMessenger.maybeOf(AppNavigator.context!)
          : null;
      messenger?.showSnackBar(
        SnackBar(
          content: Text('\${updated.title} 일정이 변경되었습니다'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      final settings =
          provider.alimtalkSettingsOf(provider.selectedClub.id);
      if (settings.promptOnScheduleChange) {
        await Future.delayed(const Duration(milliseconds: 300));
        await AlimtalkUtils.runScheduleChangeFlow(
          provider: provider,
          schedule: updated,
        );
      }
      return;`;

if (!s.includes(oldEdit)) {
  console.error('edit block not found');
  process.exit(1);
}
s = s.replace(oldEdit, newEdit);

const oldCreate = `    widget.provider.addSchedule(schedule);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\${schedule.title} 일정이 등록되었습니다 🗓️'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        _showAlimtalkDialog(
          context: context,
          provider: widget.provider,
          scheduleId: schedule.id,
          scheduleTitle: schedule.title,
          roundDate: schedule.roundDate,
        );
      }
    }
  }`;

const newCreate = `    final provider = widget.provider;
    provider.addSchedule(schedule);

    if (mounted) Navigator.pop(context);
    final messenger = AppNavigator.context != null
        ? ScaffoldMessenger.maybeOf(AppNavigator.context!)
        : null;
    messenger?.showSnackBar(
      SnackBar(
        content: Text('\${schedule.title} 일정이 등록되었습니다 🗓️'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 400));
    final rootCtx = AppNavigator.context;
    if (rootCtx != null) {
      _showAlimtalkDialog(
        context: rootCtx,
        provider: provider,
        scheduleId: schedule.id,
        scheduleTitle: schedule.title,
        roundDate: schedule.roundDate,
      );
    }
  }`;

if (!s.includes(oldCreate)) {
  console.error('create block not found');
  process.exit(1);
}
s = s.replace(oldCreate, newCreate);

// Ensure AppNavigator import exists
if (!s.includes("import '../../navigation/app_navigator.dart';")) {
  s = s.replace(
    "import '../../utils/alimtalk_utils.dart';",
    "import '../../navigation/app_navigator.dart';\nimport '../../utils/alimtalk_utils.dart';",
  );
}

fs.writeFileSync(file, s, 'utf8');
console.log('patched schedule change/create alimtalk after pop');
