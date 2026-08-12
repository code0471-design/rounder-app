// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void hqAlimtalkWriteRaw(String key, String value) {
  html.window.localStorage[key] = value;
}

String? hqAlimtalkReadRaw(String key) => html.window.localStorage[key];
