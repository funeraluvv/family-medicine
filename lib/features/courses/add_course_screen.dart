// features/courses/add_course_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:family_medicine/models/medicine_model.dart';
import 'package:family_medicine/models/course_model.dart';
import 'package:family_medicine/services/course_service.dart';
import '../../theme.dart';
import '../navigation/tabs/medicine_tab.dart';
import 'configure_selected_medicines_screen.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  String? _assignedTo;
  String? _assignedToName;
  DateTime? _startDate;
  DateTime? _endDate;

  List<MedicationSchedule> _medications = [];
  List<HealthMetric> _healthMetrics = [];
  List<Map<String, dynamic>> _familyMembers = [];
  bool _isLoading = false;
  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _currentUserName = await CourseService.getUserName();
    _familyMembers = await CourseService.getFamilyMembers();
    setState(() {});
  }

  Future<void> _pickDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    setState(() {
      final normalized = DateTime(date.year, date.month, date.day);
      if (isStart) _startDate = normalized;
      else _endDate = normalized;
    });
  }

  Future<void> _selectMedicines() async {
    final selectedMeds = await Navigator.push<List<MedicineModel>>(
      context,
      MaterialPageRoute(builder: (_) => const MedicineTab(isSelectionMode: true)),
    );
    if (selectedMeds == null || selectedMeds.isEmpty) return;

    final configured = await Navigator.push<List<MedicationSchedule>>(
      context,
      MaterialPageRoute(
        builder: (_) => ConfigureSelectedMedicinesScreen(medicines: selectedMeds),
      ),
    );
    if (configured != null && configured.isNotEmpty) {
      setState(() => _medications.addAll(configured));
    }
  }

  Future<void> _addHealthMetric() async {
    final result = await showDialog<HealthMetric>(
      context: context,
      builder: (_) => const _AddHealthMetricDialog(),
    );
    if (result != null) setState(() => _healthMetrics.add(result));
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      _showSnack('Выберите даты');
      return;
    }
    if (_assignedTo == null) {
      _showSnack('Выберите пациента');
      return;
    }
    if (_medications.isEmpty && _healthMetrics.isEmpty) {
      _showSnack('Добавьте хотя бы одно лекарство или показатель');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final courseId = DateTime.now().millisecondsSinceEpoch.toString();

      final course = CourseModel(
        id: courseId,
        name: _nameController.text.trim(),
        assignedTo: _assignedTo!,
        assignedToName: _assignedToName!,
        assignedBy: currentUser!.uid,
        assignedByName: _currentUserName ??
            currentUser!.email?.split('@').first ?? 'Пользователь',
        startDate: _startDate!,
        endDate: _endDate!,
        medications: _medications,
        healthMetrics: _healthMetrics,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        attachments: [],
        createdAt: DateTime.now(),
      );

      // ВСЕ уведомления планируются внутри CourseService.createCourse
      await CourseService.createCourse(course);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Курс создан'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Ошибка: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('addCourseScreen'),
      appBar: AppBar(
        title: const Text('Создание курса'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Название курса
            TextFormField(
              key: const Key('courseNameField'),
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название курса',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
              (v == null || v.isEmpty) ? 'Введите название' : null,
            ),
            const SizedBox(height: 12),

            // Выбор пациента
            DropdownButtonFormField<String>(
              key: const Key('patientDropdown'),
              value: _assignedTo,
              items: _familyMembers.map((m) {
                return DropdownMenuItem(
                  value: m['id'] as String,
                  child: Text(m['name'] as String),
                );
              }).toList(),
              onChanged: (v) {
                setState(() {
                  _assignedTo = v;
                  _assignedToName = _familyMembers
                      .firstWhere((e) => e['id'] == v)['name'];
                });
              },
              decoration: const InputDecoration(
                labelText: 'Пациент',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Даты
            Row(
              children: [
                Expanded(
                  child: _dateBox(
                    'Старт',
                    _startDate,
                        () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dateBox(
                    'Конец',
                    _endDate,
                        () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Лекарства
            _sectionTitle('💊 Лекарства'),
            ..._medications.map((m) => ListTile(
              title: Text(m.medicationName),
              subtitle: Text(
                '${m.dosage}, ${m.quantity} шт, ${m.formattedTimes}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => setState(() => _medications.remove(m)),
              ),
            )),
            TextButton.icon(
              key: const Key('addMedicinesButton'),
              onPressed: _selectMedicines,
              icon: const Icon(Icons.add),
              label: const Text('Добавить лекарства'),
            ),
            const SizedBox(height: 16),

            // Показатели здоровья
            _sectionTitle('📊 Показатели здоровья'),
            ..._healthMetrics.map(_buildMetricTile),
            TextButton.icon(
              key: const Key('addHealthMetricButton'),
              onPressed: _addHealthMetric,
              icon: const Icon(Icons.add),
              label: const Text('Добавить показатель'),
            ),
            const SizedBox(height: 16),

            // Заметки
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Заметки',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Кнопка сохранения
            ElevatedButton(
              key: const Key('saveCourseButton'),
              onPressed: _saveCourse,
              child: const Text('Создать курс'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateBox(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          date == null ? label : DateFormat('dd.MM.yyyy').format(date),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildMetricTile(HealthMetric metric) {
    return ListTile(
      title: Text(metric.name),
      subtitle: Text('${metric.unit} • ${metric.formattedReminders}'),
      trailing: IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () => setState(() => _healthMetrics.remove(metric)),
      ),
    );
  }
}

// ================= ДИАЛОГ ДОБАВЛЕНИЯ ПОКАЗАТЕЛЯ =================
class _AddHealthMetricDialog extends StatefulWidget {
  const _AddHealthMetricDialog();

  @override
  State<_AddHealthMetricDialog> createState() => _AddHealthMetricDialogState();
}

class _AddHealthMetricDialogState extends State<_AddHealthMetricDialog> {
  String _type = 'pressure';
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  List<TimeOfDay> _reminders = [];

  @override
  void initState() {
    super.initState();
    _updateDefaultValues();
  }

  void _updateDefaultValues() {
    if (_type == 'pressure') {
      _nameController.text = 'Артериальное давление';
      _unitController.text = 'мм рт. ст.';
    } else if (_type == 'pulse') {
      _nameController.text = 'Пульс';
      _unitController.text = 'уд/мин';
    } else if (_type == 'temperature') {
      _nameController.text = 'Температура тела';
      _unitController.text = '°C';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить показатель'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Тип'),
              items: const [
                DropdownMenuItem(value: 'pressure', child: Text('Давление')),
                DropdownMenuItem(value: 'pulse', child: Text('Пульс')),
                DropdownMenuItem(value: 'temperature', child: Text('Температура')),
                DropdownMenuItem(value: 'custom', child: Text('Свой показатель')),
              ],
              onChanged: (value) {
                setState(() {
                  _type = value!;
                  if (_type != 'custom') {
                    _updateDefaultValues();
                  } else {
                    _nameController.clear();
                    _unitController.clear();
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _unitController,
              decoration: const InputDecoration(labelText: 'Единица измерения'),
            ),
            const SizedBox(height: 16),
            const Text('Время напоминаний:'),
            ..._reminders.map((time) => ListTile(
              title: Text(time.format(context)),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => setState(() => _reminders.remove(time)),
              ),
            )),
            TextButton.icon(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() => _reminders.add(time));
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Добавить время'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              Navigator.pop(
                context,
                HealthMetric(
                  type: _type,
                  name: _nameController.text,
                  unit: _unitController.text,
                  required: true,
                  reminders: _reminders,
                ),
              );
            }
          },
          child: const Text('Добавить'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    super.dispose();
  }
}