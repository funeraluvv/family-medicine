

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_medicine/models/medicine_kit_model.dart';
import 'package:family_medicine/models/medicine_model.dart';
import 'package:family_medicine/services/medicine_service.dart';
import 'package:family_medicine/features/medicines/add_medicine_manual_screen.dart';
import 'package:family_medicine/features/medicines/add_medicine_barcode_screen.dart';
import 'package:family_medicine/features/medicines/add_medicine_catalog_screen.dart';
import 'package:family_medicine/data/barcode_database.dart';
import 'package:family_medicine/features/medicines/medicine_detail_screen.dart';
import 'package:family_medicine/data/popular_medicines_data.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:family_medicine/theme.dart';

class KitDetailScreen extends StatefulWidget {
  final MedicineKitModel kit;
  final bool isSelectionMode;

  const KitDetailScreen({
    super.key,
    required this.kit,
    this.isSelectionMode = false,
  });

  @override
  State<KitDetailScreen> createState() => _KitDetailScreenState();
}

class _KitDetailScreenState extends State<KitDetailScreen> {
  String _sortBy = 'expiry';
  final Set<String> _selectedIds = {};
  List<MedicineModel> _allMedicines = [];

  void _updateAllMedicines(List<MedicineModel> medicines) {
    _allMedicines = medicines;
  }

  void _finishSelection() {
    final selected = _allMedicines.where((m) => _selectedIds.contains(m.id)).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kitColor = Color(widget.kit.colorValue);
    final adjustedKitColor = isDark ? _adjustColorForDarkMode(kitColor) : kitColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kit.name),
        foregroundColor: isDark ? AppColors.darkTextPrimary : Colors.black87,
        elevation: 0,
        actions: [
          if (!widget.isSelectionMode)
            PopupMenuButton<String>(
              icon: Icon(Icons.sort, color: isDark ? AppColors.darkTextPrimary : Colors.black87),
              onSelected: (value) {
                setState(() {
                  _sortBy = value;
                });
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'expiry', child: Text('По сроку годности')),
                PopupMenuItem(value: 'name', child: Text('По названию')),
              ],
            ),
          if (widget.isSelectionMode)
            TextButton(
              onPressed: _selectedIds.isEmpty ? null : _finishSelection,
              child: Text('Готово (${_selectedIds.length})'),
            ),
        ],
      ),
      body: StreamBuilder<List<MedicineModel>>(
        stream: MedicineService.getMedicinesByKitStream(widget.kit.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var list = List<MedicineModel>.from(snapshot.data!);
          _updateAllMedicines(list);

          if (_sortBy == 'name') {
            list.sort((a, b) => a.name.compareTo(b.name));
          } else {
            list.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
          }

          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'В аптечке пока нет лекарств',
                    style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _showAddOptions,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить лекарство'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: adjustedKitColor,
                      foregroundColor: isDark ? AppColors.darkTextPrimary : Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) => _buildMedicineCard(list[index]),
          );
        },
      ),
      floatingActionButton: widget.isSelectionMode
          ? null
          : FloatingActionButton(
        onPressed: _showAddOptions,
        backgroundColor: adjustedKitColor,
        child: Icon(Icons.add, color: isDark ? AppColors.darkTextPrimary : Colors.black87),
      ),
    );
  }

  Widget _buildMedicineCard(MedicineModel medicine) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedIds.contains(medicine.id);
    final expiryStatus = medicine.expiryStatus;
    final isExpired = medicine.expiryDate.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (widget.isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedIds.remove(medicine.id);
              } else {
                _selectedIds.add(medicine.id);
              }
            });
          } else {
            _showMedicineDetail(medicine);
          }
        },
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // SVG иконка формы лекарства
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: medicine.form.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: SvgPicture.asset(
                        medicine.form.svgPath,
                        width: 30,
                        height: 30,
                        colorFilter: ColorFilter.mode(
                          medicine.form.color,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Информация о лекарстве
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicine.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${medicine.dosage} ${medicine.dosageUnit} • ${medicine.form.label}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Индикатор количества
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: medicine.quantity <= 5
                                    ? (isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50)
                                    : (isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${medicine.quantity} шт.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: medicine.quantity <= 5
                                      ? (isDark ? Colors.red.shade300 : Colors.red.shade700)
                                      : (isDark ? Colors.green.shade300 : Colors.green.shade700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Статус срока годности
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isExpired
                                    ? (isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50)
                                    : (isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade50),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                expiryStatus.length > 20
                                    ? '${expiryStatus.substring(0, 20)}...'
                                    : expiryStatus,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isExpired
                                      ? (isDark ? Colors.red.shade300 : Colors.red.shade700)
                                      : (isDark ? Colors.orange.shade300 : Colors.orange.shade700),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Кто добавил лекарство
                        const SizedBox(height: 8),
                        _buildAddedByInfo(medicine),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.isSelectionMode)
              Positioned(
                right: 8,
                top: 8,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) _selectedIds.add(medicine.id);
                      else _selectedIds.remove(medicine.id);
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Виджет "Кто добавил лекарство" с аватаркой
  Widget _buildAddedByInfo(MedicineModel medicine) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(medicine.addedBy)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey,
                child: Icon(Icons.person, size: 10, color: isDark ? AppColors.darkTextSecondary : Colors.white),
              ),
              const SizedBox(width: 4),
              Text(
                medicine.addedByName,
                style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500),
              ),
            ],
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final avatarUrl = data?['avatarUrl'] as String?;
        final userName = medicine.addedByName;

        return Row(
          children: [
            CircleAvatar(
              radius: 10,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? AssetImage(avatarUrl) as ImageProvider
                  : null,
              backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade300,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 8, color: isDark ? AppColors.darkTextPrimary : Colors.black87),
              )
                  : null,
            ),
            const SizedBox(width: 4),
            Text(
              'Добавил(а): $userName',
              style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500),
            ),
          ],
        );
      },
    );
  }

  /// Адаптация цвета для тёмной темы
  Color _adjustColorForDarkMode(Color color) {
    double red = color.red / 255;
    double green = color.green / 255;
    double blue = color.blue / 255;

    red = (red * 1.2).clamp(0.0, 1.0);
    green = (green * 1.2).clamp(0.0, 1.0);
    blue = (blue * 1.2).clamp(0.0, 1.0);

    return Color.fromRGBO((red * 255).round(), (green * 255).round(), (blue * 255).round(), 1.0);
  }

  void _showMedicineDetail(MedicineModel medicine) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MedicineDetailScreen(medicine: medicine, kitColor: widget.kit.color),
    );
  }

  void _showAddOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: Text('Ввести вручную', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : Colors.black87)),
            onTap: () {
              Navigator.pop(context);
              _navigateToManualAdd();
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner, color: Colors.green),
            title: Text('По штрих-коду', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : Colors.black87)),
            onTap: () {
              Navigator.pop(context);
              _navigateToBarcodeScanner();
            },
          ),
          ListTile(
            leading: const Icon(Icons.list, color: Colors.orange),
            title: Text('Из каталога', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : Colors.black87)),
            onTap: () {
              Navigator.pop(context);
              _navigateToCatalogAdd();
            },
          ),
        ],
      ),
    );
  }

  void _navigateToManualAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedicineManualScreen(kit: widget.kit),
      ),
    );
  }

  Future<void> _navigateToBarcodeScanner() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicineBarcodeScreen()),
    );

    if (barcode == null) return;

    final medicineData = barcodeDatabase[barcode];

    if (medicineData != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddMedicineManualScreen(
            kit: widget.kit,
            initialBarcode: barcode,
            initialName: medicineData.name,
            initialForm: medicineData.form,
            initialDosage: medicineData.dosage,
            initialDosageUnit: medicineData.dosageUnit,
            initialDescription: medicineData.description,
            initialIndications: medicineData.indications,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Штрих-код $barcode не найден. Заполните вручную.'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddMedicineManualScreen(
            kit: widget.kit,
            initialBarcode: barcode,
          ),
        ),
      );
    }
  }

  Future<void> _navigateToCatalogAdd() async {
    final selectedMedicine = await Navigator.push<PopularMedicine>(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicineCatalogScreen()),
    );

    if (selectedMedicine != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddMedicineManualScreen(
            kit: widget.kit,
            initialName: selectedMedicine.name,
            initialForm: selectedMedicine.form,
            initialDosage: selectedMedicine.dosage,
            initialDosageUnit: selectedMedicine.dosageUnit,
            initialDescription: selectedMedicine.description,
            initialIndications: selectedMedicine.indications,
          ),
        ),
      );
    }
  }
}