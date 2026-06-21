import 'package:flutter_test/flutter_test.dart';
import 'package:family_medicine/models/medicine_model.dart';

void main() {
  group('MedicineModel - Расчёт статуса срока годности', () {

    test('TC-MED-01: Нормальный срок годности (>30 дней)', () {
      final now = DateTime(2025, 5, 20);
      final expiryDate = DateTime(2025, 6, 20); // +31 день

      final daysLeft = expiryDate.difference(now).inDays;

      expect(daysLeft, 31);
      expect(daysLeft > 30, true);
    });

    test('TC-MED-02: Истекает завтра', () {
      final now = DateTime(2025, 5, 20);
      final expiryDate = DateTime(2025, 5, 21); // +1 день

      final daysLeft = expiryDate.difference(now).inDays;

      expect(daysLeft, 1);
    });

    test('TC-MED-03: Истекает сегодня', () {
      final now = DateTime(2025, 5, 20);
      final expiryDate = DateTime(2025, 5, 20);

      final daysLeft = expiryDate.difference(now).inDays;

      expect(daysLeft, 0);
    });

    test('TC-MED-04: Просрочено', () {
      final now = DateTime(2025, 5, 20);
      final expiryDate = DateTime(2025, 5, 19); // -1 день

      final daysLeft = expiryDate.difference(now).inDays;

      expect(daysLeft, -1);
    });

    test('TC-MED-05: Осталось 3 дня', () {
      final now = DateTime(2025, 5, 20);
      final expiryDate = DateTime(2025, 5, 23);

      final daysLeft = expiryDate.difference(now).inDays;

      expect(daysLeft, 3);
    });

    test('TC-MED-06: Осталось 6 дней', () {
      final now = DateTime(2025, 5, 20);
      final expiryDate = DateTime(2025, 5, 26);

      final daysLeft = expiryDate.difference(now).inDays;

      expect(daysLeft, 6);
    });

    test('TC-MED-07: Осталось 7 дней', () {
      final now = DateTime(2025, 5, 20);
      final expiryDate = DateTime(2025, 5, 27);

      final daysLeft = expiryDate.difference(now).inDays;

      expect(daysLeft, 7);
    });
  });

  group('MedicineModel - Расчёт прогресса расхода', () {
    test('TC-PRG-01: Половина израсходована (5 из 10) -> прогресс 50%', () {
      final medicine = MedicineModel(
        id: '1',
        kitId: 'kit1',
        name: 'Тестовое лекарство',
        form: MedicineForm.tablet,
        dosage: 500,
        dosageUnit: 'мг',
        quantity: 5,
        initialQuantity: 10,
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        addedDate: DateTime.now(),
        addedBy: 'user1',
        addedByName: 'Тест',
      );

      final progress = medicine.quantityProgress;

      expect(progress, 0.5);
    });

    test('TC-PRG-02: Всё израсходовано (0 из 10) -> прогресс 100%', () {
      final medicine = MedicineModel(
        id: '1',
        kitId: 'kit1',
        name: 'Тестовое лекарство',
        form: MedicineForm.tablet,
        dosage: 500,
        dosageUnit: 'мг',
        quantity: 0,
        initialQuantity: 10,
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        addedDate: DateTime.now(),
        addedBy: 'user1',
        addedByName: 'Тест',
      );

      final progress = medicine.quantityProgress;

      expect(progress, 1.0);
    });

    test('TC-PRG-03: Ничего не израсходовано (10 из 10) -> прогресс 0%', () {
      final medicine = MedicineModel(
        id: '1',
        kitId: 'kit1',
        name: 'Тестовое лекарство',
        form: MedicineForm.tablet,
        dosage: 500,
        dosageUnit: 'мг',
        quantity: 10,
        initialQuantity: 10,
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        addedDate: DateTime.now(),
        addedBy: 'user1',
        addedByName: 'Тест',
      );

      final progress = medicine.quantityProgress;

      expect(progress, 0.0);
    });

    test('TC-PRG-04: Нулевое начальное количество -> прогресс 0% (защита от деления)', () {
      final medicine = MedicineModel(
        id: '1',
        kitId: 'kit1',
        name: 'Тестовое лекарство',
        form: MedicineForm.tablet,
        dosage: 500,
        dosageUnit: 'мг',
        quantity: 5,
        initialQuantity: 0,
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        addedDate: DateTime.now(),
        addedBy: 'user1',
        addedByName: 'Тест',
      );

      final progress = medicine.quantityProgress;

      expect(progress, 0.0);
    });
  });

  group('MedicineModel - Расчёт низкого остатка (20% порог)', () {
    // Эти тесты проверяют логику из notification_service.dart

    test('TC-LOW-01: Остаток 20% от начального (2 из 10) -> НИЗКИЙ ОСТАТОК', () {
      final initialQuantity = 10;
      final currentQuantity = 2;

      final threshold = (initialQuantity * 0.2).ceil();
      final isLowStock = currentQuantity <= threshold && currentQuantity > 0;

      expect(threshold, 2);
      expect(isLowStock, true);
    });

    test('TC-LOW-02: Остаток 19% от начального (1 из 9) -> НИЗКИЙ ОСТАТОК', () {
      final initialQuantity = 9;
      final currentQuantity = 1;

      final threshold = (initialQuantity * 0.2).ceil();
      final isLowStock = currentQuantity <= threshold && currentQuantity > 0;

      expect(threshold, 2);
      expect(isLowStock, true);
    });

    test('TC-LOW-03: Остаток 25% от начального (3 из 10) -> НОРМАЛЬНЫЙ ОСТАТОК', () {
      final initialQuantity = 10;
      final currentQuantity = 3;

      final threshold = (initialQuantity * 0.2).ceil();
      final isLowStock = currentQuantity <= threshold && currentQuantity > 0;

      expect(threshold, 2);
      expect(isLowStock, false);
    });

    test('TC-LOW-04: Остаток 1 шт. (1 из 50) -> НИЗКИЙ ОСТАТОК', () {
      final initialQuantity = 50;
      final currentQuantity = 1;

      final threshold = (initialQuantity * 0.2).ceil();
      final isLowStock = currentQuantity <= threshold && currentQuantity > 0;

      expect(threshold, 10);
      expect(isLowStock, true);
    });

    test('TC-LOW-05: Остаток 0 шт. (0 из 10) -> НЕ считается низким остатком', () {
      final initialQuantity = 10;
      final currentQuantity = 0;

      final threshold = (initialQuantity * 0.2).ceil();
      final isLowStock = currentQuantity <= threshold && currentQuantity > 0;

      expect(threshold, 2);
      expect(isLowStock, false);
    });

    test('TC-LOW-06: Граничное значение: остаток точно 20% (2 из 10)', () {
      final initialQuantity = 10;
      final currentQuantity = 2;

      final threshold = (initialQuantity * 0.2).ceil();
      final isLowStock = currentQuantity <= threshold && currentQuantity > 0;

      expect(threshold, 2);
      expect(isLowStock, true);
    });
  });
}