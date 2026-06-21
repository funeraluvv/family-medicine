// services/schedule_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScheduleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Получить задачи расписания на конкретную дату
  static Future<List<Map<String, dynamic>>> getTasksForDate(DateTime date) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final startDateUtc = DateTime.utc(date.year, date.month, date.day);
    final endDateUtc = startDateUtc.add(const Duration(days: 1));

    final startTimestamp = Timestamp.fromDate(startDateUtc);
    final endTimestamp = Timestamp.fromDate(endDateUtc);

    final snapshot = await _firestore
        .collection('schedule')
        .where('userId', isEqualTo: uid)
        .where('scheduledTime', isGreaterThanOrEqualTo: startTimestamp)
        .where('scheduledTime', isLessThan: endTimestamp)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final scheduledTime = data['scheduledTime'] as Timestamp?;
      return {
        'id': doc.id,
        ...data,
        'time': scheduledTime?.toDate(),
      };
    }).toList();
  }

  /// Получить поток задач расписания на конкретную дату (Stream)
  static Stream<List<Map<String, dynamic>>> streamTasksForDate(DateTime date) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    final startDateUtc = DateTime.utc(date.year, date.month, date.day);
    final endDateUtc = startDateUtc.add(const Duration(days: 1));

    final startTimestamp = Timestamp.fromDate(startDateUtc);
    final endTimestamp = Timestamp.fromDate(endDateUtc);

    return _firestore
        .collection('schedule')
        .where('userId', isEqualTo: uid)
        .where('scheduledTime', isGreaterThanOrEqualTo: startTimestamp)
        .where('scheduledTime', isLessThan: endTimestamp)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      final scheduledTime = data['scheduledTime'] as Timestamp?;
      return {
        'id': doc.id,
        ...data,
        'time': scheduledTime?.toDate(),
      };
    }).toList());
  }

  /// Получить задачи для календаря (события на месяц)
  static Future<Map<DateTime, Map<String, bool>>> getMonthEvents(DateTime month) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};

    final start = DateTime.utc(month.year, month.month, 1);
    final end = DateTime.utc(month.year, month.month + 1, 1);

    final snapshot = await _firestore
        .collection('schedule')
        .where('userId', isEqualTo: uid)
        .where('scheduledTime', isGreaterThanOrEqualTo: start)
        .where('scheduledTime', isLessThan: end)
        .get();

    final result = <DateTime, Map<String, bool>>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final time = (data['scheduledTime'] as Timestamp).toDate();
      final date = DateTime(time.year, time.month, time.day);
      final type = data['type'] as String? ?? 'medication';

      if (!result.containsKey(date)) {
        result[date] = {'hasMeds': false, 'hasMetrics': false};
      }

      if (type == 'medication') {
        result[date]!['hasMeds'] = true;
      } else if (type == 'health_metric') {
        result[date]!['hasMetrics'] = true;
      }
    }

    return result;
  }

  /// Обновить статус задачи
  static Future<void> updateTaskStatus({
    required String taskId,
    required String status,
    bool isCompleted = false,
    bool isSkipped = false,
  }) async {
    final updateData = <String, dynamic>{};

    if (isCompleted) {
      updateData['status'] = 'completed';
      updateData['completedAt'] = FieldValue.serverTimestamp();
    } else if (isSkipped) {
      updateData['status'] = 'skipped';
      updateData['missedAt'] = FieldValue.serverTimestamp();
    } else {
      updateData['status'] = status;
    }

    await _firestore.collection('schedule').doc(taskId).update(updateData);
  }

  /// Отметить задачу как выполненную
  static Future<void> markAsCompleted(String taskId) async {
    await updateTaskStatus(taskId: taskId, status: 'completed', isCompleted: true);
  }

  /// Отметить задачу как пропущенную
  static Future<void> markAsSkipped(String taskId) async {
    await updateTaskStatus(taskId: taskId, status: 'skipped', isSkipped: true);
  }

  /// Обновить статус и значение для задачи-измерения
  static Future<void> completeMetricTask({
    required String taskId,
    required String value,
  }) async {
    await _firestore.collection('schedule').doc(taskId).update({
      'status': 'completed',
      'value': value,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Сохранить измерение здоровья
  static Future<void> saveHealthMeasurement({
    required String userId,
    required String type,
    required String value,
    required DateTime date,
    String? courseId,
  }) async {
    final measurementData = {
      'userId': userId,
      'type': type,
      'value': value,
      'date': Timestamp.fromDate(DateTime.utc(date.year, date.month, date.day)),
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (courseId != null) {
      measurementData['courseId'] = courseId;
    }

    await _firestore.collection('health_measurements').add(measurementData);
  }

  /// Сохранить заметку
  static Future<void> saveNote({
    required String userId,
    required String userName,
    required String text,
    required DateTime date,
  }) async {
    final utcDate = DateTime.utc(date.year, date.month, date.day);

    await _firestore.collection('notes').add({
      'userId': userId,
      'userName': userName,
      'text': text,
      'date': Timestamp.fromDate(utcDate),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Получить заметки на дату
  static Future<List<Map<String, dynamic>>> getNotesForDate(DateTime date) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final utcDate = DateTime.utc(date.year, date.month, date.day);
    final startTimestamp = Timestamp.fromDate(utcDate);
    final endTimestamp = Timestamp.fromDate(utcDate.add(const Duration(days: 1)));

    final snapshot = await _firestore
        .collection('notes')
        .where('userId', isEqualTo: uid)
        .where('date', isGreaterThanOrEqualTo: startTimestamp)
        .where('date', isLessThan: endTimestamp)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  /// Получить измерения здоровья на дату
  static Future<List<Map<String, dynamic>>> getHealthMeasurementsForDate(DateTime date) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final utcDate = DateTime.utc(date.year, date.month, date.day);
    final startTimestamp = Timestamp.fromDate(utcDate);
    final endTimestamp = Timestamp.fromDate(utcDate.add(const Duration(days: 1)));

    final snapshot = await _firestore
        .collection('health_measurements')
        .where('userId', isEqualTo: uid)
        .where('date', isGreaterThanOrEqualTo: startTimestamp)
        .where('date', isLessThan: endTimestamp)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }
}