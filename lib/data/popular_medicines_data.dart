// data/popular_medicines_data.dart
import 'package:family_medicine/models/medicine_model.dart';

class PopularMedicine {
  final String name;
  final MedicineForm form;
  final double dosage;
  final String dosageUnit;
  final String? description;
  final String? indications;

  const PopularMedicine({
    required this.name,
    required this.form,
    required this.dosage,
    required this.dosageUnit,
    this.description,
    this.indications,
  });
}

final List<PopularMedicine> popularMedicines = [
  // ========== ОБЕЗБОЛИВАЮЩИЕ ==========
  PopularMedicine(
    name: 'Анальгин',
    form: MedicineForm.tablet,
    dosage: 500,
    dosageUnit: 'мг',
    description: 'Ненаркотический анальгетик, оказывает обезболивающее, жаропонижающее и противовоспалительное действие.',
    indications: 'Головная боль, зубная боль, лихорадка.',
  ),
  PopularMedicine(
    name: 'Ибупрофен',
    form: MedicineForm.tablet,
    dosage: 400,
    dosageUnit: 'мг',
    description: 'Нестероидный противовоспалительный препарат.',
    indications: 'Боль в мышцах, суставах, головная боль, лихорадка.',
  ),
  PopularMedicine(
    name: 'Кеторол',
    form: MedicineForm.tablet,
    dosage: 10,
    dosageUnit: 'мг',
    description: 'Сильный обезболивающий препарат.',
    indications: 'Сильная боль, послеоперационная боль, зубная боль.',
  ),
  PopularMedicine(
    name: 'Нурофен',
    form: MedicineForm.tablet,
    dosage: 200,
    dosageUnit: 'мг',
    description: 'Нестероидный противовоспалительный препарат.',
    indications: 'Головная боль, зубная боль, лихорадка, боль в спине.',
  ),
  PopularMedicine(
    name: 'Парацетамол',
    form: MedicineForm.tablet,
    dosage: 500,
    dosageUnit: 'мг',
    description: 'Анальгетик и антипиретик.',
    indications: 'Лихорадка, головная боль, зубная боль.',
  ),

  // ========== ПРОСТУДА ==========
  PopularMedicine(
    name: 'Арбидол',
    form: MedicineForm.capsule,
    dosage: 100,
    dosageUnit: 'мг',
    description: 'Противовирусный препарат.',
    indications: 'Профилактика и лечение гриппа и ОРВИ.',
  ),
  PopularMedicine(
    name: 'Аскорил',
    form: MedicineForm.syrup,
    dosage: 100,
    dosageUnit: 'мг/5мл',
    description: 'Муколитический и бронхолитический препарат.',
    indications: 'Кашель с трудноотделяемой мокротой.',
  ),
  PopularMedicine(
    name: 'Гриппферон',
    form: MedicineForm.drops,
    dosage: 10000,
    dosageUnit: 'МЕ/мл',
    description: 'Интерферон для профилактики и лечения гриппа.',
    indications: 'Профилактика и лечение гриппа и ОРВИ.',
  ),
  PopularMedicine(
    name: 'Терафлю',
    form: MedicineForm.powder,
    dosage: 650,
    dosageUnit: 'мг',
    description: 'Комбинированный препарат для лечения простуды.',
    indications: 'Лихорадка, головная боль, насморк.',
  ),

  // ========== АНТИБИОТИКИ ==========
  PopularMedicine(
    name: 'Азитромицин',
    form: MedicineForm.capsule,
    dosage: 500,
    dosageUnit: 'мг',
    description: 'Антибиотик широкого спектра действия.',
    indications: 'Инфекции дыхательных путей, кожи, мочевыводящих путей.',
  ),
  PopularMedicine(
    name: 'Амоксиклав',
    form: MedicineForm.tablet,
    dosage: 875,
    dosageUnit: 'мг',
    description: 'Комбинированный антибиотик.',
    indications: 'Бактериальные инфекции дыхательных путей, ЛОР-органов.',
  ),
  PopularMedicine(
    name: 'Сумамед',
    form: MedicineForm.capsule,
    dosage: 500,
    dosageUnit: 'мг',
    description: 'Макролидный антибиотик.',
    indications: 'Инфекции дыхательных путей, кожи, мягких тканей.',
  ),

  // ========== АНТИГИСТАМИННЫЕ ==========
  PopularMedicine(
    name: 'Зиртек',
    form: MedicineForm.drops,
    dosage: 10,
    dosageUnit: 'мг/мл',
    description: 'Противогистаминный препарат.',
    indications: 'Аллергический ринит, крапивница, зуд.',
  ),
  PopularMedicine(
    name: 'Лоратадин',
    form: MedicineForm.tablet,
    dosage: 10,
    dosageUnit: 'мг',
    description: 'Противогистаминный препарат длительного действия.',
    indications: 'Аллергические заболевания, зуд, отёчность.',
  ),
  PopularMedicine(
    name: 'Супрастин',
    form: MedicineForm.tablet,
    dosage: 25,
    dosageUnit: 'мг',
    description: 'Противогистаминный препарат.',
    indications: 'Аллергические заболевания, кожный зуд.',
  ),

  // ========== ВИТАМИНЫ ==========
  PopularMedicine(
    name: 'Алфавит',
    form: MedicineForm.tablet,
    dosage: 1,
    dosageUnit: 'шт',
    description: 'Витаминно-минеральный комплекс.',
    indications: 'Профилактика гиповитаминоза.',
  ),
  PopularMedicine(
    name: 'Компливит',
    form: MedicineForm.tablet,
    dosage: 1,
    dosageUnit: 'шт',
    description: 'Поливитаминный комплекс с минералами.',
    indications: 'Профилактика авитаминоза, повышение иммунитета.',
  ),

  // ========== ГЛАЗНЫЕ КАПЛИ ==========
  PopularMedicine(
    name: 'Визоптик',
    form: MedicineForm.drops,
    dosage: 0.1,
    dosageUnit: '%',
    description: 'Увлажняющие глазные капли.',
    indications: 'Синдром сухого глаза, усталость глаз.',
  ),

  // ========== НАЗАЛЬНЫЕ СРЕДСТВА ==========
  PopularMedicine(
    name: 'Аквамарис',
    form: MedicineForm.spray,
    dosage: 100,
    dosageUnit: '%',
    description: 'Спрей для промывания носа на основе морской воды.',
    indications: 'Насморк, сухость слизистой носа.',
  ),
  PopularMedicine(
    name: 'Називин',
    form: MedicineForm.drops,
    dosage: 0.05,
    dosageUnit: '%',
    description: 'Сосудосуживающие капли в нос.',
    indications: 'Насморк, заложенность носа.',
  ),

  // ========== ДЛЯ ЖЕЛУДКА ==========
  PopularMedicine(
    name: 'Алмагель',
    form: MedicineForm.syrup,
    dosage: 5,
    dosageUnit: 'мл',
    description: 'Антацидный препарат.',
    indications: 'Изжога, гастрит, язвенная болезнь.',
  ),
  PopularMedicine(
    name: 'Мезим',
    form: MedicineForm.tablet,
    dosage: 10000,
    dosageUnit: 'ЕД',
    description: 'Ферментный препарат.',
    indications: 'Нарушение пищеварения, вздутие живота.',
  ),
  PopularMedicine(
    name: 'Но-шпа',
    form: MedicineForm.tablet,
    dosage: 40,
    dosageUnit: 'мг',
    description: 'Спазмолитик.',
    indications: 'Спазмы желудочно-кишечного тракта, головная боль.',
  ),

  // ========== МАЗИ ==========
  PopularMedicine(
    name: 'Диклофенак',
    form: MedicineForm.ointment,
    dosage: 1,
    dosageUnit: '%',
    description: 'Нестероидный противовоспалительный препарат для наружного применения.',
    indications: 'Боль в суставах, мышцах, ушибы.',
  ),
  PopularMedicine(
    name: 'Троксевазин',
    form: MedicineForm.ointment,
    dosage: 2,
    dosageUnit: '%',
    description: 'Венотонизирующий препарат.',
    indications: 'Варикозное расширение вен, отёки, гематомы.',
  ),
];