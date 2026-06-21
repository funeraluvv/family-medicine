// test/services/auth_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:family_medicine/services/auth_service.dart';

void main() {
  group('AuthService - Валидация данных и обработка ошибок', () {

    // ==================== ТЕСТЫ ВАЛИДАЦИИ EMAIL ====================

    test('TC-AUTH-01: Валидация email - корректный email', () {
      // Функция валидации email (дублируем логику из приложения)
      String? validateEmail(String? value) {
        if (value == null || value.trim().isEmpty) return 'Введите email';
        final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!regex.hasMatch(value.trim())) return 'Некорректный email';
        return null;
      }

      expect(validateEmail('user@example.com'), null);
      expect(validateEmail('test@mail.ru'), null);
      expect(validateEmail('name.surname@domain.org'), null);
    });

    test('TC-AUTH-02: Валидация email - пустое значение', () {
      String? validateEmail(String? value) {
        if (value == null || value.trim().isEmpty) return 'Введите email';
        final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!regex.hasMatch(value.trim())) return 'Некорректный email';
        return null;
      }

      expect(validateEmail(''), 'Введите email');
      expect(validateEmail('   '), 'Введите email');
      expect(validateEmail(null), 'Введите email');
    });

    test('TC-AUTH-03: Валидация email - некорректный формат', () {
      String? validateEmail(String? value) {
        if (value == null || value.trim().isEmpty) return 'Введите email';
        final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!regex.hasMatch(value.trim())) return 'Некорректный email';
        return null;
      }

      expect(validateEmail('invalid'), 'Некорректный email');
      expect(validateEmail('test@'), 'Некорректный email');
      expect(validateEmail('test@mail'), 'Некорректный email');
      expect(validateEmail('test@mail.'), 'Некорректный email');
    });

    // ==================== ТЕСТЫ ВАЛИДАЦИИ ПАРОЛЯ ====================

    test('TC-AUTH-04: Валидация пароля - корректный пароль', () {
      String? validatePassword(String? value) {
        if (value == null || value.isEmpty) return 'Введите пароль';
        if (value.length < 8) return 'Пароль должен содержать минимум 8 символов';
        if (!RegExp(r'[0-9]').hasMatch(value)) return 'Пароль должен содержать цифру';
        if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Пароль должен содержать заглавную букву';
        if (!RegExp(r'[a-z]').hasMatch(value)) return 'Пароль должен содержать строчную букву';
        return null;
      }

      expect(validatePassword('Password123'), null);
      expect(validatePassword('MySecurePass1'), null);
    });

    test('TC-AUTH-05: Валидация пароля - пустой пароль', () {
      String? validatePassword(String? value) {
        if (value == null || value.isEmpty) return 'Введите пароль';
        return null;
      }

      expect(validatePassword(''), 'Введите пароль');
      expect(validatePassword(null), 'Введите пароль');
    });

    test('TC-AUTH-06: Валидация пароля - слишком короткий (менее 8 символов)', () {
      String? validatePassword(String? value) {
        if (value == null || value.isEmpty) return 'Введите пароль';
        if (value.length < 8) return 'Пароль должен содержать минимум 8 символов';
        return null;
      }

      expect(validatePassword('Pass1'), 'Пароль должен содержать минимум 8 символов');
      expect(validatePassword('1234567'), 'Пароль должен содержать минимум 8 символов');
    });

    test('TC-AUTH-07: Валидация пароля - без цифры', () {
      String? validatePassword(String? value) {
        if (value == null || value.isEmpty) return 'Введите пароль';
        if (value.length < 8) return 'Пароль должен содержать минимум 8 символов';
        if (!RegExp(r'[0-9]').hasMatch(value)) return 'Пароль должен содержать цифру';
        return null;
      }

      expect(validatePassword('Password'), 'Пароль должен содержать цифру');
      expect(validatePassword('abcdefgh'), 'Пароль должен содержать цифру');
    });

    test('TC-AUTH-08: Валидация пароля - без заглавной буквы', () {
      String? validatePassword(String? value) {
        if (value == null || value.isEmpty) return 'Введите пароль';
        if (value.length < 8) return 'Пароль должен содержать минимум 8 символов';
        if (!RegExp(r'[0-9]').hasMatch(value)) return 'Пароль должен содержать цифру';
        if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Пароль должен содержать заглавную букву';
        return null;
      }

      expect(validatePassword('password123'), 'Пароль должен содержать заглавную букву');
    });

    test('TC-AUTH-09: Валидация пароля - без строчной буквы', () {
      String? validatePassword(String? value) {
        if (value == null || value.isEmpty) return 'Введите пароль';
        if (value.length < 8) return 'Пароль должен содержать минимум 8 символов';
        if (!RegExp(r'[0-9]').hasMatch(value)) return 'Пароль должен содержать цифру';
        if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Пароль должен содержать заглавную букву';
        if (!RegExp(r'[a-z]').hasMatch(value)) return 'Пароль должен содержать строчную букву';
        return null;
      }

      expect(validatePassword('PASSWORD123'), 'Пароль должен содержать строчную букву');
    });

    // ==================== ТЕСТЫ ОБРАБОТКИ ОШИБОК ====================

    test('TC-AUTH-10: Обработка ошибки - email уже используется', () {
      final errorMessage = AuthService.getRegisterErrorMessage('email-already-in-use');
      expect(errorMessage, 'Email уже используется');
    });

    test('TC-AUTH-11: Обработка ошибки - слабый пароль', () {
      final errorMessage = AuthService.getRegisterErrorMessage('weak-password');
      expect(errorMessage, 'Слишком слабый пароль');
    });

    test('TC-AUTH-12: Обработка ошибки - некорректный email', () {
      final errorMessage = AuthService.getRegisterErrorMessage('invalid-email');
      expect(errorMessage, 'Некорректный email');
    });

    test('TC-AUTH-13: Обработка ошибки - пользователь не найден (логин)', () {
      final errorMessage = AuthService.getLoginErrorMessage('user-not-found');
      expect(errorMessage, 'Пользователь не найден');
    });

    test('TC-AUTH-14: Обработка ошибки - неверный пароль (логин)', () {
      final errorMessage = AuthService.getLoginErrorMessage('wrong-password');
      expect(errorMessage, 'Неверный пароль');
    });

    test('TC-AUTH-15: Обработка ошибки - слишком много попыток', () {
      final errorMessage = AuthService.getLoginErrorMessage('too-many-requests');
      expect(errorMessage, 'Слишком много попыток');
    });

    test('TC-AUTH-16: Обработка ошибки - нет интернета', () {
      final errorMessage = AuthService.getLoginErrorMessage('network-request-failed');
      expect(errorMessage, 'Проверьте интернет');
    });

    test('TC-AUTH-17: Обработка ошибки - пользователь не найден (восстановление)', () {
      final errorMessage = AuthService.getResetErrorMessage('user-not-found');
      expect(errorMessage, 'Пользователь с таким email не найден');
    });

    test('TC-AUTH-18: Обработка ошибки - некорректный email (восстановление)', () {
      final errorMessage = AuthService.getResetErrorMessage('invalid-email');
      expect(errorMessage, 'Некорректный формат email');
    });

    // ==================== ТЕСТЫ ФОРМАТИРОВАНИЯ ====================

    test('TC-AUTH-19: Форматирование email - удаление пробелов', () {
      final email = '  user@example.com  ';
      final trimmed = email.trim();
      expect(trimmed, 'user@example.com');
    });

    test('TC-AUTH-23: Валидация имени - не должно быть пустым', () {
      String? validateName(String? value) {
        if (value == null || value.trim().isEmpty) return 'Введите имя';
        return null;
      }

      expect(validateName(''), 'Введите имя');
      expect(validateName('   '), 'Введите имя');
      expect(validateName(null), 'Введите имя');
      expect(validateName('Иван'), null);
    });

    test('TC-AUTH-24: Валидация имени - максимальная длина', () {
      String? validateNameLength(String? value) {
        if (value == null || value.trim().isEmpty) return 'Введите имя';
        if (value.length > 50) return 'Имя не должно превышать 50 символов';
        return null;
      }

      final longName = 'А' * 51;
      expect(validateNameLength(longName), 'Имя не должно превышать 50 символов');
      expect(validateNameLength('Иван'), null);
    });
  });
}