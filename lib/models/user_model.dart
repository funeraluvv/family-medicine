import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? familyId;
  final String role; // 'owner' или 'member'
  final DateTime createdAt;
  final String? avatarUrl;
  final DateTime? joinedAt; // когда присоединился к семье

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.familyId,
    this.role = 'member',
    required this.createdAt,
    this.avatarUrl,
    this.joinedAt,
  });

  bool get hasFamily => familyId != null;
  bool get isOwner => role == 'owner';

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? 'Пользователь',
      familyId: data['familyId'],
      role: data['role'] ?? 'member',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      avatarUrl: data['avatarUrl'],
      joinedAt: data['joinedAt'] != null
          ? (data['joinedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'familyId': familyId,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'joinedAt': joinedAt != null ? Timestamp.fromDate(joinedAt!) : null,
    };
  }
}