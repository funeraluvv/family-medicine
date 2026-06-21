import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_medicine/theme.dart';
import 'onboarding_data.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool isLastPage = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: const Key('onboardingScreen'),
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Кнопка пропуска
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('skipButton'),
                    onPressed: _completeOnboarding,
                    child: Text(
                      'Пропустить',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),

              // PageView с онбордингом
              Expanded(
                child: PageView.builder(
                  key: const Key('onboardingPageView'),
                  controller: _controller,
                  itemCount: onboardingData.length,
                  onPageChanged: (index) {
                    setState(() {
                      isLastPage = index == onboardingData.length - 1;
                    });
                  },
                  itemBuilder: (context, index) {
                    final page = onboardingData[index];
                    return Container(
                      key: Key('onboardingPage_$index'),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Изображение
                          Image.asset(
                            page.imagePath,
                            key: Key('onboardingImage_$index'),
                            height: 280,
                            color: isDark
                                ? (page.imagePath.contains('logo') ? Colors.white : null)
                                : null,
                          ),
                          const SizedBox(height: 32),
                          // Заголовок
                          Text(
                            page.title,
                            key: Key('onboardingTitle_$index'),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          // Описание
                          Text(
                            page.description,
                            key: Key('onboardingDescription_$index'),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Индикатор страниц
              SmoothPageIndicator(
                key: const Key('pageIndicator'),
                controller: _controller,
                count: onboardingData.length,
                effect: WormEffect(
                  dotHeight: 10,
                  dotWidth: 10,
                  activeDotColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                  dotColor: isDark ? AppColors.darkTextSecondary.withOpacity(0.4) : AppColors.inactive,
                ),
              ),

              const SizedBox(height: 24),

              // Кнопка "Далее"/"Начать"
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: isLastPage ? const Key('startButton') : const Key('nextButton'),
                  onPressed: () {
                    if (isLastPage) {
                      _completeOnboarding();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isLastPage ? 'Начать' : 'Далее',
                    key: isLastPage ? const Key('startButtonText') : const Key('nextButtonText'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}