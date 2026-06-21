
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:family_medicine/theme.dart';
import 'package:flutter/services.dart';
import 'package:family_medicine/services/notification_service.dart';
import 'package:family_medicine/services/schedule_service.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  bool _isLoading = true;
  final user = FirebaseAuth.instance.currentUser;

  String _userName = '';
  String? _avatarUrl;
  String _greeting = '';

  List<Map<String, dynamic>> _medications = [];
  List<Map<String, dynamic>> _metrics = [];
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _manualMetrics = [];

  Set<DateTime> _daysWithMeds = {};
  Set<DateTime> _daysWithMetrics = {};

  DateTime _normalize(DateTime d) {
    return DateTime(d.year, d.month, d.day);
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.requestAllPermissions();
    });
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDate = _normalize(DateTime.now());
    _focusedDay = _normalize(DateTime.now());

    NotificationService.refreshHomeNotifier.addListener(_onRefreshFromNotification);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    NotificationService.refreshHomeNotifier.removeListener(_onRefreshFromNotification);
    super.dispose();
  }

  void _onRefreshFromNotification() {
    print('🔄 Обновление UI после действия в уведомлении');
    _refreshData();
  }

  Future<void> _init() async {
    await initializeDateFormatting('ru_RU');
    _setGreeting();
    await _loadUserName();
    await _loadAllData();
    setState(() => _isLoading = false);
  }

  Future<void> _loadUserName() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    _userName = doc.data()?['name'] ?? user!.email?.split('@').first ?? 'Пользователь';
    _avatarUrl = doc.data()?['avatarUrl'] as String?;
  }

  void _setGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) {
      _greeting = 'Доброе утро,';
    } else if (h < 18) {
      _greeting = 'Добрый день,';
    } else {
      _greeting = 'Добрый вечер,';
    }
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadDataForSelectedDate(),
      _loadMonthEvents(),
    ]);
  }

  Future<void> _loadDataForSelectedDate() async {
    if (user == null) return;

    final tasks = await ScheduleService.getTasksForDate(_selectedDate);

    _medications = tasks.where((t) => t['type'] == 'medication').toList();
    _metrics = tasks.where((t) => t['type'] == 'health_metric').toList();
    _notes = await ScheduleService.getNotesForDate(_selectedDate);
    _manualMetrics = await ScheduleService.getHealthMeasurementsForDate(_selectedDate);

    if (mounted) setState(() {});
  }

  Future<void> _loadMonthEvents() async {
    if (user == null) return;

    final events = await ScheduleService.getMonthEvents(_focusedDay);

    final meds = <DateTime>{};
    final metrics = <DateTime>{};

    for (final entry in events.entries) {
      if (entry.value['hasMeds'] == true) meds.add(entry.key);
      if (entry.value['hasMetrics'] == true) metrics.add(entry.key);
    }

    setState(() {
      _daysWithMeds = meds;
      _daysWithMetrics = metrics;
    });
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _loadAllData();
    if (mounted) setState(() => _isLoading = false);
  }

  void _onDaySelected(DateTime selected, DateTime focused) {
    final normalizedSelected = _normalize(selected);
    if (normalizedSelected == _selectedDate) return;

    setState(() {
      _selectedDate = normalizedSelected;
      _focusedDay = normalizedSelected;
      _isLoading = true;
    });

    _loadDataForSelectedDate().then((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _onPageChanged(DateTime focusedDay) {
    setState(() => _focusedDay = _normalize(focusedDay));
    _loadMonthEvents();
  }

  Future<void> _markAsMissed(Map task) async {
    try {
      await ScheduleService.markAsSkipped(task['id']);
      await _loadDataForSelectedDate();
      _showSnackBar('❌ Пропущено', Colors.orange);
    } catch (e) {
      _showSnackBar('Ошибка: $e', Colors.red);
    }
  }

  Future<void> _markAsCompleted(Map task) async {
    final medicationId = task['medicationId'];
    final quantity = task['quantity'] ?? 1;

    try {
      await ScheduleService.markAsCompleted(task['id']);

      if (medicationId != null) {
        final medicineRef = FirebaseFirestore.instance
            .collection('medicines')
            .doc(medicationId);
        final medicineDoc = await medicineRef.get();
        if (medicineDoc.exists) {
          final currentQuantity = medicineDoc.data()?['quantity'] ?? 0;
          final newQuantity = (currentQuantity - quantity).clamp(0, currentQuantity);
          await medicineRef.update({'quantity': newQuantity});

          final initialQuantity = medicineDoc.data()?['initialQuantity'] ?? currentQuantity;
          await NotificationService.checkLowStock(
            medicineId: medicationId,
            medicineName: task['medicationName'] ?? '',
            quantity: newQuantity,
            initialQuantity: initialQuantity,
          );
        }
      }

      await _loadDataForSelectedDate();
      _showSnackBar('✅ Выполнено!', Colors.green);
    } catch (e) {
      _showSnackBar('Ошибка: $e', Colors.red);
    }
  }

  IconData _getMetricIcon(String type) {
    switch (type) {
      case 'pressure': return Icons.monitor_heart;
      case 'pulse': return Icons.favorite;
      case 'temperature': return Icons.thermostat;
      default: return Icons.monitor;
    }
  }

  Color _getMetricColor(String type) {
    switch (type) {
      case 'pressure': return Colors.red;
      case 'pulse': return Colors.red.shade700;
      case 'temperature': return Colors.orange;
      default: return Colors.blue;
    }
  }

  Future<void> _addNote() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Добавить заметку', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 5,
              style: TextStyle(color: isDark ? AppColors.darkTextPrimary : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Введите текст заметки...',
                hintStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: isDark ? AppColors.darkInputFill : Colors.grey.shade50,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Отмена', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.black54)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final text = controller.text.trim();
                      if (text.isNotEmpty) {
                        await ScheduleService.saveNote(
                          userId: user!.uid,
                          userName: _userName,
                          text: text,
                          date: _selectedDate,
                        );
                        if (mounted) Navigator.pop(context);
                        await _loadDataForSelectedDate();
                        _showSnackBar('✅ Заметка добавлена', Colors.green);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('Добавить'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _addManualMeasurement() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String selectedType = 'pressure';
    final valueController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Добавить измерение', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Тип измерения',
                    labelStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'pressure', child: Text('Давление')),
                    DropdownMenuItem(value: 'pulse', child: Text('Пульс')),
                    DropdownMenuItem(value: 'temperature', child: Text('Температура')),
                  ],
                  onChanged: (value) => setStateDialog(() => selectedType = value!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: valueController,
                  keyboardType: selectedType == 'pressure' ? TextInputType.text : TextInputType.number,
                  style: TextStyle(color: isDark ? AppColors.darkTextPrimary : Colors.black87),
                  decoration: InputDecoration(
                    labelText: selectedType == 'pressure'
                        ? 'Значение (120/80)'
                        : (selectedType == 'pulse' ? 'Значение (60-100)' : 'Значение (36.6)'),
                    labelStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Отмена', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.black54)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          String value = valueController.text.trim();
                          if (value.isNotEmpty) {
                            if (selectedType == 'pressure' && !RegExp(r'^\d+/\d+$').hasMatch(value)) {
                              _showSnackBar('Введите давление в формате 120/80', Colors.orange);
                              return;
                            }
                            await ScheduleService.saveHealthMeasurement(
                              userId: user!.uid,
                              type: selectedType,
                              value: value,
                              date: _selectedDate,
                            );
                            if (mounted) Navigator.pop(context);
                            await _loadDataForSelectedDate();
                            _showSnackBar('✅ Измерение добавлено', Colors.green);
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Сохранить'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.monitor_heart, color: AppColors.primary),
              title: const Text('Добавить измерение'),
              onTap: () {
                Navigator.pop(context);
                _addManualMeasurement();
              },
            ),
            ListTile(
              leading: const Icon(Icons.note, color: AppColors.primary),
              title: const Text('Добавить заметку'),
              onTap: () {
                Navigator.pop(context);
                _addNote();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Widget _buildManualMetricCard(Map m) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = m['type'];
    final value = m['value'] ?? '';
    final createdAt = (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final timeStr = DateFormat('HH:mm').format(createdAt);

    String displayType = '';
    IconData icon = Icons.edit_note;
    Color iconColor = Colors.orange;

    switch (type) {
      case 'pressure':
        displayType = 'Давление';
        icon = Icons.monitor_heart;
        iconColor = Colors.red;
        break;
      case 'pulse':
        displayType = 'Пульс';
        icon = Icons.favorite;
        iconColor = Colors.red.shade700;
        break;
      case 'temperature':
        displayType = 'Температура';
        icon = Icons.thermostat;
        iconColor = Colors.orange;
        break;
      default:
        displayType = type ?? 'Измерение';
        icon = Icons.show_chart;
        iconColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayType,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$timeStr • $value',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.edit, size: 12, color: Colors.orange.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Добавлено вручную',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allTasks = [
      ..._medications,
      ..._metrics,
    ];

    final selectedDay = _normalize(_selectedDate);

    final dayTasks = allTasks.where((task) {
      final taskTime = task['time'] as DateTime?;
      if (taskTime == null) return false;
      return _normalize(taskTime) == selectedDay;
    }).toList();

    final pending = dayTasks
        .where((t) => (t['status'] ?? 'pending') == 'pending')
        .toList();

    final completed = dayTasks
        .where((t) => (t['status'] ?? 'pending') != 'pending')
        .toList();

    final morning = pending.where((t) {
      final h = (t['time'] as DateTime).hour;
      return h < 12;
    }).toList();

    final day = pending.where((t) {
      final h = (t['time'] as DateTime).hour;
      return h >= 12 && h < 18;
    }).toList();

    final evening = pending.where((t) {
      final h = (t['time'] as DateTime).hour;
      return h >= 18;
    }).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.all(16),
      children: [
        if (morning.isNotEmpty) ...[
          Text(
            '🌅 Утро',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...morning.map((t) => _buildTaskCard(t)),
          const SizedBox(height: 20),
        ],

        if (day.isNotEmpty) ...[
          Text(
            '☀️ День',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...day.map((t) => _buildTaskCard(t)),
          const SizedBox(height: 20),
        ],

        if (evening.isNotEmpty) ...[
          Text(
            '🌙 Вечер',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...evening.map((t) => _buildTaskCard(t)),
          const SizedBox(height: 20),
        ],

        if (pending.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Нет активных задач',
                style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey),
              ),
            ),
          ),

        if (completed.isNotEmpty) ...[
          Text(
            '📌 Завершённые',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          ...completed.map((t) => _buildTaskCard(t, faded: true)),
        ],

        if (_manualMetrics.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            '✏️ Ручные измерения',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          ..._manualMetrics.map((m) => _buildManualMetricCard(m)),
        ],
      ],
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, {bool faded = false}) {
    final type = task['type'];

    if (type == 'health_metric') {
      return _buildHealthMetricCard(task, faded: faded);
    }

    return _buildMedicationCard(task, faded: faded);
  }

  Widget _buildHealthMetricCard(Map<String, dynamic> task, {bool faded = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final time = task['time'] != null
        ? DateFormat('HH:mm').format(task['time'])
        : '--:--';

    final status = task['status'];
    final isCompleted = status == 'completed';
    final isPending = status == 'pending';
    final taskTime = task['time'] as DateTime?;
    final now = DateTime.now();

    String actionType = 'completed';

    if (taskTime != null) {
      final taskDate = DateTime(taskTime.year, taskTime.month, taskTime.day);
      final today = DateTime(now.year, now.month, now.day);
      final isToday = taskDate == today;

      if (isCompleted) {
        actionType = 'completed';
      } else if (isPending && isToday) {
        actionType = 'active';
      } else if (isPending && taskDate.isAfter(today)) {
        actionType = 'locked';
      } else if (isPending && taskDate.isBefore(today)) {
        actionType = 'overdue';
      }
    } else {
      if (isCompleted) {
        actionType = 'completed';
      } else if (isPending) {
        actionType = 'active';
      }
    }

    Widget trailingWidget;

    switch (actionType) {
      case 'active':
        trailingWidget = ElevatedButton(
          onPressed: () => _enterMetricValue(task),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(70, 32),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text('Ввести', style: TextStyle(fontSize: 12)),
        );
        break;
      case 'locked':
        trailingWidget = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock, color: Colors.orange, size: 18),
            const SizedBox(height: 2),
            Text(
              'Рано',
              style: TextStyle(fontSize: 10, color: Colors.orange.shade700),
            ),
          ],
        );
        break;
      case 'overdue':
        trailingWidget = const Icon(Icons.cancel, color: Colors.red, size: 22);
        break;
      default:
        trailingWidget = const Icon(Icons.check_circle, color: Colors.green, size: 22);
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: faded
          ? (isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade50)
          : (isDark ? AppColors.darkSurface : Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted ? Icons.check : Icons.monitor_heart,
                color: isCompleted ? Colors.green : Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['metricName'] ?? 'Измерение',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$time • ${task['unit'] ?? ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                    ),
                  ),
                  if (isCompleted && task['value'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Введено: ${task['value']}',
                        style: const TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ),
                  if (actionType == 'overdue')
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Пропущено',
                        style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(
              width: 80,
              child: Center(child: trailingWidget),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationCard(Map<String, dynamic> task, {bool faded = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final time = task['time'] != null
        ? DateFormat('HH:mm').format(task['time'])
        : '--:--';

    final status = task['status'];
    final isCompleted = status == 'completed';
    final isSkipped = status == 'skipped';
    final isPending = status == 'pending';
    final taskTime = task['time'] as DateTime?;
    final now = DateTime.now();

    String actionType = 'completed';

    if (taskTime != null) {
      final taskDate = DateTime(taskTime.year, taskTime.month, taskTime.day);
      final today = DateTime(now.year, now.month, now.day);
      final isToday = taskDate == today;
      final isFuture = taskDate.isAfter(today);

      if (isCompleted) {
        actionType = 'completed';
      } else if (isSkipped) {
        actionType = 'skipped';
      } else if (isPending && isToday) {
        actionType = 'active';
      } else if (isPending && isFuture) {
        actionType = 'locked';
      } else if (isPending && taskDate.isBefore(today)) {
        actionType = 'overdue';
      }
    } else {
      if (isCompleted) {
        actionType = 'completed';
      } else if (isSkipped) {
        actionType = 'skipped';
      } else if (isPending) {
        actionType = 'active';
      }
    }

    Widget trailingWidget;

    switch (actionType) {
      case 'active':
        trailingWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _markAsMissed(task),
              icon: const Icon(Icons.close, color: Colors.red, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 20,
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => _markAsCompleted(task),
              icon: const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 20,
            ),
          ],
        );
        break;
      case 'locked':
        trailingWidget = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock, color: Colors.orange, size: 18),
            const SizedBox(height: 2),
            Text(
              'Рано',
              style: TextStyle(fontSize: 10, color: Colors.orange.shade700),
            ),
          ],
        );
        break;
      case 'overdue':
      case 'skipped':
        trailingWidget = const Icon(Icons.cancel, color: Colors.red, size: 22);
        break;
      default:
        trailingWidget = const Icon(Icons.check_circle, color: Colors.green, size: 22);
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: faded
          ? (isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade50)
          : (isDark ? AppColors.darkSurface : Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted || isSkipped
                      ? (isCompleted ? Icons.check : Icons.close)
                      : Icons.medication,
                  color: isCompleted
                      ? Colors.green
                      : (isSkipped ? Colors.red : AppColors.primary),
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['medicationName'] ?? 'Лекарство',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$time • ${task['dosage']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (actionType == 'overdue')
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Просрочено',
                        style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),

            Container(
              constraints: const BoxConstraints(minWidth: 70),
              child: Center(child: trailingWidget),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_notes.isEmpty) {
      return Center(
        child: Text(
          'Нет заметок на этот день',
          style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey),
        ),
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.all(16),
      children: _notes.map((note) {
        final created = (note['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final userName = note['userName'] ?? 'Пользователь';
        final isCurrentUser = userName == _userName;
        final avatarUrl = note['avatarUrl'] as String?;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isDark ? AppColors.darkSurface : Colors.white,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? ClipOval(
                child: Image.asset(
                  avatarUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.person, color: AppColors.primary),
                ),
              )
                  : Icon(Icons.person, color: AppColors.primary),
            ),
            title: Text(note['text'] ?? '', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : Colors.black87)),
            subtitle: Text(
              isCurrentUser
                  ? 'Вы • ${DateFormat('HH:mm').format(created)}'
                  : '$userName • ${DateFormat('HH:mm').format(created)}',
              style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _enterMetricValue(Map metric) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final metricName = metric['metricName'] ?? 'Показатель';
    final metricType = metric['metricType'] as String? ?? 'custom';
    final unit = metric['unit'] ?? '';
    final courseId = metric['courseId'];

    final systolicController = TextEditingController();
    final diastolicController = TextEditingController();
    final pulseController = TextEditingController();
    final temperatureController = TextEditingController();
    final valueController = TextEditingController();

    String? _selectedPressureUnit = 'mmHg';

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            title: Row(
              children: [
                Icon(_getMetricIcon(metricType), color: _getMetricColor(metricType), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Введите: $metricName',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (metricType == 'pressure') ...[
                      _buildPressureInput(isDark, systolicController, diastolicController),
                    ],
                    if (metricType == 'pulse') ...[
                      _buildPulseInput(isDark, pulseController),
                    ],
                    if (metricType == 'temperature') ...[
                      _buildTemperatureInput(isDark, temperatureController),
                    ],
                    if (metricType != 'pressure' &&
                        metricType != 'pulse' &&
                        metricType != 'temperature') ...[
                      _buildCustomInput(isDark, valueController, unit),
                    ],
                    const SizedBox(height: 16),
                    _buildInfoHint(isDark),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? AppColors.darkTextSecondary : Colors.black54,
                ),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () async {
                  String value = '';

                  if (metricType == 'pressure') {
                    final systolic = systolicController.text.trim();
                    final diastolic = diastolicController.text.trim();
                    if (systolic.isEmpty || diastolic.isEmpty) {
                      _showSnackBar('Введите оба значения давления', Colors.orange);
                      return;
                    }
                    final systolicNum = int.tryParse(systolic);
                    final diastolicNum = int.tryParse(diastolic);
                    if (systolicNum == null || diastolicNum == null) {
                      _showSnackBar('Введите корректные числа', Colors.orange);
                      return;
                    }
                    int finalSystolic = systolicNum;
                    int finalDiastolic = diastolicNum;
                    if (_selectedPressureUnit == 'kPa') {
                      finalSystolic = (systolicNum * 7.5).round();
                      finalDiastolic = (diastolicNum * 7.5).round();
                    }
                    value = '$finalSystolic/$finalDiastolic';
                    if (finalSystolic > 250 || finalDiastolic > 150) {
                      _showSnackBar('⚠️ Значения давления выглядят аномально. Проверьте данные.', Colors.orange);
                      return;
                    }
                  } else if (metricType == 'pulse') {
                    final pulse = pulseController.text.trim();
                    if (pulse.isEmpty) {
                      _showSnackBar('Введите значение пульса', Colors.orange);
                      return;
                    }
                    final pulseNum = int.tryParse(pulse);
                    if (pulseNum == null) {
                      _showSnackBar('Введите корректное число', Colors.orange);
                      return;
                    }
                    if (pulseNum < 30 || pulseNum > 200) {
                      _showSnackBar('⚠️ Значение пульса выходит за пределы нормы. Проверьте данные.', Colors.orange);
                      return;
                    }
                    value = pulse;
                  } else if (metricType == 'temperature') {
                    final temp = temperatureController.text.trim();
                    if (temp.isEmpty) {
                      _showSnackBar('Введите значение температуры', Colors.orange);
                      return;
                    }
                    final tempNum = double.tryParse(temp);
                    if (tempNum == null) {
                      _showSnackBar('Введите корректное число', Colors.orange);
                      return;
                    }
                    if (tempNum < 34 || tempNum > 42) {
                      _showSnackBar('⚠️ Значение температуры выходит за пределы нормы. Проверьте данные.', Colors.orange);
                      return;
                    }
                    value = temp;
                  } else {
                    value = valueController.text.trim();
                    if (value.isEmpty) {
                      _showSnackBar('Введите значение', Colors.orange);
                      return;
                    }
                  }

                  final utcDate = DateTime.utc(
                    _selectedDate.year,
                    _selectedDate.month,
                    _selectedDate.day,
                  );

                  final measurementData = {
                    'userId': user?.uid,
                    'type': metricType,
                    'value': value,
                    'date': Timestamp.fromDate(utcDate),
                    'createdAt': FieldValue.serverTimestamp(),
                  };

                  if (courseId != null) {
                    measurementData['courseId'] = courseId;
                  }

                  await FirebaseFirestore.instance
                      .collection('health_measurements')
                      .add(measurementData);

                  await ScheduleService.completeMetricTask(
                    taskId: metric['id'],
                    value: value,
                  );

                  if (mounted) Navigator.pop(context);
                  await _loadDataForSelectedDate();
                  _showSnackBar('✅ Значение сохранено', Colors.green);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPressureInput(
      bool isDark,
      TextEditingController systolicCtrl,
      TextEditingController diastolicCtrl,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkInputBorder : Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart, color: Colors.red.shade400, size: 20),
              const SizedBox(width: 8),
              Text(
                'Артериальное давление',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: systolicCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: isDark ? AppColors.darkTextPrimary : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Систолическое',
                    hintText: '120',
                    hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    suffixText: 'мм рт.ст.',
                    suffixStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: diastolicCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: isDark ? AppColors.darkTextPrimary : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Диастолическое',
                    hintText: '80',
                    hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    suffixText: 'мм рт.ст.',
                    suffixStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Норма: 120/80 мм рт.ст.',
            style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseInput(bool isDark, TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkInputBorder : Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, color: Colors.red.shade400, size: 20),
              const SizedBox(width: 8),
              Text(
                'Пульс',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? AppColors.darkTextPrimary : Colors.black87),
            decoration: InputDecoration(
              labelText: 'Частота пульса',
              hintText: '72',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixText: 'уд/мин',
              suffixStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
          ),
          const SizedBox(height: 6),
          Text(
            'Норма: 60-100 уд/мин',
            style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureInput(bool isDark, TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkInputBorder : Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.thermostat, color: Colors.orange.shade400, size: 20),
              const SizedBox(width: 8),
              Text(
                'Температура тела',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: isDark ? AppColors.darkTextPrimary : Colors.black87),
            decoration: InputDecoration(
              labelText: 'Температура',
              hintText: '36.6',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixText: '°C',
              suffixStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              LengthLimitingTextInputFormatter(5),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Норма: 36.1-37.2 °C',
            style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomInput(bool isDark, TextEditingController controller, String unit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkInputBorder : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, color: Colors.blue.shade400, size: 20),
              const SizedBox(width: 8),
              Text(
                'Значение',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? AppColors.darkTextPrimary : Colors.black87),
            decoration: InputDecoration(
              labelText: unit.isNotEmpty ? 'Значение ($unit)' : 'Значение',
              hintText: 'Введите число',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoHint(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: isDark ? AppColors.darkPrimary : Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Введите значения, затем нажмите "Сохранить"',
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkPrimary : Colors.blue.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                ? AssetImage(_avatarUrl!) as ImageProvider
                : null,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                ? Text(
              _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting, style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextSecondary : Colors.black87)),
                Text(
                  _userName,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TableCalendar(
        firstDay: DateTime(2024, 1, 1),
        lastDay: DateTime(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => _normalize(day) == _selectedDate,
        onDaySelected: _onDaySelected,
        onPageChanged: _onPageChanged,
        calendarFormat: _calendarFormat,
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        availableCalendarFormats: const {
          CalendarFormat.month: 'Месяц',
          CalendarFormat.twoWeeks: '2 недели',
          CalendarFormat.week: 'Неделя',
        },
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: true,
          formatButtonShowsNext: false,
          leftChevronIcon: Icon(Icons.chevron_left),
          rightChevronIcon: Icon(Icons.chevron_right),
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade700),
          weekendStyle: const TextStyle(color: Colors.red),
        ),
        calendarStyle: CalendarStyle(
          selectedDecoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          selectedTextStyle: const TextStyle(color: Colors.white),
          todayDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
          todayTextStyle: const TextStyle(color: Colors.white),
          weekendTextStyle: const TextStyle(color: Colors.red),
          markerSize: 6,
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            final normalizedDate = _normalize(date);
            final hasMeds = _daysWithMeds.contains(normalizedDate);
            final hasMetrics = _daysWithMetrics.contains(normalizedDate);

            if (hasMeds || hasMetrics) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasMeds)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    ),
                  if (hasMetrics)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    ),
                ],
              );
            }
            return null;
          },
        ),
        locale: 'ru_RU',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.primary,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _header(),
                  _calendar(),
                  const SizedBox(height: 8),
                  TabBar(
                    controller: _tabController,
                    labelColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                    unselectedLabelColor: isDark ? AppColors.darkTextSecondary : Colors.grey,
                    indicatorColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                    tabs: const [
                      Tab(text: '💊 Лекарства и измерения'),
                      Tab(text: '📝 Заметки'),
                    ],
                  ),
                ],
              ),
            ),
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTasksView(),
                  _buildNotesView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}