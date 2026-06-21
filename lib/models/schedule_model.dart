
import 'package:cloud_firestore/cloud_firestore.dart';

/// Тип записи в расписании
enum ScheduleType {
  medication,     // Прием лекарства
  healthMetric,   // Измерение показателя (пульс, давление и т.д.)
}

/// Статус выполнения задачи
enum ScheduleStatus {
  pending,    // Ожидает выполнения
  completed,  // Выполнено
  skipped,    // Пропущено
  cancelled,  // Отменено (например, курс отменили)
}

/// Модель одного события в календаре / расписании
class ScheduleModel {
  final String id;                // ID документа
  final String courseId;          // Связь с курсом
  final String userId;            // Для какого пользователя

  final ScheduleType type;        // Тип (лекарство или показатель)

  final DateTime scheduledTime;   // Когда нужно выполнить
  final ScheduleStatus status;    // Статус выполнения

  final DateTime createdAt;       // Когда создано

  // ===== ДАННЫЕ ДЛЯ ЛЕКАРСТВА =====
  final String? medicationId;
  final String? medicationName;
  final String? dosage;
  final int? quantity;

  // ===== ДАННЫЕ ДЛЯ ПОКАЗАТЕЛЯ =====
  final String? metricType;
  final String? metricName;
  final String? unit;

  // Для тестирования: возможность подменить текущую дату
  static DateTime? _testCurrentDate;

  ScheduleModel({
    required this.id,
    required this.courseId,
    required this.userId,
    required this.type,
    required this.scheduledTime,
    required this.status,
    required this.createdAt,

    this.medicationId,
    this.medicationName,
    this.dosage,
    this.quantity,

    this.metricType,
    this.metricName,
    this.unit,
  });

  /// Установка тестовой даты (только для модульного тестирования)
  static void setTestDate(DateTime? date) {
    _testCurrentDate = date;
  }

  /// Получение текущей даты (реальная или тестовая)
  DateTime _getCurrentDate() {
    return _testCurrentDate ?? DateTime.now();
  }

  /// Преобразование Firestore -> Model
  factory ScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ScheduleModel(
      id: doc.id,
      courseId: data['courseId'] ?? '',
      userId: data['userId'] ?? '',
      type: _typeFromString(data['type']),

      scheduledTime:
      (data['scheduledTime'] as Timestamp).toDate(),

      status: _statusFromString(data['status']),

      createdAt:
      (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),

      // лекарство
      medicationId: data['medicationId'],
      medicationName: data['medicationName'],
      dosage: data['dosage'],
      quantity: data['quantity'],

      // показатель
      metricType: data['metricType'],
      metricName: data['metricName'],
      unit: data['unit'],
    );
  }

  /// Преобразование Model -> Firestore
  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'userId': userId,
      'type': _typeToString(type),

      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'status': _statusToString(status),
      'createdAt': Timestamp.fromDate(createdAt),

      // лекарство
      'medicationId': medicationId,
      'medicationName': medicationName,
      'dosage': dosage,
      'quantity': quantity,

      // показатель
      'metricType': metricType,
      'metricName': metricName,
      'unit': unit,
    };
  }

  // ===== ENUM -> STRING =====

  static String _typeToString(ScheduleType type) {
    switch (type) {
      case ScheduleType.medication:
        return 'medication';
      case ScheduleType.healthMetric:
        return 'health_metric';
    }
  }

  static ScheduleType _typeFromString(String? type) {
    switch (type) {
      case 'medication':
        return ScheduleType.medication;
      case 'health_metric':
        return ScheduleType.healthMetric;
      default:
        return ScheduleType.medication;
    }
  }

  static String _statusToString(ScheduleStatus status) {
    switch (status) {
      case ScheduleStatus.pending:
        return 'pending';
      case ScheduleStatus.completed:
        return 'completed';
      case ScheduleStatus.skipped:
        return 'skipped';
      case ScheduleStatus.cancelled:
        return 'cancelled';
    }
  }

  static ScheduleStatus _statusFromString(String? status) {
    switch (status) {
      case 'completed':
        return ScheduleStatus.completed;
      case 'skipped':
        return ScheduleStatus.skipped;
      case 'cancelled':
        return ScheduleStatus.cancelled;
      default:
        return ScheduleStatus.pending;
    }
  }

  /// Проверка: задача на сегодня
  bool isToday() {
    final now = _getCurrentDate();
    return scheduledTime.year == now.year &&
        scheduledTime.month == now.month &&
        scheduledTime.day == now.day;
  }

  /// Проверка: просрочена ли задача
  bool get isOverdue {
    if (status != ScheduleStatus.pending) {
      return false;
    }

    final now = _getCurrentDate();

    // Нормализуем текущую дату до начала дня
    final today = DateTime(now.year, now.month, now.day);

    // Нормализуем дату задачи до начала дня
    final taskDate = DateTime(scheduledTime.year, scheduledTime.month, scheduledTime.day);

    // Если дата задачи раньше сегодняшнего дня - просрочена
    return taskDate.isBefore(today);
  }

  /// Проверка: выполнена ли
  bool get isCompleted {
    return status == ScheduleStatus.completed;
  }
}