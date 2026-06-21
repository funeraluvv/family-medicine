import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:family_medicine/models/medicine_kit_model.dart';
import 'package:family_medicine/models/medicine_model.dart';
import 'package:family_medicine/services/medicine_service.dart';
import 'package:family_medicine/services/notification_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:family_medicine/theme.dart';

class AddMedicineManualScreen extends StatefulWidget {
  final MedicineKitModel kit;
  final String? initialBarcode;
  final String? initialDescription;
  final String? initialIndications;

  final String? initialName;
  final MedicineForm? initialForm;
  final double? initialDosage;
  final String? initialDosageUnit;

  final bool isEditing;
  final MedicineModel? existingMedicine;

  const AddMedicineManualScreen({
    super.key,
    required this.kit,
    this.initialBarcode,
    this.initialDescription,
    this.initialIndications,
    this.initialName,
    this.initialForm,
    this.initialDosage,
    this.initialDosageUnit,
    this.isEditing = false,
    this.existingMedicine,
  });

  @override
  State<AddMedicineManualScreen> createState() => _AddMedicineManualScreenState();
}

class _AddMedicineManualScreenState extends State<AddMedicineManualScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _indicationsController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();

  late MedicineForm _selectedForm;
  late String _selectedDosageUnit;
  late DateTime _purchaseDate;
  late DateTime _expiryDate;

  final List<String> _dosageUnits = ['мг', 'г', 'мл', 'шт', 'мкг', 'МЕ', '%', 'ЕД'];

  @override
  void initState() {
    super.initState();

    if (widget.isEditing && widget.existingMedicine != null) {
      final medicine = widget.existingMedicine!;
      _nameController.text = medicine.name;
      _dosageController.text = medicine.dosage.toString();
      _quantityController.text = medicine.quantity.toString();
      _descriptionController.text = medicine.description ?? '';
      _barcodeController.text = medicine.barcode ?? '';
      _selectedForm = medicine.form;
      _selectedDosageUnit = medicine.dosageUnit;
      _purchaseDate = medicine.addedDate;
      _expiryDate = medicine.expiryDate;
    } else {
      _selectedForm = widget.initialForm ?? MedicineForm.tablet;
      _selectedDosageUnit = widget.initialDosageUnit ?? 'мг';
      _purchaseDate = DateTime.now();
      _expiryDate = DateTime.now().add(const Duration(days: 365));

      if (widget.initialName != null) {
        _nameController.text = widget.initialName!;
      }
      if (widget.initialDosage != null) {
        _dosageController.text = widget.initialDosage!.toString();
      }
      if (widget.initialDescription != null) {
        _descriptionController.text = widget.initialDescription!;
      }
      if (widget.initialIndications != null) {
        _indicationsController.text = widget.initialIndications!;
      }
      if (widget.initialBarcode != null) {
        _barcodeController.text = widget.initialBarcode!;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _quantityController.dispose();
    _indicationsController.dispose();
    _descriptionController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь не авторизован'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.isEditing && widget.existingMedicine != null) {
        await MedicineService.updateMedicine(
          medicineId: widget.existingMedicine!.id,
          kitId: widget.kit.id,
          name: _nameController.text.trim(),
          form: _selectedForm,
          dosage: double.parse(_dosageController.text.trim()),
          dosageUnit: _selectedDosageUnit,
          quantity: int.parse(_quantityController.text.trim()),
          expiryDate: _expiryDate,
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        );

        await NotificationService.scheduleExpiryNotification(
          medicineId: widget.existingMedicine!.id,
          medicineName: _nameController.text.trim(),
          expiryDate: _expiryDate,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Лекарство обновлено'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        }
      } else {
        final docRef = await MedicineService.addMedicine(
          kitId: widget.kit.id,
          name: _nameController.text.trim(),
          form: _selectedForm,
          dosage: double.parse(_dosageController.text.trim()),
          dosageUnit: _selectedDosageUnit,
          quantity: int.parse(_quantityController.text.trim()),
          purchaseDate: _purchaseDate,
          expiryDate: _expiryDate,
          indications: _indicationsController.text.trim().isEmpty ? null : _indicationsController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        );

        await NotificationService.scheduleExpiryNotification(
          medicineId: docRef.id,
          medicineName: _nameController.text.trim(),
          expiryDate: _expiryDate,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Лекарство добавлено'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        }
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

  Future<void> _selectDate({required bool isPurchase}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isPurchase ? _purchaseDate : _expiryDate,
      firstDate: isPurchase ? DateTime(2000) : DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      locale: const Locale('ru', 'RU'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
              primary: AppColors.darkPrimary,
              onPrimary: Colors.white,
              surface: AppColors.darkSurface,
            )
                : const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
            dialogBackgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isPurchase) {
          _purchaseDate = picked;
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kitColor = Color(widget.kit.colorValue);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Редактировать лекарство' : 'Добавить лекарство'),
        backgroundColor: isDark ? AppColors.darkSurface : kitColor,
        foregroundColor: isDark ? AppColors.darkTextPrimary : Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTextField(
              controller: _nameController,
              label: 'Название *',
              icon: Icons.medication,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Введите название';
                return null;
              },
            ),
            const SizedBox(height: 16),


            _buildFormSelector(),
            const SizedBox(height: 16),

            _buildDosageRow(),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _quantityController,
              label: 'Количество *',
              icon: Icons.numbers,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Введите количество';
                final quantity = int.tryParse(value.trim());
                if (quantity == null) return 'Введите целое число';
                if (quantity <= 0) return 'Количество должно быть больше 0';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ========== ДАТЫ ==========
            _buildDatePicker(
              label: 'Дата покупки',
              icon: Icons.shopping_cart,
              date: _purchaseDate,
              onTap: () => _selectDate(isPurchase: true),
            ),
            const SizedBox(height: 12),

            _buildDatePicker(
              label: 'Срок годности *',
              icon: Icons.calendar_today,
              date: _expiryDate,
              onTap: () => _selectDate(isPurchase: false),
            ),
            const SizedBox(height: 16),

            // ========== ПОКАЗАНИЯ ==========
            _buildTextField(
              controller: _indicationsController,
              label: 'Показания',
              icon: Icons.healing,
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // ========== ОПИСАНИЕ ==========
            _buildTextField(
              controller: _descriptionController,
              label: 'Описание',
              icon: Icons.note,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // ========== ШТРИХ-КОД ==========
            if (widget.initialBarcode != null || (widget.isEditing && widget.existingMedicine?.barcode != null))
              _buildBarcodeInfo(),

            const SizedBox(height: 24),


            _buildNotificationInfo(),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveMedicine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkPrimary : kitColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(widget.isEditing ? 'Сохранить изменения' : 'Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      style: TextStyle(color: isDark ? AppColors.darkTextPrimary : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
        prefixIcon: Icon(icon, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: isDark ? AppColors.darkInputFill : Colors.grey.shade50,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppColors.darkInputBorder : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppColors.darkPrimary : AppColors.primary),
        ),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildFormSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Форма выпуска *',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: isDark ? AppColors.darkTextPrimary : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: MedicineForm.values.length,
            itemBuilder: (context, index) {
              final form = MedicineForm.values[index];
              final isSelected = _selectedForm == form;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedForm = form;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 75,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? form.color.withOpacity(0.15)
                        : (isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? form.color : (isDark ? AppColors.darkInputBorder : Colors.grey.shade300),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                        color: form.color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        form.svgPath,
                        width: 28,
                        height: 28,
                        colorFilter: ColorFilter.mode(
                          isSelected ? form.color : (isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        form.shortName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? form.color
                              : (isDark ? AppColors.darkTextSecondary : Colors.grey.shade700),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDosageRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: _dosageController,
            style: TextStyle(color: isDark ? AppColors.darkTextPrimary : Colors.black87),
            decoration: InputDecoration(
              labelText: 'Дозировка *',
              hintText: '500',
              hintStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500),
              prefixIcon: const Icon(Icons.speed),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkInputFill : Colors.grey.shade50,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? AppColors.darkInputBorder : Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? AppColors.darkPrimary : AppColors.primary),
              ),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Введите дозировку';
              final dosage = double.tryParse(value.trim());
              if (dosage == null) return 'Введите число';
              if (dosage <= 0) return 'Дозировка должна быть больше 0';
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkInputFill : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkInputBorder : Colors.grey.shade400),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDosageUnit,
                isExpanded: true,
                dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                style: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                ),
                items: _dosageUnits.map((unit) {
                  return DropdownMenuItem(
                    value: unit,
                    child: Text(unit),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDosageUnit = value!;
                  });
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required IconData icon,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkInputFill : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkInputBorder : Colors.grey.shade400),
        ),
        child: Row(
          children: [
            Icon(icon, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    DateFormat('dd MMMM yyyy', 'ru_RU').format(date),
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildBarcodeInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barcode = widget.isEditing
        ? widget.existingMedicine?.barcode
        : widget.initialBarcode;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkInputBorder : Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.qr_code, color: isDark ? AppColors.darkPrimary : Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Штрих-код',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkPrimary : Colors.blue.shade700,
                  ),
                ),
                Text(
                  barcode ?? '',
                  style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.blue.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkInputBorder : Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active, color: isDark ? AppColors.darkPrimary : Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Уведомления будут запланированы:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkPrimary : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• За 30, 14, 7, 3, 1 день до истечения срока\n'
                      '• В день истечения срока годности',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}