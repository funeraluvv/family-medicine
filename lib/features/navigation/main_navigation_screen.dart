import 'package:flutter/material.dart';
import 'package:awesome_bottom_bar/awesome_bottom_bar.dart';
import 'package:family_medicine/theme.dart';
import 'package:awesome_bottom_bar/widgets/inspired/inspired.dart';

import 'tabs/home_tab.dart';
import 'tabs/medicine_tab.dart';
import 'tabs/courses_tab.dart';
import 'tabs/profile_tab.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    HomeTab(),
    MedicineTab(),
    CoursesTab(),
    ProfileTab(),
  ];

  static const List<TabItem> bottomItems = [
    TabItem(icon: Icons.home, title: 'Главная'),
    TabItem(icon: Icons.medical_services, title: 'Аптечка'),
    TabItem(icon: Icons.timeline, title: 'Курсы'),
    TabItem(icon: Icons.person, title: 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: const Key('homeScreen'),
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                blurRadius: 10,
              ),
            ],
          ),
          child: BottomBarInspiredFancy(
            items: bottomItems,
            backgroundColor: Colors.transparent,
            color: isDark ? AppColors.darkTextSecondary : AppColors.inactive,
            colorSelected: isDark ? AppColors.darkPrimary : AppColors.primary,
            indexSelected: currentIndex,
            onTap: (index) => setState(() => currentIndex = index),
          ),
        ),
      ),
    );
  }
}