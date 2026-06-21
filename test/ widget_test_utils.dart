// test/widget_test_utils.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class WidgetTestUtils {
  static Future<void> delay(WidgetTester tester) async {
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
  }

  static Future<void> fillRegistrationForm(
      WidgetTester tester, {
        required String name,
        required String email,
        required String password,
        String confirmPassword = '',
      }) async {
    await tester.enterText(find.byKey(const Key('nameField')), name);
    await tester.enterText(find.byKey(const Key('emailField')), email);
    await tester.enterText(find.byKey(const Key('passwordField')), password);
    await tester.enterText(
      find.byKey(const Key('confirmPasswordField')),
      confirmPassword.isEmpty ? password : confirmPassword,
    );
    await delay(tester);
  }

  static Future<void> acceptPrivacyPolicy(WidgetTester tester) async {
    final checkboxFinder = find.byType(Checkbox);
    expect(checkboxFinder, findsOneWidget);
    await tester.tap(checkboxFinder);
    await delay(tester);
  }

  static Future<void> tapRegisterButton(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('registerButton')));
    await delay(tester);
  }
}