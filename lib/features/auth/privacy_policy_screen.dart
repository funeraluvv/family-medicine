import 'package:flutter/material.dart';
import 'package:family_medicine/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Политика конфиденциальности',
          style: textTheme.titleLarge?.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                title: '1. Общие положения',
                content: 'Настоящая политика конфиденциальности описывает порядок обработки и хранения персональных данных пользователей приложения «Family Medicine».',
                textTheme: textTheme,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _buildSection(
                title: '2. Какие данные собираются',
                content: 'Приложение может собирать следующие данные:\n\n'
                    '• Имя пользователя\n'
                    '• Адрес электронной почты\n'
                    '• Данные о лекарственных препаратах (название, дозировка, количество, срок годности)\n'
                    '• Данные о курсах лечения и показателях здоровья (давление, пульс, температура)\n'
                    '• Данные о членах семьи (для семейного доступа)',
                textTheme: textTheme,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _buildSection(
                title: '3. Использование данных',
                content: 'Собранные данные используются исключительно для:\n\n'
                    '• Обеспечения работы функционала приложения\n'
                    '• Хранения информации о лекарствах и курсах лечения\n'
                    '• Отправки напоминаний о приёме лекарств\n'
                    '• Организации семейного доступа к медицинской информации\n'
                    '• Синхронизации данных между устройствами пользователя\n\n'
                    'Данные не передаются третьим лицам без согласия пользователя.',
                textTheme: textTheme,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _buildSection(
                title: '4. Хранение и защита данных',
                content: 'Все данные пользователя хранятся в защищённой облачной базе данных Firebase Firestore.\n\n'
                    'Для обеспечения безопасности применяются:\n'
                    '• Правила безопасности Firestore (ограничение доступа по аутентификации)\n'
                    '• Шифрование данных при передаче (TLS/SSL)\n'
                    '• Аутентификация пользователей через Firebase Authentication\n\n'
                    'Пользователь может удалить свой аккаунт и все связанные данные в любое время через настройки профиля.',
                textTheme: textTheme,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _buildSection(
                title: '5. Права пользователя',
                content: 'Пользователь имеет право:\n\n'
                    '• На доступ к своим персональным данным\n'
                    '• На изменение и дополнение своих данных\n'
                    '• На удаление своего аккаунта и всех данных\n'
                    '• На отзыв согласия на обработку данных\n'
                    '• На получение информации об обработке данных',
                textTheme: textTheme,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _buildSection(
                title: '6. Контакты',
                content: 'По вопросам обработки данных вы можете связаться с разработчиком по электронной почте:\n\n'
                    '📧 tatyana101204@mail.ru',
                textTheme: textTheme,
                isDark: isDark,
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightInputFill,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📌 Дата последнего обновления',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '11 мая 2026 г.',
                      style: textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required TextTheme textTheme,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkPrimary : AppColors.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkPrimary : AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            content,
            style: textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}