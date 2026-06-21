import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'services/notification_settings_service.dart';
import 'services/firestore_listener_service.dart';
import 'providers/theme_provider.dart';
import 'firebase_options.dart';
import 'features/splash/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/navigation/main_navigation_screen.dart';
import 'theme.dart';
import 'models/theme_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('1. Инициализация Firebase...');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('Firebase инициализирован');

  print('2. Инициализация локальных настроек...');
  await LocalSettingsService.init();
  print('Локальные настройки инициализированы');

  print('3. Инициализация уведомлений...');
  await NotificationService.initialize();
  await NotificationService.requestAllPermissions();
  print('Уведомления инициализированы');

  print('4. Запуск приложения...');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late ThemeProvider _themeProvider;
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeProvider = ThemeProvider();
    _checkFirstLaunch();
    _setupAuthListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('onboarding_completed') ?? false;
    setState(() {
      _showOnboarding = !hasSeenOnboarding;
    });
  }

  void _setupAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        print('Пользователь вошёл: ${user.email}');
        FirestoreListenerService.startListening();
        await NotificationService.checkAllMedicinesOnStartup();

        // синхронизация локальных уведомлений для пациента
        await NotificationService.syncRemindersForCurrentUser();
      } else {
        print('Пользователь вышел');
        FirestoreListenerService.stopListening();
        await NotificationService.cancelAll();
      }
    });
  }

  @override
  void didChangePlatformBrightness() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _themeProvider.updateSystemTheme(brightness);
  }

  String _getInitialRoute() {
    if (_showOnboarding == null) return '/splash';
    if (_showOnboarding == true) return '/onboarding';
    if (FirebaseAuth.instance.currentUser != null) return '/home';
    return '/login';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _themeProvider,
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Family Medicine',
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            locale: const Locale('ru', 'RU'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ru', 'RU'),
              Locale('en', 'US'),
            ],
            themeMode: themeProvider.themeModel.mode == AppThemeMode.system
                ? ThemeMode.system
                : (themeProvider.themeModel.mode == AppThemeMode.dark
                ? ThemeMode.dark
                : ThemeMode.light),
            initialRoute: _getInitialRoute(),
            routes: {
              '/splash': (context) => const SplashScreen(),
              '/onboarding': (context) => const OnboardingScreen(),
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const MainNavigationScreen(),
            },
          );
        },
      ),
    );
  }
}