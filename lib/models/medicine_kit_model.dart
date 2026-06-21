import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MedicineKitModel {
  final String id;
  final String name;
  final String? description;
  final int colorValue; // сохраняем как int
  final String type; // 'personal' или 'family'
  final String? familyId; // null для личных
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final int medicinesCount;

  MedicineKitModel({
    required this.id,
    required this.name,
    this.description,
    required this.colorValue,
    required this.type,
    this.familyId,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.medicinesCount = 0,
  });

  Color get color => Color(colorValue);

  factory MedicineKitModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MedicineKitModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      colorValue: data['colorValue'] ?? 0xFFE3F2FD,
      type: data['type'] ?? 'personal',
      familyId: data['familyId'],
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'] ?? 'Неизвестно',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      medicinesCount: data['medicinesCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'colorValue': colorValue,
      'type': type,
      'familyId': familyId,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'medicinesCount': medicinesCount,
    };
  }
}