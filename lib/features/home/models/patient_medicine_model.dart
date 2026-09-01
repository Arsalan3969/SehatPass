import '../../medicines/models/medicine_item.dart';

/// Model representing a patient medication from `public.patient_medicines`.
class PatientMedicineModel {
  final String id;
  final String patientId;
  final String name;
  final String dosage;
  final String instruction;
  final String scheduledTime;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? createdAt;

  const PatientMedicineModel({
    required this.id,
    required this.patientId,
    required this.name,
    required this.dosage,
    required this.instruction,
    required this.scheduledTime,
    this.isActive = true,
    this.startDate,
    this.createdAt,
  });

  PatientMedicineModel copyWith({
    String? id,
    String? patientId,
    String? name,
    String? dosage,
    String? instruction,
    String? scheduledTime,
    bool? isActive,
    DateTime? startDate,
    DateTime? createdAt,
  }) {
    return PatientMedicineModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      instruction: instruction ?? this.instruction,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory PatientMedicineModel.fromMap(Map<String, dynamic> map) {
    return PatientMedicineModel(
      id: map['id']?.toString() ?? '',
      patientId: map['patient_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      dosage: map['dosage']?.toString() ?? '',
      instruction: map['instruction']?.toString() ?? '',
      scheduledTime: map['scheduled_time']?.toString() ?? '',
      isActive: map['is_active'] == true || map['is_active'] == null,
      startDate: map['start_date'] != null
          ? DateTime.tryParse(map['start_date'].toString())
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'name': name,
      'dosage': dosage,
      'instruction': instruction,
      'scheduled_time': scheduledTime,
      'is_active': isActive,
      if (startDate != null)
        'start_date':
            '${startDate!.year.toString().padLeft(4, '0')}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}',
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Converts to [MedicineItem] for UI interoperability.
  MedicineItem toMedicineItem({
    MedicineStatus status = MedicineStatus.upcoming,
    String? doseLogId,
  }) {
    return MedicineItem(
      id: id,
      patientId: patientId,
      name: name,
      dosage: dosage,
      instruction: instruction,
      time: scheduledTime,
      status: status,
      doseLogId: doseLogId,
      isActive: isActive,
      startDate: startDate,
    );
  }
}
