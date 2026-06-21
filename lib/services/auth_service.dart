import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Регистрация нового пользователя
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Пользователь не создан');
      }

      await user.sendEmailVerification();

      await _firestore.collection('users').doc(user.uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'role': 'member',
        'familyId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'fcmTokens': [],
      });

      await _auth.signOut();

      return {
        'success': true,
        'email': email.trim(),
        'user': user,
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'errorCode': e.code,
        'errorMessage': getRegisterErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'unknown',
        'errorMessage': 'Произошла неизвестная ошибка',
      };
    }
  }

  /// Вход в систему
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return {
          'success': false,
          'errorCode': 'user-not-found',
          'errorMessage': 'Пользователь не найден',
        };
      }

      if (!user.emailVerified) {
        await _auth.signOut();
        return {
          'success': false,
          'errorCode': 'email-not-verified',
          'errorMessage': 'Email не подтверждён',
          'email': user.email,
        };
      }

      await _ensureUserDocument(user, user.email ?? email);

      return {
        'success': true,
        'user': user,
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'errorCode': e.code,
        'errorMessage': getLoginErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'unknown',
        'errorMessage': 'Произошла неизвестная ошибка',
      };
    }
  }

  /// Выход из системы
  static Future<Map<String, dynamic>> logout() async {
    try {
      await _auth.signOut();
      return {'success': true};
    } catch (e) {
      return {
        'success': false,
        'errorMessage': 'Ошибка при выходе: $e',
      };
    }
  }

  /// Сброс пароля
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return {
        'success': true,
        'email': email.trim(),
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'errorCode': e.code,
        'errorMessage': getResetErrorMessage(e.code),
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'unknown',
        'errorMessage': 'Произошла неизвестная ошибка',
      };
    }
  }

  /// Повторная отправка письма подтверждения
  static Future<Map<String, dynamic>> resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'errorMessage': 'Пользователь не найден',
        };
      }
      await user.sendEmailVerification();
      return {'success': true};
    } catch (e) {
      return {
        'success': false,
        'errorMessage': 'Ошибка: $e',
      };
    }
  }

  /// Проверка, авторизован ли пользователь
  static bool get isAuthenticated => _auth.currentUser != null;

  /// Получение текущего пользователя
  static User? get currentUser => _auth.currentUser;

  /// Проверка, подтверждён ли email
  static bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Отслеживание состояния авторизации
  static Stream<User?> get authStateChanges => _auth.userChanges();

  // Вспомогательные методы

  static Future<void> _ensureUserDocument(User user, String email) async {
    final userDocRef = _firestore.collection('users').doc(user.uid);
    final doc = await userDocRef.get();

    if (doc.exists) {
      await userDocRef.update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } else {
      final name = email.split('@').first;
      await userDocRef.set({
        'email': email,
        'name': name,
        'role': 'member',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'fcmTokens': [],
      });
    }
  }

  static String getRegisterErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email уже используется';
      case 'weak-password':
        return 'Слишком слабый пароль';
      case 'invalid-email':
        return 'Некорректный email';
      default:
        return 'Ошибка регистрации';
    }
  }

  static String getLoginErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Пользователь не найден';
      case 'wrong-password':
        return 'Неверный пароль';
      case 'invalid-email':
        return 'Некорректный email';
      case 'user-disabled':
        return 'Аккаунт заблокирован';
      case 'too-many-requests':
        return 'Слишком много попыток';
      case 'network-request-failed':
        return 'Проверьте интернет';
      default:
        return 'Ошибка входа';
    }
  }

  static String getResetErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Пользователь с таким email не найден';
      case 'invalid-email':
        return 'Некорректный формат email';
      case 'network-request-failed':
        return 'Проверьте подключение к интернету';
      case 'too-many-requests':
        return 'Слишком много попыток. Попробуйте позже';
      default:
        return 'Ошибка при отправке';
    }
  }
}