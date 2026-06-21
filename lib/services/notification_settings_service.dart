
import 'package:shared_preferences/shared_preferences.dart';

/// Сервис для хранения пользовательских настроек приложения в локальном хранилище (SharedPreferences).
/// Позволяет включать/отключать различные типы уведомлений, настраивать тихие часы,
/// повторные напоминания, семейные уведомления и звук/вибрацию.
class LocalSettingsService {
  // Ключи для SharedPreferences
  static const String _keyMedicationReminders = 'medication_reminders';
  static const String _keyExpiryNotifications = 'expiry_notifications';
  static const String _keyLowStockNotifications = 'low_stock_notifications';
  static const String _keyQuietHoursEnabled = 'quiet_hours_enabled';
  static const String _keyQuietHoursStart = 'quiet_hours_start';
  static const String _keyQuietHoursEnd = 'quiet_hours_end';
  static const String _keyRepeatRemindersEnabled = 'repeat_reminders_enabled';
  static const String _keyRepeatCount = 'repeat_count';
  static const String _keyRepeatIntervalMinutes = 'repeat_interval_minutes';
  static const String _keyNotifyOnFamilyTaken = 'notify_on_family_taken';
  static const String _keyNotifyOnFamilyMissed = 'notify_on_family_missed';
  static const String _keyNotifyOnFamilyAdded = 'notify_on_family_added';
  static const String _keyNotifyOnFamilyRemoved = 'notify_on_family_removed';
  static const String _keySoundEnabled = 'sound_enabled';
  static const String _keyVibrationEnabled = 'vibration_enabled';
  static const String _keyCourseNotifications = 'course_notifications'; // Уведомления о курсах

  static SharedPreferences? _prefs;

  /// Инициализация – обязательный вызов перед использованием сервиса (в main.dart).
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Проверка, что инициализация выполнена (внутренний метод)
  static void _checkInit() {
    if (_prefs == null) {
      throw Exception('LocalSettingsService не инициализирован. Вызовите init() в main.dart');
    }
  }

  // ==================== НАПОМИНАНИЯ О ЛЕКАРСТВАХ ====================
  static bool get medicationReminders {
    _checkInit();
    return _prefs!.getBool(_keyMedicationReminders) ?? true; // по умолчанию включено
  }
  static Future<void> setMedicationReminders(bool value) async {
    _checkInit();
    await _prefs!.setBool(_keyMedicationReminders, value);
  }

  // ==================== УВЕДОМЛЕНИЯ О СРОКЕ ГОДНОСТИ ====================
  static bool get expiryNotifications {
    _checkInit();
    return _prefs!.getBool(_keyExpiryNotifications) ?? true;
  }
  static Future<void> setExpiryNotifications(bool value) async {
    _checkInit();
    await _prefs!.setBool(_keyExpiryNotifications, value);
  }

  // ==================== УВЕДОМЛЕНИЯ О НИЗКОМ ОСТАТКЕ ====================
  static bool get lowStockNotifications {
    _checkInit();
    return _prefs!.getBool(_keyLowStockNotifications) ?? true;
  }
  static Future<void> setLowStockNotifications(bool value) async {
    _checkInit();
    await _prefs!.setBool(_keyLowStockNotifications, value);
  }

  // ==================== ТИХИЕ ЧАСЫ (отключение уведомлений на ночь) ====================
  static bool get quietHoursEnabled {
    _checkInit();
    return _prefs!.getBool(_keyQuietHoursEnabled) ?? false; // по умолчанию выключено
  }
  static int get quietHoursStart {
    _checkInit();
    return _prefs!.getInt(_keyQuietHoursStart) ?? 23; // час начала (0-23)
  }
  static int get quietHoursEnd {
    _checkInit();
    return _prefs!.getInt(_keyQuietHoursEnd) ?? 7;   // час окончания (0-23)
  }
  static Future<void> setQuietHoursEnabled(bool value) async {
    _checkInit();
    await _prefs!.setBool(_keyQuietHoursEnabled, value);
  }
  static Future<void> setQuietHoursTime({required int start, required int end}) async {
    _checkInit();
    await _prefs!.setInt(_keyQuietHoursStart, start);
    await _prefs!.setInt(_keyQuietHoursEnd, end);
  }

  // ==================== ПОВТОРНЫЕ НАПОМИНАНИЯ ====================
  static bool get repeatRemindersEnabled {
    _checkInit();
    return _prefs!.getBool(_keyRepeatRemindersEnabled) ?? true;
  }
  static int get repeatCount {
    _checkInit();
    return _prefs!.getInt(_keyRepeatCount) ?? 2;          // количество повторов (1-5)
  }
  static int get repeatIntervalMinutes {
    _checkInit();
    return _prefs!.getInt(_keyRepeatIntervalMinutes) ?? 10; // интервал между повторами (мин)
  }
  static Future<void> setRepeatRemindersEnabled(bool value) async {
    _checkInit();
    await _prefs!.setBool(_keyRepeatRemindersEnabled, value);
  }
  static Future<void> setRepeatCount(int value) async {
    _checkInit();
    await _prefs!.setInt(_keyRepeatCount, value.clamp(1, 5));
  }
  static Future<void> setRepeatIntervalMinutes(int value) async {
    _checkInit();
    await _prefs!.setInt(_keyRepeatIntervalMinutes, value.clamp(5, 30));
  }

  // ==================== СЕМЕЙНЫЕ УВЕДОМЛЕНИЯ ====================
  static bool get notifyOnFamilyTaken {
    _checkInit();
    return _prefs!.getBool(_keyNotifyOnFamilyTaken) ?? true; // приём лекарства
  }
  static bool get notifyOnFamilyMissed {
    _checkInit();
    return _prefs!.getBool(_keyNotifyOnFamilyMissed) ?? true; // пропуск
  }
  static bool get notifyOnFamilyAdded {
    _checkInit();
    return _prefs!.getBool(_keyNotifyOnFamilyAdded) ?? true;  // добавлен участник
  }
  static bool get notifyOnFamilyRemoved {
    _checkInit();
    return _prefs!.getBool(_keyNotifyOnFamilyRemoved) ?? true; // удалён участник
  }
  static Future<void> setNotifyOnFamilyTaken(bool value) async {
    _checkInit();
    await _prefs!.setBool(_keyNotifyOnFamilyTaken, value);
  }
  static Future<void> setNotifyOnFamilyMissed(bool value) async {
    _checkInit();
    await _prefs!.setBool(_keyNotifyOnFamilyMissed, value);
  }
  static Future<void> setNotifyOnFamilyAdded(bool value) async {
    _checkInit();
    await _prefs!.setBool(_keyNotifyOnFamilyAdded, value);
  }
  static Future<void> setNotifyOnFamilyRemoved(bool value) async {
    _checkInit();
    await _prefs!.setBool(_keyNotifyOnFamilyRemoved, value);
  }

  // ==================== ЗВУК И ВИБРАЦИЯ ====================
  static bool get soundEnabled {
    _checkInit();
    return _prefs!.getBool(_keySoundEnabled) ?? true;
  }
  static bool get vibrationEnabled {
    _checkInit();
    return _prefs!.getBool(_keyVibrationEnabled) ?? true;
  }
  static Future<void> setSoundEnabled(bool value) async {
    _checkInit();
    await _prefs!.setBool(_keySoundEnabled, value);
  }
  static Future<void> setVibrationEnabled(bool value) async {
    _checkInit();
    await _prefs!.setBool(_keyVibrationEnabled, value);
  }

  // ==================== НАСТРОЙКИ УВЕДОМЛЕНИЙ О КУРСАХ ЛЕЧЕНИЯ ====================
  static bool get courseNotifications {
    _checkInit();
    return _prefs!.getBool(_keyCourseNotifications) ?? true;
  }
  static Future<void> setCourseNotifications(bool enabled) async {
    _checkInit();
    await _prefs!.setBool(_keyCourseNotifications, enabled);
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================

  /// Проверяет, попадает ли текущее время в интервал «тихих часов».
  /// Возвращает true, если уведомления должны быть временно отключены.
  /// Учитывает переход через полночь (например, 23:00 – 07:00).
  static bool isQuietHoursNow() {
    if (!quietHoursEnabled) return false;
    final now = DateTime.now();
    final currentHour = now.hour;
    final start = quietHoursStart;
    final end = quietHoursEnd;

    if (start > end) {
      // Интервал пересекает полночь, например с 23 до 7
      return currentHour >= start || currentHour < end;
    } else {
      // Обычный интервал, например с 22 до 6
      return currentHour >= start && currentHour < end;
    }
  }

  /// Сбрасывает все настройки к значениям по умолчанию (полезно при сбросе приложения).
  static Future<void> resetToDefaults() async {
    _checkInit();
    await setMedicationReminders(true);
    await setExpiryNotifications(true);
    await setLowStockNotifications(true);
    await setQuietHoursEnabled(false);
    await setQuietHoursTime(start: 23, end: 7);
    await setRepeatRemindersEnabled(true);
    await setRepeatCount(2);
    await setRepeatIntervalMinutes(10);
    await setNotifyOnFamilyTaken(true);
    await setNotifyOnFamilyMissed(true);
    await setNotifyOnFamilyAdded(true);
    await setNotifyOnFamilyRemoved(true);
    await setSoundEnabled(true);
    await setVibrationEnabled(true);
    await setCourseNotifications(true);
  }

  /// Возвращает карту со всеми текущими настройками – удобно для отладки или отображения в UI.
  static Map<String, dynamic> getAllSettings() {
    return {
      'medicationReminders': medicationReminders,
      'expiryNotifications': expiryNotifications,
      'lowStockNotifications': lowStockNotifications,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'repeatRemindersEnabled': repeatRemindersEnabled,
      'repeatCount': repeatCount,
      'repeatIntervalMinutes': repeatIntervalMinutes,
      'notifyOnFamilyTaken': notifyOnFamilyTaken,
      'notifyOnFamilyMissed': notifyOnFamilyMissed,
      'notifyOnFamilyAdded': notifyOnFamilyAdded,
      'notifyOnFamilyRemoved': notifyOnFamilyRemoved,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'courseNotifications': courseNotifications,
    };
  }
}