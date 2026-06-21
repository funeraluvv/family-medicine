import 'package:flutter/material.dart';
import 'package:family_medicine/models/medicine_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:family_medicine/theme.dart';

// Класс для передачи данных из формы
class MedicineFormData {
  final String name;
  final MedicineForm form;
  final double dosage;
  final String dosageUnit;
  final int quantity;
  final DateTime purchaseDate;
  final DateTime expiryDate;
  final String? indications;
  final String? description;

  MedicineFormData({
    required this.name,
    required this.form,
    required this.dosage,
    required this.dosageUnit,
    required this.quantity,
    required this.purchaseDate,
    required this.expiryDate,
    this.indications,
    this.description,
  });
}

class MedicineFormWidget extends StatefulWidget {
  final Function(MedicineFormData) onSubmit;
  final MedicineFormData? initialData;
  final String kitName;

  const MedicineFormWidget({
    super.key,
    required this.onSubmit,
    this.initialData,
    required this.kitName,
  });

  @override
  State<MedicineFormWidget> createState() => _MedicineFormWidgetState();
}

class _MedicineFormWidgetState extends State<MedicineFormWidget> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController dosageController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController indicationsController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  late MedicineForm selectedForm;
  late String selectedDosageUnit;
  late DateTime selectedPurchaseDate;
  late DateTime selectedExpiryDate;

  bool _isLoading = false;

  final List<String> dosageUnits = ['мг', 'г', 'мл', 'шт', 'мкг', 'МЕ', '%', 'ЕД'];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      nameController.text = widget.initialData!.name;
      dosageController.text = widget.initialData!.dosage.toString();
      quantityController.text = widget.initialData!.quantity.toString();
      indicationsController.text = widget.initialData!.indications ?? '';
      descriptionController.text = widget.initialData!.description ?? '';
      selectedForm = widget.initialData!.form;
      selectedDosageUnit = widget.initialData!.dosageUnit;
      selectedPurchaseDate = widget.initialData!.purchaseDate;
      selectedExpiryDate = widget.initialData!.expiryDate;
    } else {
      selectedForm = MedicineForm.tablet;
      selectedDosageUnit = 'мг';
      selectedPurchaseDate = DateTime.now();
      selectedExpiryDate = DateTime.now().add(const Duration(days: 365));
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    quantityController.dispose();
    indicationsController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Form(
      key: _formKey,
      child: ListView(
        children: [
          // Название
          _buildTextField(
            controller: nameController,
            label: 'Название *',
            icon: Icons.medication,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Введите название';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Форма выпуска
          _buildFormSelector(),
          const SizedBox(height: 16),

          // Дозировка
          _buildDosageRow(),
          const SizedBox(height: 16),

          // Количество
          _buildTextField(
            controller: quantityController,
            label: 'Количество *',
            icon: Icons.numbers,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Введите количество';
              if (int.tryParse(value) == null) return 'Введите целое число';
              if (int.parse(value) <= 0) return 'Количество должно быть больше 0';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Дата покупки
          _buildDatePicker(
            label: 'Дата покупки *',
            icon: Icons.shopping_cart,
            date: selectedPurchaseDate,
            onTap: () => _selectDate(isPurchase: true),
          ),
          const SizedBox(height: 16),

          // Срок годности
          _buildDatePicker(
            label: 'Срок годности *',
            icon: Icons.calendar_today,
            date: selectedExpiryDate,
            onTap: () => _selectDate(isPurchase: false),
          ),
          const SizedBox(height: 16),

          // Показания
          _buildTextField(
            controller: indicationsController,
            label: 'Показания',
            icon: Icons.healing,
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // Описание
          _buildTextField(
            controller: descriptionController,
            label: 'Описание (необязательно)',
            icon: Icons.note,
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          // Информация об уведомлениях
          _buildNotificationInfo(),
          const SizedBox(height: 24),

          // Кнопка
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Сохранить'),
            ),
          ),
        ],
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
            color: isDark ? AppColors.darkTextPrimary : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: MedicineForm.values.length,
            itemBuilder: (context, index) {
              final form = MedicineForm.values[index];
              final isSelected = selectedForm == form;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedForm = form;
                  });
                },
                child: Container(
                  width: 70,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? form.color.withOpacity(0.2)
                        : (isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? form.color : (isDark ? AppColors.darkInputBorder : Colors.grey.shade300),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        form.svgPath,
                        width: 28,
                        height: 28,
                        colorFilter: ColorFilter.mode(
                          isSelected ? form.color : (isDark ? AppColors.darkTextSecondary : Colors.grey.shade700),
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        form.label.split(' ').last,
                        style: TextStyle(
                          fontSize: 10,
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
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: dosageController,
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
              if (value == null || value.isEmpty) return 'Введите дозировку';
              if (double.tryParse(value) == null) return 'Введите число';
              if (double.parse(value) <= 0) return 'Дозировка должна быть больше 0';
              return null;
            },
          ),
        ),
        const SizedBox(width: 8),
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
                value: selectedDosageUnit,
                isExpanded: true,
                dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                style: TextStyle(color: isDark ? AppColors.darkTextPrimary : Colors.black87),
                items: dosageUnits.map((unit) {
                  return DropdownMenuItem(
                    value: unit,
                    child: Text(unit),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedDosageUnit = value!;
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
                  '• За 30 дней до истечения срока\n'
                      '• За 14 дней\n'
                      '• За 7 дней\n'
                      '• За 3 дня\n'
                      '• За 1 день\n'
                      '• В день истечения',
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

  Future<void> _selectDate({required bool isPurchase}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isPurchase ? selectedPurchaseDate : selectedExpiryDate,
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
              primary: Colors.green,
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
          selectedPurchaseDate = picked;
        } else {
          selectedExpiryDate = picked;
        }
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      widget.onSubmit(MedicineFormData(
        name: nameController.text.trim(),
        form: selectedForm,
        dosage: double.parse(dosageController.text.trim()),
        dosageUnit: selectedDosageUnit,
        quantity: int.parse(quantityController.text.trim()),
        purchaseDate: selectedPurchaseDate,
        expiryDate: selectedExpiryDate,
        indications: indicationsController.text.isNotEmpty ? indicationsController.text.trim() : null,
        description: descriptionController.text.isNotEmpty ? descriptionController.text.trim() : null,
      ));
    }
  }
}