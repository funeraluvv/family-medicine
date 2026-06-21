import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';  // ✅ ДОБАВИТЬ ИМПОРТ
import '../../theme.dart';
import '../onboarding/onboarding_screen.dart';
import '../auth/login_screen.dart';
import '../navigation/main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _opacityAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_controller);

    _controller.forward();

    _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2));

    final currentUser = FirebaseAuth.instance.currentUser;
    print('=== ПРОВЕРКА В SPLASH ===');
    print('Пользователь: ${currentUser?.email}');

    final prefs = await SharedPreferences.getInstance();
    final isOnboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    if (!mounted) return;

    if (currentUser != null && currentUser.emailVerified) {
      print('✅ Пользователь уже вошел, переход на главный');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
      return;
    }

    if (isOnboardingCompleted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('splashScreen'),
      backgroundColor: AppColors.primary,
      body: FadeTransition(
        opacity: _opacityAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.medical_services,
                size: 72,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                'Семейная аптечка',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              LoadingAnimationWidget.threeRotatingDots(
                color: Colors.white,
                size: 50,
              ),
            ],
          ),
        ),
      ),
    );
  }
}