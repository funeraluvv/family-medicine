// test/models/schedule_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:family_medicine/models/schedule_model.dart';

void main() {
  group('ScheduleModel - Расчёт статуса и проверка задач расписания', () {
    // Устанавливаем тестовую дату для всех тестов
    final testDate = DateTime(2026, 5, 22);

    setUpAll(() {
      ScheduleModel.setTestDate(testDate);
    });

    tearDownAll(() {
      ScheduleModel.setTestDate(null);
    });

    // Вспомогательная функция для создания задачи-лекарства
    ScheduleModel createMedicationTask({
      required DateTime scheduledTime,
      ScheduleStatus status = ScheduleStatus.pending,
    }) {
      return ScheduleModel(
        id: 'task1',
        courseId: 'course1',
        userId: 'user1',
        type: ScheduleType.medication,
        scheduledTime: scheduledTime,
        status: status,
        createdAt: testDate,
        medicationId: 'med1',
        medicationName: 'Аспирин',
        dosage: '500 мг',
        quantity: 1,
      );
    }

    // Вспомогательная функция для создания задачи-измерения
    ScheduleModel createHealthMetricTask({
      required DateTime scheduledTime,
      ScheduleStatus status = ScheduleStatus.pending,
    }) {
      return ScheduleModel(
        id: 'task2',
        courseId: 'course1',
        userId: 'user1',
        type: ScheduleType.healthMetric,
        scheduledTime: scheduledTime,
        status: status,
        createdAt: testDate,
        metricType: 'pressure',
        metricName: 'Артериальное давление',
        unit: 'мм рт.ст.',
      );
    }

    // ==================== ТЕСТЫ ДЛЯ isToday ====================

    test('TC-SCHEDULE-01: isToday - задача на сегодня (должна быть true)', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 22, 10, 0),
      );

      expect(task.isToday(), true);
    });

    test('TC-SCHEDULE-02: isToday - задача на другой день (должна быть false)', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 23, 10, 0),
      );

      expect(task.isToday(), false);
    });

    test('TC-SCHEDULE-03: isToday - задача на прошлую дату (должна быть false)', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 21, 10, 0),
      );

      expect(task.isToday(), false);
    });

    // ==================== ТЕСТЫ ДЛЯ isOverdue ====================

    test('TC-SCHEDULE-04: isOverdue - задача на сегодня (не просрочена)', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 22, 10, 0),
        status: ScheduleStatus.pending,
      );

      expect(task.isOverdue, false);
    });

    test('TC-SCHEDULE-05: isOverdue - задача на завтра (не просрочена)', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 23, 10, 0),
        status: ScheduleStatus.pending,
      );

      expect(task.isOverdue, false);
    });

    test('TC-SCHEDULE-06: isOverdue - задача на вчера (просрочена)', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 21, 10, 0),
        status: ScheduleStatus.pending,
      );

      expect(task.isOverdue, true);
    });

    test('TC-SCHEDULE-07: isOverdue - задача на вчера, но уже выполнена (не просрочена)', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 21, 10, 0),
        status: ScheduleStatus.completed,
      );

      expect(task.isOverdue, false);
    });

    test('TC-SCHEDULE-08: isOverdue - задача на вчера, пропущена (не просрочена)', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 21, 10, 0),
        status: ScheduleStatus.skipped,
      );

      expect(task.isOverdue, false);
    });

    // ==================== ТЕСТЫ ДЛЯ isCompleted ====================

    test('TC-SCHEDULE-09: isCompleted - задача выполнена (true)', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 22, 10, 0),
        status: ScheduleStatus.completed,
      );

      expect(task.isCompleted, true);
    });

    test('TC-SCHEDULE-10: isCompleted - задача ожидает выполнения (false)', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 22, 10, 0),
        status: ScheduleStatus.pending,
      );

      expect(task.isCompleted, false);
    });

    test('TC-SCHEDULE-11: isCompleted - задача пропущена (false)', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 22, 10, 0),
        status: ScheduleStatus.skipped,
      );

      expect(task.isCompleted, false);
    });

    // ==================== ТЕСТЫ ДЛЯ РАЗНЫХ ТИПОВ ЗАДАЧ ====================

    test('TC-SCHEDULE-12: тип задачи - лекарство', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 22, 10, 0),
      );

      expect(task.type, ScheduleType.medication);
      expect(task.medicationName, 'Аспирин');
      expect(task.dosage, '500 мг');
      expect(task.quantity, 1);
    });

    test('TC-SCHEDULE-13: тип задачи - измерение', () {
      final task = createHealthMetricTask(
        scheduledTime: DateTime(2026, 5, 22, 10, 0),
      );

      expect(task.type, ScheduleType.healthMetric);
      expect(task.metricType, 'pressure');
      expect(task.metricName, 'Артериальное давление');
      expect(task.unit, 'мм рт.ст.');
    });

    // ==================== ТЕСТЫ ДЛЯ ФОРМАТИРОВАНИЯ ВРЕМЕНИ ====================

    test('TC-SCHEDULE-14: проверка времени задачи (10:00)', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 22, 10, 0),
      );

      expect(task.scheduledTime.hour, 10);
      expect(task.scheduledTime.minute, 0);
    });

    test('TC-SCHEDULE-15: проверка времени задачи (14:30)', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 22, 14, 30),
      );

      expect(task.scheduledTime.hour, 14);
      expect(task.scheduledTime.minute, 30);
    });

    // ==================== ТЕСТЫ ДЛЯ СТАТУСОВ ====================

    test('TC-SCHEDULE-16: статус задачи - pending', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 22, 10, 0),
        status: ScheduleStatus.pending,
      );

      expect(task.status, ScheduleStatus.pending);
    });

    test('TC-SCHEDULE-17: статус задачи - completed', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 22, 10, 0),
        status: ScheduleStatus.completed,
      );

      expect(task.status, ScheduleStatus.completed);
    });

    test('TC-SCHEDULE-18: статус задачи - skipped', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 22, 10, 0),
        status: ScheduleStatus.skipped,
      );

      expect(task.status, ScheduleStatus.skipped);
    });

    // ==================== ТЕСТЫ ДЛЯ toMap ====================

    test('TC-SCHEDULE-19: Преобразование модели в Map', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 22, 10, 0),
      );

      final map = task.toMap();

      expect(map['courseId'], 'course1');
      expect(map['userId'], 'user1');
      expect(map['type'], 'medication');
      expect(map['medicationName'], 'Аспирин');
      expect(map['dosage'], '500 мг');
      expect(map['quantity'], 1);
    });

    // ==================== ГРАНИЧНЫЕ ТЕСТЫ ====================

    test('TC-SCHEDULE-20: isOverdue - задача на сегодня в 23:59 (не просрочена)', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 22, 23, 59),
        status: ScheduleStatus.pending,
      );

      expect(task.isOverdue, false);
    });

    test('TC-SCHEDULE-21: isOverdue - задача на сегодня в 00:00 (не просрочена)', () {
      final task = createMedicationTask(
        scheduledTime: DateTime(2026, 5, 22, 0, 0),
        status: ScheduleStatus.pending,
      );

      expect(task.isOverdue, false);
    });
  });
}