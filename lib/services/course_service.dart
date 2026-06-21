// services/course_service.dart (исправленная версия)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/course_model.dart';
import 'notification_service.dart';

class CourseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;


  /// Получить курсы, где пользователь является пациентом
  static Stream<List<CourseModel>> getCoursesForPatient() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('courses')
        .where('assignedTo', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => CourseModel.fromFirestore(doc))
        .toList());
  }

  /// Получить курсы, созданные пользователем
  static Stream<List<CourseModel>> getCoursesCreatedByMe() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('courses')
        .where('assignedBy', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => CourseModel.fromFirestore(doc))
        .toList());
  }

  /// Получить один курс по ID
  static Future<CourseModel?> getCourse(String courseId) async {
    final doc = await _firestore.collection('courses').doc(courseId).get();
    if (!doc.exists) return null;
    return CourseModel.fromFirestore(doc);
  }

  /// Получить расписание (задачи) для курса
  static Future<List<QueryDocumentSnapshot>> getScheduleForCourse(String courseId) async {
    final snapshot = await _firestore
        .collection('schedule')
        .where('courseId', isEqualTo: courseId)
        .get();
    return snapshot.docs;
  }

  /// Получить процент выполнения курса (только прошедшие задачи)
  static Future<double> getCourseCompletion(String courseId) async {
    final snapshot = await _firestore
        .collection('schedule')
        .where('courseId', isEqualTo: courseId)
        .get();

    final tasks = snapshot.docs;
    if (tasks.isEmpty) return 0.0;

    final now = DateTime.now();
    int completed = 0;
    int totalRelevant = 0;

    for (final task in tasks) {
      final taskData = task.data();
      final scheduledTime = (taskData['scheduledTime'] as Timestamp?)?.toDate();

      if (scheduledTime != null && scheduledTime.isBefore(now)) {
        totalRelevant++;
        if (taskData['status'] == 'completed') {
          completed++;
        }
      }
    }

    if (totalRelevant == 0) return 0.0;
    return (completed / totalRelevant) * 100;
  }

  /// Получить статистику курса
  static Future<Map<String, dynamic>> getCourseStats(String courseId) async {
    final snapshot = await _firestore
        .collection('schedule')
        .where('courseId', isEqualTo: courseId)
        .get();

    final tasks = snapshot.docs;
    if (tasks.isEmpty) {
      return {'completed': 0, 'missed': 0, 'total': 0, 'compliance': 0.0};
    }

    final now = DateTime.now();
    int completed = 0;
    int missed = 0;
    int totalRelevant = 0;

    for (final task in tasks) {
      final taskData = task.data();
      final scheduledTime = (taskData['scheduledTime'] as Timestamp?)?.toDate();

      if (scheduledTime != null && scheduledTime.isBefore(now)) {
        totalRelevant++;
        final status = taskData['status'] as String? ?? 'pending';
        if (status == 'completed') {
          completed++;
        } else if (status == 'missed' || status == 'skipped') {
          missed++;
        }
      }
    }

    final compliance = totalRelevant == 0 ? 0.0 : completed / totalRelevant;

    return {
      'completed': completed,
      'missed': missed,
      'total': totalRelevant,
      'compliance': compliance,
    };
  }

  /// Создать новый курс и расписание с планированием уведомлений
  static Future<void> createCourse(CourseModel course) async {
    final batch = _firestore.batch();
    final scheduleRef = _firestore.collection('schedule');

    // 1. Сохраняем курс
    batch.set(_firestore.collection('courses').doc(course.id), course.toMap());

    // 2. Генерируем дни курса
    final courseDays = _generateCourseDays(course.startDate, course.endDate);

    // 3. Создаём задачи для лекарств (БЕЗ ПЛАНИРОВАНИЯ УВЕДОМЛЕНИЙ)
    for (final med in course.medications) {
      for (final day in courseDays) {
        for (final time in med.times) {
          final scheduledDateTime = DateTime(
            day.year, day.month, day.day,
            time.hour, time.minute,
          );
          final docRef = scheduleRef.doc();
          batch.set(docRef, {
            'courseId': course.id,
            'userId': course.assignedTo,
            'type': 'medication',
            'medicationId': med.medicationId,
            'medicationName': med.medicationName,
            'dosage': med.dosage,
            'quantity': med.quantity,
            'scheduledTime': Timestamp.fromDate(scheduledDateTime),
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    // 4. Создаём задачи для показателей здоровья (БЕЗ ПЛАНИРОВАНИЯ)
    for (final metric in course.healthMetrics) {
      for (final day in courseDays) {
        for (final reminderTime in metric.reminders) {
          final scheduledDateTime = DateTime(
            day.year, day.month, day.day,
            reminderTime.hour, reminderTime.minute,
          );
          final docRef = scheduleRef.doc();
          batch.set(docRef, {
            'courseId': course.id,
            'userId': course.assignedTo,
            'type': 'health_metric',
            'metricType': metric.type,
            'metricName': metric.name,
            'unit': metric.unit,
            'scheduledTime': Timestamp.fromDate(scheduledDateTime),
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    await batch.commit();
    print('✅ Курс создан: ${course.name}, ID: ${course.id}');
  }
  // ==================== ОБНОВЛЕНИЕ КУРСА ====================

  /// Досрочно завершить курс
  static Future<void> completeCourse(String courseId, double completionPercentage) async {
    final batch = _firestore.batch();

    final futureSchedules = await _firestore
        .collection('schedule')
        .where('courseId', isEqualTo: courseId)
        .where('scheduledTime', isGreaterThan: Timestamp.now())
        .get();

    for (final doc in futureSchedules.docs) {
      batch.update(doc.reference, {
        'status': 'missed',
        'closedAutomatically': true,
      });
    }

    final courseRef = _firestore.collection('courses').doc(courseId);
    batch.update(courseRef, {
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'completionPercentage': completionPercentage,
    });

    await batch.commit();
    print('Курс завершён: $courseId');
  }

  /// Удалить курс со всеми связанными данными и отменить уведомления
  static Future<void> deleteCourse(String courseId, List<QueryDocumentSnapshot> scheduleDocs) async {
    final batch = _firestore.batch();

    // Отменяем все уведомления, связанные с курсом
    for (final doc in scheduleDocs) {
      final taskId = doc.id;
      // Отменяем уведомления для задачи
      await NotificationService.cancelReminderNotificationsForTask(taskId);
      batch.delete(doc.reference);
    }

    final healthSnap = await _firestore
        .collection('health_measurements')
        .where('courseId', isEqualTo: courseId)
        .get();

    for (final doc in healthSnap.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_firestore.collection('courses').doc(courseId));
    await batch.commit();

    print('Курс удалён: $courseId');
  }

  /// Отменить все уведомления для курса
  static Future<void> cancelCourseNotifications(String courseId) async {
    final scheduleDocs = await getScheduleForCourse(courseId);

    for (final doc in scheduleDocs) {
      await NotificationService.cancelReminderNotificationsForTask(doc.id);
    }

    print('🗑Отменены все уведомления для курса: $courseId');
  }

  /// Генерация списка дней курса
  static List<DateTime> _generateCourseDays(DateTime startDate, DateTime endDate) {
    final days = <DateTime>[];
    DateTime currentDay = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (currentDay.isBefore(end) || currentDay.isAtSameMomentAs(end)) {
      days.add(currentDay);
      currentDay = currentDay.add(const Duration(days: 1));
    }
    return days;
  }

  /// Получить ID семьи текущего пользователя
  static Future<String?> getFamilyId() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return null;

    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    return userDoc.data()?['familyId'] as String?;
  }

  /// Получить имя текущего пользователя
  static Future<String> getUserName() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return 'Пользователь';

    final doc = await _firestore.collection('users').doc(currentUserId).get();
    final name = doc.data()?['name'] as String?;
    if (name != null && name.isNotEmpty) return name;

    final email = _auth.currentUser?.email;
    if (email != null && email.isNotEmpty) return email.split('@').first;

    return 'Пользователь';
  }

  /// Получить членов семьи для выбора пациента
  static Future<List<Map<String, dynamic>>> getFamilyMembers() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    final familyId = userDoc.data()?['familyId'] as String?;

    if (familyId == null) {
      return [
        {'id': currentUserId, 'name': 'Я (${_auth.currentUser?.email ?? 'Пользователь'})'}
      ];
    }

    final snapshot = await _firestore
        .collection('users')
        .where('familyId', isEqualTo: familyId)
        .get();

    final members = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'] ?? 'Пользователь',
      };
    }).toList();

    if (!members.any((m) => m['id'] == currentUserId)) {
      members.insert(0, {
        'id': currentUserId,
        'name': 'Я (${_auth.currentUser?.email ?? 'Пользователь'})'
      });
    }

    return members;
  }
}