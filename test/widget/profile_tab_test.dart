// test/widgets/profile_tab_test.dart
// Интеграционные виджет-тесты для экрана профиля (ProfileTab)
// Тестируют корректность отображения ключевых элементов интерфейса

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_medicine/features/navigation/tabs/profile_tab.dart';
import 'package:family_medicine/providers/theme_provider.dart';
import 'package:family_medicine/models/theme_model.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'theme': 'light',
      'fontSize': 'medium',
      'medication_reminders': true,
      'expiry_notifications': true,
      'low_stock_notifications': true,
      'quiet_hours_enabled': false,
      'quiet_hours_start': 23,
      'quiet_hours_end': 7,
      'repeat_interval_minutes': 15,
      'repeat_count': 3,
      'sound_enabled': true,
      'vibration_enabled': true,
      'notify_on_family_taken': true,
      'notify_on_family_missed': true,
      'notify_on_family_added': true,
      'notify_on_family_removed': true,
    });
  });

  // ТЕСТ 1: Базовая проверка отображения
  testWidgets(
    'ProfileTab отображает заголовок и базовые элементы',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
          child: const MaterialApp(
            home: Scaffold(
              body: ProfileTab(),
            ),
          ),
        ),
      );

      // Ждём завершения всех асинхронных операций
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Проверяем наличие заголовка
      expect(find.text('Профиль'), findsOneWidget);

      // Проверяем наличие секций
      expect(find.text('Основные настройки'), findsOneWidget);
      expect(find.text('Уведомления'), findsOneWidget);
      expect(find.text('Информация'), findsOneWidget);
    },
  );

  // ТЕСТ 2: Проверка переключателей уведомлений
  testWidgets(
    'ProfileTab отображает переключатели настроек уведомлений',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
          child: const MaterialApp(
            home: Scaffold(
              body: ProfileTab(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Проверяем наличие ключевых переключателей
      expect(find.text('Напоминания о приёме'), findsOneWidget);
      expect(find.text('Истекающие лекарства'), findsOneWidget);
      expect(find.text('Низкий остаток лекарств'), findsOneWidget);

      // Проверяем наличие переключателей (Switch виджетов)
      expect(find.byType(Switch), findsWidgets);
    },
  );

  // ТЕСТ 3: Проверка раздела настроек темы
  testWidgets(
    'ProfileTab отображает селектор темы оформления',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
          child: const MaterialApp(
            home: Scaffold(
              body: ProfileTab(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Проверяем наличие заголовка темы
      expect(find.text('Тема оформления'), findsOneWidget);

      // Проверяем наличие опций темы (иконки или текст)
      expect(find.byIcon(Icons.light_mode), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    },
  );

  // ТЕСТ 4: Проверка раздела "Семья"
  testWidgets(
    'ProfileTab отображает раздел управления семьёй',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
          child: const MaterialApp(
            home: Scaffold(
              body: ProfileTab(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Проверяем наличие заголовка раздела
      expect(find.text('Семья'), findsOneWidget);

      // Для неавторизованного пользователя или без семьи
      // должны быть соответствующие элементы
      expect(find.byType(ProfileTab), findsOneWidget);
    },
  );

  // ТЕСТ 5: Проверка элементов информации
  testWidgets(
    'ProfileTab отображает информационные элементы',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
          child: const MaterialApp(
            home: Scaffold(
              body: ProfileTab(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Проверяем наличие информационных элементов
      expect(find.text('Политика конфиденциальности'), findsOneWidget);
      expect(find.text('Поддержка'), findsOneWidget);
      expect(find.text('О приложении'), findsOneWidget);
    },
  );
}