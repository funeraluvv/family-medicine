import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medicine_kit_model.dart';
import '../models/medicine_model.dart';
import 'notification_service.dart';

class MedicineService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Получить все доступные аптечки (личные + семейные) однократно
  static Future<List<MedicineKitModel>> getUserKitsFuture() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    // 1. Личные аптечки
    final personalSnapshot = await _firestore
        .collection('medicine_kits')
        .where('createdBy', isEqualTo: currentUserId)
        .where('type', isEqualTo: 'personal')
        .get();

    final kits = personalSnapshot.docs
        .map((doc) => MedicineKitModel.fromFirestore(doc))
        .toList();

    // 2. Семейные (если пользователь в семье)
    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    final familyId = userDoc.data()?['familyId'] as String?;
    if (familyId != null && familyId.isNotEmpty) {
      final familySnapshot = await _firestore
          .collection('medicine_kits')
          .where('familyId', isEqualTo: familyId)
          .where('type', isEqualTo: 'family')
          .get();
      kits.addAll(familySnapshot.docs
          .map((doc) => MedicineKitModel.fromFirestore(doc))
          .toList());
    }
    return kits;
  }

  /// Получить все аптечки текущего пользователя (личные + семейные)
  static Stream<List<MedicineKitModel>> getUserKits() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _firestore.collection('medicine_kits').snapshots().map((snapshot) {
      final allKits = snapshot.docs.map((doc) => MedicineKitModel.fromFirestore(doc)).toList();

      // Фильтрация аптечек, доступных пользователю
      return allKits.where((kit) {
        final isPersonal = kit.createdBy == currentUserId && kit.type == 'personal';
        final isFamily = kit.type == 'family' && kit.familyId != null;
        return isPersonal || isFamily;
      }).toList();
    });
  }

  /// Получить личные аптечки пользователя
  static Future<List<MedicineKitModel>> getPersonalKits() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    final snapshot = await _firestore
        .collection('medicine_kits')
        .where('createdBy', isEqualTo: currentUserId)
        .where('type', isEqualTo: 'personal')
        .get();

    return snapshot.docs.map((doc) => MedicineKitModel.fromFirestore(doc)).toList();
  }

  /// Создание личной аптечки (по умолчанию)
  static Future<void> ensurePersonalKit() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final existing = await _firestore
        .collection('medicine_kits')
        .where('createdBy', isEqualTo: currentUserId)
        .where('type', isEqualTo: 'personal')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return;

    // Получить имя пользователя
    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    final userName = userDoc.data()?['name'] ?? 'Пользователь';

    await _firestore.collection('medicine_kits').add({
      'name': 'Моя аптечка',
      'description': 'Личная аптечка',
      'colorValue': 0xFFE3F2FD,
      'type': 'personal',
      'createdBy': currentUserId,
      'createdByName': userName,
      'createdAt': FieldValue.serverTimestamp(),
      'medicinesCount': 0,
    });
  }

  /// Создать новую аптечку
  static Future<void> createKit({
    required String name,
    String? description,
    required int colorValue,
    required String type,
    String? familyId,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('Пользователь не авторизован');

    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    final userName = userDoc.data()?['name'] ?? 'Пользователь';

    final kitData = {
      'name': name,
      'description': description,
      'colorValue': colorValue,
      'type': type,
      'createdBy': currentUserId,
      'createdByName': userName,
      'createdAt': FieldValue.serverTimestamp(),
      'medicinesCount': 0,
    };

    if (type == 'family' && familyId != null) {
      kitData['familyId'] = familyId;
    }

    await _firestore.collection('medicine_kits').add(kitData);
  }

  /// Удалить аптечку и все лекарства в ней
  static Future<void> deleteKit(MedicineKitModel kit) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId != kit.createdBy) {
      throw Exception('Вы не можете удалить эту аптечку');
    }

    // Удаляем все лекарства в аптечке
    final medicinesSnapshot = await _firestore
        .collection('medicines')
        .where('kitId', isEqualTo: kit.id)
        .get();

    final batch = _firestore.batch();
    for (final doc in medicinesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_firestore.collection('medicine_kits').doc(kit.id));
    await batch.commit();
  }

  /// Получить все лекарства из аптечки
  static Stream<List<MedicineModel>> getMedicinesByKitStream(String kitId) {
    return _firestore
        .collection('medicines')
        .where('kitId', isEqualTo: kitId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => MedicineModel.fromFirestore(doc))
        .toList());
  }

  /// Получить все лекарства из аптечки (однократно)
  static Future<List<MedicineModel>> getMedicinesByKit(String kitId) async {
    final snapshot = await _firestore
        .collection('medicines')
        .where('kitId', isEqualTo: kitId)
        .orderBy('name')
        .get();

    return snapshot.docs.map((doc) => MedicineModel.fromFirestore(doc)).toList();
  }

  /// Получить одно лекарство по ID
  static Future<MedicineModel?> getMedicine(String medicineId) async {
    final doc = await _firestore.collection('medicines').doc(medicineId).get();
    if (!doc.exists) return null;
    return MedicineModel.fromFirestore(doc);
  }

  /// Добавить лекарство
  static Future<DocumentReference> addMedicine({
    required String kitId,
    required String name,
    required MedicineForm form,
    required double dosage,
    required String dosageUnit,
    required int quantity,
    required DateTime purchaseDate,
    required DateTime expiryDate,
    String? indications,
    String? description,
    String? barcode,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('Пользователь не авторизован');

    // Получить имя пользователя
    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    final userName = userDoc.data()?['name'] ?? 'Пользователь';

    final medicineData = {
      'kitId': kitId,
      'name': name,
      'form': form.name,
      'dosage': dosage,
      'dosageUnit': dosageUnit,
      'quantity': quantity,
      'initialQuantity': quantity,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'indications': indications,
      'description': description,
      'addedDate': FieldValue.serverTimestamp(),
      'addedBy': currentUserId,
      'addedByName': userName,
      'barcode': barcode,
    };

    final docRef = await _firestore.collection('medicines').add(medicineData);

    // Обновление счётчика в аптечке
    await _firestore.collection('medicine_kits').doc(kitId).update({
      'medicinesCount': FieldValue.increment(1),
    });

    //  Планирование уведомления о добавлении лекарства (всем членам семьи)
    await NotificationService.showMedicineAddedNotification(
      medicineName: name,
      addedByUserName: userName,
      kitId: kitId,
    );

    // Планирование уведомлений о сроке годности
    await NotificationService.scheduleExpiryNotification(
      medicineId: docRef.id,
      medicineName: name,
      expiryDate: expiryDate,
    );
    return docRef;
  }

  /// Обновление лекарства
  static Future<void> updateMedicine({
    required String medicineId,
    required String kitId,
    required String name,
    required MedicineForm form,
    required double dosage,
    required String dosageUnit,
    required int quantity,
    required DateTime expiryDate,
    String? description,
    String? barcode,
  }) async {
    final updateData = {
      'name': name,
      'form': form.name,
      'dosage': dosage,
      'dosageUnit': dosageUnit,
      'quantity': quantity,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'description': description,
      'barcode': barcode,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('medicines').doc(medicineId).update(updateData);
  }

  /// Обновить количество лекарства
  static Future<void> updateQuantity({
    required String medicineId,
    required int newQuantity,
  }) async {
    await _firestore.collection('medicines').doc(medicineId).update({
      'quantity': newQuantity,
    });
  }

  /// Удалить лекарство
  static Future<void> deleteMedicine({
    required String medicineId,
    required String kitId,
  }) async {
    await _firestore.collection('medicines').doc(medicineId).delete();

    // Обновляем счётчик в аптечке
    await _firestore.collection('medicine_kits').doc(kitId).update({
      'medicinesCount': FieldValue.increment(-1),
    });
  }

  /// Получить ID семьи текущего пользователя
  static Future<String?> getFamilyId() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return null;

    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    return userDoc.data()?['familyId'] as String?;
  }

  /// Получить имя текущего пользователя
  static Future<String> getUserName() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return 'Пользователь';

    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    return userDoc.data()?['name'] ?? 'Пользователь';
  }
}