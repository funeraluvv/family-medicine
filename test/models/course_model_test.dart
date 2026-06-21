// test/models/course_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:family_medicine/models/course_model.dart';

void main() {
  group('CourseModel - Расчёт параметров курса лечения', () {
    // Устанавливаем тестовую дату для всех тестов
    setUpAll(() {
      CourseModel.setTestDate(DateTime(2026, 5, 22));
    });

    // Сбрасываем тестовую дату после всех тестов
    tearDownAll(() {
      CourseModel.setTestDate(null);
    });

    // Вспомогательная функция для создания курса
    CourseModel createCourse({
      required DateTime startDate,
      required DateTime endDate,
      CourseStatus status = CourseStatus.active,
    }) {
      return CourseModel(
        id: '1',
        name: 'Тестовый курс',
        assignedTo: 'user1',
        assignedToName: 'Тест Пациент',
        assignedBy: 'user2',
        assignedByName: 'Тест Создатель',
        startDate: startDate,
        endDate: endDate,
        healthMetrics: [],
        medications: [],
        createdAt: DateTime(2026, 5, 22),
        status: status,
      );
    }

    // ==================== ТЕСТЫ ДЛЯ daysLeft ====================

    test('TC-COURSE-01: daysLeft - курс только начался (5 дней)', () {
      final course = createCourse(
        startDate: DateTime(2026, 5, 22),
        endDate: DateTime(2026, 5, 26),
      );

      final daysLeft = course.daysLeft;

      expect(daysLeft, 5);
    });

    test('TC-COURSE-02: daysLeft - курс в середине (3 дня осталось)', () {
      // Временно меняем тестовую дату на 24 мая
      CourseModel.setTestDate(DateTime(2026, 5, 24));

      final course = createCourse(
        startDate: DateTime(2026, 5, 22),
        endDate: DateTime(2026, 5, 26),
      );

      final daysLeft = course.daysLeft;

      expect(daysLeft, 3);

      // Возвращаем исходную тестовую дату
      CourseModel.setTestDate(DateTime(2026, 5, 22));
    });

    test('TC-COURSE-03: daysLeft - курс завершён по статусу (0 дней)', () {
      final course = createCourse(
        startDate: DateTime(2026, 5, 22),
        endDate: DateTime(2026, 5, 26),
        status: CourseStatus.completed,
      );

      final daysLeft = course.daysLeft;

      expect(daysLeft, 0);
    });

    test('TC-COURSE-04: daysLeft - курс ещё не начался (5 дней)', () {
      final course = createCourse(
        startDate: DateTime(2026, 5, 26),
        endDate: DateTime(2026, 5, 30),
      );

      final daysLeft = course.daysLeft;

      expect(daysLeft, 5);
    });

    test('TC-COURSE-05: daysLeft - курс закончился вчера (0 дней)', () {
      // Временно меняем тестовую дату на 23 мая
      CourseModel.setTestDate(DateTime(2026, 5, 23));

      final course = createCourse(
        startDate: DateTime(2026, 5, 20),
        endDate: DateTime(2026, 5, 22),
      );

      final daysLeft = course.daysLeft;

      expect(daysLeft, 0);

      // Возвращаем исходную тестовую дату
      CourseModel.setTestDate(DateTime(2026, 5, 22));
    });

    // ==================== ТЕСТЫ ДЛЯ isActive ====================

    test('TC-COURSE-06: isActive - активный курс (должен быть true)', () {
      final course = createCourse(
        startDate: DateTime(2026, 5, 22),
        endDate: DateTime(2026, 5, 26),
        status: CourseStatus.active,
      );

      expect(course.isActive, true);
    });

    test('TC-COURSE-07: isActive - завершённый по статусу (должен быть false)', () {
      final course = createCourse(
        startDate: DateTime(2026, 5, 22),
        endDate: DateTime(2026, 5, 26),
        status: CourseStatus.completed,
      );

      expect(course.isActive, false);
    });

    test('TC-COURSE-08: isActive - однодневный курс сегодня (должен быть true)', () {
      final course = createCourse(
        startDate: DateTime(2026, 5, 22),
        endDate: DateTime(2026, 5, 22),
        status: CourseStatus.active,
      );

      expect(course.isActive, true);
    });

    test('TC-COURSE-09: isActive - курс с датой окончания в прошлом (должен быть false)', () {
      // Временно меняем тестовую дату на 24 мая
      CourseModel.setTestDate(DateTime(2026, 5, 24));

      final course = createCourse(
        startDate: DateTime(2026, 5, 20),
        endDate: DateTime(2026, 5, 22),
        status: CourseStatus.active,
      );

      expect(course.isActive, false);

      // Возвращаем исходную тестовую дату
      CourseModel.setTestDate(DateTime(2026, 5, 22));
    });

    // ==================== ТЕСТЫ ДЛЯ duration ====================

    test('TC-COURSE-10: duration - корректная длительность курса (5 дней)', () {
      final course = createCourse(
        startDate: DateTime(2026, 5, 22),
        endDate: DateTime(2026, 5, 26),
      );

      final duration = course.duration;

      expect(duration, 5);
    });

    test('TC-COURSE-11: duration - однодневный курс (1 день)', () {
      final course = createCourse(
        startDate: DateTime(2026, 5, 22),
        endDate: DateTime(2026, 5, 22),
      );

      final duration = course.duration;

      expect(duration, 1);
    });

    // ==================== ТЕСТЫ ДЛЯ daysLeftText ====================

    test('TC-COURSE-12: daysLeftText - осталось 5 дней', () {
      final course = createCourse(
        startDate: DateTime(2026, 5, 22),
        endDate: DateTime(2026, 5, 26),
      );

      final text = course.daysLeftText;

      expect(text, 'Осталось 5 дней');
    });


    test('TC-COURSE-13: daysLeftText - однодневный курс (заканчивается сегодня)', () {
      // Устанавливаем тестовую дату на 22 мая
      CourseModel.setTestDate(DateTime(2026, 5, 22));

      final course = createCourse(
        startDate: DateTime(2026, 5, 22),
        endDate: DateTime(2026, 5, 22),
      );

      final text = course.daysLeftText;

      expect(text, 'Заканчивается сегодня');

      // Возвращаем исходную тестовую дату
      CourseModel.setTestDate(DateTime(2026, 5, 22));
    });

    test('TC-COURSE-14: daysLeftText - курс завершён', () {
      final course = createCourse(
        startDate: DateTime(2026, 5, 22),
        endDate: DateTime(2026, 5, 26),
        status: CourseStatus.completed,
      );

      final text = course.daysLeftText;

      expect(text, 'Завершён');
    });

    test('TC-COURSE-15: daysLeftText - курс ещё не начался', () {
      final course = createCourse(
        startDate: DateTime(2026, 5, 26),
        endDate: DateTime(2026, 5, 30),
      );

      final text = course.daysLeftText;

      expect(text, 'Осталось 5 дней');
    });

    // ==================== ТЕСТЫ ДЛЯ isCompleted ====================

    test('TC-COURSE-16: isCompleted - завершённый по статусу (должен быть true)', () {
      final course = createCourse(
        startDate: DateTime(2026, 5, 22),
        endDate: DateTime(2026, 5, 26),
        status: CourseStatus.completed,
      );

      expect(course.isCompleted, true);
    });

    test('TC-COURSE-17: isCompleted - курс с датой окончания в прошлом (должен быть true)', () {
      // Временно меняем тестовую дату на 24 мая
      CourseModel.setTestDate(DateTime(2026, 5, 24));

      final course = createCourse(
        startDate: DateTime(2026, 5, 20),
        endDate: DateTime(2026, 5, 22),
        status: CourseStatus.active,
      );

      expect(course.isCompleted, true);

      // Возвращаем исходную тестовую дату
      CourseModel.setTestDate(DateTime(2026, 5, 22));
    });

    test('TC-COURSE-18: isCompleted - активный курс (должен быть false)', () {
      final course = createCourse(
        startDate: DateTime(2026, 5, 22),
        endDate: DateTime(2026, 5, 26),
        status: CourseStatus.active,
      );

      expect(course.isCompleted, false);
    });

    // ==================== ТЕСТЫ ДЛЯ ДЛИТЕЛЬНЫХ КУРСОВ ====================

    test('TC-COURSE-19: daysLeft - длительный курс (30 дней)', () {
      final course = createCourse(
        startDate: DateTime(2026, 5, 22),
        endDate: DateTime(2026, 6, 20),
      );

      final daysLeft = course.daysLeft;

      expect(daysLeft, 30);
    });

    test('TC-COURSE-20: daysLeftText - длительный курс', () {
      final course = createCourse(
        startDate: DateTime(2026, 5, 22),
        endDate: DateTime(2026, 6, 20),
      );

      final text = course.daysLeftText;

      expect(text, 'Осталось 30 дней');
    });
  });
}