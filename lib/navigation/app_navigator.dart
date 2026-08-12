import 'package:flutter/material.dart';

/// MaterialApp 루트 Navigator — 중첩 Navigator/context 문제 우회
class AppNavigator {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static NavigatorState? get state => key.currentState;
  static BuildContext? get context => key.currentContext;
}
