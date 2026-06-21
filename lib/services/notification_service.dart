import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_settings_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static final ValueNotifier<bool> refreshHomeNotifier = ValueNotifier(false);

  static void notifyRefreshNeeded() {
    refreshHomeNotifier.value = !refreshHomeNotifier.value;
  }

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _handleBackgroundNotificationTap,
    );

    await _createChannels();
  }

  // ==================== РАЗРЕШЕНИЯ ====================
  static Future<void> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      // Основное разрешение на уведомления (Android 13+)
      PermissionStatus status = await Permission.notification.status;
      if (!status.isGranted) {
        status = await Permission.notification.request();
      }

      if (status.isGranted) {
        // Для Android 12+ запрашиваем точное планирование
        if (await _isAndroidVersion(31)) { // Android 12+
          final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
          if (!exactAlarmStatus.isGranted) {
            await Permission.scheduleExactAlarm.request();
          }
        }

        // Для Android 14+ дополнительно можно запросить USE_EXACT_ALARM (но оно уже включено в SCHEDULE_EXACT_ALARM)
        // Оставляем для ясности
        if (await _isAndroidVersion(34)) {
          final useExactAlarmStatus = await Permission.scheduleExactAlarm.status;
          if (!useExactAlarmStatus.isGranted) {
            await Permission.scheduleExactAlarm.request();
          }
        }
      }
    }

    // iOS разрешения
    final ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<bool> _isAndroidVersion(int minApi) async {
    if (!Platform.isAndroid) return false;
    final androidInfo = await _getAndroidApiLevel();
    return androidInfo >= minApi;
  }

  static Future<int> _getAndroidApiLevel() async {
    return int.tryParse(await _getAndroidSdkVersion() ?? '0') ?? 0;
  }

  static Future<String?> _getAndroidSdkVersion() async {
    if (Platform.isAndroid) {
      try {
        return await Permission.notification.status
            .then((_) => androidBuildVersion);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Получение версии Android через платформенный канал (упрощённо)
  static String get androidBuildVersion {
    // В реальном проекте используйте device_info_plus или аналоги
    // Для примера возвращаем 33
    return '33';
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  static Future<void> requestAllPermissions() async {
    await requestNotificationPermission();
    await requestIgnoreBatteryOptimizations();
  }

  // ==================== КАНАЛЫ ====================
  static Future<void> _createChannels() async {
    const medicationChannel = AndroidNotificationChannel(
      'medication_channel',
      'Приём лекарств',
      description: 'Напоминания о приёме лекарств',
      importance: Importance.max,
    );

    const expiryChannel = AndroidNotificationChannel(
      'expiry_channel',
      'Срок годности',
      description: 'Срок годности лекарств',
      importance: Importance.high,
    );

    const stockChannel = AndroidNotificationChannel(
      'stock_channel',
      'Остаток',
      description: 'Низкий остаток',
      importance: Importance.high,
    );

    const familyChannel = AndroidNotificationChannel(
      'family_channel',
      'Семья',
      description: 'Уведомления о действиях членов семьи',
      importance: Importance.high,
    );

    const courseChannel = AndroidNotificationChannel(
      'course_channel',
      'Курсы лечения',
      description: 'Уведомления о курсах лечения',
      importance: Importance.high,
    );

    const healthMetricsChannel = AndroidNotificationChannel(
      'health_metrics_channel',
      'Показатели здоровья',
      description: 'Напоминания об измерении показателей',
      importance: Importance.high,
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(medicationChannel);
    await android?.createNotificationChannel(expiryChannel);
    await android?.createNotificationChannel(stockChannel);
    await android?.createNotificationChannel(familyChannel);
    await android?.createNotificationChannel(courseChannel);
    await android?.createNotificationChannel(healthMetricsChannel);
  }

  // ==================== ПОСТРОЕНИЕ УВЕДОМЛЕНИЙ ====================
  static Future<NotificationDetails> _getNotificationDetails({
    required String channelId,
    required String channelName,
    List<AndroidNotificationAction>? actions,
  }) async {
    bool soundEnabled = true;
    bool vibrationEnabled = true;
    try {
      soundEnabled = LocalSettingsService.soundEnabled;
      vibrationEnabled = LocalSettingsService.vibrationEnabled;
    } catch (_) {}

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      sound: null,
      enableVibration: vibrationEnabled,
      vibrationPattern: vibrationEnabled ? Int64List.fromList([0, 500, 200, 500]) : null,
      actions: actions,
    );

    return NotificationDetails(android: androidDetails);
  }

  static bool _isQuietHours() {
    try {
      return LocalSettingsService.isQuietHoursNow();
    } catch (_) {
      return false;
    }
  }

  // ==================== ПОКАЗ И ПЛАНИРОВАНИЕ ====================
  static Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    if (_isQuietHours()) return;
    final details = await _getNotificationDetails(
      channelId: channelId,
      channelName: channelName,
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime date,
    required String channelId,
    required String channelName,
    String? payload,
    List<AndroidNotificationAction>? actions,
  }) async {
    if (_isQuietHours()) return;
    if (date.isBefore(DateTime.now())) return;

    final details = await _getNotificationDetails(
      channelId: channelId,
      channelName: channelName,
      actions: actions,
    );

    final tzDate = tz.TZDateTime.from(date, tz.local);
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  // ==================== НАПОМИНАНИЕ О КУРСЕ ====================
  static Future<void> scheduleCourseStartReminder({
    required String courseId,
    required String courseName,
    required String assignedToName,
    required String assignedBy,
    required DateTime startDate,
  }) async {
    bool enabled = true;
    try {
      enabled = LocalSettingsService.courseNotifications;
    } catch (_) {}
    if (!enabled) return;

    final reminderDate = startDate.subtract(const Duration(days: 1));
    if (reminderDate.isBefore(DateTime.now())) return;

    await _schedule(
      id: 'course_start_$courseId'.hashCode,
      title: '📋 Завтра начинается курс',
      body: 'Курс "$courseName" для $assignedToName начинается завтра',
      date: reminderDate,
      channelId: 'course_channel',
      channelName: 'Курсы лечения',
      payload: 'course:reminder:$courseId',
    );
  }

  // ==================== ЕЖЕДНЕВНАЯ ПРОВЕРКА КУРСОВ ====================
  static Future<void> checkAndShowDailyCourseReminders() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final coursesSnapshot = await FirebaseFirestore.instance
        .collection('courses')
        .where('assignedTo', isEqualTo: currentUser.uid)
        .get();

    final prefs = await SharedPreferences.getInstance();

    for (final doc in coursesSnapshot.docs) {
      final data = doc.data();
      final startDate = (data['startDate'] as Timestamp).toDate();
      final startDay = DateTime(startDate.year, startDate.month, startDate.day);
      final reminderDay = startDay.subtract(const Duration(days: 1));

      if (reminderDay == today) {
        final courseId = doc.id;
        final lastShownKey = 'last_course_reminder_$courseId';
        final lastShown = prefs.getString(lastShownKey);

        if (lastShown != today.toIso8601String()) {
          final courseName = data['name'] ?? 'Курс';
          final assignedByName = data['assignedByName'] ?? 'Назначен';

          await showLocalNotification(
            id: 'course_daily_${courseId}_${today.millisecondsSinceEpoch}'.hashCode,
            title: '📋 Курс начинается завтра!',
            body: 'Курс "$courseName" ($assignedByName) – завтра первый день.',
            channelId: 'course_channel',
            channelName: 'Курсы лечения',
            payload: 'course:start_reminder:$courseId',
          );
          await prefs.setString(lastShownKey, today.toIso8601String());
        }
      }
    }
  }

  // ==================== ЛЕКАРСТВА ====================
  static Future<void> scheduleMedicationReminder({
    required String medicationId,
    required String medicationName,
    required String dosage,
    required DateTime scheduledTime,
    required String taskId,
  }) async {
    bool remindersEnabled = true;
    bool repeatEnabled = true;
    int repeatCount = 2;
    int intervalMinutes = 10;

    try {
      remindersEnabled = LocalSettingsService.medicationReminders;
      repeatEnabled = LocalSettingsService.repeatRemindersEnabled;
      repeatCount = LocalSettingsService.repeatCount;
      intervalMinutes = LocalSettingsService.repeatIntervalMinutes;
    } catch (_) {}

    if (!remindersEnabled) return;
    if (scheduledTime.isBefore(DateTime.now())) return;
    if (_isQuietHours()) return;

    final baseId = '$medicationId-${scheduledTime.millisecondsSinceEpoch}'.hashCode;
    final payload = 'medication:$medicationId:$taskId';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medication_channel',
        'Приём лекарств',
        importance: Importance.max,
        priority: Priority.high,
        actions: const [
          AndroidNotificationAction('taken', '✅ Принял'),
          AndroidNotificationAction('skipped', '⏭️ Пропустил'),
        ],
      ),
    );

    final tzDate = tz.TZDateTime.from(scheduledTime, tz.local);
    await _plugin.zonedSchedule(
      id: baseId,
      title: '💊 Примите лекарство',
      body: '$medicationName, $dosage',
      scheduledDate: tzDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );

    if (repeatEnabled) {
      for (int i = 1; i <= repeatCount; i++) {
        final repeatTime = scheduledTime.add(Duration(minutes: intervalMinutes * i));
        if (repeatTime.isBefore(DateTime.now())) continue;
        final repeatTzDate = tz.TZDateTime.from(repeatTime, tz.local);
        await _plugin.zonedSchedule(
          id: baseId + i,
          title: '🔔 Напоминание',
          body: '$medicationName, $dosage',
          scheduledDate: repeatTzDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
        );
      }
    }
  }

  // ==================== ПОКАЗАТЕЛИ ЗДОРОВЬЯ ====================
  static Future<void> scheduleHealthMetricReminder({
    required String metricId,
    required String metricName,
    required String unit,
    required DateTime scheduledTime,
    required String courseId,
    required String taskId,
  }) async {
    bool enabled = true;
    try {
      enabled = LocalSettingsService.medicationReminders;
    } catch (_) {}
    if (!enabled || scheduledTime.isBefore(DateTime.now()) || _isQuietHours()) return;

    final id = 'metric_${metricId}_${scheduledTime.millisecondsSinceEpoch}'.hashCode;
    final payload = 'health_metric:$taskId:$courseId:$metricId';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'health_metrics_channel',
        'Показатели здоровья',
        importance: Importance.high,
        priority: Priority.high,
        channelShowBadge: true,
        actions: const [
          AndroidNotificationAction('recorded', '✅ Записано'),
          AndroidNotificationAction('remind_later', '⏰ Напомнить позже'),
        ],
      ),
    );

    final tzDate = tz.TZDateTime.from(scheduledTime, tz.local);
    await _plugin.zonedSchedule(
      id: id,
      title: '📊 Измерьте показатель',
      body: '$metricName ($unit)',
      scheduledDate: tzDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  // ==================== СРОК ГОДНОСТИ ====================
  static Future<void> scheduleExpiryNotification({
    required String medicineId,
    required String medicineName,
    required DateTime expiryDate,
  }) async {
    bool enabled = true;
    try {
      enabled = LocalSettingsService.expiryNotifications;
    } catch (_) {}
    if (!enabled || expiryDate.isBefore(DateTime.now())) return;

    const reminderDays = [30, 14, 7, 3, 1];
    for (final days in reminderDays) {
      final scheduleDate = expiryDate.subtract(Duration(days: days));
      if (scheduleDate.isBefore(DateTime.now())) continue;

      final id = '$medicineId-expiry-$days'.hashCode;
      final tzDate = tz.TZDateTime.from(scheduleDate, tz.local);
      await _plugin.zonedSchedule(
        id: id,
        title: days == 1 ? '⚠️ Срок истекает завтра' : '⚠️ Срок годности истекает',
        body: days == 1
            ? 'У "$medicineName" истекает срок годности завтра'
            : 'У "$medicineName" осталось $days дня(ей)',
        scheduledDate: tzDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'expiry_channel',
            'Срок годности',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'expiry:$medicineId',
      );
    }
  }

  // ==================== ПРОВЕРКИ ПРИ ЗАПУСКЕ ====================
  static Future<void> checkExpiringMedicinesOnStartup() async {
    bool enabled = true;
    try {
      enabled = LocalSettingsService.expiryNotifications;
    } catch (_) {}
    if (!enabled) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final medicines = await FirebaseFirestore.instance
        .collection('medicines')
        .where('addedBy', isEqualTo: user.uid)
        .get();

    final now = DateTime.now();
    final medicinesToNotify = <Map<String, dynamic>>[];

    for (final doc in medicines.docs) {
      final data = doc.data();
      final expiryDate = (data['expiryDate'] as Timestamp).toDate();
      final daysLeft = expiryDate.difference(now).inDays;
      final name = data['name'] ?? 'Лекарство';
      if (daysLeft <= 7 && daysLeft >= 0) {
        medicinesToNotify.add({'name': name, 'daysLeft': daysLeft});
      }
    }

    if (medicinesToNotify.isNotEmpty) {
      final medicinesList = medicinesToNotify.map((m) {
        final days = m['daysLeft'];
        String daysText;
        if (days == 0) daysText = 'сегодня';
        else if (days == 1) daysText = 'завтра';
        else daysText = 'через $days дней';
        return '• ${m['name']} (истекает $daysText)';
      }).join('\n');

      final title = medicinesToNotify.length == 1
          ? '⚠️ Истекает срок годности'
          : '⚠️ У ${medicinesToNotify.length} лекарств истекает срок';

      await _show(
        id: DateTime.now().millisecondsSinceEpoch.hashCode,
        title: title,
        body: medicinesList,
        channelId: 'expiry_channel',
        channelName: 'Срок годности',
      );
    }
  }

  static Future<void> checkAllMedicinesOnStartup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final medicines = await FirebaseFirestore.instance
        .collection('medicines')
        .where('addedBy', isEqualTo: user.uid)
        .get();

    for (final doc in medicines.docs) {
      final data = doc.data();
      final quantity = data['quantity'] ?? 0;
      final initialQuantity = data['initialQuantity'] ?? quantity;
      await checkLowStock(
        medicineId: doc.id,
        medicineName: data['name'] ?? 'Лекарство',
        quantity: quantity,
        initialQuantity: initialQuantity,
      );
    }
    await checkExpiringMedicinesOnStartup();
  }

  static Future<void> checkLowStock({
    required String medicineId,
    required String medicineName,
    required int quantity,
    required int initialQuantity,
  }) async {
    bool enabled = true;
    try {
      enabled = LocalSettingsService.lowStockNotifications;
    } catch (_) {}
    if (!enabled || initialQuantity <= 0) return;

    final threshold = (initialQuantity * 0.2).ceil();
    if (quantity <= threshold && quantity > 0) {
      final medicineDoc = await FirebaseFirestore.instance
          .collection('medicines')
          .doc(medicineId)
          .get();
      if (!medicineDoc.exists) return;

      final kitId = medicineDoc.data()?['kitId'];
      final kitDoc = await FirebaseFirestore.instance
          .collection('medicine_kits')
          .doc(kitId)
          .get();
      if (!kitDoc.exists) return;

      final kit = kitDoc.data()!;
      final isFamilyKit = kit['type'] == 'family';
      final familyId = kit['familyId'];

      final title = '📦 Заканчивается';
      final body = '$medicineName осталось $quantity шт.';

      if (isFamilyKit && familyId != null) {
        final members = await FirebaseFirestore.instance
            .collection('users')
            .where('familyId', isEqualTo: familyId)
            .get();
        for (final member in members.docs) {
          await _show(
            id: medicineId.hashCode + member.id.hashCode,
            title: title,
            body: body,
            channelId: 'stock_channel',
            channelName: 'Остаток',
            payload: 'low_stock:$medicineId',
          );
        }
      } else {
        await _show(
          id: medicineId.hashCode,
          title: title,
          body: body,
          channelId: 'stock_channel',
          channelName: 'Остаток',
          payload: 'low_stock:$medicineId',
        );
      }
    }
  }

  // ==================== ОТМЕНА УВЕДОМЛЕНИЙ ====================
  static Future<void> cancelReminderNotificationsForTask(String taskId) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      if (notification.payload?.contains(taskId) == true) {
        await _plugin.cancel(id: notification.id);
      }
    }
  }

  static Future<void> cancelMedicineNotifications(String medicineId) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      if (notification.payload?.contains(medicineId) == true) {
        await _plugin.cancel(id: notification.id);
      }
    }
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ==================== ОБРАБОТЧИКИ НАЖАТИЙ ====================
  static void _handleNotificationTap(NotificationResponse response) {
    _processNotificationAction(response.actionId, response.payload);
  }

  static Future<void> _handleBackgroundNotificationTap(
      NotificationResponse response) async {
    await _processNotificationActionAsync(response.actionId, response.payload);
  }

  static void _processNotificationAction(String? action, String? payload) {
    if (payload == null) return;
    if (payload.startsWith('medication:')) {
      if (action == 'taken') {
        _markMedicationAsCompleted(payload, fromNotification: true);
      } else if (action == 'skipped') {
        _markMedicationAsSkipped(payload, fromNotification: true);
      }
    } else if (payload.startsWith('health_metric:')) {
      _handleHealthMetricAction(action ?? '', payload);
    }
  }

  static Future<void> _processNotificationActionAsync(String? action, String? payload) async {
    if (payload == null) return;
    if (payload.startsWith('medication:')) {
      if (action == 'taken') {
        await _markMedicationAsCompletedAsync(payload, fromNotification: true);
      } else if (action == 'skipped') {
        await _markMedicationAsSkippedAsync(payload, fromNotification: true);
      }
    } else if (payload.startsWith('health_metric:')) {
      await _handleHealthMetricActionAsync(action ?? '', payload);
    }
  }

  static void _markMedicationAsCompleted(String payload, {bool fromNotification = false}) {
    _markMedicationAsCompletedAsync(payload, fromNotification: fromNotification);
  }

  static Future<void> _markMedicationAsCompletedAsync(String payload, {bool fromNotification = false}) async {
    if (!payload.startsWith('medication:')) return;
    final parts = payload.split(':');
    if (parts.length < 3) return;
    final medicationId = parts[1];
    final taskId = parts[2];

    try {
      final taskDoc = await FirebaseFirestore.instance
          .collection('schedule')
          .doc(taskId)
          .get();
      if (!taskDoc.exists) return;
      final taskData = taskDoc.data()!;
      if (taskData['status'] == 'completed') return;

      final quantity = taskData['quantity'] ?? 1;
      await cancelReminderNotificationsForTask(taskId);
      await FirebaseFirestore.instance
          .collection('schedule')
          .doc(taskId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      if (medicationId.isNotEmpty) {
        final medicineRef = FirebaseFirestore.instance
            .collection('medicines')
            .doc(medicationId);
        final medicineDoc = await medicineRef.get();
        if (medicineDoc.exists) {
          final currentQuantity = medicineDoc.data()?['quantity'] ?? 0;
          final newQuantity = (currentQuantity - quantity).clamp(0, currentQuantity);
          await medicineRef.update({'quantity': newQuantity});
          final initialQuantity = medicineDoc.data()?['initialQuantity'] ?? currentQuantity;
          await checkLowStock(
            medicineId: medicationId,
            medicineName: taskData['medicationName'] ?? '',
            quantity: newQuantity,
            initialQuantity: initialQuantity,
          );
        }
      }

      final courseId = taskData['courseId'] as String?;
      if (courseId != null) {
        final courseDoc = await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .get();
        if (courseDoc.exists) {
          final courseData = courseDoc.data()!;
          final assignedBy = courseData['assignedBy'] as String?;
          final assignedToName = courseData['assignedToName'] as String? ?? 'Пациент';
          if (assignedBy != null) {
            await showMedicationTakenByFamilyNotification(
              medicineName: taskData['medicationName'] ?? 'лекарство',
              takenByUserName: '',
              assignedToName: assignedToName,
              courseId: courseId,
              assignedBy: assignedBy,
            );
          }
        }
      }

      notifyRefreshNeeded();
      if (fromNotification) {
        await _show(
          id: DateTime.now().millisecondsSinceEpoch.hashCode,
          title: '✅ Выполнено!',
          body: 'Приём ${taskData['medicationName'] ?? 'лекарства'} отмечен',
          channelId: 'medication_channel',
          channelName: 'Приём лекарств',
        );
      }
    } catch (e) {
      print('Ошибка при отметке приёма: $e');
    }
  }

  static void _markMedicationAsSkipped(String payload, {bool fromNotification = false}) {
    _markMedicationAsSkippedAsync(payload, fromNotification: fromNotification);
  }

  static Future<void> _markMedicationAsSkippedAsync(String payload, {bool fromNotification = false}) async {
    if (!payload.startsWith('medication:')) return;
    final parts = payload.split(':');
    if (parts.length < 3) return;
    final taskId = parts[2];

    try {
      final taskDoc = await FirebaseFirestore.instance
          .collection('schedule')
          .doc(taskId)
          .get();
      if (!taskDoc.exists) return;
      final taskData = taskDoc.data()!;
      if (taskData['status'] == 'completed') return;

      await cancelReminderNotificationsForTask(taskId);
      await FirebaseFirestore.instance
          .collection('schedule')
          .doc(taskId)
          .update({
        'status': 'skipped',
        'missedAt': FieldValue.serverTimestamp(),
      });

      final courseId = taskData['courseId'] as String?;
      if (courseId != null) {
        final courseDoc = await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .get();
        if (courseDoc.exists) {
          final courseData = courseDoc.data()!;
          final assignedBy = courseData['assignedBy'] as String?;
          final assignedToName = courseData['assignedToName'] as String? ?? 'Пациент';
          if (assignedBy != null) {
            await showMedicationMissedByFamilyNotification(
              medicineName: taskData['medicationName'] ?? 'лекарство',
              assignedToName: assignedToName,
              courseId: courseId,
              assignedBy: assignedBy,
            );
          }
        }
      }

      if (fromNotification) {
        await _show(
          id: DateTime.now().millisecondsSinceEpoch.hashCode,
          title: '⏭️ Пропущено',
          body: 'Приём ${taskData['medicationName'] ?? 'лекарства'} отмечен как пропущенный',
          channelId: 'medication_channel',
          channelName: 'Приём лекарств',
        );
      }
      notifyRefreshNeeded();
    } catch (e) {
      print('Ошибка при отметке пропуска: $e');
    }
  }

  static Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    await _show(
      id: id,
      title: title,
      body: body,
      channelId: channelId,
      channelName: channelName,
      payload: payload,
    );
  }

  // ==================== СЕМЕЙНЫЕ УВЕДОМЛЕНИЯ ====================
  static Future<void> showMedicineAddedNotification({
    required String medicineName,
    required String addedByUserName,
    required String kitId,
  }) async {
    bool enabled = true;
    try {
      enabled = LocalSettingsService.notifyOnFamilyAdded;
    } catch (_) {}
    if (!enabled) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final kitDoc = await FirebaseFirestore.instance
        .collection('medicine_kits')
        .doc(kitId)
        .get();
    if (!kitDoc.exists) return;

    final kitData = kitDoc.data()!;
    if (kitData['type'] != 'family') return;
    final familyId = kitData['familyId'] as String?;
    if (familyId == null) return;

    final members = await FirebaseFirestore.instance
        .collection('users')
        .where('familyId', isEqualTo: familyId)
        .get();

    for (final member in members.docs) {
      if (member.id == currentUser.uid) continue;
      await _show(
        id: 'medicine_added_${medicineName}_${member.id}_${DateTime.now().millisecondsSinceEpoch}'.hashCode,
        title: '💊 Новое лекарство',
        body: '$addedByUserName добавил(а) "$medicineName" в семейную аптечку',
        channelId: 'family_channel',
        channelName: 'Семья',
        payload: 'medicine_added:$kitId',
      );
    }
  }

  static Future<void> showMedicationTakenByFamilyNotification({
    required String medicineName,
    required String takenByUserName,
    required String assignedToName,
    required String courseId,
    required String assignedBy,
  }) async {
    bool enabled = true;
    try {
      enabled = LocalSettingsService.notifyOnFamilyTaken;
    } catch (_) {}
    if (!enabled) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || assignedBy == currentUser.uid) return;

    await _show(
      id: 'family_taken_${courseId}_${medicineName}_${DateTime.now().millisecondsSinceEpoch}'.hashCode,
      title: '✅ Приём лекарства',
      body: '$assignedToName принял(а) "$medicineName"',
      channelId: 'family_channel',
      channelName: 'Семья',
      payload: 'medication_taken:$courseId',
    );
  }

  static Future<void> showMedicationMissedByFamilyNotification({
    required String medicineName,
    required String assignedToName,
    required String courseId,
    required String assignedBy,
  }) async {
    bool enabled = true;
    try {
      enabled = LocalSettingsService.notifyOnFamilyMissed;
    } catch (_) {}
    if (!enabled) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || assignedBy == currentUser.uid) return;

    await _show(
      id: 'family_missed_${courseId}_${medicineName}_${DateTime.now().millisecondsSinceEpoch}'.hashCode,
      title: '⚠️ Пропуск лекарства',
      body: '$assignedToName пропустил(а) приём "$medicineName"',
      channelId: 'family_channel',
      channelName: 'Семья',
      payload: 'medication_missed:$courseId',
    );
  }

  // ==================== СИНХРОНИЗАЦИЯ ПРИ ЗАПУСКЕ ====================
  static Future<void> syncRemindersForCurrentUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final now = DateTime.now();
    final tasksSnapshot = await FirebaseFirestore.instance
        .collection('schedule')
        .where('userId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .where('scheduledTime', isGreaterThan: Timestamp.fromDate(now))
        .get();

    for (final doc in tasksSnapshot.docs) {
      final data = doc.data();
      final scheduledTime = (data['scheduledTime'] as Timestamp).toDate();
      final type = data['type'];
      if (type == 'medication') {
        await scheduleMedicationReminder(
          medicationId: data['medicationId'],
          medicationName: data['medicationName'],
          dosage: data['dosage'],
          scheduledTime: scheduledTime,
          taskId: doc.id,
        );
      } else if (type == 'health_metric') {
        final metricId = data['metricId'] ?? '${doc.id}_metric';
        await scheduleHealthMetricReminder(
          metricId: metricId,
          metricName: data['metricName'],
          unit: data['unit'],
          scheduledTime: scheduledTime,
          courseId: data['courseId'],
          taskId: doc.id,
        );
      }
    }

    final coursesSnapshot = await FirebaseFirestore.instance
        .collection('courses')
        .where('assignedTo', isEqualTo: currentUser.uid)
        .where('startDate', isGreaterThan: Timestamp.fromDate(now))
        .get();

    for (final doc in coursesSnapshot.docs) {
      final data = doc.data();
      final startDate = (data['startDate'] as Timestamp).toDate();
      await scheduleCourseStartReminder(
        courseId: doc.id,
        courseName: data['name'],
        assignedToName: data['assignedToName'],
        assignedBy: data['assignedBy'],
        startDate: startDate,
      );
    }
    await checkAndShowDailyCourseReminders();
  }

  // ==================== ОБРАБОТКА ПОКАЗАТЕЛЕЙ ЗДОРОВЬЯ (вспомогательная) ====================
  static Future<void> _handleHealthMetricAction(String action, String payload) async {
    if (!payload.startsWith('health_metric:')) return;
    final parts = payload.split(':');
    if (parts.length < 4) return;
    final taskId = parts[1];
    final courseId = parts[2];
    final metricId = parts[3];
    if (action == 'recorded') {
      await _markHealthMetricAsRecorded(taskId, metricId, courseId);
    } else if (action == 'remind_later') {
      await _remindHealthMetricLater(taskId, metricId, courseId);
    }
  }

  static Future<void> _markHealthMetricAsRecorded(String taskId, String metricId, String courseId) async {
    try {
      await FirebaseFirestore.instance
          .collection('schedule')
          .doc(taskId)
          .update({'status': 'completed', 'completedAt': FieldValue.serverTimestamp()});
      await _show(
        id: DateTime.now().millisecondsSinceEpoch.hashCode,
        title: '✅ Записано!',
        body: 'Показатель отмечен как измеренный',
        channelId: 'health_metrics_channel',
        channelName: 'Показатели здоровья',
      );
      notifyRefreshNeeded();
    } catch (e) {
      print('Ошибка при отметке показателя: $e');
    }
  }

  static Future<void> _remindHealthMetricLater(String taskId, String metricId, String courseId) async {
    try {
      final taskDoc = await FirebaseFirestore.instance
          .collection('schedule')
          .doc(taskId)
          .get();
      if (!taskDoc.exists) return;
      final data = taskDoc.data()!;
      final laterTime = DateTime.now().add(const Duration(minutes: 15));
      await scheduleHealthMetricReminder(
        metricId: metricId,
        metricName: data['metricName'],
        unit: data['unit'],
        scheduledTime: laterTime,
        courseId: courseId,
        taskId: taskId,
      );
    } catch (e) {
      print('Ошибка при повторном напоминании: $e');
    }
  }

  static Future<void> _handleHealthMetricActionAsync(String action, String payload) async {
    if (!payload.startsWith('health_metric:')) return;
    final parts = payload.split(':');
    if (parts.length < 4) return;
    final taskId = parts[1];
    final courseId = parts[2];
    final metricId = parts[3];
    if (action == 'recorded') {
      await _markHealthMetricAsRecorded(taskId, metricId, courseId);
    } else if (action == 'remind_later') {
      await _remindHealthMetricLater(taskId, metricId, courseId);
    }
  }
}