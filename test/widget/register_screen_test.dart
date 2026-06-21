// test/widget/register_screen_test.dart
import 'package:flutter/material.dart';
import '../ widget_test_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_medicine/features/auth/register_screen.dart';

void main() {
  group('Тестирование экрана регистрации', () {

    // ==================== TC-UI-01: Отображение всех элементов ====================

    testWidgets('TC-UI-01: Все элементы экрана отображаются корректно', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await WidgetTestUtils.delay(tester);

      expect(find.text('Регистрация'), findsOneWidget);
      expect(find.byKey(const Key('nameField')), findsOneWidget);
      expect(find.byKey(const Key('emailField')), findsOneWidget);
      expect(find.byKey(const Key('passwordField')), findsOneWidget);
      expect(find.byKey(const Key('confirmPasswordField')), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.byKey(const Key('registerButton')), findsOneWidget);
      expect(find.text('Назад'), findsOneWidget);

      print('TC-UI-01: Все элементы экрана отображаются');
    });

    // ==================== TC-UI-02: Валидация поля имени ====================

    testWidgets('TC-UI-02: Ошибка при пустом имени', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await WidgetTestUtils.delay(tester);

      await WidgetTestUtils.fillRegistrationForm(
        tester,
        name: '',
        email: 'test@example.com',
        password: 'Password123!',
      );

      await WidgetTestUtils.acceptPrivacyPolicy(tester);
      await WidgetTestUtils.tapRegisterButton(tester);

      expect(find.text('Введите имя'), findsOneWidget);

      print('  TC-UI-02: Ошибка при пустом имени отображена');
    });

    // ==================== TC-UI-03: Валидация поля email ====================

    testWidgets('TC-UI-03: Ошибка при некорректном email', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await WidgetTestUtils.delay(tester);

      await WidgetTestUtils.fillRegistrationForm(
        tester,
        name: 'Тестовый Пользователь',
        email: 'invalid-email',
        password: 'Password123!',
      );

      await WidgetTestUtils.acceptPrivacyPolicy(tester);
      await WidgetTestUtils.tapRegisterButton(tester);

      expect(find.text('Некорректный email'), findsOneWidget);

      print('  TC-UI-03: Ошибка при некорректном email отображена');
    });

    // ==================== TC-UI-04: Валидация пароля ====================

    testWidgets('TC-UI-04: Ошибка при коротком пароле (<8 символов)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await WidgetTestUtils.delay(tester);

      await WidgetTestUtils.fillRegistrationForm(
        tester,
        name: 'Тестовый Пользователь',
        email: 'test@example.com',
        password: 'Pass1',
      );

      await WidgetTestUtils.acceptPrivacyPolicy(tester);
      await WidgetTestUtils.tapRegisterButton(tester);

      expect(find.text('Пароль должен содержать минимум 8 символов'), findsOneWidget);

      print('  TC-UI-04: Ошибка при коротком пароле отображена');
    });

    testWidgets('TC-UI-04b: Ошибка при пароле без цифры', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await WidgetTestUtils.delay(tester);

      await WidgetTestUtils.fillRegistrationForm(
        tester,
        name: 'Тестовый Пользователь',
        email: 'test@example.com',
        password: 'Password',
      );

      await WidgetTestUtils.acceptPrivacyPolicy(tester);
      await WidgetTestUtils.tapRegisterButton(tester);

      expect(find.text('Пароль должен содержать хотя бы одну цифру'), findsOneWidget);

      print('  TC-UI-04b: Ошибка при пароле без цифры отображена');
    });

    testWidgets('TC-UI-04c: Ошибка при пароле без заглавной буквы', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await WidgetTestUtils.delay(tester);

      await WidgetTestUtils.fillRegistrationForm(
        tester,
        name: 'Тестовый Пользователь',
        email: 'test@example.com',
        password: 'password123',
      );

      await WidgetTestUtils.acceptPrivacyPolicy(tester);
      await WidgetTestUtils.tapRegisterButton(tester);

      expect(find.text('Пароль должен содержать хотя бы одну заглавную букву'), findsOneWidget);

      print('  TC-UI-04c: Ошибка при пароле без заглавной буквы отображена');
    });

    // ==================== TC-UI-05: Несовпадение паролей ====================

    testWidgets('TC-UI-05: Ошибка при несовпадении паролей', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await WidgetTestUtils.delay(tester);

      await tester.enterText(find.byKey(const Key('nameField')), 'Тестовый Пользователь');
      await tester.enterText(find.byKey(const Key('emailField')), 'test@example.com');
      await tester.enterText(find.byKey(const Key('passwordField')), 'Password123!');
      await tester.enterText(find.byKey(const Key('confirmPasswordField')), 'Password456!');

      await WidgetTestUtils.acceptPrivacyPolicy(tester);
      await WidgetTestUtils.tapRegisterButton(tester);

      expect(find.text('Пароли не совпадают'), findsOneWidget);

      print('  TC-UI-05: Ошибка несовпадения паролей отображена');
    });

    // ==================== TC-UI-06: Кнопка заблокирована без политики ====================

    testWidgets('TC-UI-06: Кнопка регистрации заблокирована без принятия политики', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await WidgetTestUtils.delay(tester);

      await WidgetTestUtils.fillRegistrationForm(
        tester,
        name: 'Тестовый Пользователь',
        email: 'test@example.com',
        password: 'Password123!',
      );

      // НЕ принимаем политику

      final registerButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('registerButton')),
      );
      expect(registerButton.enabled, false);

      print('  TC-UI-06: Кнопка заблокирована до принятия политики');
    });

    // ==================== TC-UI-07: Кнопка разблокируется после политики ====================

    testWidgets('TC-UI-07: Кнопка разблокируется после принятия политики', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await WidgetTestUtils.delay(tester);

      await WidgetTestUtils.fillRegistrationForm(
        tester,
        name: 'Тестовый Пользователь',
        email: 'test@example.com',
        password: 'Password123!',
      );

      // Проверяем, что кнопка заблокирована
      var registerButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('registerButton')),
      );
      expect(registerButton.enabled, false);

      // Принимаем политику
      await WidgetTestUtils.acceptPrivacyPolicy(tester);

      // Проверяем, что кнопка разблокировалась
      registerButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('registerButton')),
      );
      expect(registerButton.enabled, true);

      print('  TC-UI-07: Кнопка разблокирована после принятия политики');
    });

    // ==================== TC-UI-08: Индикатор силы пароля ====================

    testWidgets('TC-UI-08: Отображается индикатор силы пароля', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await WidgetTestUtils.delay(tester);

      // Вводим слабый пароль
      await tester.enterText(find.byKey(const Key('passwordField')), '123');
      await WidgetTestUtils.delay(tester);

      expect(find.text('Слабый пароль'), findsOneWidget);

      // Вводим средний пароль
      await tester.enterText(find.byKey(const Key('passwordField')), 'Password1');
      await WidgetTestUtils.delay(tester);

      expect(find.text('Средний пароль'), findsOneWidget);

      // Вводим надёжный пароль
      await tester.enterText(find.byKey(const Key('passwordField')), 'Password123!');
      await WidgetTestUtils.delay(tester);

      expect(find.text('Надёжный пароль'), findsOneWidget);

      print('  TC-UI-08: Индикатор силы пароля работает корректно');
    });

    // ==================== TC-UI-09: Переключение видимости пароля ====================


    testWidgets('TC-UI-09: Кнопка показа/скрытия пароля работает', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await WidgetTestUtils.delay(tester);

      // Находим поле пароля (основное)
      final passwordField = find.byKey(const Key('passwordField'));
      expect(passwordField, findsOneWidget);

      // Находим иконку переключения видимости рядом с полем пароля
      // Ищем виджет-обёртку поля пароля, затем внутри него ищем IconButton
      final passwordFieldWidget = tester.widget<TextFormField>(passwordField);
      final passwordFieldContext = tester.element(passwordField);

      // Альтернативный подход
      final allVisibilityOffIcons = find.byIcon(Icons.visibility_off);
      final allVisibilityIcons = find.byIcon(Icons.visibility);

      // Должна быть хотя бы одна иконка "глаз зачёркнутый" (для поля пароля)
      expect(allVisibilityOffIcons, findsWidgets);

      // Нажимаем ПЕРВУЮ иконку (которая относится к полю пароля, а не к полю подтверждения)
      final firstHiddenIcon = allVisibilityOffIcons.first;
      await tester.tap(firstHiddenIcon);
      await WidgetTestUtils.delay(tester);

      // Проверяем, что появилась иконка "открытый глаз"
      expect(find.byIcon(Icons.visibility), findsWidgets);

      // Снова нажимаем
      final firstVisibleIcon = find.byIcon(Icons.visibility).first;
      await tester.tap(firstVisibleIcon);
      await WidgetTestUtils.delay(tester);

      // Проверяем, что вернулась иконка "зачёркнутый глаз"
      expect(find.byIcon(Icons.visibility_off), findsWidgets);

      print('  TC-UI-09: Переключение видимости пароля работает');
    });
  });
}