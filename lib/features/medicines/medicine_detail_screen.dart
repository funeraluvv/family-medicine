import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/medicine_model.dart';
import '../../services/medicine_service.dart';
import 'add_medicine_manual_screen.dart';
import 'package:family_medicine/models/medicine_kit_model.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MedicineDetailScreen extends StatefulWidget {
  final MedicineModel medicine;
  final Color kitColor;

  const MedicineDetailScreen({
    super.key,
    required this.medicine,
    required this.kitColor,
  });

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  String getStatus() {
    final now = DateTime.now();
    final expiry = widget.medicine.expiryDate;

    if (expiry.isBefore(now)) {
      return 'Просрочено';
    }

    final daysLeft = expiry.difference(now).inDays;

    if (daysLeft > 180) return 'Норма';
    if (daysLeft > 30) return 'Срок подходит к концу';
    return 'Скоро истекает';
  }

  Color getStatusColor() {
    final now = DateTime.now();
    final expiry = widget.medicine.expiryDate;

    if (expiry.isBefore(now)) return Colors.red.shade400;

    final daysLeft = expiry.difference(now).inDays;

    if (daysLeft > 180) return Colors.green.shade400;
    if (daysLeft > 30) return Colors.orange.shade400;
    return Colors.deepOrange.shade400;
  }

  IconData getFormIcon() {
    switch (widget.medicine.form) {
      case MedicineForm.tablet:
        return Icons.circle;
      case MedicineForm.capsule:
        return Icons.blur_circular;
      case MedicineForm.syrup:
        return Icons.local_drink;
      case MedicineForm.ointment:
        return Icons.healing;
      case MedicineForm.spray:
        return Icons.air;
      case MedicineForm.drops:
        return Icons.water_drop;
      case MedicineForm.powder:
        return Icons.bubble_chart;
      case MedicineForm.ampoule:
        return Icons.medical_services;
      case MedicineForm.other:
        return Icons.medication;
    }
  }

  Color getFormIconColor() {
    return widget.medicine.form.color;
  }

  Future<void> _deleteMedicine() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить препарат'),
        content: Text('Удалить "${widget.medicine.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await MedicineService.deleteMedicine(
      medicineId: widget.medicine.id,
      kitId: widget.medicine.kitId,
    );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _editMedicine() async {
    // Загружаем данные аптечки по ID
    final kitDoc = await FirebaseFirestore.instance
        .collection('medicine_kits')
        .doc(widget.medicine.kitId)
        .get();

    if (!kitDoc.exists) {
      _showSnackBar('Аптечка не найдена', Colors.red);
      return;
    }

    final kit = MedicineKitModel.fromFirestore(kitDoc);

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddMedicineManualScreen(
          kit: kit,
          isEditing: true,
          existingMedicine: widget.medicine,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final statusColor = getStatusColor();
    final now = DateTime.now();
    final expiry = widget.medicine.expiryDate;
    final isExpired = expiry.isBefore(now);

    // Более точный расчёт прогресса срока годности
    double expiryProgress;

    if (isExpired) {
      expiryProgress = 0.0;
    } else {
      final addedDate = widget.medicine.addedDate;

      final totalDays = expiry.difference(addedDate).inDays;
      final remainingDays = expiry.difference(now).inDays;

      if (totalDays <= 0) {
        expiryProgress = 0.0;
      } else {
        expiryProgress = (remainingDays / totalDays).clamp(0.0, 1.0);
      }
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey.shade900 : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: widget.medicine.form.color.withOpacity(isDarkMode ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SvgPicture.asset(
                          widget.medicine.form.svgPath,
                          width: 40,
                          height: 40,
                          colorFilter: ColorFilter.mode(
                            widget.medicine.form.color,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.medicine.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.medicine.form.label} • ${widget.medicine.dosage} ${widget.medicine.dosageUnit}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: isDarkMode ? Colors.white : Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(isDarkMode ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: statusColor.withOpacity(isDarkMode ? 0.3 : 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(isDarkMode ? 0.25 : 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isExpired ? Icons.warning : Icons.health_and_safety,
                          color: statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          getStatus(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _infoItem(
                        icon: Icons.speed,
                        title: 'Дозировка',
                        value: '${widget.medicine.dosage} ${widget.medicine.dosageUnit}',
                        isDarkMode: isDarkMode,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                      ),
                      _infoItem(
                        icon: Icons.inventory_2_outlined,
                        title: 'Количество',
                        value: '${widget.medicine.quantity} ${_getQuantityUnit()}',
                        isDarkMode: isDarkMode,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                      ),
                      _infoItem(
                        icon: Icons.calendar_today,
                        title: 'Годен до',
                        value: DateFormat('dd.MM.yyyy').format(expiry),
                        isDarkMode: isDarkMode,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Срок годности',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          isExpired ? 'Истёк' : '${expiry.difference(now).inDays} дней осталось',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        value: expiryProgress,
                        minHeight: 8,
                        backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                if (widget.medicine.description != null &&
                    widget.medicine.description!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.description,
                                size: 18,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              'Описание',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.medicine.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 30),


                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _editMedicine,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Редактировать'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDarkMode ? Colors.white : Colors.black,
                          side: BorderSide(
                            color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _deleteMedicine,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Удалить'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String title,
    required String value,
    required bool isDarkMode,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon,
              size: 20, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  String _getQuantityUnit() {
    switch (widget.medicine.form) {
      case MedicineForm.tablet:
      case MedicineForm.capsule:
      case MedicineForm.ampoule:
        return 'шт';
      case MedicineForm.syrup:
      case MedicineForm.drops:
      case MedicineForm.spray:
        return 'мл';
      case MedicineForm.ointment:
      case MedicineForm.powder:
        return 'г';
      default:
        return 'шт';
    }
  }
}