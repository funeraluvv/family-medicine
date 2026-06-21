import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:family_medicine/theme.dart';
import 'package:family_medicine/models/medicine_kit_model.dart';
import 'package:family_medicine/features/medicines/kit_detail_screen.dart';
import 'package:family_medicine/models/medicine_model.dart';
import 'package:family_medicine/services/medicine_service.dart';

class MedicineTab extends StatefulWidget {
  final bool isSelectionMode;
  const MedicineTab({super.key, this.isSelectionMode = false});

  @override
  State<MedicineTab> createState() => _MedicineTabState();
}

class _MedicineTabState extends State<MedicineTab> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String? familyId;
  bool _isLoading = true;
  String _filterType = 'all';
  List<MedicineKitModel> _kits = [];
  final List<MedicineModel> _selectedMedicines = [];

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    await _loadFamilyId();
    await MedicineService.ensurePersonalKit(); // создаст личную аптечку, если нет
    await _loadKits();
    setState(() => _isLoading = false);
  }

  Future<void> _loadFamilyId() async {
    familyId = await MedicineService.getFamilyId();
  }

  Future<void> _loadKits() async {
    final kits = await MedicineService.getUserKitsFuture();
    setState(() => _kits = kits);
  }

  void _addSelectedMedicines(List<MedicineModel> newMeds) {
    setState(() {
      for (var med in newMeds) {
        if (!_selectedMedicines.any((m) => m.id == med.id)) {
          _selectedMedicines.add(med);
        }
      }
    });
  }

  void _finishSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(_selectedMedicines);
    });
  }

  String _getMedicineWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'препарат';
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) return 'препарата';
    return 'препаратов';
  }

  Future<void> _deleteKit(MedicineKitModel kit) async {
    try {
      await MedicineService.deleteKit(kit);
      await _loadKits(); // обновляем список после удаления
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Аптечка удалена'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Фильтрация по типу
    List<MedicineKitModel> filtered = _kits;
    if (_filterType == 'personal') {
      filtered = filtered.where((k) => k.type == 'personal').toList();
    } else if (_filterType == 'family') {
      filtered = filtered.where((k) => k.type == 'family').toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSelectionMode ? 'Выберите аптечку' : 'Аптечка'),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        foregroundColor: isDark ? AppColors.darkTextPrimary : Colors.black87,
        elevation: 0,
        actions: [
          if (!widget.isSelectionMode && familyId != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.filter_list, color: isDark ? AppColors.darkTextSecondary : Colors.grey),
              onSelected: (value) => setState(() => _filterType = value),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'all', child: Text('Все аптечки')),
                PopupMenuItem(value: 'personal', child: Text('Личные')),
                PopupMenuItem(value: 'family', child: Text('Семейные')),
              ],
            ),
          if (widget.isSelectionMode)
            TextButton(
              onPressed: _selectedMedicines.isEmpty ? null : _finishSelection,
              child: Text('Готово (${_selectedMedicines.length})'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadKits,
        child: filtered.isEmpty
            ? Center(
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
                'Нет аптечек',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              if (!widget.isSelectionMode)
                ElevatedButton.icon(
                  onPressed: _showAddKitDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Создать аптечку'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                  ),
                ),
            ],
          ),
        )
            : GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) => _buildKitCard(filtered[index]),
        ),
      ),
      floatingActionButton: widget.isSelectionMode
          ? null
          : FloatingActionButton.extended(
        onPressed: _showAddKitDialog,
        icon: const Icon(Icons.add),
        label: const Text('Аптечка'),
        backgroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildKitCard(MedicineKitModel kit) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final originalColor = Color(kit.colorValue);
    final isFamily = kit.type == 'family';
    final isOwner = kit.createdBy == currentUser?.uid;
    final canDelete = !widget.isSelectionMode && isOwner;

    final backgroundColor = originalColor;
    final luminance = backgroundColor.computeLuminance();

    final textColor = luminance > 0.5 ? Colors.black87 : Colors.white;
    final secondaryTextColor = luminance > 0.5 ? Colors.black54 : Colors.white70;
    final iconColor = luminance > 0.5 ? Colors.black54 : Colors.white70;

    return GestureDetector(
      onTap: () {
        if (widget.isSelectionMode) {
          _openKitForSelection(kit);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => KitDetailScreen(kit: kit)),
          );
        }
      },
      onLongPress: canDelete ? () => _deleteKit(kit) : null,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      kit.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    isFamily ? Icons.family_restroom : Icons.person,
                    color: iconColor,
                    size: 20,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${kit.medicinesCount} ${_getMedicineWord(kit.medicinesCount)}',
                style: TextStyle(
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openKitForSelection(MedicineKitModel kit) async {
    final selected = await Navigator.push<List<MedicineModel>>(
      context,
      MaterialPageRoute(
        builder: (_) => KitDetailScreen(kit: kit, isSelectionMode: true),
      ),
    );
    if (selected != null && selected.isNotEmpty) {
      setState(() {
        for (var med in selected) {
          if (!_selectedMedicines.any((m) => m.id == med.id)) {
            _selectedMedicines.add(med);
          }
        }
      });
    }
  }

  void _showAddKitDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    int selectedColor = 0xFFE3F2FD;
    String selectedType = 'personal';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Если пользователь не в семье, нельзя создать семейную аптечку
    final bool canCreateFamily = familyId != null && familyId!.isNotEmpty;

    final List<int> colorValues = [
      0xFFE3F2FD,
      0xFFE8F5E9,
      0xFFFFF3E0,
      0xFFF3E5F5,
      0xFFFFEBEE,
      0xFFE0F2F1,
      0xFFFFF9C4,
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Создать аптечку'),
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Название',
                      hintText: 'Например: Домашняя',
                      labelStyle: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                      ),
                      hintStyle: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkInputBorder : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Описание (необязательно)',
                      hintText: 'Где находится, для кого...',
                      labelStyle: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                      ),
                      hintStyle: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkInputBorder : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  const Text('Тип аптечки', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Личная'),
                          selected: selectedType == 'personal',
                          onSelected: (selected) {
                            if (selected) setState(() => selectedType = 'personal');
                          },
                          selectedColor: Colors.green.shade100,
                          labelStyle: TextStyle(
                            color: _getChipTextColor(selectedType == 'personal', isDark),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Tooltip(
                          message: canCreateFamily ? '' : 'Вы не состоите в семье',
                          child: ChoiceChip(
                            label: const Text('Семейная'),
                            selected: selectedType == 'family',
                            selectedColor: Colors.blue.shade100,
                            labelStyle: TextStyle(
                              color: _getChipTextColor(selectedType == 'family', isDark),
                            ),
                            onSelected: canCreateFamily
                                ? (selected) {
                              if (selected) setState(() => selectedType = 'family');
                            }
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!canCreateFamily && selectedType == 'family')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Чтобы создать семейную аптечку, сначала присоединитесь к семье.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text('Цвет аптечки', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: colorValues.map((colorValue) {
                      final color = Color(colorValue);
                      final isSelected = selectedColor == colorValue;
                      return GestureDetector(
                        onTap: () => setState(() => selectedColor = colorValue),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: isDark ? AppColors.darkPrimary : Colors.black, width: 2)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Отмена', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade700)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Введите название аптечки')),
                    );
                    return;
                  }
                  if (selectedType == 'family' && !canCreateFamily) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Вы не состоите в семье, нельзя создать семейную аптечку')),
                    );
                    return;
                  }
                  try {
                    await MedicineService.createKit(
                      name: name,
                      description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                      colorValue: selectedColor,
                      type: selectedType,
                      familyId: selectedType == 'family' ? familyId : null,
                    );
                    if (!mounted) return;
                    Navigator.pop(context);
                    await _loadKits(); // обновляем список после создания
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Аптечка создана'), backgroundColor: Colors.green),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                ),
                child: const Text('Создать'),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getChipTextColor(bool isSelected, bool isDark) {
    if (isSelected) return Colors.black87;
    return isDark ? AppColors.darkTextSecondary : Colors.black54;
  }
}