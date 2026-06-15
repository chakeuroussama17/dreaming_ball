// Unit tests that don't require Supabase/dotenv initialization.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dreaming_ball/app/app.dart';

void main() {
  group('ThemeModeNotifier.decode', () {
    test('maps stored strings to ThemeMode', () {
      expect(ThemeModeNotifier.decode('light'), ThemeMode.light);
      expect(ThemeModeNotifier.decode('system'), ThemeMode.system);
      expect(ThemeModeNotifier.decode('dark'), ThemeMode.dark);
    });

    test('defaults to dark for null/unknown values', () {
      expect(ThemeModeNotifier.decode(null), ThemeMode.dark);
      expect(ThemeModeNotifier.decode('nonsense'), ThemeMode.dark);
    });
  });
}
