
import 'package:flutter/material.dart';
import 'package:family_medicine/services/course_service.dart';
import 'package:family_medicine/models/course_model.dart';
import 'package:family_medicine/theme.dart';
import 'package:family_medicine/services/course_service.dart';
import 'package:family_medicine/features/courses/add_course_screen.dart';
import 'package:family_medicine/features/courses/course_stats_screen.dart';


class CoursesTab extends StatefulWidget {
  const CoursesTab({super.key});

  @override
  State<CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<CoursesTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, double> _completionCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<double> _getCompletion(String courseId) async {
    if (_completionCache.containsKey(courseId)) {
      return _completionCache[courseId]!;
    }
    final completion = await CourseService.getCourseCompletion(courseId);
    _completionCache[courseId] = completion;
    return completion;
  }

  String _formatDate(DateTime date) => '${date.day}.${date.month}.${date.year}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Курсы лечения'),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        foregroundColor: isDark ? AppColors.darkTextPrimary : Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? AppColors.darkPrimary : AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.darkTextSecondary : Colors.grey,
          indicatorColor: isDark ? AppColors.darkPrimary : AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Мои курсы'),
            Tab(icon: Icon(Icons.person_add), text: 'Назначенные мной'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCoursesForPatient(),
          _buildCoursesCreatedByMe(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCourseScreen()));
        },
        icon: const Icon(Icons.add),
        label: const Text('Курс'),
        backgroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildCoursesForPatient() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<CourseModel>>(
      stream: CourseService.getCoursesForPatient(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.red)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final courses = snapshot.data!;
        final active = courses.where((c) => c.isActive).toList();
        final completed = courses.where((c) => !c.isActive).toList();

        if (courses.isEmpty) {
          return _buildEmptyState('Нет курсов лечения', 'Курсы, назначенные вам, появятся здесь');
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (active.isNotEmpty) ...[
              _buildSectionHeader('Активные курсы', Icons.play_circle, Colors.green),
              ...active.map((course) => _buildCourseCard(course, true)),
              const SizedBox(height: 16),
            ],
            if (completed.isNotEmpty) ...[
              _buildSectionHeader('Завершённые', Icons.check_circle, Colors.grey),
              ...completed.map((course) => _buildCourseCard(course, true)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCoursesCreatedByMe() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<CourseModel>>(
      stream: CourseService.getCoursesCreatedByMe(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.red)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final courses = snapshot.data!;
        final active = courses.where((c) => c.isActive).toList();
        final completed = courses.where((c) => !c.isActive).toList();

        if (courses.isEmpty) {
          return _buildEmptyState('Нет созданных курсов', 'Курсы, которые вы создали, появятся здесь');
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (active.isNotEmpty) ...[
              _buildSectionHeader('Активные курсы', Icons.play_circle, Colors.green),
              ...active.map((course) => _buildCourseCard(course, false)),
              const SizedBox(height: 16),
            ],
            if (completed.isNotEmpty) ...[
              _buildSectionHeader('Завершённые', Icons.check_circle, Colors.grey),
              ...completed.map((course) => _buildCourseCard(course, false)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildCourseCard(CourseModel course, bool isForPatient) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final daysLeft = course.daysLeft;
    final totalDays = course.duration;

    String daysLeftText;
    Color daysLeftColor;

    if (!course.isActive) {
      daysLeftText = 'Завершён';
      daysLeftColor = Colors.grey;
    } else if (daysLeft < 0) {
      daysLeftText = 'Просрочен';
      daysLeftColor = Colors.red;
    } else if (daysLeft == 0) {
      daysLeftText = 'Заканчивается сегодня';
      daysLeftColor = Colors.orange;
    } else if (daysLeft == 1) {
      daysLeftText = 'Остался 1 день';
      daysLeftColor = Colors.orange;
    } else {
      daysLeftText = 'Осталось $daysLeft дней';
      daysLeftColor = Colors.orange;
    }

    return FutureBuilder<double>(
      future: _getCompletion(course.id!),
      builder: (context, snapshot) {
        final completion = snapshot.data ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: isDark ? AppColors.darkSurface : Colors.white,
          child: InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => CourseStatsScreen(course: course)));
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(course.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : Colors.black87)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: course.isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(course.isActive ? 'Активен' : 'Завершён', style: TextStyle(fontSize: 12, color: course.isActive ? Colors.green : Colors.grey)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(isForPatient ? Icons.person_outline : Icons.person_add, size: 14, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(isForPatient ? course.assignedToName : course.assignedByName, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600)),
                      const Spacer(),
                      Icon(Icons.calendar_today, size: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('${_formatDate(course.startDate)} → ${_formatDate(course.endDate)}', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text('Длительность: $totalDays ${_getDaysWord(totalDays)}', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Выполнение', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600)),
                          Text('${completion.toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: completion >= 70 ? Colors.green : (completion >= 40 ? Colors.orange : Colors.red))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: completion / 100,
                        backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(completion >= 70 ? Colors.green : (completion >= 40 ? Colors.orange : Colors.red)),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDetailChip(Icons.medication, '${course.medications.length} ${_getMedicationWord(course.medications.length)}', Colors.blue),
                      _buildDetailChip(Icons.monitor_heart, '${course.healthMetrics.length} ${_getMetricWord(course.healthMetrics.length)}', Colors.red),
                      if (course.isActive && daysLeft > 0)
                        _buildDetailChip(Icons.timer, daysLeftText, daysLeftColor),
                      if (course.isActive && daysLeft == 0)
                        _buildDetailChip(Icons.warning, daysLeftText, Colors.red),
                      if (course.isActive && daysLeft < 0)
                        _buildDetailChip(Icons.cancel, daysLeftText, Colors.red),
                    ],
                  ),
                  if (course.notes != null && course.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Icon(Icons.note, size: 14, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(child: Text(course.notes!, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailChip(IconData icon, String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_services_outlined, size: 80, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextPrimary : Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500)),
        ],
      ),
    );
  }

  String _getDaysWord(int days) {
    days = days.abs();
    if (days % 10 == 1 && days % 100 != 11) return 'день';
    if (days % 10 >= 2 && days % 10 <= 4 && (days % 100 < 10 || days % 100 >= 20)) return 'дня';
    return 'дней';
  }

  String _getMedicationWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'лекарство';
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) return 'лекарства';
    return 'лекарств';
  }

  String _getMetricWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'показатель';
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) return 'показателя';
    return 'показателей';
  }
}