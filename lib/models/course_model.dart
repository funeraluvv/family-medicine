// models/course_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Статус курса лечения
enum CourseStatus {
  active,     // Активный
  completed,  // Завершён
  cancelled,  // Отменён
}

/// Модель курса лечения
class CourseModel {
  final String? id;
  final String name;
  final String assignedTo;
  final String assignedToName;
  final String assignedBy;
  final String assignedByName;
  final DateTime startDate;
  final DateTime endDate;
  final List<HealthMetric> healthMetrics;
  final List<MedicationSchedule> medications;
  final String? notes;
  final List<String> attachments;
  final DateTime createdAt;
  final CourseStatus status;
  final double? completionPercentage;

  // Для тестирования: возможность подменить текущую дату
  static DateTime? _testCurrentDate;

  CourseModel({
    this.id,
    required this.name,
    required this.assignedTo,
    required this.assignedToName,
    required this.assignedBy,
    required this.assignedByName,
    required this.startDate,
    required this.endDate,
    required this.healthMetrics,
    required this.medications,
    this.notes,
    this.attachments = const [],
    required this.createdAt,
    this.status = CourseStatus.active,
    this.completionPercentage,
  });

  /// Установка тестовой даты (только для модульного тестирования)
  static void setTestDate(DateTime? date) {
    _testCurrentDate = date;
  }

  /// Получение текущей даты (реальная или тестовая)
  DateTime _getCurrentDate() {
    return _testCurrentDate ?? DateTime.now();
  }

  /// Активен ли курс (статус active и дата окончания не раньше сегодня)
  bool get isActive {
    if (status != CourseStatus.active) return false;
    final today = _getCurrentDate();
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    // Курс активен, если сегодня <= дата окончания
    return !end.isBefore(today);
  }

  /// Завершён ли курс (статус completed или дата окончания уже прошла)
  bool get isCompleted {
    if (status == CourseStatus.completed) return true;
    final today = _getCurrentDate();
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return end.isBefore(today);
  }

  /// Длительность курса в днях (включая даты начала и окончания)
  int get duration => endDate.difference(startDate).inDays + 1;

  /// Общее количество задач (лекарства + показатели)
  int get totalTasks => medications.length + healthMetrics.length;

  /// Количество оставшихся дней (включая сегодня)
  int get daysLeft {
    final today = _getCurrentDate();
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    // Если курс завершён по статусу
    if (status == CourseStatus.completed) {
      return 0;
    }

    // Если курс ещё не начался
    if (today.isBefore(start)) {
      return end.difference(start).inDays + 1;
    }

    // Если курс уже завершён по дате
    if (today.isAfter(end)) {
      return 0;
    }

    // Курс идёт: считаем от сегодня до конца (включая сегодня)
    return end.difference(today).inDays + 1;
  }

  /// Текстовое представление оставшихся дней
  // models/course_model.dart

  /// Текстовое представление оставшихся дней
  String get daysLeftText {
    if (!isActive) return 'Завершён';

    final today = _getCurrentDate();
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    // Если курс ещё не начался
    if (today.isBefore(start)) {
      final days = end.difference(start).inDays + 1;
      return 'Осталось $days дней';
    }

    // Если сегодня последний день курса
    if (today.isAtSameMomentAs(end)) {
      return 'Заканчивается сегодня';
    }

    final days = daysLeft;
    if (days == 1) return 'Остался 1 день';
    return 'Осталось $days дней';
  }
  /// Цвет для отображения оставшихся дней
  Color get daysLeftColor {
    if (!isActive) return Colors.grey;
    final days = daysLeft;
    if (days <= 3) return Colors.red;
    if (days <= 7) return Colors.orange;
    return Colors.green;
  }

  /// Прогресс выполнения курса на основе переданных задач расписания
  double getCompletionPercentage(List<QueryDocumentSnapshot> scheduleTasks) {
    if (scheduleTasks.isEmpty) return 0.0;

    final now = _getCurrentDate();

    // Прошедшие приёмы
    final pastTasks = scheduleTasks.where((task) {
      final scheduledTime = task['scheduledTime'] as Timestamp?;
      if (scheduledTime == null) return false;
      return scheduledTime.toDate().isBefore(now);
    }).toList();

    if (pastTasks.isEmpty) return 0.0;

    final completed = pastTasks.where((task) {
      return task['status'] == 'completed';
    }).length;

    return (completed / pastTasks.length) * 100;
  }

  /// Форматированный период курса
  String get formattedPeriod {
    return '${_formatDate(startDate)} - ${_formatDate(endDate)}';
  }

  // ==================== МЕТОДЫ ДЛЯ РАБОТЫ С FIRESTORE ====================

  /// Преобразование модели в Map для сохранения в Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'assignedBy': assignedBy,
      'assignedByName': assignedByName,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'healthMetrics': healthMetrics.map((m) => m.toMap()).toList(),
      'medications': medications.map((m) => m.toMap()).toList(),
      'notes': notes,
      'attachments': attachments,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': _statusToString(status),
      'completionPercentage': completionPercentage?.toDouble(),
    };
  }

  /// Создание модели из документа Firestore
  factory CourseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Безопасное преобразование completionPercentage
    double? completionPercentage;
    if (data['completionPercentage'] != null) {
      if (data['completionPercentage'] is int) {
        completionPercentage = (data['completionPercentage'] as int).toDouble();
      } else if (data['completionPercentage'] is double) {
        completionPercentage = data['completionPercentage'] as double;
      } else if (data['completionPercentage'] is num) {
        completionPercentage = (data['completionPercentage'] as num).toDouble();
      }
    }

    return CourseModel(
      id: doc.id,
      name: data['name'] ?? '',
      assignedTo: data['assignedTo'] ?? '',
      assignedToName: data['assignedToName'] ?? '',
      assignedBy: data['assignedBy'] ?? '',
      assignedByName: data['assignedByName'] ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      healthMetrics: (data['healthMetrics'] as List?)
          ?.map((m) => HealthMetric.fromMap(m as Map<String, dynamic>))
          .toList() ??
          [],
      medications: (data['medications'] as List?)
          ?.map((m) => MedicationSchedule.fromMap(m as Map<String, dynamic>))
          .toList() ??
          [],
      notes: data['notes'],
      attachments: List<String>.from(data['attachments'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _stringToStatus(data['status']),
      completionPercentage: completionPercentage,
    );
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================

  static String _statusToString(CourseStatus status) {
    switch (status) {
      case CourseStatus.active:
        return 'active';
      case CourseStatus.completed:
        return 'completed';
      case CourseStatus.cancelled:
        return 'cancelled';
    }
  }

  static CourseStatus _stringToStatus(String? status) {
    switch (status) {
      case 'active':
        return CourseStatus.active;
      case 'completed':
        return CourseStatus.completed;
      case 'cancelled':
        return CourseStatus.cancelled;
      default:
        return CourseStatus.active;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}

/// Показатель здоровья
class HealthMetric {
  final String type;
  final String name;
  final String unit;
  final bool required;
  final List<TimeOfDay> reminders;

  HealthMetric({
    required this.type,
    required this.name,
    required this.unit,
    this.required = true,
    this.reminders = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'name': name,
      'unit': unit,
      'required': required,
      'reminders': reminders.map((t) => {
        'hour': t.hour,
        'minute': t.minute,
      }).toList(),
    };
  }

  factory HealthMetric.fromMap(Map<String, dynamic> map) {
    return HealthMetric(
      type: map['type'] ?? 'custom',
      name: map['name'] ?? '',
      unit: map['unit'] ?? '',
      required: map['required'] ?? true,
      reminders: (map['reminders'] as List?)
          ?.map((t) => TimeOfDay(
        hour: (t as Map)['hour'] as int,
        minute: t['minute'] as int,
      ))
          .toList() ??
          [],
    );
  }

  IconData get icon {
    switch (type) {
      case 'pressure':
        return Icons.monitor_heart;
      case 'pulse':
        return Icons.favorite;
      case 'temperature':
        return Icons.thermostat;
      default:
        return Icons.monitor;
    }
  }

  Color get color {
    switch (type) {
      case 'pressure':
        return Colors.red;
      case 'pulse':
        return Colors.red.shade700;
      case 'temperature':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String get formattedReminders {
    return reminders.map((t) => _formatTimeOfDay(t)).join(', ');
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Расписание приёма лекарства
class MedicationSchedule {
  final String medicationId;
  final String medicationName;
  final String dosage;
  final String frequency;
  final List<TimeOfDay> times;
  final int quantity;
  final String? notes;

  MedicationSchedule({
    required this.medicationId,
    required this.medicationName,
    required this.dosage,
    required this.frequency,
    required this.times,
    required this.quantity,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'medicationId': medicationId,
      'medicationName': medicationName,
      'dosage': dosage,
      'frequency': frequency,
      'times': times.map((t) => {'hour': t.hour, 'minute': t.minute}).toList(),
      'quantity': quantity,
      'notes': notes,
    };
  }

  factory MedicationSchedule.fromMap(Map<String, dynamic> map) {
    return MedicationSchedule(
      medicationId: map['medicationId'] ?? '',
      medicationName: map['medicationName'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? 'once_daily',
      times: (map['times'] as List?)
          ?.map((t) => TimeOfDay(
        hour: (t as Map)['hour'] as int,
        minute: t['minute'] as int,
      ))
          .toList() ??
          [],
      quantity: map['quantity'] ?? 1,
      notes: map['notes'],
    );
  }

  String get formattedTimes {
    return times.map((t) => _formatTimeOfDay(t)).join(', ');
  }

  String get frequencyText {
    switch (frequency) {
      case 'once_daily':
        return '1 раз в день';
      case 'twice_daily':
        return '2 раза в день';
      case 'custom':
        return 'По расписанию';
      default:
        return frequency;
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

extension TimeOfDayExtension on TimeOfDay {
  DateTime toDateTime(DateTime date) {
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String toTimeString() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

/// Утилитарный класс для работы с курсами
class CourseUtils {
  static double calculateCompletionPercentage(
      CourseModel course,
      List<QueryDocumentSnapshot> completedTasks,
      ) {
    final totalTasks = course.totalTasks;
    if (totalTasks == 0) return 0;
    return (completedTasks.length / totalTasks) * 100;
  }

  static bool isMedicationDueToday(
      MedicationSchedule medication,
      DateTime date,
      ) {
    return true;
  }

  static List<DateTime> getMedicationScheduleDates(
      MedicationSchedule medication,
      DateTime startDate,
      DateTime endDate,
      ) {
    final dates = <DateTime>[];
    for (var date = startDate;
    date.isBefore(endDate.add(const Duration(days: 1)));
    date = date.add(const Duration(days: 1))) {
      if (isMedicationDueToday(medication, date)) {
        for (final time in medication.times) {
          dates.add(time.toDateTime(date));
        }
      }
    }
    return dates;
  }

  static String formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}