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

  static MedicineStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'taken':
        return MedicineStatus.taken;
      case 'missed':
        return MedicineStatus.missed;
      case 'upcoming':
      default:
        return MedicineStatus.upcoming;
    }
  }
}

/// A single medicine entry in today's schedule.
class MedicineItem {
  final String id;
  final String patientId;
  final String name;
  final String dosage;
  final String instruction;
  final String time;
  final MedicineStatus status;
  final String? doseLogId;
  final bool isActive;
  final DateTime? startDate;

  const MedicineItem({
    this.id = '',
    this.patientId = '',
    required this.name,
    required this.dosage,
    required this.instruction,
    required this.time,
    required this.status,
    this.doseLogId,
    this.isActive = true,
    this.startDate,
  });

  MedicineItem copyWith({
    String? id,
    String? patientId,
    String? name,
    String? dosage,
    String? instruction,
    String? time,
    MedicineStatus? status,
    String? doseLogId,
    bool? isActive,
    DateTime? startDate,
  }) {
    return MedicineItem(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      instruction: instruction ?? this.instruction,
      time: time ?? this.time,
      status: status ?? this.status,
      doseLogId: doseLogId ?? this.doseLogId,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
    );
  }
}

/// Initial dummy medicines for today's schedule.
class DummyMedicines {
  DummyMedicines._();

  static List<MedicineItem> get todayList => [
        const MedicineItem(
          id: 'dummy-1',
          name: 'Panadol',
          dosage: '1 Tablet',
          instruction: 'After Dinner',
          time: '8:00 PM',
          status: MedicineStatus.taken,
        ),
        const MedicineItem(
          id: 'dummy-2',
          name: 'Vitamin C',
          dosage: '1 Capsule',
          instruction: 'After Breakfast',
          time: '9:00 AM',
          status: MedicineStatus.taken,
        ),
        const MedicineItem(
          id: 'dummy-3',
          name: 'Amoxicillin',
          dosage: '1 Capsule',
          instruction: 'After Lunch',
          time: '2:00 PM',
          status: MedicineStatus.upcoming,
        ),
      ];
}
