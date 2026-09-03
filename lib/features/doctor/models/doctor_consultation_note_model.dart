import 'prescription_item_model.dart';

/// Model representing a doctor's clinical consultation record from `public.doctor_consultation_notes`.
class DoctorConsultationNoteModel {
  final String id;
  final String appointmentId;
  final String doctorId;
  final String patientId;
  final String? diagnosis;
  final String? notes;
  final List<PrescriptionItemModel> prescriptions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Optional UI metadata joins
  final String? doctorName;
  final String? doctorSpecialization;
  final String? appointmentReferenceNo;
  final String? appointmentDate;

  const DoctorConsultationNoteModel({
    required this.id,
    required this.appointmentId,
    required this.doctorId,
    required this.patientId,
    this.diagnosis,
    this.notes,
    this.prescriptions = const [],
    this.createdAt,
    this.updatedAt,
    this.doctorName,
    this.doctorSpecialization,
    this.appointmentReferenceNo,
    this.appointmentDate,
  });

  DoctorConsultationNoteModel copyWith({
    String? id,
    String? appointmentId,
    String? doctorId,
    String? patientId,
    String? diagnosis,
    String? notes,
    List<PrescriptionItemModel>? prescriptions,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? doctorName,
    String? doctorSpecialization,
    String? appointmentReferenceNo,
    String? appointmentDate,
  }) {
    return DoctorConsultationNoteModel(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      doctorId: doctorId ?? this.doctorId,
      patientId: patientId ?? this.patientId,
      diagnosis: diagnosis ?? this.diagnosis,
      notes: notes ?? this.notes,
      prescriptions: prescriptions ?? this.prescriptions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      doctorName: doctorName ?? this.doctorName,
      doctorSpecialization: doctorSpecialization ?? this.doctorSpecialization,
      appointmentReferenceNo:
          appointmentReferenceNo ?? this.appointmentReferenceNo,
      appointmentDate: appointmentDate ?? this.appointmentDate,
    );
  }

  factory DoctorConsultationNoteModel.fromMap(Map<String, dynamic> map) {
    final rawPrescriptions = map['prescriptions'];
    List<PrescriptionItemModel> parsedPrescriptions = [];

    if (rawPrescriptions is List) {
      parsedPrescriptions = rawPrescriptions
          .whereType<Map>()
          .map((item) => PrescriptionItemModel.fromMap(
              Map<String, dynamic>.from(item)))
          .toList();
    }

    // Resolve optional joins
    final profileMap = map['profiles'] is Map
        ? Map<String, dynamic>.from(map['profiles'] as Map)
        : null;
    final doctorProfileMap = map['doctor_profiles'] is Map
        ? Map<String, dynamic>.from(map['doctor_profiles'] as Map)
        : null;
    final aptMap = map['appointments'] is Map
        ? Map<String, dynamic>.from(map['appointments'] as Map)
        : null;

    return DoctorConsultationNoteModel(
      id: map['id']?.toString() ?? '',
      appointmentId: map['appointment_id']?.toString() ?? '',
      doctorId: map['doctor_id']?.toString() ?? '',
      patientId: map['patient_id']?.toString() ?? '',
      diagnosis: map['diagnosis']?.toString(),
      notes: map['notes']?.toString(),
      prescriptions: parsedPrescriptions,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      doctorName: profileMap?['full_name']?.toString() ??
          map['doctor_name']?.toString(),
      doctorSpecialization: doctorProfileMap?['specialization']?.toString() ??
          map['doctor_specialization']?.toString(),
      appointmentReferenceNo: aptMap?['reference_no']?.toString() ??
          map['reference_no']?.toString(),
      appointmentDate: aptMap?['appointment_date']?.toString() ??
          map['appointment_date']?.toString(),
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    return {
      if (includeId && id.isNotEmpty) 'id': id,
      'appointment_id': appointmentId,
      'doctor_id': doctorId,
      'patient_id': patientId,
      if (diagnosis != null) 'diagnosis': diagnosis!.trim(),
      if (notes != null) 'notes': notes!.trim(),
      'prescriptions': prescriptions.map((p) => p.toMap()).toList(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  String get formattedDate {
    final d = createdAt;
    if (d == null) return 'Recent';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
