import '../models/medicine_model.dart';
import '../features/medicines/widgets/medicine_form.dart';

class BarcodeMedicineFullData {
  final String name;
  final MedicineForm form;
  final double dosage;
  final String dosageUnit;
  final String? description;
  final String? indications;
  final String? barcode;

  BarcodeMedicineFullData({
    required this.name,
    required this.form,
    required this.dosage,
    required this.dosageUnit,
    this.description,
    this.indications,
    this.barcode,
  });
}

final Map<String, BarcodeMedicineFullData> barcodeDatabase = {
  '8901148246591': BarcodeMedicineFullData(
    name: 'Кетарол',
    form: MedicineForm.tablet,
    dosage: 10,
    dosageUnit: 'мг',
    description: 'Нестероидный противовоспалительный препарат. Обладает обезболивающим, жаропонижающим и противовоспалительным действием.',
    indications: 'Головная боль, зубная боль, мигрень, лихорадка, мышечные боли.',
    barcode: '8901148246591',
  ),
};