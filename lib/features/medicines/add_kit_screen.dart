import 'package:flutter/material.dart';
import 'package:family_medicine/services/medicine_service.dart';

class AddMedicineKitScreen extends StatefulWidget {
  const AddMedicineKitScreen({super.key});

  @override
  State<AddMedicineKitScreen> createState() => _AddMedicineKitScreenState();
}

class _AddMedicineKitScreenState extends State<AddMedicineKitScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _familyId;
  String _selectedType = 'personal';
  int _selectedColorValue = 0xFFE3F2FD;
  bool _isLoading = false;

  // Доступные цвета для аптечки
  final List<int> _colorValues = [
    0xFFE3F2FD,
    0xFFE8F5E9,
    0xFFFFF3E0,
    0xFFF3E5F5,
    0xFFFFEBEE,
    0xFFE0F2F1,
    0xFFFFF9C4,
    0xFFFCE4EC,
    0xFFE8EAF6,
    0xFFFFF8E1,
  ];

  @override
  void initState() {
    super.initState();
    _loadFamilyId();
  }

  Future<void> _loadFamilyId() async {
    _familyId = await MedicineService.getFamilyId();
    setState(() {});
  }

  Future<void> _createMedicineKit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await MedicineService.createKit(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        colorValue: _selectedColorValue,
        type: _selectedType,
        familyId: _selectedType == 'family' ? _familyId : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Аптечка создана'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать аптечку'),
        backgroundColor: Color(_selectedColorValue),
        foregroundColor: _getForegroundColor(),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название аптечки *',
                hintText: 'Например: Домашняя, Дачная, Для путешествий',
                prefixIcon: Icon(Icons.medical_services),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите название аптечки';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Описание (необязательно)',
                hintText: 'Где находится, для кого предназначена...',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // ========== ТИП АПТЕЧКИ ==========
            const Text(
              'Тип аптечки',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTypeCard(
                    title: 'Личная',
                    description: 'Только для вас',
                    icon: Icons.person,
                    typeValue: 'personal',
                    isSelected: _selectedType == 'personal',
                    onTap: () => setState(() => _selectedType = 'personal'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTypeCard(
                    title: 'Семейная',
                    description: 'Для всех членов семьи',
                    icon: Icons.family_restroom,
                    typeValue: 'family',
                    isSelected: _selectedType == 'family',
                    isDisabled: _familyId == null,
                    disabledReason: 'Вы не состоите в семье',
                    onTap: () => setState(() => _selectedType = 'family'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ========== ВЫБОР ЦВЕТА ==========
            const Text(
              'Цвет аптечки',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _colorValues.map((colorValue) {
                final color = Color(colorValue);
                final isSelected = _selectedColorValue == colorValue;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColorValue = colorValue;
                    });
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 3)
                          : Border.all(color: Colors.grey.shade300, width: 1),
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                          : null,
                    ),
                    child: isSelected
                        ? const Center(
                      child: Icon(Icons.check, size: 24, color: Colors.black54),
                    )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // ========== КНОПКА СОЗДАНИЯ ==========
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createMedicineKit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(_selectedColorValue),
                  foregroundColor: _getForegroundColor(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                  'Создать аптечку',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Карточка выбора типа аптечки
  Widget _buildTypeCard({
    required String title,
    required String description,
    required IconData icon,
    required String typeValue,
    required bool isSelected,
    required VoidCallback onTap,
    bool isDisabled = false,
    String? disabledReason,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Color(_selectedColorValue).withOpacity(0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Color(_selectedColorValue)
                : (isDisabled ? Colors.grey.shade300 : Colors.grey.shade400),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Color(_selectedColorValue).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? Color(_selectedColorValue)
                  : (isDisabled ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Color(_selectedColorValue)
                    : (isDisabled ? Colors.grey.shade500 : Colors.black87),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: isDisabled ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (isDisabled && disabledReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  disabledReason,
                  style: TextStyle(fontSize: 10, color: Colors.orange.shade800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getForegroundColor() {
    final color = Color(_selectedColorValue);
    final brightness = color.computeLuminance();
    return brightness > 0.5 ? Colors.black87 : Colors.white;
  }
}