import 'package:flutter/material.dart';
import 'package:family_medicine/models/medicine_model.dart';
import 'package:family_medicine/models/course_model.dart';

class ConfigureSelectedMedicinesScreen extends StatefulWidget {
  final List<MedicineModel> medicines;

  const ConfigureSelectedMedicinesScreen({
    super.key,
    required this.medicines,
  });

  @override
  State<ConfigureSelectedMedicinesScreen> createState() =>
      _ConfigureSelectedMedicinesScreenState();
}

class _ConfigureSelectedMedicinesScreenState
    extends State<ConfigureSelectedMedicinesScreen> {

  late Map<String, _MedicineConfig> _configs;

  // массовые настройки
  String _globalFrequency = 'once_daily';
  List<TimeOfDay> _globalTimes = [const TimeOfDay(hour: 9, minute: 0)];

  @override
  void initState() {
    super.initState();

    _configs = {
      for (var med in widget.medicines)
        med.id: _MedicineConfig(
          medicine: med,
          dosage: '${med.dosage} ${med.dosageUnit}',
          quantity: 1,
          frequency: 'once_daily',
          times: [const TimeOfDay(hour: 9, minute: 0)],
        )
    };
  }

  void _applyGlobalSettings() {
    setState(() {
      for (var config in _configs.values) {
        config.frequency = _globalFrequency;
        config.times = List.from(_globalTimes);
      }
    });
  }

  // ================= СОХРАНЕНИЕ =================

  void _finish() {
    final result = _configs.values.map((c) {
      return MedicationSchedule(
        medicationId: c.medicine.id,
        medicationName: c.medicine.name,
        dosage: c.dosage,
        quantity: c.quantity,
        frequency: c.frequency,
        times: c.times,
        notes: 'Из аптечки',
      );
    }).toList();

    Navigator.pop(context, result);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройка приёма'),
        actions: [
          TextButton(
            onPressed: _finish,
            child: const Text('Готово'),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          const Text(
            'Общие настройки',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _globalFrequency,
            decoration: const InputDecoration(
              labelText: 'Частота',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'once_daily', child: Text('1 раз в день')),
              DropdownMenuItem(value: 'twice_daily', child: Text('2 раза в день')),
              DropdownMenuItem(value: 'custom', child: Text('Своя')),
            ],
            onChanged: (value) {
              setState(() {
                _globalFrequency = value!;
                if (value == 'once_daily') {
                  _globalTimes = [const TimeOfDay(hour: 9, minute: 0)];
                } else if (value == 'twice_daily') {
                  _globalTimes = const [
                    TimeOfDay(hour: 9, minute: 0),
                    TimeOfDay(hour: 21, minute: 0),
                  ];
                }
              });
            },
          ),

          const SizedBox(height: 12),

          ..._globalTimes.map((time) => ListTile(
            title: Text(time.format(context)),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                setState(() => _globalTimes.remove(time));
              },
            ),
          )),

          TextButton.icon(
            onPressed: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (t != null) {
                setState(() => _globalTimes.add(t));
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Добавить время'),
          ),

          const SizedBox(height: 8),

          ElevatedButton(
            onPressed: _applyGlobalSettings,
            child: const Text('Применить ко всем'),
          ),

          const Divider(height: 32),

          // ===== ИНДИВИДУАЛЬНАЯ НАСТРОЙКА =====

          const Text(
            'Каждое лекарство',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          ..._configs.values.map(_buildMedicineCard),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(_MedicineConfig config) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(config.medicine.name),
        subtitle: Text('${config.dosage} • ${config.quantity} шт'),
        children: [

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [

                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Дозировка',
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: config.dosage),
                  onChanged: (v) => config.dosage = v,
                ),

                const SizedBox(height: 12),

                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Количество',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(
                    text: config.quantity.toString(),
                  ),
                  onChanged: (v) =>
                  config.quantity = int.tryParse(v) ?? 1,
                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: config.frequency,
                  decoration: const InputDecoration(
                    labelText: 'Частота',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'once_daily', child: Text('1 раз')),
                    DropdownMenuItem(value: 'twice_daily', child: Text('2 раза')),
                    DropdownMenuItem(value: 'custom', child: Text('Своя')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      config.frequency = v!;
                    });
                  },
                ),

                const SizedBox(height: 8),

                ...config.times.map((time) => ListTile(
                  title: Text(time.format(context)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() => config.times.remove(time));
                    },
                  ),
                )),

                TextButton.icon(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (t != null) {
                      setState(() => config.times.add(t));
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить время'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _MedicineConfig {
  final MedicineModel medicine;

  String dosage;
  int quantity;
  String frequency;
  List<TimeOfDay> times;

  _MedicineConfig({
    required this.medicine,
    required this.dosage,
    required this.quantity,
    required this.frequency,
    required this.times,
  });
}