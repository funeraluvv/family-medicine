// features/courses/course_stats_screen.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_medicine/models/course_model.dart';
import 'package:family_medicine/services/course_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:family_medicine/theme.dart';
import 'package:flutter/services.dart' show rootBundle;

class CourseStatsScreen extends StatefulWidget {
  final CourseModel course;
  const CourseStatsScreen({super.key, required this.course});

  @override
  State<CourseStatsScreen> createState() => _CourseStatsScreenState();
}

class _CourseStatsScreenState extends State<CourseStatsScreen> {
  bool _loading = true;
  List<QueryDocumentSnapshot> _schedule = [];
  int _completed = 0, _missed = 0, _total = 0;
  double _compliance = 0;
  Map<DateTime, Map<String, int>> _dailyStats = {};
  Map<String, List<Map<String, dynamic>>> _healthData = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    _schedule = await CourseService.getScheduleForCourse(widget.course.id!);

    final healthSnap = await FirebaseFirestore.instance
        .collection('health_measurements')
        .where('courseId', isEqualTo: widget.course.id)
        .get();

    final now = DateTime.now();
    final Map<DateTime, Map<String, int>> daily = {};
    int completed = 0, missed = 0, totalRelevant = 0;

    for (final d in _schedule) {
      final data = d.data() as Map<String, dynamic>;
      final ts = data['scheduledTime'] as Timestamp?;
      if (ts == null) continue;

      final scheduledDate = ts.toDate();
      final isPast = scheduledDate.isBefore(now);
      final dateKey = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
      final status = data['status'] as String? ?? 'pending';

      // Для ежедневной статистики учитываем все задачи
      daily.putIfAbsent(dateKey, () => {'total': 0, 'completed': 0, 'missed': 0});
      daily[dateKey]!['total'] = daily[dateKey]!['total']! + 1;

      // Для подсчёта выполненных/пропущенных учитываем только прошедшие задачи
      if (isPast) {
        totalRelevant++;
        if (status == 'completed') {
          completed++;
          daily[dateKey]!['completed'] = daily[dateKey]!['completed']! + 1;
        } else if (status == 'missed' || status == 'skipped') {
          missed++;
          daily[dateKey]!['missed'] = daily[dateKey]!['missed']! + 1;
        }
      }
    }

    final compliance = totalRelevant == 0 ? 0.0 : completed / totalRelevant;

    final Map<String, List<Map<String, dynamic>>> healthData = {};
    for (final doc in healthSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final type = data['type'] as String? ?? 'unknown';
      final date = (data['date'] as Timestamp).toDate();
      final value = data['value'];
      healthData.putIfAbsent(type, () => []).add({'date': date, 'value': value});
    }
    for (final type in healthData.keys) {
      healthData[type]!.sort((a, b) => a['date'].compareTo(b['date']));
    }

    setState(() {
      _dailyStats = daily;
      _completed = completed;
      _missed = missed;
      _total = totalRelevant;
      _compliance = compliance;
      _healthData = healthData;
      _loading = false;
    });
  }

  Future<void> _finishCourse() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Завершить курс досрочно?'),
        content: const Text('Все будущие приёмы будут отмечены как пропущенные.\nКурс будет перемещён в завершённые.\n\nВы уверены?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Завершить')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await CourseService.completeCourse(widget.course.id!, _compliance * 100);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Курс успешно завершён'), backgroundColor: Colors.green),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteCourse() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Удалить курс?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : Colors.black87,
          ),
        ),
        content: Text(
          'Будут удалены:\n'
              '• Все приёмы (schedule) для этого курса\n'
              '• Все показатели здоровья\n'
              '• Сам курс\n\n'
              'Это действие необратимо.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? AppColors.darkTextSecondary : Colors.grey.shade700,
            ),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await CourseService.deleteCourse(widget.course.id!, _schedule);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Курс удалён'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при удалении: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportPdf() async {
    try {
      final regularFont = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Inter_18pt-Regular.ttf'),
      );
      final boldFont = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Inter_24pt-Bold.ttf'),
      );

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
        ),
      );

      final now = DateTime.now();
      final compliancePercent = (_compliance * 100).toStringAsFixed(1);

      final sortedSchedule = [..._schedule]..sort((a, b) {
        final aTime = (a.data() as Map<String, dynamic>)['scheduledTime'] as Timestamp?;
        final bTime = (b.data() as Map<String, dynamic>)['scheduledTime'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return aTime.toDate().compareTo(bTime.toDate());
      });

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            // Заголовок
            pw.Text(
              'Отчёт по курсу лечения',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Сформировано: ${DateFormat('dd.MM.yyyy HH:mm').format(now)}',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.Divider(height: 30),

            // Общая информация
            pw.Text(
              'Общая информация',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            _buildInfoRow('Название курса', widget.course.name, regularFont),
            _buildInfoRow('Пациент', widget.course.assignedToName, regularFont),
            _buildInfoRow('Дата начала', _formatDate(widget.course.startDate), regularFont),
            _buildInfoRow('Дата окончания', _formatDate(widget.course.endDate), regularFont),
            _buildInfoRow('Процент соблюдения', '$compliancePercent%', regularFont),
            pw.SizedBox(height: 20),

            // Статистика выполнения
            pw.Text(
              'Статистика выполнения',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableCell('Показатель', bold: true),
                    _tableCell('Значение', bold: true),
                  ],
                ),
                pw.TableRow(children: [_tableCell('Выполнено'), _tableCell(_completed.toString())]),
                pw.TableRow(children: [_tableCell('Пропущено'), _tableCell(_missed.toString())]),
                pw.TableRow(children: [_tableCell('Всего задач'), _tableCell(_total.toString())]),
                pw.TableRow(children: [_tableCell('Соблюдение курса'), _tableCell('$compliancePercent%')]),
              ],
            ),
            pw.SizedBox(height: 20),

            // Лекарства
            if (widget.course.medications.isNotEmpty) ...[
              pw.Text(
                'Лекарства курса',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 12),
              ...widget.course.medications.map((med) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(med.medicationName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Дозировка: ${med.dosage}'),
                    pw.Text('Частота: ${med.frequencyText}'),
                    pw.Text('Время приёма: ${med.formattedTimes}'),
                    pw.Text('Количество: ${med.quantity} шт.'),
                  ],
                ),
              )),
              pw.SizedBox(height: 20),
            ],

            // Показатели здоровья
            if (widget.course.healthMetrics.isNotEmpty) ...[
              pw.Text(
                'Показатели здоровья',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 12),
              ...widget.course.healthMetrics.map((metric) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(metric.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Тип: ${metric.type}'),
                    pw.Text('Единица измерения: ${metric.unit}'),
                    if (metric.reminders.isNotEmpty)
                      pw.Text('Напоминания: ${metric.formattedReminders}'),
                  ],
                ),
              )),
              pw.SizedBox(height: 20),
            ],

            // Заметки
            if (widget.course.notes != null && widget.course.notes!.isNotEmpty) ...[
              pw.Text(
                'Заметки',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(widget.course.notes!),
              ),
              pw.SizedBox(height: 20),
            ],

            // История показателей
            if (_healthData.isNotEmpty) ...[
              pw.Text(
                'История показателей здоровья',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 12),
              ..._healthData.entries.map((entry) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Показатель: ${entry.key}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [_tableCell('Дата', bold: true), _tableCell('Значение', bold: true)],
                      ),
                      ...entry.value.map((value) => pw.TableRow(children: [
                        _tableCell(DateFormat('dd.MM.yyyy HH:mm').format(value['date'])),
                        _tableCell(value['value'].toString()),
                      ])),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                ],
              )),
            ],

            // Расписание
            pw.Text(
              'История расписания',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableCell('Событие', bold: true),
                    _tableCell('Дата', bold: true),
                    _tableCell('Статус', bold: true),
                  ],
                ),
                ...sortedSchedule.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final type = data['type'] ?? 'medication';
                  final status = data['status'] ?? 'pending';
                  final time = (data['scheduledTime'] as Timestamp?)?.toDate();
                  final title = type == 'medication'
                      ? data['medicationName'] ?? 'Лекарство'
                      : 'Измерение: ${data['metricName'] ?? 'Показатель'}';
                  String statusText;
                  if (status == 'completed') statusText = 'Выполнено';
                  else if (status == 'missed' || status == 'skipped') statusText = 'Пропущено';
                  else statusText = 'Ожидает';
                  return pw.TableRow(children: [
                    _tableCell(title),
                    _tableCell(time != null ? DateFormat('dd.MM.yyyy HH:mm').format(time) : '-'),
                    _tableCell(statusText),
                  ]);
                }),
              ],
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка экспорта PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  pw.Widget _buildInfoRow(String label, String value, pw.Font font) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 100,
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font)),
        ),
        pw.Expanded(child: pw.Text(value, style: pw.TextStyle(font: font))),
      ],
    );
  }

  pw.Widget _tableCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compliancePercent = (_compliance * 100).toInt();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика курса'),
        actions: [
          IconButton(onPressed: _exportPdf, icon: const Icon(Icons.picture_as_pdf), tooltip: 'Экспорт PDF'),
          IconButton(onPressed: _finishCourse, icon: const Icon(Icons.check_circle), tooltip: 'Досрочно завершить курс'),
          IconButton(onPressed: _deleteCourse, icon: const Icon(Icons.delete), tooltip: 'Удалить курс'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: isDark ? AppColors.darkSurface : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.course.name,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_formatDate(widget.course.startDate)} → ${_formatDate(widget.course.endDate)}',
                        style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Пациент: ${widget.course.assignedToName}',
                              style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _compliance >= 0.8
                                  ? (isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade100)
                                  : (_compliance >= 0.5
                                  ? (isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade100)
                                  : (isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade100)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$compliancePercent%',
                              style: TextStyle(
                                color: _compliance >= 0.8
                                    ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                                    : (_compliance >= 0.5
                                    ? (isDark ? Colors.orange.shade300 : Colors.orange.shade700)
                                    : (isDark ? Colors.red.shade300 : Colors.red.shade700)),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: _compliance,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(8),
                        backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade200,
                        color: _compliance >= 0.8 ? Colors.green : (_compliance >= 0.5 ? Colors.orange : Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // KPI cards
              Row(
                children: [
                  _buildKpiCard('✅ Выполнено', _completed.toString(), Icons.check_circle, Colors.green, isDark),
                  const SizedBox(width: 12),
                  _buildKpiCard('❌ Пропущено', _missed.toString(), Icons.cancel, Colors.red, isDark),
                  const SizedBox(width: 12),
                  _buildKpiCard('📋 Всего', _total.toString(), Icons.list, Colors.blue, isDark),
                ],
              ),
              const SizedBox(height: 16),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📋 Информация о курсе', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildInfoRowWidget('Длительность', '${widget.course.duration} дней'),
                      _buildInfoRowWidget('Осталось дней', widget.course.daysLeftText, valueColor: widget.course.daysLeftColor),
                      _buildInfoRowWidget('Лекарств', '${widget.course.medications.length}'),
                      _buildInfoRowWidget('Показателей', '${widget.course.healthMetrics.length}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Medications card
              if (widget.course.medications.isNotEmpty) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💊 Лекарства в курсе', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ...widget.course.medications.map((med) => _buildMedicationTile(med)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Health metrics card
              if (widget.course.healthMetrics.isNotEmpty) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📊 Отслеживаемые показатели', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ...widget.course.healthMetrics.map((metric) => _buildHealthMetricTile(metric)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Notes card
              if (widget.course.notes != null && widget.course.notes!.isNotEmpty) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: isDark ? AppColors.darkSurfaceVariant : Colors.amber.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [Icon(Icons.note, color: Colors.amber), SizedBox(width: 8), Text('Заметки', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))],
                        ),
                        const SizedBox(height: 8),
                        Text(widget.course.notes ?? '', style: const TextStyle(height: 1.4)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Compliance chart
              if (_dailyStats.isNotEmpty) ...[
                _buildComplianceChart(),
                const SizedBox(height: 16),
              ],

              // Health charts
              ..._buildHealthCharts(),

              // Schedule list
              _buildScheduleList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isDark ? AppColors.darkSurface : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : Colors.black87),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRowWidget(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Text(':'),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w500, color: valueColor))),
        ],
      ),
    );
  }

  Widget _buildMedicationTile(MedicationSchedule med) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.medication, color: Colors.blue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.medicationName, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  '${med.dosage} • ${med.frequencyText} • ${med.formattedTimes}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text('${med.quantity} шт/приём', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetricTile(HealthMetric metric) {
    final color = _getMetricColor(metric.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(_getMetricIcon(metric.type), color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(metric.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Единица: ${metric.unit}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                if (metric.reminders.isNotEmpty)
                  Text('Замеры: ${metric.formattedReminders}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceChart() {
    final dates = _dailyStats.keys.toList()..sort();
    final spots = <FlSpot>[];
    for (int i = 0; i < dates.length; i++) {
      final data = _dailyStats[dates[i]]!;
      final percent = data['total']! > 0 ? data['completed']! / data['total']! : 0;
      spots.add(FlSpot(i.toDouble(), percent * 100));
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📈 Динамика соблюдения', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Процент выполненных приёмов по дням', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(LineChartData(
                minY: 0,
                maxY: 100,
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text('${value.toInt()}%', style: const TextStyle(fontSize: 10)),
                      reservedSize: 35,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < dates.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('${dates[index].day}.${dates[index].month}', style: const TextStyle(fontSize: 9)),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 30,
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
                  ),
                ],
              )),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHealthCharts() {
    final charts = <Widget>[];
    for (final metric in widget.course.healthMetrics) {
      final data = _healthData[metric.type] ?? [];
      if (data.isEmpty) continue;

      final color = _getMetricColor(metric.type);
      final spots = <FlSpot>[];
      for (int i = 0; i < data.length; i++) {
        spots.add(FlSpot(i.toDouble(), _getNumericValue(metric.type, data[i]['value'])));
      }

      charts.add(Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_getMetricIcon(metric.type), color: color, size: 24),
                  const SizedBox(width: 8),
                  Expanded(child: Text('📊 ${metric.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  Text('${data.length} зап.', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 4),
              Text('Единица: ${metric.unit}', style: TextStyle(fontSize: 12, color: color)),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: LineChart(LineChartData(
                  minY: _getMinY(metric.type, spots),
                  maxY: _getMaxY(metric.type, spots),
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => metric.type == 'temperature'
                            ? Text('${value.toInt()}°', style: const TextStyle(fontSize: 10))
                            : Text('${value.toInt()}', style: const TextStyle(fontSize: 10)),
                        reservedSize: 35,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < data.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('${data[index]['date'].day}.${data[index]['date'].month}', style: const TextStyle(fontSize: 9)),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 30,
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
                    ),
                  ],
                )),
              ),
            ],
          ),
        ),
      ));
      charts.add(const SizedBox(height: 16));
    }
    return charts;
  }

  Widget _buildScheduleList() {
    final sorted = [..._schedule]..sort((a, b) {
      final aTime = (a.data() as Map<String, dynamic>)['scheduledTime'] as Timestamp?;
      final bTime = (b.data() as Map<String, dynamic>)['scheduledTime'] as Timestamp?;
      if (aTime == null || bTime == null) return 0;
      return aTime.toDate().compareTo(bTime.toDate());
    });

    final now = DateTime.now();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📅 Расписание приёмов', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...sorted.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final type = data['type'] as String? ?? 'medication';
              final status = data['status'] as String? ?? 'pending';
              final time = (data['scheduledTime'] as Timestamp?)?.toDate();
              final isPast = time != null && time.isBefore(now);
              final title = type == 'medication' ? data['medicationName'] ?? 'Лекарство' : 'Измерение: ${data['metricName'] ?? 'показатель'}';
              final icon = type == 'medication' ? Icons.medication : Icons.monitor_heart;
              final iconColor = type == 'medication' ? Colors.blue : Colors.red;

              Color statusColor;
              String statusText;
              if (status == 'completed') {
                statusColor = Colors.green;
                statusText = 'Выполнено';
              } else if (status == 'skipped' || status == 'missed') {
                statusColor = Colors.red;
                statusText = 'Пропущено';
              } else if (isPast) {
                statusColor = Colors.orange;
                statusText = 'Просрочено';
              } else {
                statusColor = Colors.blue;
                statusText = 'Ожидает';
              }

              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  time != null ? DateFormat('dd.MM.yyyy HH:mm').format(time) : '—',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(statusText, style: TextStyle(fontSize: 10, color: statusColor)),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  double _getNumericValue(String type, dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      if (type == 'pressure') {
        final parts = value.split('/');
        if (parts.length == 2) return int.tryParse(parts[0])?.toDouble() ?? 0;
      }
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  double _getMinY(String type, List<FlSpot> spots) {
    if (spots.isEmpty) return 0;
    final min = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    switch (type) {
      case 'temperature': return (min - 1).clamp(35.0, double.infinity);
      case 'pulse': return (min - 10).clamp(30.0, double.infinity);
      case 'pressure': return (min - 20).clamp(60.0, double.infinity);
      default: return min - 5;
    }
  }

  double _getMaxY(String type, List<FlSpot> spots) {
    if (spots.isEmpty) return 100;
    final max = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    switch (type) {
      case 'temperature': return (max + 1).clamp(35.5, 42.0);
      case 'pulse': return (max + 10).clamp(40, 150);
      case 'pressure': return (max + 20).clamp(80, 200);
      default: return max + 5;
    }
  }

  String _formatDate(DateTime date) => '${date.day}.${date.month}.${date.year}';
  IconData _getMetricIcon(String type) => type == 'pressure' ? Icons.monitor_heart : (type == 'pulse' ? Icons.favorite : (type == 'temperature' ? Icons.thermostat : Icons.show_chart));
  Color _getMetricColor(String type) => type == 'pressure' ? Colors.red : (type == 'pulse' ? Colors.red.shade700 : (type == 'temperature' ? Colors.orange : Colors.blue));
}