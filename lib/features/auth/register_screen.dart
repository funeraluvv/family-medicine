import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:family_medicine/theme.dart';
import 'package:family_medicine/services/auth_service.dart';
import 'privacy_policy_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final repeatPasswordController = TextEditingController();

  bool acceptPolicy = false;
  bool obscurePassword = true;
  bool obscureRepeatPassword = true;
  bool isLoading = false;

  String? _validatePassword(String password) {
    if (password.isEmpty) return 'Введите пароль';
    if (password.length < 8) return 'Пароль должен содержать минимум 8 символов';
    if (!RegExp(r'[0-9]').hasMatch(password)) return 'Пароль должен содержать хотя бы одну цифру';
    if (!RegExp(r'[A-ZА-Я]').hasMatch(password)) return 'Пароль должен содержать хотя бы одну заглавную букву';
    if (!RegExp(r'[a-zа-я]').hasMatch(password)) return 'Пароль должен содержать хотя бы одну строчную букву';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) return 'Пароль должен содержать хотя бы один специальный символ';

    final lowerPassword = password.toLowerCase();
    if (lowerPassword.contains('password') ||
        lowerPassword.contains('qwerty') ||
        lowerPassword.contains('123456') ||
        lowerPassword.contains('admin')) {
      return 'Пароль слишком простой. Используйте более сложную комбинацию';
    }
    return null;
  }

  Widget _buildPasswordStrengthIndicator(String password) {
    if (password.isEmpty) return const SizedBox();

    int strength = 0;
    if (password.length >= 8) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[A-ZА-Я]').hasMatch(password)) strength++;
    if (RegExp(r'[a-zа-я]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;

    Color color;
    String text;
    if (strength <= 2) {
      color = Colors.red;
      text = 'Слабый пароль';
    } else if (strength <= 4) {
      color = Colors.orange;
      text = 'Средний пароль';
    } else {
      color = Colors.green;
      text = 'Надёжный пароль';
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: strength / 5,
          backgroundColor: Colors.grey.shade200,
          color: color,
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(text, style: TextStyle(fontSize: 11, color: color)),
        ),
      ],
    );
  }

  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (!acceptPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Примите условия политики')),
      );
      return;
    }

    setState(() => isLoading = true);

    final result = await AuthService.register(
      name: nameController.text.trim(),
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() => isLoading = false);

    if (result['success'] == true) {
      _showSuccessDialog(result['email'], result['user']);
    } else {
      _showSnackBar(result['errorMessage'], Colors.red);
    }
  }

  void _showSuccessDialog(String email, User user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('📧 Подтвердите email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Письмо отправлено на:', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurfaceVariant
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            const Text('✓ Перейдите по ссылке в письме\n✓ Затем войдите в приложение'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pop(context);
            },
            child: const Text('Понятно'),
          ),
          TextButton(
            onPressed: () async {
              final resendResult = await AuthService.resendVerificationEmail();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(resendResult['success'] ? 'Письмо отправлено повторно' : resendResult['errorMessage']),
                  backgroundColor: resendResult['success'] ? Colors.green : Colors.red,
                ),
              );
            },
            child: const Text('Отправить снова'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    repeatPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _input(String hint, IconData icon, {bool isPassword = false, VoidCallback? onToggle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      prefixIcon: Icon(icon, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      filled: true,
      fillColor: isDark ? AppColors.darkInputFill : AppColors.lightInputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      suffixIcon: isPassword
          ? IconButton(
        icon: Icon(
          obscurePassword ? Icons.visibility_off : Icons.visibility,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
        onPressed: onToggle,
      )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppColors.darkBackground, AppColors.darkSurface]
                : [const Color(0xFF6E7FF3), const Color(0xFFA685E2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                GestureDetector(
                  onTap: isLoading ? null : () => Navigator.pop(context),
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white70),
                      SizedBox(width: 4),
                      Text('Назад', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Регистрация',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 32),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          key: const Key('nameField'),
                          controller: nameController,
                          enabled: !isLoading,
                          style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          decoration: _input('Имя', Icons.person),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Введите имя' : null,
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          key: const Key('emailField'),
                          controller: emailController,
                          enabled: !isLoading,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          decoration: _input('Email', Icons.email),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Введите email';
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) return 'Некорректный email';
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          key: const Key('passwordField'),
                          controller: passwordController,
                          obscureText: obscurePassword,
                          enabled: !isLoading,
                          style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          decoration: _input('Пароль', Icons.lock, isPassword: true, onToggle: () {
                            setState(() => obscurePassword = !obscurePassword);
                          }),
                          validator: (value) => _validatePassword(value ?? ''),
                          onChanged: (value) => setState(() {}),
                        ),

                        if (passwordController.text.isNotEmpty)
                          _buildPasswordStrengthIndicator(passwordController.text),

                        const SizedBox(height: 16),

                        TextFormField(
                          key: const Key('confirmPasswordField'),
                          controller: repeatPasswordController,
                          obscureText: obscureRepeatPassword,
                          enabled: !isLoading,
                          style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          decoration: _input('Повторите пароль', Icons.lock_outline, isPassword: true, onToggle: () {
                            setState(() => obscureRepeatPassword = !obscureRepeatPassword);
                          }),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Повторите пароль';
                            if (value != passwordController.text) return 'Пароли не совпадают';
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Theme(
                              data: Theme.of(context).copyWith(
                                unselectedWidgetColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                              child: Checkbox(
                                value: acceptPolicy,
                                onChanged: isLoading ? null : (v) => setState(() => acceptPolicy = v ?? false),
                              ),
                            ),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Я принимаю '),
                                    TextSpan(
                                      text: 'политику конфиденциальности',
                                      style: TextStyle(
                                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = isLoading
                                            ? null
                                            : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                                        ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),


                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            key: const Key('registerButton'),
                            onPressed: acceptPolicy && !isLoading ? registerUser : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? AppColors.darkPrimary : const Color(0xFF6E7FF3),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Зарегистрироваться'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}