import 'package:flutter/material.dart';

import '../data/golf_courses_kr.dart';
import '../theme/app_theme.dart';

export '../data/golf_courses_kr.dart' show golfCoursesFromSchedules, GolfCourse;

/// 골프장 이름 입력 시 목록에서 고르면 주소가 따라옵니다.
class GolfCourseNameField extends StatefulWidget {
  final TextEditingController courseController;
  final TextEditingController addressController;
  final InputDecoration decoration;
  final List<GolfCourse> extras;
  final String? Function(String?)? validator;

  const GolfCourseNameField({
    super.key,
    required this.courseController,
    required this.addressController,
    required this.decoration,
    this.extras = const [],
    this.validator,
  });

  @override
  State<GolfCourseNameField> createState() => _GolfCourseNameFieldState();
}

class _GolfCourseNameFieldState extends State<GolfCourseNameField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<GolfCourse>(
      textEditingController: widget.courseController,
      focusNode: _focus,
      displayStringForOption: (c) => c.name,
      optionsBuilder: (value) {
        return searchGolfCourses(value.text, extras: widget.extras);
      },
      onSelected: (course) {
        widget.courseController.text = course.name;
        widget.courseController.selection = TextSelection.collapsed(
          offset: course.name.length,
        );
        if (course.address.isNotEmpty) {
          widget.addressController.text = course.address;
        }
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: widget.decoration.copyWith(
            hintText: widget.decoration.hintText ?? '골프장 이름 입력',
            suffixIcon: const Icon(Icons.search, size: 20),
          ),
          textInputAction: TextInputAction.next,
          validator: widget.validator,
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        if (list.isEmpty) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 280),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = list[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.golf_course,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: c.address.isEmpty
                        ? null
                        : Text(
                            c.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                    onTap: () => onSelected(c),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
