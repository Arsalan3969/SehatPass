/// Model representing an individual prescribed medication item within a doctor's consultation note.
class PrescriptionItemModel {
  final String medicineName;
  final String dosage;
  final String frequency;
  final String duration;
  final String instruction;
  final String notes;

  const PrescriptionItemModel({
    required this.medicineName,
    required this.dosage,
    this.frequency = '',
    this.duration = '',
    this.instruction = '',
    this.notes = '',
  });

  PrescriptionItemModel copyWith({
    String? medicineName,
    String? dosage,
    String? frequency,
    String? duration,
    String? instruction,
    String? notes,
  }) {
    return PrescriptionItemModel(
      medicineName: medicineName ?? this.medicineName,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      duration: duration ?? this.duration,
      instruction: instruction ?? this.instruction,
      notes: notes ?? this.notes,
    );
  }

  factory PrescriptionItemModel.fromMap(Map<String, dynamic> map) {
    return PrescriptionItemModel(
      medicineName: map['medicine_name']?.toString() ??
          map['medicineName']?.toString() ??
          map['name']?.toString() ??
          '',
      dosage: map['dosage']?.toString() ?? '',
      frequency: map['frequency']?.toString() ?? '',
      duration: map['duration']?.toString() ?? '',
      instruction: map['instruction']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medicine_name': medicineName.trim(),
      'dosage': dosage.trim(),
      'frequency': frequency.trim(),
      'duration': duration.trim(),
      'instruction': instruction.trim(),
      'notes': notes.trim(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrescriptionItemModel &&
          runtimeType == other.runtimeType &&
          medicineName == other.medicineName &&
          dosage == other.dosage &&
          frequency == other.frequency &&
          duration == other.duration &&
          instruction == other.instruction &&
          notes == other.notes;

  @override
  int get hashCode => Object.hash(
        medicineName,
        dosage,
        frequency,
        duration,
        instruction,
        notes,
      );

  @override
  String toString() {
    return 'PrescriptionItemModel(medicineName: $medicineName, dosage: $dosage, frequency: $frequency, duration: $duration)';
  }
}
