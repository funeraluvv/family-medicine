// features/medicines/add_medicine_catalog_screen.dart
import 'package:flutter/material.dart';
import 'package:family_medicine/models/medicine_model.dart';
import 'package:family_medicine/data/popular_medicines_data.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:family_medicine/theme.dart';

class AddMedicineCatalogScreen extends StatefulWidget {
  const AddMedicineCatalogScreen({super.key});

  @override
  State<AddMedicineCatalogScreen> createState() => _AddMedicineCatalogScreenState();
}

class _AddMedicineCatalogScreenState extends State<AddMedicineCatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<PopularMedicine> _filteredMedicines = [];
  List<String> _alphabet = [];
  Map<String, int> _sectionPositions = {};
  String? _activeLetter;

  static const double _itemHeight = 80.0;
  static const double _headerHeight = 32.0;

  @override
  void initState() {
    super.initState();
    popularMedicines.sort((a, b) => a.name.compareTo(b.name));
    _filteredMedicines = List.from(popularMedicines);
    _buildAlphabet();
    _searchController.addListener(_filterMedicines);
    _scrollController.addListener(_updateActiveLetter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _buildAlphabet() {
    final letters = <String>{};
    for (var medicine in _filteredMedicines) {
      final firstLetter = medicine.name[0].toUpperCase();
      if (_isLetter(firstLetter)) {
        letters.add(firstLetter);
      }
    }
    _alphabet = letters.toList()..sort();
    _calculateSectionPositions();
  }

  bool _isLetter(String char) {
    return RegExp(r'[А-ЯA-Z]').hasMatch(char);
  }

  void _calculateSectionPositions() {
    final positions = <String, int>{};
    String? currentLetter;
    int position = 0;

    for (int i = 0; i < _filteredMedicines.length; i++) {
      final letter = _filteredMedicines[i].name[0].toUpperCase();

      if (letter != currentLetter && _alphabet.contains(letter)) {
        positions[letter] = position;
        currentLetter = letter;
      }

      final hasHeader = i == 0 || _filteredMedicines[i - 1].name[0].toUpperCase() != letter;
      position += hasHeader ? (_itemHeight + _headerHeight).toInt() : _itemHeight.toInt();
    }

    _sectionPositions = positions;
  }

  void _filterMedicines() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        _filteredMedicines = List.from(popularMedicines);
      } else {
        _filteredMedicines = popularMedicines
            .where((med) => med.name.toLowerCase().contains(query))
            .toList();
      }
      _buildAlphabet();
    });
  }

  void _scrollToLetter(String letter) {
    final index = _sectionPositions[letter];
    if (index != null && _scrollController.hasClients) {
      _scrollController.animateTo(
        index.toDouble(),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _updateActiveLetter() {
    if (!_scrollController.hasClients || _filteredMedicines.isEmpty) return;

    final offset = _scrollController.offset;
    double accumulatedHeight = 0;
    String? newActiveLetter;

    for (int i = 0; i < _filteredMedicines.length; i++) {
      final medicine = _filteredMedicines[i];
      final letter = medicine.name[0].toUpperCase();
      final hasHeader = i == 0 || _filteredMedicines[i - 1].name[0].toUpperCase() != letter;
      final itemTotalHeight = hasHeader ? _itemHeight + _headerHeight : _itemHeight;

      if (offset >= accumulatedHeight && offset < accumulatedHeight + itemTotalHeight) {
        newActiveLetter = letter;
        break;
      }
      accumulatedHeight += itemTotalHeight;
    }

    if (newActiveLetter != _activeLetter && mounted) {
      setState(() {
        _activeLetter = newActiveLetter;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите лекарство из каталога'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                // Поле поиска
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: isDark ? AppColors.darkTextPrimary : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Поиск по названию...',
                      hintStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500),
                      prefixIcon: Icon(Icons.search, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
                        onPressed: () {
                          _searchController.clear();
                          _filterMedicines();
                        },
                      )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? AppColors.darkInputBorder : Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: isDark ? AppColors.darkInputFill : Colors.white,
                    ),
                  ),
                ),

                // Список лекарств
                Expanded(
                  child: _filteredMedicines.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                    controller: _scrollController,
                    itemCount: _filteredMedicines.length,
                    itemBuilder: (context, index) {
                      final medicine = _filteredMedicines[index];
                      final String currentLetter = medicine.name[0].toUpperCase();
                      final String? previousLetter = index > 0
                          ? _filteredMedicines[index - 1].name[0].toUpperCase()
                          : null;
                      final bool showHeader = _searchController.text.isEmpty &&
                          (index == 0 || currentLetter != previousLetter);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Заголовок секции (буква)
                          if (showHeader)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              color: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                              child: Text(
                                currentLetter,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkPrimary : Colors.blue,
                                ),
                              ),
                            ),
                          // Карточка лекарства
                          _buildMedicineCard(medicine),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ========== АЛФАВИТНАЯ ПАНЕЛЬ ==========
          if (_searchController.text.isEmpty && _alphabet.isNotEmpty)
            Container(
              width: 40,
              alignment: Alignment.center,
              child: ListView.builder(
                itemCount: _alphabet.length,
                itemBuilder: (context, index) {
                  final letter = _alphabet[index];
                  final isActive = _activeLetter == letter;

                  return GestureDetector(
                    onTap: () => _scrollToLetter(letter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Center(
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            color: isActive
                                ? (isDark ? AppColors.darkPrimary : Colors.blue.shade700)
                                : (isDark ? AppColors.darkTextSecondary : Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Карточка лекарства
  Widget _buildMedicineCard(PopularMedicine medicine) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formColor = medicine.form.color;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 2,
      color: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => Navigator.pop(context, medicine),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Иконка формы лекарства (SVG)
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: formColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SvgPicture.asset(
                    medicine.form.svgPath,
                    width: 34,
                    height: 34,
                    colorFilter: ColorFilter.mode(
                      formColor,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: formColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            medicine.form.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: formColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${medicine.dosage} ${medicine.dosageUnit}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right,
                  color: isDark ? AppColors.darkPrimary : Colors.blue.shade700,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Состояние пустого списка
  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication,
            size: 64,
            color: isDark ? AppColors.darkTextSecondary : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Лекарства не найдены',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? AppColors.darkTextSecondary : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Попробуйте изменить поисковый запрос',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}