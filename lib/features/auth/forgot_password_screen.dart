import 'package:flutter/material.dart';
import 'package:family_medicine/theme.dart';
import 'package:family_medicine/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  bool isLoading = false;
  bool isEmailSent = false;

  Future<void> resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      isEmailSent = false;
    });

    final result = await AuthService.resetPassword(
      email: emailController.text.trim(),
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        isLoading = false;
        isEmailSent = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Письмо отправлено на ${result['email']}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['errorMessage']), backgroundColor: Colors.red),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                GestureDetector(
                  onTap: isLoading ? null : () => Navigator.pop(context),
                  child: Row(
                    children: const [
                      Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white70),
                      SizedBox(width: 4),
                      Text('Назад', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Восстановление пароля',
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
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !isLoading,
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Email',
                            hintStyle: TextStyle(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            prefixIcon: Icon(
                              Icons.email,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            filled: true,
                            fillColor: isDark ? AppColors.darkInputFill : AppColors.lightInputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Введите email';
                            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegex.hasMatch(value.trim())) return 'Некорректный email';
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: EdgeInsets.all(isEmailSent ? 12 : 0),
                          decoration: BoxDecoration(
                            color: isEmailSent
                                ? (isDark ? AppColors.darkSurfaceVariant : Colors.green.shade50)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              if (isEmailSent)
                                Icon(
                                  Icons.check_circle,
                                  color: isDark ? AppColors.darkPrimary : Colors.green.shade700,
                                  size: 20,
                                ),
                              if (isEmailSent) const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isEmailSent
                                      ? '✓ Письмо отправлено! Проверьте почту.'
                                      : 'На почту придут инструкции для сброса пароля',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark
                                        ? (isEmailSent ? AppColors.darkPrimary : AppColors.darkTextSecondary)
                                        : (isEmailSent ? Colors.green.shade800 : AppColors.lightTextSecondary),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : resetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEmailSent
                                  ? (isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade200)
                                  : (isDark ? AppColors.darkPrimary : const Color(0xFF6E7FF3)),
                              foregroundColor: isEmailSent
                                  ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                                  : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(isEmailSent ? 'Отправить еще раз' : 'Восстановить пароль'),
                          ),
                        ),

                        if (isEmailSent) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Вернуться ко входу',
                              style: TextStyle(
                                color: isDark ? AppColors.darkPrimary : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
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