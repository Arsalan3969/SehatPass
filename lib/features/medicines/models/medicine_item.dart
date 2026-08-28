/// Status of a medicine dose for the day.
enum MedicineStatus { taken, upcoming, missed }

extension MedicineStatusProps on MedicineStatus {
  String get label {
    switch (this) {
      case MedicineStatus.taken:
        return 'Taken';
      case MedicineStatus.upcoming:
        return 'Upcoming';
      case MedicineStatus.missed:
        return 'Missed';
    }
  }
}

/// A single medicine entry in today's schedule.
class MedicineItem {
  final String name;
  final String dosage;
  final String instruction;
  final String time;
  final MedicineStatus status;

  const MedicineItem({
    required this.name,
    required this.dosage,
    required this.instruction,
    required this.time,
    required this.status,
  });

  MedicineItem copyWith({MedicineStatus? status}) {
    return MedicineItem(
      name: name,
      dosage: dosage,
      instruction: instruction,
      time: time,
      status: status ?? this.status,
    );
  }
}

/// Initial dummy medicines for today's schedule.
class DummyMedicines {
  DummyMedicines._();

  static List<MedicineItem> get todayList => [
        const MedicineItem(
          name: 'Panadol',
          dosage: '1 Tablet',
          instruction: 'After Dinner',
          time: '8:00 PM',
          status: MedicineStatus.taken,
        ),
        const MedicineItem(
          name: 'Vitamin C',
          dosage: '1 Capsule',
          instruction: 'After Breakfast',
          time: '9:00 AM',
          status: MedicineStatus.taken,
        ),
        const MedicineItem(
          name: 'Amoxicillin',
          dosage: '1 Capsule',
          instruction: 'After Lunch',
          time: '2:00 PM',
          status: MedicineStatus.upcoming,
        ),
      ];
}
