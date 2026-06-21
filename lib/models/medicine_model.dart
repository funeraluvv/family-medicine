import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum MedicineForm {
  tablet('Таблетки'),
  capsule('Капсулы'),
  syrup('Сироп'),
  ointment('Мазь'),
  spray('Спрей'),
  drops('Капли'),
  powder('Порошок'),
  ampoule('Ампулы'),
  other('Другое');

  final String label;
  const MedicineForm(this.label);

  static MedicineForm fromString(String value) {
    return values.firstWhere(
          (e) => e.name == value,
      orElse: () => MedicineForm.other,
    );
  }
}

class MedicineModel {
  final String id;
  final String kitId; // ID аптечки
  final String name;
  final MedicineForm form;
  final double dosage;
  final String dosageUnit; // мг, мл, г, шт
  final int quantity;
  final int initialQuantity; // для расчета прогресса
  final DateTime expiryDate;
  final DateTime addedDate;
  final String? description;
  final String addedBy;
  final String addedByName;
  final String? barcode; // для будущего сканирования

  MedicineModel({
    required this.id,
    required this.kitId,
    required this.name,
    required this.form,
    required this.dosage,
    required this.dosageUnit,
    required this.quantity,
    required this.initialQuantity,
    required this.expiryDate,
    required this.addedDate,
    this.description,
    required this.addedBy,
    required this.addedByName,
    this.barcode,
  });

  // Прогресс-бар (сколько осталось до срока годности)
  double get expiryProgress {
    final total = expiryDate.difference(addedDate).inDays;
    final passed = DateTime.now().difference(addedDate).inDays;
    if (passed >= total) return 1.0; // просрочено
    if (passed <= 0) return 0.0;
    return passed / total;
  }

  // Цвет в зависимости от срока годности
  Color get expiryColor {
    final daysLeft = expiryDate.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return Colors.red.shade100; // просрочено
    if (daysLeft < 30) return Colors.orange.shade100; // скоро истекает
    if (daysLeft < 90) return Colors.yellow.shade100; // нормально
    return Colors.green.shade100; // свежее
  }

  // Статус
  String get expiryStatus {
    final daysLeft = expiryDate.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return 'Просрочено';
    if (daysLeft == 0) return 'Истекает сегодня';
    if (daysLeft == 1) return 'Истекает завтра';
    if (daysLeft < 30) return 'Осталось $daysLeft дн.';
    return 'Годен до ${expiryDate.day}.${expiryDate.month}.${expiryDate.year}';
  }

  // Количество в процентах
  double get quantityProgress {
    if (initialQuantity == 0) return 0.0;
    return (initialQuantity - quantity) / initialQuantity;
  }

  factory MedicineModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MedicineModel(
      id: doc.id,
      kitId: data['kitId'] ?? '',
      name: data['name'] ?? '',
      form: MedicineForm.fromString(data['form'] ?? 'other'),
      dosage: (data['dosage'] ?? 0.0).toDouble(),
      dosageUnit: data['dosageUnit'] ?? 'шт',
      quantity: data['quantity'] ?? 0,
      initialQuantity: data['initialQuantity'] ?? data['quantity'] ?? 0,
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      addedDate: (data['addedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: data['description'],
      addedBy: data['addedBy'] ?? '',
      addedByName: data['addedByName'] ?? 'Неизвестно',
      barcode: data['barcode'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'kitId': kitId,
      'name': name,
      'form': form.name,
      'dosage': dosage,
      'dosageUnit': dosageUnit,
      'quantity': quantity,
      'initialQuantity': initialQuantity,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'addedDate': Timestamp.fromDate(addedDate),
      'description': description,
      'addedBy': addedBy,
      'addedByName': addedByName,
      'barcode': barcode,
    };
  }
}

extension MedicineFormExtension on MedicineForm {
  /// Путь к SVG-иконке
  String get svgPath {
    switch (this) {
      case MedicineForm.tablet:
        return 'assets/icons/tablet.svg';
      case MedicineForm.capsule:
        return 'assets/icons/capsule.svg';
      case MedicineForm.syrup:
        return 'assets/icons/syrup.svg';
      case MedicineForm.ointment:
        return 'assets/icons/ointment.svg';
      case MedicineForm.spray:
        return 'assets/icons/spray.svg';
      case MedicineForm.drops:
        return 'assets/icons/drops.svg';
      case MedicineForm.powder:
        return 'assets/icons/powder.svg';
      case MedicineForm.ampoule:
        return 'assets/icons/ampoule.svg';
      case MedicineForm.other:
        return 'assets/icons/other.svg';
    }
  }

  /// Цвет для формы
  Color get color {
    switch (this) {
      case MedicineForm.tablet:
        return Colors.blue;
      case MedicineForm.capsule:
        return Colors.purple;
      case MedicineForm.syrup:
        return Colors.orange;
      case MedicineForm.ointment:
        return Colors.teal;
      case MedicineForm.spray:
        return Colors.cyan;
      case MedicineForm.drops:
        return Colors.indigo;
      case MedicineForm.powder:
        return Colors.brown;
      case MedicineForm.ampoule:
        return Colors.pink;
      case MedicineForm.other:
        return Colors.grey;
    }
  }

  /// Короткое название для карточки
  String get shortName {
    switch (this) {
      case MedicineForm.tablet:
        return 'Таблетки';
      case MedicineForm.capsule:
        return 'Капсулы';
      case MedicineForm.syrup:
        return 'Сироп';
      case MedicineForm.ointment:
        return 'Мазь';
      case MedicineForm.spray:
        return 'Спрей';
      case MedicineForm.drops:
        return 'Капли';
      case MedicineForm.powder:
        return 'Порошок';
      case MedicineForm.ampoule:
        return 'Ампулы';
      case MedicineForm.other:
        return 'Другое';
    }
  }
}