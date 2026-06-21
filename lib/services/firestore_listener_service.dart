// services/firestore_listener_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'notification_settings_service.dart';

/// Сервис для прослушивания изменений в Firestore и показа уведомлений
/// на устройствах других пользователей (без FCM)
///
/// Как это работает:
/// 1. Устройство пользователя А подписывается на изменения в коллекциях,
///    которые относятся к другим пользователям
/// 2. Когда пользователь Б изменяет данные, устройство А получает
///    это изменение через snapshot и самостоятельно генерирует локальное уведомление
///
/// Ограничения:
/// - Уведомления приходят только когда приложение открыто или в фоне
/// - Если приложение полностью закрыто (свайп вверх), уведомления не доходят
class FirestoreListenerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Подписки для разных типов событий
  static StreamSubscription<QuerySnapshot>? _coursesForPatientSubscription;
  static StreamSubscription<QuerySnapshot>? _scheduleForCreatorSubscription;
  static final Map<String, StreamSubscription<QuerySnapshot>> _courseScheduleSubscriptions = {};

  // Подписки для семейных событий
  static StreamSubscription<DocumentSnapshot>? _userFamilySubscription;
  static StreamSubscription<DocumentSnapshot>? _familyMembersSubscription;
  static String? _currentFamilyId;
  static Set<String> _previousMemberIds = {};

  /// Запуск всех слушателей (вызывать после успешной авторизации пользователя)
  static void startListening() {
    stopListening(); // Сначала останавливаем старые подписки

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      print('⚠️ FirestoreListenerService: пользователь не авторизован');
      return;
    }

    print('✅ FirestoreListenerService: запуск слушателей для пользователя $currentUserId');

    // Запускаем все слушатели
    _listenForNewCoursesForPatient();
    _listenForScheduleChangesForCreator();
    _listenForFamilyChanges();

    print('✅ FirestoreListenerService: все слушатели запущены');
  }

  /// Остановка всех слушателей (вызывать при выходе пользователя)
  static void stopListening() {
    _coursesForPatientSubscription?.cancel();
    _scheduleForCreatorSubscription?.cancel();

    for (var sub in _courseScheduleSubscriptions.values) {
      sub.cancel();
    }
    _courseScheduleSubscriptions.clear();

    _userFamilySubscription?.cancel();
    _familyMembersSubscription?.cancel();
    _previousMemberIds.clear();
    _currentFamilyId = null;

    print(' FirestoreListenerService: все слушатели остановлены');
  }

  // ==================== 1. НАЗНАЧЕНИЕ КУРСА (для ПАЦИЕНТА) ====================
  ///
  /// Пользователь (пациент) слушает коллекцию 'courses' на предмет новых курсов,
  /// где assignedTo == его userId.
  /// При добавлении нового курса показывает локальное уведомление и
  /// планирует напоминания для всех задач курса.
  static void _listenForNewCoursesForPatient() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    print('Пациент слушает новые курсы (assignedTo == $currentUserId)');

    _coursesForPatientSubscription = _firestore
        .collection('courses')
        .where('assignedTo', isEqualTo: currentUserId)
        .snapshots()
        .listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final courseName = data['name'] as String? ?? 'Курс';
          final assignedByName = data['assignedByName'] as String? ?? 'Кто-то';
          final startDate = (data['startDate'] as Timestamp?)?.toDate();
          final courseId = change.doc.id;

          String body;
          if (startDate != null) {
            body = '$assignedByName назначил(а) вам курс "$courseName" с ${_formatDate(startDate)}';
          } else {
            body = '$assignedByName назначил(а) вам курс "$courseName"';
          }

          print(' Новый курс для пациента: $courseName');

          NotificationService.showLocalNotification(
            id: courseId.hashCode,
            title: '📋 Новый курс лечения',
            body: body,
            channelId: 'course_channel',
            channelName: 'Курсы лечения',
            payload: 'course:assigned:$courseId',
          );

          // Планирование всех напоминаний для задач этого курса
          await _scheduleNotificationsForCourse(courseId);
        }
      }
    });
  }

  /// Запланировать уведомления для всех задач курса (лекарства, показатели здоровья)
  static Future<void> _scheduleNotificationsForCourse(String courseId) async {
    final scheduleSnapshot = await _firestore
        .collection('schedule')
        .where('courseId', isEqualTo: courseId)
        .get();

    for (final doc in scheduleSnapshot.docs) {
      final data = doc.data();
      final scheduledTime = (data['scheduledTime'] as Timestamp).toDate();
      final type = data['type'];
      if (type == 'medication') {
        await NotificationService.scheduleMedicationReminder(
          medicationId: data['medicationId'],
          medicationName: data['medicationName'],
          dosage: data['dosage'],
          scheduledTime: scheduledTime,
          taskId: doc.id,
        );
      } else if (type == 'health_metric') {
        await NotificationService.scheduleHealthMetricReminder(
          metricId: data['metricId'] ?? '${doc.id}_metric',
          metricName: data['metricName'],
          unit: data['unit'],
          scheduledTime: scheduledTime,
          courseId: courseId,
          taskId: doc.id,
        );
      }
    }
  }

  // ==================== 2. ПРИЁМ/ПРОПУСК ЛЕКАРСТВА (для СОЗДАТЕЛЯ) ====================
  ///
  /// Создатель курса слушает изменения в расписании (коллекция 'schedule')
  /// для всех курсов, которые он создал (assignedBy == его userId).
  /// При изменении статуса задачи на 'completed' или 'skipped' показывает уведомление.
  static void _listenForScheduleChangesForCreator() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    print('Создатель слушает изменения schedule для своих курсов (assignedBy == $currentUserId)');

    _scheduleForCreatorSubscription = _firestore
        .collection('courses')
        .where('assignedBy', isEqualTo: currentUserId)
        .snapshots()
        .listen((coursesSnapshot) {
      // Получаем список текущих ID курсов создателя
      final currentCourseIds = coursesSnapshot.docs.map((d) => d.id).toList();

      // Удаляем подписки для курсов, которых больше нет
      final toRemove = _courseScheduleSubscriptions.keys
          .where((courseId) => !currentCourseIds.contains(courseId))
          .toList();
      for (var courseId in toRemove) {
        _courseScheduleSubscriptions[courseId]?.cancel();
        _courseScheduleSubscriptions.remove(courseId);
        print(' Курс $courseId: подписка удалена (курс больше не принадлежит создателю)');
      }

      // Для каждого текущего курса создаём подписку (если ещё нет)
      for (var courseDoc in coursesSnapshot.docs) {
        final courseId = courseDoc.id;

        // Если подписка уже существует - пропускаем
        if (_courseScheduleSubscriptions.containsKey(courseId)) {
          continue;
        }

        final courseData = courseDoc.data() as Map<String, dynamic>;
        final patientName = courseData['assignedToName'] as String? ?? 'Пациент';

        print(' Курс $courseId: слушаем schedule для пациента "$patientName"');

        // Подписываемся на изменения в schedule для этого курса
        final subscription = _firestore
            .collection('schedule')
            .where('courseId', isEqualTo: courseId)
            .snapshots()
            .listen((scheduleSnapshot) {
          for (var change in scheduleSnapshot.docChanges) {
            if (change.type == DocumentChangeType.modified) {
              final data = change.doc.data() as Map<String, dynamic>;
              final newStatus = data['status'] as String?;

              // Отправляем уведомление только при изменении статуса на завершённый или пропущенный
              if (newStatus == 'completed' || newStatus == 'skipped') {
                final medicationName = data['medicationName'] as String? ?? 'лекарство';
                final taskId = change.doc.id;

                if (newStatus == 'completed') {
                  print('💊 Уведомление создателю: "$patientName" принял "$medicationName"');
                  NotificationService.showLocalNotification(
                    id: '$courseId-taken-$taskId'.hashCode,
                    title: '💊 Приём лекарства',
                    body: '$patientName принял(а) $medicationName',
                    channelId: 'family_channel',
                    channelName: 'Семья',
                    payload: 'family:taken:$courseId',
                  );
                } else if (newStatus == 'skipped') {
                  print('⚠️ Уведомление создателю: "$patientName" пропустил "$medicationName"');
                  NotificationService.showLocalNotification(
                    id: '$courseId-missed-$taskId'.hashCode,
                    title: '⚠️ Пропуск приёма',
                    body: '$patientName пропустил(а) $medicationName',
                    channelId: 'family_channel',
                    channelName: 'Семья',
                    payload: 'family:missed:$courseId',
                  );
                }
              }
            }
          }
        });

        _courseScheduleSubscriptions[courseId] = subscription;
      }
    });
  }

  // ==================== 3. СЕМЕЙНЫЕ СОБЫТИЯ (добавление/удаление участников) ====================
  ///
  /// Следит за изменениями в составе семьи.
  /// При добавлении или удалении участника показывает уведомление всем членам семьи.
  static void _listenForFamilyChanges() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    print(' Слушаем изменения в семье для пользователя $currentUserId');

    // Подписываемся на изменения в документе текущего пользователя,
    // чтобы отслеживать, изменилась ли его семья
    _userFamilySubscription = _firestore
        .collection('users')
        .doc(currentUserId)
        .snapshots()
        .listen((userDoc) {
      final userData = userDoc.data() as Map<String, dynamic>?;
      final newFamilyId = userData?['familyId'] as String?;

      // Если familyId изменился
      if (_currentFamilyId != newFamilyId) {
        print('Семья пользователя изменилась: $_currentFamilyId -> $newFamilyId');

        // Отписываемся от старой семьи
        _familyMembersSubscription?.cancel();
        _previousMemberIds.clear();
        _currentFamilyId = newFamilyId;

        // Подписываемся на новую семью
        if (newFamilyId != null && newFamilyId.isNotEmpty) {
          _subscribeToFamilyMembers(newFamilyId, currentUserId);
        }
      }
    });
  }

  /// Подписка на изменения состава конкретной семьи
  static void _subscribeToFamilyMembers(String familyId, String currentUserId) {
    print('Подписываемся на изменения участников семьи $familyId');

    _familyMembersSubscription = _firestore
        .collection('families')
        .doc(familyId)
        .snapshots()
        .listen((familyDoc) {
      if (!familyDoc.exists) {
        print('⚠️ Документ семьи $familyId не существует');
        return;
      }

      final familyData = familyDoc.data() as Map<String, dynamic>?;
      if (familyData == null) return;

      final newMemberIds = _getSafeMemberIds(familyData['memberIds']);
      final familyName = familyData['name'] as String? ?? 'Семья';

      // Инициализация при первом запуске
      if (_previousMemberIds.isEmpty && newMemberIds.isNotEmpty) {
        _previousMemberIds = Set<String>.from(newMemberIds);
        return;
      }

      // Если предыдущий список пуст, а новый пуст - выходим
      if (_previousMemberIds.isEmpty && newMemberIds.isEmpty) {
        return;
      }

      final oldSet = _previousMemberIds;
      final newSet = Set<String>.from(newMemberIds);

      // Определяем добавленных и удалённых
      final added = newSet.difference(oldSet);
      final removed = oldSet.difference(newSet);

      // Обрабатываем добавление участника
      for (final userId in added) {
        if (userId != currentUserId) {
          _notifyMemberAdded(userId, familyName, familyId);
        }
      }

      // Обрабатываем удаление участника
      for (final userId in removed) {
        if (userId != currentUserId) {
          _notifyMemberRemoved(userId, familyName, familyId);
        }
      }

      _previousMemberIds = newSet;
    });
  }

  /// Безопасное получение списка memberIds
  static List<String> _getSafeMemberIds(dynamic memberIdsData) {
    if (memberIdsData == null) return [];
    if (memberIdsData is List) {
      return memberIdsData.whereType<String>().toList();
    }
    return [];
  }

  /// Показать уведомление о добавлении участника
  static Future<void> _notifyMemberAdded(String newMemberId, String familyName, String familyId) async {
    try {
      // Проверяем настройки уведомлений
      final bool shouldNotify = LocalSettingsService.notifyOnFamilyAdded;
      if (!shouldNotify) {
        print('Уведомления о добавлении участников отключены в настройках');
        return;
      }

      // Загружаем имя нового участника
      final userDoc = await _firestore.collection('users').doc(newMemberId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userName = userData?['name'] as String? ?? 'Новый участник';

      // Показываем уведомление
      await NotificationService.showLocalNotification(
        id: 'family_added_${familyId}_$newMemberId'.hashCode,
        title: '👨‍👩‍👧 Новый участник',
        body: '$userName присоединился(ась) к семье "$familyName"',
        channelId: 'family_channel',
        channelName: 'Семья',
        payload: 'family:added:$familyId',
      );

      print(' Уведомление о добавлении участника отправлено: $userName');
    } catch (e) {
      print('❌ Ошибка при отправке уведомления о добавлении: $e');
    }
  }

  /// Показать уведомление об удалении участника
  static Future<void> _notifyMemberRemoved(String removedMemberId, String familyName, String familyId) async {
    try {
      // Проверяем настройки уведомлений
      final bool shouldNotify = LocalSettingsService.notifyOnFamilyRemoved;
      if (!shouldNotify) {
        print(' Уведомления об удалении участников отключены в настройках');
        return;
      }

      // Загружаем имя удалённого участника
      final userDoc = await _firestore.collection('users').doc(removedMemberId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userName = userData?['name'] as String? ?? 'Участник';

      // Показываем уведомление
      await NotificationService.showLocalNotification(
        id: 'family_removed_${familyId}_$removedMemberId'.hashCode,
        title: '👋 Участник покинул семью',
        body: '$userName покинул(а) семью "$familyName"',
        channelId: 'family_channel',
        channelName: 'Семья',
        payload: 'family:removed:$familyId',
      );

      print(' Уведомление об удалении участника отправлено: $userName');
    } catch (e) {
      print('Ошибка при отправке уведомления об удалении: $e');
    }
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================

  /// Форматирование даты для отображения в уведомлениях
  static String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}