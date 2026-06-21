// test/widget/medicine_detail_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_medicine/models/medicine_model.dart';
import 'package:family_medicine/features/medicines/medicine_detail_screen.dart';
import '../ widget_test_utils.dart';

void main() {
  group('Тестирование экрана детализации лекарства', () {

    // Создаём тестовое лекарство
    final testMedicine = MedicineModel(
      id: '1',
      kitId: 'kit1',
      name: 'Аспирин',
      form: MedicineForm.tablet,
      dosage: 500,
      dosageUnit: 'мг',
      quantity: 10,
      initialQuantity: 10,
      expiryDate: DateTime.now().add(const Duration(days: 365)),
      addedDate: DateTime.now(),
      addedBy: 'user1',
      addedByName: 'Тестовый пользователь',
      description: 'Для снижения температуры и боли',
    );

    // ==================== TC-DETAIL-01: Отображение названия лекарства ====================

    testWidgets('TC-DETAIL-01: Отображение названия лекарства', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicineDetailScreen(
              medicine: testMedicine,
              kitColor: Colors.blue,
            ),
          ),
        ),
      );
      await WidgetTestUtils.delay(tester);

      // Проверка названия лекарства (это точно должно быть)
      expect(find.text('Аспирин'), findsOneWidget);

      // Проверка кнопок (они всегда есть)
      expect(find.text('Редактировать'), findsOneWidget);
      expect(find.text('Удалить'), findsOneWidget);

      print('✅ TC-DETAIL-01: Название и кнопки отображаются');
    });

    // ==================== TC-DETAIL-02: Отображение количества лекарства ====================

    testWidgets('TC-DETAIL-02: Отображение количества лекарства', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicineDetailScreen(
              medicine: testMedicine,
              kitColor: Colors.blue,
            ),
          ),
        ),
      );
      await WidgetTestUtils.delay(tester);

      // Проверка количества
      expect(find.text('10 шт'), findsOneWidget);

      print('✅ TC-DETAIL-02: Количество лекарства отображается');
    });

    // ==================== TC-DETAIL-03: Отображение статуса срока годности ====================

    testWidgets('TC-DETAIL-03: Отображение статуса срока годности', (tester) async {
      // Лекарство с нормальным сроком (>180 дней)
      final normalMedicine = MedicineModel(
        id: '1',
        kitId: 'kit1',
        name: 'Аспирин',
        form: MedicineForm.tablet,
        dosage: 500,
        dosageUnit: 'мг',
        quantity: 10,
        initialQuantity: 10,
        expiryDate: DateTime.now().add(const Duration(days: 200)),
        addedDate: DateTime.now(),
        addedBy: 'user1',
        addedByName: 'Тест',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicineDetailScreen(
              medicine: normalMedicine,
              kitColor: Colors.blue,
            ),
          ),
        ),
      );
      await WidgetTestUtils.delay(tester);

      // Проверка статуса "Норма"
      expect(find.text('Норма'), findsOneWidget);

      print('✅ TC-DETAIL-03: Статус срока годности отображается');
    });

    // ==================== TC-DETAIL-04: Отображение просроченного лекарства ====================

    testWidgets('TC-DETAIL-04: Отображение просроченного лекарства', (tester) async {
      final expiredMedicine = MedicineModel(
        id: '1',
        kitId: 'kit1',
        name: 'Просроченное лекарство',
        form: MedicineForm.tablet,
        dosage: 500,
        dosageUnit: 'мг', quantity: 5, initialQuantity: 10,
        expiryDate: DateTime.now().subtract(const Duration(days: 10)),
        addedDate: DateTime.now(),
        addedBy: 'user1',
        addedByName: 'Тест',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicineDetailScreen(
              medicine: expiredMedicine,
              kitColor: Colors.blue,
            ),
          ),
        ),
      );
      await WidgetTestUtils.delay(tester);
      expect(find.text('Просрочено'), findsOneWidget);
      print(' TC-DETAIL-04: Просроченное лекарство отображается корректно');
    });
  });
}