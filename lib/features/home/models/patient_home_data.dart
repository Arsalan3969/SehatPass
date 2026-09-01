import 'patient_medicine_model.dart';
import 'medical_report_model.dart';

/// Aggregated data model for the Patient Home Dashboard.
class PatientHomeData {
  final String patientName;
  final String email;
  final List<PatientMedicineModel> medicines;
  final List<MedicalReportModel> reports;

  const PatientHomeData({
    required this.patientName,
    required this.email,
    this.medicines = const [],
    this.reports = const [],
  });

  /// The next scheduled medicine, if any.
  PatientMedicineModel? get nextMedicine =>
      medicines.isNotEmpty ? medicines.first : null;

  /// The most recent medical report, if any.
  MedicalReportModel? get latestReport =>
      reports.isNotEmpty ? reports.first : null;

  PatientHomeData copyWith({
    String? patientName,
    String? email,
    List<PatientMedicineModel>? medicines,
    List<MedicalReportModel>? reports,
  }) {
    return PatientHomeData(
      patientName: patientName ?? this.patientName,
      email: email ?? this.email,
      medicines: medicines ?? this.medicines,
      reports: reports ?? this.reports,
    );
  }
}
