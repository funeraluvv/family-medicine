
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_medicine/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:url_launcher/url_launcher.dart';
import 'package:family_medicine/features/auth/privacy_policy_screen.dart';
import 'package:family_medicine/services/notification_service.dart';
import 'package:family_medicine/services/notification_settings_service.dart';
import 'package:family_medicine/services/family_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:family_medicine/providers/theme_provider.dart';
import 'package:family_medicine/models/theme_model.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  User? get currentUser => FirebaseAuth.instance.currentUser;

  bool isScanning = false;

  // ============ НАСТРОЙКИ УВЕДОМЛЕНИЙ ============
  bool remindersEnabled = true;
  bool expiryNotifications = true;
  bool lowStockNotifications = true;
  bool familyActionNotifications = true;

  // Тихий час
  TimeOfDay? quietHourStart;
  TimeOfDay? quietHourEnd;
  bool quietHoursEnabled = false;

  // Повторные напоминания
  int repeatIntervalMinutes = 15;
  int maxRepeatCount = 3;

  // Настройки звука
  bool soundEnabled = true;
  bool vibrationEnabled = true;

  // Настройки семьи
  bool notifyOnFamilyTaken = true;
  bool notifyOnFamilyMissed = true;
  bool notifyOnFamilyAdded = true;
  bool notifyOnFamilyRemoved = true;

  // Другие настройки
  String selectedTheme = 'light';
  String selectedFontSize = 'medium';

  // Данные пользователя
  Map<String, dynamic>? userData;
  bool isLoading = true;

  // Список доступных аватарок
  final List<String> avatarPaths = [
    'assets/avatars/avatar1.png',
    'assets/avatars/avatar2.png',
    'assets/avatars/avatar3.png',
    'assets/avatars/avatar4.png',
    'assets/avatars/avatar5.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
    _loadUserData();
  }

  Future<void> _loadAllSettings() async {
    remindersEnabled = LocalSettingsService.medicationReminders;
    expiryNotifications = LocalSettingsService.expiryNotifications;
    lowStockNotifications = LocalSettingsService.lowStockNotifications;

    quietHoursEnabled = LocalSettingsService.quietHoursEnabled;
    quietHourStart = TimeOfDay(hour: LocalSettingsService.quietHoursStart, minute: 0);
    quietHourEnd = TimeOfDay(hour: LocalSettingsService.quietHoursEnd, minute: 0);

    repeatIntervalMinutes = LocalSettingsService.repeatIntervalMinutes;
    maxRepeatCount = LocalSettingsService.repeatCount;

    soundEnabled = LocalSettingsService.soundEnabled;
    vibrationEnabled = LocalSettingsService.vibrationEnabled;

    notifyOnFamilyTaken = LocalSettingsService.notifyOnFamilyTaken;
    notifyOnFamilyMissed = LocalSettingsService.notifyOnFamilyMissed;
    notifyOnFamilyAdded = LocalSettingsService.notifyOnFamilyAdded;
    notifyOnFamilyRemoved = LocalSettingsService.notifyOnFamilyRemoved;

    familyActionNotifications = notifyOnFamilyTaken || notifyOnFamilyMissed;

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedTheme = prefs.getString('theme') ?? 'light';
      selectedFontSize = prefs.getString('fontSize') ?? 'medium';
    });
  }

  // ============ СОХРАНЕНИЕ НАСТРОЕК ============
  Future<void> _saveNotificationSettings() async {
    await LocalSettingsService.setMedicationReminders(remindersEnabled);
    await LocalSettingsService.setExpiryNotifications(expiryNotifications);
    await LocalSettingsService.setLowStockNotifications(lowStockNotifications);
    await LocalSettingsService.setQuietHoursEnabled(quietHoursEnabled);
    await LocalSettingsService.setQuietHoursTime(
      start: quietHourStart?.hour ?? 23,
      end: quietHourEnd?.hour ?? 7,
    );
    await LocalSettingsService.setRepeatCount(maxRepeatCount);
    await LocalSettingsService.setRepeatIntervalMinutes(repeatIntervalMinutes);
    await LocalSettingsService.setSoundEnabled(soundEnabled);
    await LocalSettingsService.setVibrationEnabled(vibrationEnabled);
    await LocalSettingsService.setNotifyOnFamilyTaken(notifyOnFamilyTaken);
    await LocalSettingsService.setNotifyOnFamilyMissed(notifyOnFamilyMissed);
    await LocalSettingsService.setNotifyOnFamilyAdded(notifyOnFamilyAdded);
    await LocalSettingsService.setNotifyOnFamilyRemoved(notifyOnFamilyRemoved);
  }

  Future<void> _loadUserData() async {
    if (currentUser == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();
    setState(() {
      userData = doc.data();
      isLoading = false;
    });
  }

  Future<void> _updateFontSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fontSize', size);
    setState(() => selectedFontSize = size);
  }

  double _getFontScale() {
    switch (selectedFontSize) {
      case 'small': return 0.85;
      case 'large': return 1.15;
      default: return 1.0;
    }
  }

  bool _isQuietHoursNow() {
    final now = DateTime.now();
    return now.hour >= 23 || now.hour < 7;
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка выхода: $e')));
    }
  }

  Future<void> _deleteAccount() async {
    final user = currentUser;
    if (user == null) return;
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Удаление аккаунта'),
          content: const Text('Вы уверены? Это действие необратимо. Все ваши данные будут удалены.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (confirm != true) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      await user.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Аккаунт удален')));
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      String message = 'Ошибка при удалении';
      if (e.code == 'requires-recent-login') message = 'Требуется повторный вход. Выйдите и зайдите снова.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  // ================= ДИАЛОГ РЕДАКТИРОВАНИЯ ПРОФИЛЯ =================
  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: userData?['name'] ?? '');
    String? selectedAvatarPath = userData?['avatarUrl'] as String?;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Редактировать профиль', style: Theme.of(context).textTheme.titleLarge),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _showAvatarSelection(context, (newPath) {
                      setStateDialog(() => selectedAvatarPath = newPath);
                    }, selectedAvatarPath),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 45,
                          backgroundImage: selectedAvatarPath != null && selectedAvatarPath!.isNotEmpty
                              ? AssetImage(selectedAvatarPath!) as ImageProvider
                              : null,
                          backgroundColor: Colors.grey.shade300,
                          child: (selectedAvatarPath == null || selectedAvatarPath!.isEmpty)
                              ? Text(nameController.text.isNotEmpty ? nameController.text[0].toUpperCase() : '?', style: const TextStyle(fontSize: 32, color: Colors.white))
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.edit, size: 18, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setStateDialog(() => selectedAvatarPath = null),
                    child: const Text('Сбросить аватарку', style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Имя', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
              ElevatedButton(
                onPressed: () async {
                  final newName = nameController.text.trim();
                  if (newName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Имя не может быть пустым')));
                    return;
                  }
                  final updateData = <String, dynamic>{'name': newName};
                  if (selectedAvatarPath != null && selectedAvatarPath!.isNotEmpty) {
                    updateData['avatarUrl'] = selectedAvatarPath;
                  } else {
                    updateData['avatarUrl'] = null;
                  }
                  await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update(updateData);
                  await _loadUserData();
                  if (mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Профиль обновлён'), backgroundColor: Colors.green));
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAvatarSelection(BuildContext context, Function(String) onSelect, String? currentPath) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Выберите аватарку', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1),
              itemCount: avatarPaths.length,
              itemBuilder: (context, index) {
                final path = avatarPaths[index];
                final isSelected = (currentPath == path);
                return GestureDetector(
                  onTap: () { onSelect(path); Navigator.pop(context); },
                  child: Stack(
                    children: [
                      CircleAvatar(radius: 30, backgroundImage: AssetImage(path)),
                      if (isSelected)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(Icons.check, size: 16, color: Colors.white)),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================= УПРАВЛЕНИЕ СЕМЬЕЙ =================

  Future<void> _createFamily(String familyName) async {
    try {
      final result = await FamilyService.createFamily(familyName);
      if (!mounted) return;
      _showInviteCodeDialog(result['inviteCode'], result['familyName']);
      await _loadUserData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _joinFamilyByCode(String code) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Присоединение к семье...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final result = await FamilyService.joinFamilyByCode(code);
      if (!mounted) return;
      await _loadUserData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Вы присоединились к семье "${result['familyName']}"!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _regenerateInviteCode(String familyId) async {
    try {
      final newCode = await FamilyService.regenerateInviteCode(familyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Новый код сгенерирован'), backgroundColor: Colors.green),
      );
      // Обновляем диалог с новым кодом
      final familyDoc = await FamilyService.getFamily(familyId);
      final familyData = familyDoc.data() as Map<String, dynamic>?;
      final familyName = familyData?['name'] as String? ?? 'Семья';
      _showInviteCodeDialog(newCode, familyName);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _leaveFamily() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Покинуть семью'),
        content: const Text('Вы уверены, что хотите покинуть семью?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Покинуть', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FamilyService.leaveFamily();
      if (!mounted) return;
      await _loadUserData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Вы покинули семью'), backgroundColor: Colors.green),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _removeFamilyMember(String memberId, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить участника'),
        content: Text('Вы уверены, что хотите удалить "$memberName" из семьи?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FamilyService.removeFamilyMember(memberId, memberName);
      if (!mounted) return;
      await _loadUserData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(' Участник удалён из семьи'), backgroundColor: Colors.green),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ================= QR-ФУНКЦИИ =================
  Future<void> _checkCameraPermission() async {
    final status = await perm.Permission.camera.request();
    if (status.isGranted) {
      _startQRScan();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Необходимо разрешение на использование камеры')));
    }
  }

  void _startQRScan() {
    setState(() => isScanning = true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Сканируйте QR-код', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Наведите камеру на QR-код приглашения', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        Navigator.pop(context);
                        _joinFamilyByCode(barcode.rawValue!);
                        setState(() => isScanning = false);
                        break;
                      }
                    }
                  },
                  controller: MobileScannerController(detectionSpeed: DetectionSpeed.normal, facing: CameraFacing.back),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: () { Navigator.pop(context); setState(() => isScanning = false); }, child: const Text('Отмена')),
          ],
        ),
      ),
    );
  }

  void _showInviteCodeDialog(String code, String familyName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 350),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Код приглашения', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Семья: $familyName', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                  child: QrImageView(data: code, version: QrVersions.auto, size: 200.0, gapless: false),
                ),
                const SizedBox(height: 16),
                Row(children: [const Expanded(child: Divider()), const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('ИЛИ')), const Expanded(child: Divider())]),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400)),
                  child: SelectableText(code, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4)),
                ),
                const SizedBox(height: 8),
                const Text('Покажите этот код или QR-код тому, кого хотите пригласить', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.of(context).pop(), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), child: const Text('Закрыть'))),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreateFamilyDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать семью'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: controller, decoration: const InputDecoration(labelText: 'Название семьи', prefixIcon: Icon(Icons.family_restroom))),
            const SizedBox(height: 16),
            const Text('Вы станете владельцем семьи и сможете приглашать других участников', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(onPressed: () async {
            final name = controller.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите название семьи')));
              return;
            }
            await _createFamily(name);
            if (mounted) Navigator.pop(context);
          }, child: const Text('Создать')),
        ],
      ),
    );
  }

  void _showEnterCodeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ввести код'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Код приглашения', hintText: '000000', prefixIcon: Icon(Icons.qr_code)), keyboardType: TextInputType.number, maxLength: 6),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(onPressed: () async {
            final code = controller.text.trim();
            if (code.length != 6) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите 6-значный код')));
              return;
            }
            await _joinFamilyByCode(code);
            if (mounted) Navigator.pop(context);
          }, child: const Text('Присоединиться')),
        ],
      ),
    );
  }

  void _showJoinOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.qr_code_scanner, color: Colors.white)), title: const Text('Отсканировать QR-код'), subtitle: const Text('Наведите камеру на код владельца семьи'), onTap: () { Navigator.pop(context); _checkCameraPermission(); }),
            ListTile(leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.keyboard, color: Colors.white)), title: const Text('Ввести код вручную'), subtitle: const Text('6-значный код приглашения'), onTap: () { Navigator.pop(context); _showEnterCodeDialog(); }),
          ],
        ),
      ),
    );
  }

  // ================= ДИАЛОГ РАСШИРЕННЫХ НАСТРОЕК УВЕДОМЛЕНИЙ =================
  void _showNotificationSettingsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          var localSoundEnabled = soundEnabled;
          var localVibrationEnabled = vibrationEnabled;
          var localNotifyOnFamilyTaken = notifyOnFamilyTaken;
          var localNotifyOnFamilyMissed = notifyOnFamilyMissed;
          var localNotifyOnFamilyAdded = notifyOnFamilyAdded;
          var localNotifyOnFamilyRemoved = notifyOnFamilyRemoved;
          var localQuietHourStart = quietHourStart;
          var localQuietHourEnd = quietHourEnd;
          var localQuietHoursEnabled = quietHoursEnabled;
          var localRepeatInterval = repeatIntervalMinutes;
          var localMaxRepeatCount = maxRepeatCount;

          return Container(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Настройки уведомлений', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Типы уведомлений', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  _buildDialogSwitchTile(title: '💊 Напоминания о приёме', value: remindersEnabled, onChanged: (val) { setState(() => remindersEnabled = val); setDialogState(() => {}); _saveNotificationSettings(); }),
                  _buildDialogSwitchTile(title: '⚠️ Истекающие лекарства', value: expiryNotifications, onChanged: (val) { setState(() => expiryNotifications = val); setDialogState(() => {}); _saveNotificationSettings(); }),
                  _buildDialogSwitchTile(title: '📦 Низкий остаток', value: lowStockNotifications, onChanged: (val) { setState(() => lowStockNotifications = val); setDialogState(() => {}); _saveNotificationSettings(); }),
                  const Divider(height: 24),
                  const Text('Уведомления о семье', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  _buildDialogSwitchTile(title: '👨‍👩‍👧 Кто-то принял лекарство', value: localNotifyOnFamilyTaken, onChanged: (val) async { setDialogState(() => localNotifyOnFamilyTaken = val); setState(() => notifyOnFamilyTaken = val); await LocalSettingsService.setNotifyOnFamilyTaken(val); }),
                  _buildDialogSwitchTile(title: '⚠️ Кто-то пропустил приём', value: localNotifyOnFamilyMissed, onChanged: (val) async { setDialogState(() => localNotifyOnFamilyMissed = val); setState(() => notifyOnFamilyMissed = val); await LocalSettingsService.setNotifyOnFamilyMissed(val); }),
                  _buildDialogSwitchTile(title: '➕ Новый участник', value: localNotifyOnFamilyAdded, onChanged: (val) async { setDialogState(() => localNotifyOnFamilyAdded = val); setState(() => notifyOnFamilyAdded = val); await LocalSettingsService.setNotifyOnFamilyAdded(val); }),
                  _buildDialogSwitchTile(title: '➖ Удаление участника', value: localNotifyOnFamilyRemoved, onChanged: (val) async { setDialogState(() => localNotifyOnFamilyRemoved = val); setState(() => notifyOnFamilyRemoved = val); await LocalSettingsService.setNotifyOnFamilyRemoved(val); }),
                  const Divider(height: 24),
                  SwitchListTile(title: const Text('Тихий час', style: TextStyle(fontWeight: FontWeight.w600)), subtitle: const Text('Не беспокоить в указанное время'), value: localQuietHoursEnabled, onChanged: (val) async { setDialogState(() => localQuietHoursEnabled = val); setState(() => quietHoursEnabled = val); await LocalSettingsService.setQuietHoursEnabled(val); }, activeColor: AppColors.primary, contentPadding: EdgeInsets.zero),
                  if (localQuietHoursEnabled) ...[
                    const SizedBox(height: 12),
                    Row(children: [Expanded(child: _buildDialogTimePickerTile(label: 'С', time: localQuietHourStart, onTap: () async { final time = await showTimePicker(context: context, initialTime: localQuietHourStart ?? const TimeOfDay(hour: 22, minute: 0)); if (time != null) { setDialogState(() => localQuietHourStart = time); setState(() => quietHourStart = time); await LocalSettingsService.setQuietHoursTime(start: time.hour, end: quietHourEnd?.hour ?? 7); } })), const SizedBox(width: 16), Expanded(child: _buildDialogTimePickerTile(label: 'До', time: localQuietHourEnd, onTap: () async { final time = await showTimePicker(context: context, initialTime: localQuietHourEnd ?? const TimeOfDay(hour: 8, minute: 0)); if (time != null) { setDialogState(() => localQuietHourEnd = time); setState(() => quietHourEnd = time); await LocalSettingsService.setQuietHoursTime(start: quietHourStart?.hour ?? 22, end: time.hour); } }))]),
                  ],
                  const Divider(height: 24),
                  const Text('Повторные напоминания', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(children: [const Text('Повторять через (мин):'), const Spacer(), IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), onPressed: () { if (localRepeatInterval > 5) { setDialogState(() => localRepeatInterval -= 5); setState(() => repeatIntervalMinutes = localRepeatInterval); LocalSettingsService.setRepeatIntervalMinutes(localRepeatInterval); } }), Container(width: 50, alignment: Alignment.center, child: Text('$localRepeatInterval', style: const TextStyle(fontWeight: FontWeight.bold))), IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: () { if (localRepeatInterval < 60) { setDialogState(() => localRepeatInterval += 5); setState(() => repeatIntervalMinutes = localRepeatInterval); LocalSettingsService.setRepeatIntervalMinutes(localRepeatInterval); } })]),
                  const SizedBox(height: 8),
                  Row(children: [const Text('Макс. количество повторов:'), const Spacer(), IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), onPressed: () { if (localMaxRepeatCount > 1) { setDialogState(() => localMaxRepeatCount--); setState(() => maxRepeatCount = localMaxRepeatCount); LocalSettingsService.setRepeatCount(localMaxRepeatCount); } }), Container(width: 40, alignment: Alignment.center, child: Text('$localMaxRepeatCount', style: const TextStyle(fontWeight: FontWeight.bold))), IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: () { if (localMaxRepeatCount < 10) { setDialogState(() => localMaxRepeatCount++); setState(() => maxRepeatCount = localMaxRepeatCount); LocalSettingsService.setRepeatCount(localMaxRepeatCount); } })]),
                  const Divider(height: 24),
                  const Text('Звук и вибрация', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _buildDialogSwitchTile(title: '🔊 Звук уведомлений', value: localSoundEnabled, onChanged: (val) async { setDialogState(() => localSoundEnabled = val); setState(() => soundEnabled = val); await LocalSettingsService.setSoundEnabled(val); }),
                  _buildDialogSwitchTile(title: '📳 Вибрация', value: localVibrationEnabled, onChanged: (val) async { setDialogState(() => localVibrationEnabled = val); setState(() => vibrationEnabled = val); await LocalSettingsService.setVibrationEnabled(val); }),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _showResetSettingsDialog(), icon: const Icon(Icons.restore, color: Colors.orange), label: const Text('Сбросить все настройки'), style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange)))),
                  const SizedBox(height: 16),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть', style: TextStyle(fontSize: 16))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showResetSettingsDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сброс настроек'),
        content: const Text('Все настройки уведомлений будут возвращены к значениям по умолчанию. Продолжить?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Сбросить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await LocalSettingsService.resetToDefaults();
      await _loadAllSettings();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Настройки сброшены'), backgroundColor: Colors.green));
      }
    }
  }

  Widget _buildDialogSwitchTile({required String title, required bool value, required ValueChanged<bool> onChanged}) {
    return SwitchListTile(title: Text(title), value: value, onChanged: onChanged, contentPadding: EdgeInsets.zero, activeColor: AppColors.primary);
  }

  Widget _buildDialogTimePickerTile({required String label, required TimeOfDay? time, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w500)), const Spacer(), Text(time != null ? time.format(context) : '--:--', style: TextStyle(color: AppColors.primary))]),
      ),
    );
  }

  // ================= ОСНОВНОЙ BUILD =================
  @override
  Widget build(BuildContext context) {
    final textScaleFactor = _getFontScale();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: textScaleFactor),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [AppColors.darkBackground, AppColors.darkSurface]
                  : [const Color(0xFFF3F0FF), const Color(0xFFEDE7FF), const Color(0xFFFFF0F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Профиль', style: Theme.of(context).textTheme.headlineMedium),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.red),
                        onPressed: _signOut,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ======= ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ =======
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return _buildProfileCard(name: 'Загрузка...', email: currentUser?.email ?? '', onEdit: null);
                      if (snapshot.hasError) return _buildProfileCard(name: 'Ошибка загрузки', email: currentUser?.email ?? '', onEdit: null);
                      if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) return _buildProfileCard(name: 'Пользователь', email: currentUser?.email ?? '');
                      final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                      final name = data['name'] ?? (currentUser?.email?.split('@').first ?? 'Пользователь');
                      final email = data['email'] ?? currentUser?.email ?? '';
                      final avatarUrl = data['avatarUrl'] as String?;
                      return _buildProfileCardWithAvatar(name: name, email: email, avatarUrl: avatarUrl, onEdit: _showEditProfileDialog);
                    },
                  ),
                  const SizedBox(height: 32),

                  // ======= СЕМЬЯ =======
                  _buildSectionTitle('Семья'),
                  const SizedBox(height: 12),
                  _buildFamilyWidget(),
                  const SizedBox(height: 32),

                  // ======= ОСНОВНЫЕ НАСТРОЙКИ =======
                  _buildSectionTitle('Основные настройки'),
                  const SizedBox(height: 12),
                  _buildThemeSelector(),
                  const SizedBox(height: 12),
                  _buildFontSizeSelector(),
                  const SizedBox(height: 32),

                  // ======= УВЕДОМЛЕНИЯ =======
                  _buildSectionTitle('Уведомления'),
                  const SizedBox(height: 12),
                  _buildSwitchTile(icon: Icons.notifications_active_rounded, title: 'Напоминания о приёме', value: remindersEnabled, onChanged: (val) { setState(() => remindersEnabled = val); _saveNotificationSettings(); }),
                  _buildSwitchTile(icon: Icons.warning_amber_rounded, title: 'Истекающие лекарства', value: expiryNotifications, onChanged: (val) { setState(() => expiryNotifications = val); _saveNotificationSettings(); }),
                  _buildSwitchTile(icon: Icons.inventory_2_rounded, title: 'Низкий остаток лекарств', value: lowStockNotifications, onChanged: (val) { setState(() => lowStockNotifications = val); _saveNotificationSettings(); }),
                  _buildSwitchTile(icon: Icons.family_restroom_rounded, title: 'Действия членов семьи', value: familyActionNotifications, onChanged: (val) { setState(() { familyActionNotifications = val; notifyOnFamilyTaken = val; notifyOnFamilyMissed = val; }); _saveNotificationSettings(); }),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _showNotificationSettingsDialog,
                    child: Row(
                      children: [
                        Icon(Icons.settings, size: 18, color: isDark ? AppColors.darkTextSecondary : Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Расширенные настройки',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : Colors.grey[600],
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ======= ИНФОРМАЦИЯ И ПОДДЕРЖКА =======
                  _buildSectionTitle('Информация'),
                  const SizedBox(height: 12),
                  _buildInfoTile(icon: Icons.privacy_tip_rounded, title: 'Политика конфиденциальности', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()))),
                  _buildInfoTile(icon: Icons.support_agent_rounded, title: 'Поддержка', onTap: () async { final Uri emailUri = Uri(scheme: 'mailto', path: 'support@familymedicine.com', query: 'subject=Поддержка Family Medicine'); if (await canLaunchUrl(emailUri)) { await launchUrl(emailUri); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось открыть почтовое приложение'))); } }),
                  _buildInfoTile(icon: Icons.info_outline_rounded, title: 'О приложении', subtitle: 'Версия 1.0.0', onTap: () => showAboutDialog(context: context, applicationName: 'Family Medicine', applicationVersion: '1.0.0', applicationLegalese: '© 2026 Family Medicine App', children: const [Text('Приложение для управления семейной аптечкой, контроля приема лекарств и отслеживания курсов лечения.')])),
                  const SizedBox(height: 32),

                  // ======= КНОПКИ УПРАВЛЕНИЯ АККАУНТОМ =======
                  _buildAccountActions(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard({required String name, required String email, VoidCallback? onEdit}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface.withOpacity(0.95) : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 45,
            backgroundColor: Colors.grey.shade300,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 32, color: Colors.white)),
          ),
          const SizedBox(height: 16),
          Text(name, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text(email, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (onEdit != null) ElevatedButton(onPressed: onEdit, child: const Text('Редактировать профиль')),
        ],
      ),
    );
  }

  Widget _buildProfileCardWithAvatar({required String name, required String email, String? avatarUrl, required VoidCallback onEdit}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface.withOpacity(0.95) : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 45,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? AssetImage(avatarUrl) as ImageProvider : null,
            backgroundColor: Colors.grey.shade300,
            child: (avatarUrl == null || avatarUrl.isEmpty) ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 32, color: Colors.white)) : null,
          ),
          const SizedBox(height: 16),
          Text(name, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text(email, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onEdit, child: const Text('Редактировать профиль')),
        ],
      ),
    );
  }


  Widget _buildFamilyWidget() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || userSnapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        final hasFamily = userData['familyId'] != null;
        final userRole = userData['role'] ?? 'member';
        final familyId = userData['familyId'];

        if (!hasFamily) {
          return _buildNoFamilyView();
        }
        return _buildFamilyView(familyId, userRole);
      },
    );
  }

  Widget _buildNoFamilyView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceVariant : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkInputBorder : Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: isDark ? AppColors.darkPrimary : Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Вы пока не в семье. Создайте свою или присоединитесь к существующей.',
                  style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.blue.shade700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildActionCard(icon: Icons.group_add, title: 'Создать семью', description: 'Станьте владельцем', color: Colors.green, onTap: _showCreateFamilyDialog)),
            const SizedBox(width: 12),
            Expanded(child: _buildActionCard(icon: Icons.qr_code_scanner, title: 'Присоединиться', description: 'По коду или QR', color: Colors.orange, onTap: _showJoinOptions)),
          ],
        ),
      ],
    );
  }

  Widget _buildFamilyView(String familyId, String userRole) {
    final isOwner = userRole == 'owner';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FamilyService.streamFamily(familyId),
      builder: (context, familySnapshot) {
        if (familySnapshot.hasError) {
          return _buildFamilyErrorState(isDark);
        }
        if (!familySnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final familyDoc = familySnapshot.data!;
        if (!familyDoc.exists) {
          return _buildFamilyNotFoundState(isDark);
        }

        final familyData = familyDoc.data() as Map<String, dynamic>? ?? {};
        final familyName = familyData['name'] ?? 'Семья';
        final inviteCode = familyData['inviteCode'] ?? '';
        final memberCount = (familyData['memberIds'] as List?)?.length ?? 0;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isOwner
                      ? (isDark ? [Colors.amber.shade800, Colors.orange.shade900] : [Colors.amber.shade100, Colors.orange.shade50])
                      : (isDark ? [Colors.blue.shade900, Colors.lightBlue.shade900] : [Colors.blue.shade50, Colors.lightBlue.shade50]),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isOwner ? Colors.amber : Colors.blue,
                    child: Icon(isOwner ? Icons.star : Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          familyName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$memberCount участников • Вы ${isOwner ? 'владелец' : 'участник'}',
                          style: TextStyle(color: Colors.black26, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (isOwner) ...[
              _buildActionButton(icon: Icons.qr_code, label: 'Показать код приглашения',
                  onTap: () => _showInviteCodeDialog(inviteCode, familyName)),
              const SizedBox(height: 8),
              _buildActionButton(icon: Icons.refresh, label: 'Сгенерировать новый код',
                  color: Colors.orange, onTap: () => _regenerateInviteCode(familyId)),
            ] else ...[
              _buildActionButton(icon: Icons.exit_to_app, label: 'Покинуть семью',
                  color: Colors.red, onTap: _leaveFamily),
            ],
            const SizedBox(height: 16),
            if (memberCount > 0) _buildMembersList(familyId, isOwner, isDark),
          ],
        );
      },
    );
  }

  Widget _buildFamilyErrorState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 8),
          Text('Ошибка загрузки данных семьи', style: TextStyle(color: Colors.red.shade700)),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: () => setState(() {}), child: const Text('Повторить')),
        ],
      ),
    );
  }

  Widget _buildFamilyNotFoundState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
          SizedBox(height: 8),
          Text('Семья не найдена или была удалена'),
        ],
      ),
    );
  }

  Widget _buildMembersList(String familyId, bool isOwner, bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FamilyService.streamFamilyMembers(familyId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Ошибка загрузки: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 12));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final members = snapshot.data!;
        final currentUserId = currentUser?.uid;

        if (members.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('Нет участников', style: TextStyle(color: Colors.grey))),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Участники:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...members.map((member) => _buildMemberTile(member, isOwner, familyId, isDark, currentUserId)),
            if (isOwner && members.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '⏱️ Удерживайте участника для удаления',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member, bool isOwner, String familyId, bool isDark, String? currentUserId) {
    final memberId = member['id'];
    final name = member['name'] ?? 'Пользователь';
    final role = member['role'] ?? 'member';
    final avatarUrl = member['avatarUrl'] as String?;
    final isCurrentUser = memberId == currentUserId;
    final isMemberOwner = role == 'owner';
    final canRemove = isOwner && !isCurrentUser && !isMemberOwner;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
              ? AssetImage(avatarUrl) as ImageProvider
              : null,
          backgroundColor: Colors.grey.shade300,
          child: (avatarUrl == null || avatarUrl.isEmpty)
              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 18))
              : null,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(role == 'owner' ? 'Владелец' : 'Участник', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: role == 'owner'
            ? const Icon(Icons.star, color: Colors.amber)
            : (isCurrentUser ? const Icon(Icons.person, color: Colors.blue) : null),
        onLongPress: canRemove ? () => _removeFamilyMember(memberId, name) : null,
      ),
    );
  }

  Widget _buildActionCard({required IconData icon, required String title, required String description, required Color color, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap, Color color = Colors.blue}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          elevation: 0,
          side: BorderSide(color: color.withOpacity(0.5)),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600));

  Widget _buildSwitchTile({required IconData icon, required String title, required bool value, required ValueChanged<bool> onChanged}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: AppColors.primary),
        title: Text(title),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildInfoTile({required IconData icon, required String title, String? subtitle, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)) : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _buildThemeSelector() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentMode = themeProvider.themeModel.mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Тема оформления',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Row(
            children: [
              _buildThemeOption(
                context,
                icon: Icons.light_mode,
                label: 'Светлая',
                isSelected: currentMode == AppThemeMode.light,
                onTap: () => themeProvider.setThemeMode(AppThemeMode.light),
              ),
              _buildThemeOption(
                context,
                icon: Icons.dark_mode,
                label: 'Тёмная',
                isSelected: currentMode == AppThemeMode.dark,
                onTap: () => themeProvider.setThemeMode(AppThemeMode.dark),
              ),
              _buildThemeOption(
                context,
                icon: Icons.settings,
                label: 'Системная',
                isSelected: currentMode == AppThemeMode.system,
                onTap: () => themeProvider.setThemeMode(AppThemeMode.system),
              ),
            ],
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
      BuildContext context, {
        required IconData icon,
        required String label,
        required bool isSelected,
        required VoidCallback onTap,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isDark ? AppColors.darkInputBorder : AppColors.lightInputBorder),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFontSizeSelector() => _buildRadioBlock(icon: Icons.text_fields_rounded, title: 'Размер шрифта', groupValue: selectedFontSize, options: const {'small': 'Маленький', 'medium': 'Средний', 'large': 'Крупный'}, onChanged: _updateFontSize);

  Widget _buildRadioBlock({required IconData icon, required String title, required String groupValue, required Map<String, String> options, required ValueChanged<String> onChanged}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: AppColors.primary), const SizedBox(width: 8), Text(title)]),
          const SizedBox(height: 12),
          ...options.entries.map((entry) => RadioListTile<String>(title: Text(entry.value), value: entry.key, groupValue: groupValue, activeColor: AppColors.primary, onChanged: (value) => onChanged(value!), contentPadding: EdgeInsets.zero)),
        ],
      ),
    );
  }

  Widget _buildAccountActions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.orange),
            title: const Text('Выйти из аккаунта'),
            onTap: _signOut,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Удалить аккаунт', style: TextStyle(color: Colors.red)),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}