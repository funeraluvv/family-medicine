// services/family_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FamilyService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Генерация 6-значного кода приглашения
  static String generateInviteCode() {
    return (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
  }

  /// Получение ID семьи текущего пользователя
  static Future<String?> getFamilyId() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return null;

    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    return userDoc.data()?['familyId'] as String?;
  }

  /// Получение роли пользователя в семье
  static Future<String?> getUserRole() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return null;

    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    return userDoc.data()?['role'] as String? ?? 'member';
  }

  /// Получение данных семьи по ID
  static Future<DocumentSnapshot> getFamily(String familyId) async {
    return await _firestore.collection('families').doc(familyId).get();
  }

  /// Получение потока данных семьи в реальном времени
  static Stream<DocumentSnapshot> streamFamily(String familyId) {
    return _firestore.collection('families').doc(familyId).snapshots();
  }

  /// Создание новой семьи
  static Future<Map<String, dynamic>> createFamily(String familyName) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final inviteCode = generateInviteCode();
    final familyRef = await _firestore.collection('families').add({
      'name': familyName,
      'inviteCode': inviteCode,
      'ownerId': currentUserId,
      'memberIds': [currentUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': null,
    });

    await _firestore.collection('users').doc(currentUserId).update({
      'familyId': familyRef.id,
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return {
      'familyId': familyRef.id,
      'inviteCode': inviteCode,
      'familyName': familyName,
    };
  }

  /// Присоединение к семье по коду приглашения
  static Future<Map<String, dynamic>> joinFamilyByCode(String code) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('Пользователь не авторизован');
    }

    // Поиск семьи по коду
    final familyQuery = await _firestore
        .collection('families')
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();

    if (familyQuery.docs.isEmpty) {
      throw Exception('Неверный код приглашения');
    }

    final familyDoc = familyQuery.docs.first;
    final familyData = familyDoc.data();

    // Проверка срока действия кода
    if (familyData['expiresAt'] != null) {
      final expiresAt = (familyData['expiresAt'] as Timestamp).toDate();
      if (expiresAt.isBefore(DateTime.now())) {
        throw Exception('Код приглашения истек');
      }
    }

    // Проверка, не состоит ли пользователь уже в семье
    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    if (userDoc.data()?['familyId'] != null) {
      throw Exception('Вы уже состоите в семье');
    }

    final batch = _firestore.batch();
    final currentMemberIds = List<String>.from(familyData['memberIds'] ?? []);

    batch.update(familyDoc.reference, {
      'memberIds': [...currentMemberIds, currentUserId]
    });

    batch.update(_firestore.collection('users').doc(currentUserId), {
      'familyId': familyDoc.id,
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return {
      'familyId': familyDoc.id,
      'familyName': familyData['name'] ?? 'Семья',
    };
  }

  /// Покинуть семью
  static Future<void> leaveFamily() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    final familyId = userDoc.data()?['familyId'] as String?;

    if (familyId == null) {
      throw Exception('Вы не состоите в семье');
    }

    final batch = _firestore.batch();

    final familyDoc = await _firestore.collection('families').doc(familyId).get();
    if (familyDoc.exists) {
      final familyData = familyDoc.data()!;
      final currentMemberIds = List<String>.from(familyData['memberIds'] ?? []);
      batch.update(familyDoc.reference, {
        'memberIds': currentMemberIds.where((id) => id != currentUserId).toList()
      });
    }

    batch.update(_firestore.collection('users').doc(currentUserId), {
      'familyId': null,
      'role': 'member',
      'joinedAt': null,
    });

    await batch.commit();
  }

  /// Удаление участника из семьи (только для владельца)
  static Future<void> removeFamilyMember(String memberId, String memberName) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    final familyId = userDoc.data()?['familyId'] as String?;

    if (familyId == null) {
      throw Exception('Вы не состоите в семье');
    }

    // Проверка, является ли текущий пользователь владельцем
    final currentRole = userDoc.data()?['role'] as String?;
    if (currentRole != 'owner') {
      throw Exception('Только владелец семьи может удалять участников');
    }

    final batch = _firestore.batch();

    final familyDoc = await _firestore.collection('families').doc(familyId).get();
    if (familyDoc.exists) {
      final familyData = familyDoc.data()!;
      final currentMemberIds = List<String>.from(familyData['memberIds'] ?? []);
      batch.update(familyDoc.reference, {
        'memberIds': currentMemberIds.where((id) => id != memberId).toList(),
      });
    }

    batch.update(_firestore.collection('users').doc(memberId), {
      'familyId': null,
      'role': 'member',
      'joinedAt': null,
    });

    await batch.commit();
  }

  /// Обновление кода приглашения
  static Future<String> regenerateInviteCode(String familyId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final newCode = generateInviteCode();

    await _firestore.collection('families').doc(familyId).update({
      'inviteCode': newCode,
      'expiresAt': null,
    });

    return newCode;
  }

  /// Получение списка участников семьи с данными пользователей
  static Future<List<Map<String, dynamic>>> getFamilyMembers(String familyId) async {
    final familyDoc = await _firestore.collection('families').doc(familyId).get();

    if (!familyDoc.exists) {
      return [];
    }

    final familyData = familyDoc.data()!;
    final memberIds = List<String>.from(familyData['memberIds'] ?? []);

    if (memberIds.isEmpty) {
      return [];
    }

    // Разбиваем на чанки по 10 (ограничение Firestore whereIn)
    final chunks = <List<String>>[];
    for (var i = 0; i < memberIds.length; i += 10) {
      chunks.add(memberIds.sublist(i, i + 10 > memberIds.length ? memberIds.length : i + 10));
    }

    final allMembers = <Map<String, dynamic>>[];

    for (final chunk in chunks) {
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        allMembers.add({
          'id': doc.id,
          'name': data['name'] ?? 'Пользователь',
          'role': data['role'] ?? 'member',
          'avatarUrl': data['avatarUrl'],
          'email': data['email'],
          'joinedAt': data['joinedAt'],
        });
      }
    }

    // Сортировка: владельцы первые
    allMembers.sort((a, b) {
      if (a['role'] == 'owner' && b['role'] != 'owner') return -1;
      if (a['role'] != 'owner' && b['role'] == 'owner') return 1;
      return (a['name'] ?? '').compareTo(b['name'] ?? '');
    });

    return allMembers;
  }

  /// Получение потока участников семьи в реальном времени
  static Stream<List<Map<String, dynamic>>> streamFamilyMembers(String familyId) {
    return _firestore.collection('families').doc(familyId).snapshots().asyncMap((familyDoc) async {
      if (!familyDoc.exists) return [];

      final familyData = familyDoc.data()!;
      final memberIds = List<String>.from(familyData['memberIds'] ?? []);

      if (memberIds.isEmpty) return [];

      final chunks = <List<String>>[];
      for (var i = 0; i < memberIds.length; i += 10) {
        chunks.add(memberIds.sublist(i, i + 10 > memberIds.length ? memberIds.length : i + 10));
      }

      final allMembers = <Map<String, dynamic>>[];

      for (final chunk in chunks) {
        final snapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          allMembers.add({
            'id': doc.id,
            'name': data['name'] ?? 'Пользователь',
            'role': data['role'] ?? 'member',
            'avatarUrl': data['avatarUrl'],
            'email': data['email'],
            'joinedAt': data['joinedAt'],
          });
        }
      }

      allMembers.sort((a, b) {
        if (a['role'] == 'owner' && b['role'] != 'owner') return -1;
        if (a['role'] != 'owner' && b['role'] == 'owner') return 1;
        return (a['name'] ?? '').compareTo(b['name'] ?? '');
      });

      return allMembers;
    });
  }

  /// Проверка, является ли пользователь владельцем семьи
  static Future<bool> isFamilyOwner() async {
    final role = await getUserRole();
    return role == 'owner';
  }

  /// Проверка, состоит ли пользователь в семье
  static Future<bool> isInFamily() async {
    final familyId = await getFamilyId();
    return familyId != null && familyId.isNotEmpty;
  }
}