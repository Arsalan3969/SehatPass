import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_user_avatar.dart';
import '../../home/models/patient_medicine_model.dart';
import '../../home/models/medical_report_model.dart';
import '../data/doctor_repository.dart';
import '../models/doctor_patient_model.dart';
import '../models/doctor_consultation_note_model.dart';

class DoctorPatientDetailScreen extends StatefulWidget {
  final DoctorPatientModel? patient;
  final String? patientId;
  final DoctorRepository? repository;
  final List<PatientMedicineModel>? initialMedicines;
  final List<MedicalReportModel>? initialReports;
  final List<DoctorConsultationNoteModel>? initialConsultations;

  const DoctorPatientDetailScreen({
    super.key,
    this.patient,
    this.patientId,
    this.repository,
    this.initialMedicines,
    this.initialReports,
    this.initialConsultations,
  });

  @override
  State<DoctorPatientDetailScreen> createState() =>
      _DoctorPatientDetailScreenState();
}

class _DoctorPatientDetailScreenState extends State<DoctorPatientDetailScreen> {
  late final DoctorRepository _repository;
  DoctorPatientModel? _patient;
  bool _isLoadingPatient = false;
  String? _patientError;

  List<PatientMedicineModel> _medicines = [];
  bool _isLoadingMedicines = false;
  String? _medicinesError;

  List<MedicalReportModel> _reports = [];
  bool _isLoadingReports = false;
  String? _reportsError;

  List<DoctorConsultationNoteModel> _consultations = [];
  bool _isLoadingConsultations = false;
  String? _consultationsError;

  String? _openingReportId;

  String get _targetPatientId =>
      widget.patientId ?? widget.patient?.id ?? _patient?.id ?? '';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DoctorRepository.instance;
    _patient = widget.patient;

    if (widget.initialMedicines != null) {
      _medicines = List.from(widget.initialMedicines!);
    }
    if (widget.initialReports != null) {
      _reports = List.from(widget.initialReports!);
    }
    if (widget.initialConsultations != null) {
      _consultations = List.from(widget.initialConsultations!);
    }

    final targetId = _targetPatientId;
    if (targetId.isNotEmpty) {
      _loadPatient(targetId);
      if (widget.initialMedicines == null) {
        _loadMedicines(targetId);
      }
      if (widget.initialReports == null) {
        _loadReports(targetId);
      }
      if (widget.initialConsultations == null) {
        _loadConsultations(targetId);
      }
    }
  }

  Future<void> _loadConsultations(String patientId) async {
    setState(() {
      _isLoadingConsultations = true;
      _consultationsError = null;
    });

    try {
      final list = await _repository.getPatientConsultationHistory(patientId);
      if (mounted) {
        setState(() {
          _consultations = list;
          _isLoadingConsultations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _consultationsError = e.toString();
          _isLoadingConsultations = false;
        });
      }
    }
  }

  Future<void> _loadPatient(String patientId) async {
    if (_patient == null) {
      setState(() {
        _isLoadingPatient = true;
        _patientError = null;
      });
    }

    try {
      final fetched = await _repository.getDoctorPatientDetail(patientId);
      if (mounted) {
        setState(() {
          if (fetched != null) {
            _patient = fetched;
          }
          _isLoadingPatient = false;
          if (_patient == null && fetched == null) {
            _patientError =
                'Patient record not found or unauthorized. You can only view patients with confirmed or scheduled appointments.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_patient == null) {
            _patientError = e.toString();
          }
          _isLoadingPatient = false;
        });
      }
    }
  }

  Future<void> _loadMedicines(String patientId) async {
    setState(() {
      _isLoadingMedicines = true;
      _medicinesError = null;
    });

    try {
      final list = await _repository.getDoctorPatientMedicines(patientId);
      if (mounted) {
        setState(() {
          _medicines = list;
          _isLoadingMedicines = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _medicinesError = e.toString();
          _isLoadingMedicines = false;
        });
      }
    }
  }

  Future<void> _loadReports(String patientId) async {
    setState(() {
      _isLoadingReports = true;
      _reportsError = null;
    });

    try {
      final list = await _repository.getDoctorPatientReports(patientId);
      if (mounted) {
        setState(() {
          _reports = list;
          _isLoadingReports = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reportsError = e.toString();
          _isLoadingReports = false;
        });
      }
    }
  }

  Future<void> _handleViewReportFile(MedicalReportModel report) async {
    final storagePath = report.storageFilePath;
    if (storagePath == null || storagePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No file attached to this report.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _openingReportId = report.id);

    try {
      final signedUrl = await _repository.getDoctorReportSignedUrl(storagePath);
      if (!mounted) return;
      setState(() => _openingReportId = null);

      if (signedUrl != null && signedUrl.isNotEmpty) {
        final uri = Uri.parse(signedUrl);
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (!launched && mounted) {
          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to generate secure file link. The file may no longer be available.',
              ),
              backgroundColor: AppColors.emergency,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _openingReportId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing report file: $e'),
            backgroundColor: AppColors.emergency,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Patient Details',
          style: AppTextStyles.headingMedium,
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingPatient) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_patientError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.emergencySurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 40,
                  color: AppColors.emergency,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _patientError!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to Patients'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final patient = _patient;
    if (patient == null) {
      return const Center(
        child: Text('No patient information available.'),
      );
    }

    final ageDisplay =
        patient.age > 0 ? '${patient.age} yrs' : 'Age not specified';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Patient Profile Header Card ─────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    AppUserAvatar(
                      imageUrlOrPath: patient.photoUrl,
                      name: patient.name,
                      size: 60,
                      isCircle: true,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient.name,
                            style: AppTextStyles.headingMedium.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$ageDisplay • ${patient.gender} • Blood Group: ${patient.bloodGroup}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            patient.phone,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                // Quick Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        label: 'Allergies',
                        value: patient.allergies,
                      ),
                    ),
                    Container(
                      height: 32,
                      width: 1,
                      color: AppColors.border,
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        label: 'Total Visits',
                        value: '${patient.totalVisits}',
                      ),
                    ),
                    Container(
                      height: 32,
                      width: 1,
                      color: AppColors.border,
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        label: 'Last Visit',
                        value: patient.lastVisit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Clinical Conditions & Medical Summary ───────────────────────
          Text(
            'Clinical Summary',
            style: AppTextStyles.headingSmall.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  icon: Icons.favorite_border_rounded,
                  label: 'Chronic Conditions',
                  value: patient.medicalConditions,
                ),
                const Divider(height: 20),
                _buildSummaryRow(
                  icon: Icons.warning_amber_rounded,
                  label: 'Recorded Allergies',
                  value: patient.allergies,
                ),
                const Divider(height: 20),
                _buildSummaryRow(
                  icon: Icons.medical_services_outlined,
                  label: 'Primary Concern',
                  value: patient.primaryCondition,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Consultation History Section (Phase 4C Live Data) ───────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Consultation & Encounter History',
                style: AppTextStyles.headingSmall.copyWith(fontSize: 16),
              ),
              if (_consultations.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_consultations.length}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _buildConsultationsSection(),

          const SizedBox(height: 24),

          // ── Active Medications Section (Phase 4B Live Data) ─────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Medications',
                style: AppTextStyles.headingSmall.copyWith(fontSize: 16),
              ),
              if (_medicines.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_medicines.length}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _buildMedicinesSection(),

          const SizedBox(height: 24),

          // ── Medical & Diagnostic Reports Section (Phase 4B Live Data) ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Medical & Diagnostic Reports',
                style: AppTextStyles.headingSmall.copyWith(fontSize: 16),
              ),
              if (_reports.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_reports.length}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _buildReportsSection(),

          const SizedBox(height: 28),

          // ── View Full Records Button ──────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showFullRecordsModal,
              icon: const Icon(Icons.folder_shared_outlined, size: 18),
              label: const Text('View Full Records'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildConsultationsSection() {
    if (_isLoadingConsultations) {
      return Container(
        height: 90,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_consultationsError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.emergencySurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.emergency, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _consultationsError!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.emergency),
              ),
            ),
            TextButton(
              onPressed: () => _loadConsultations(_targetPatientId),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_consultations.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.history_edu_outlined, color: AppColors.textTertiary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No consultation history yet.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _consultations.map((note) => _buildConsultationCard(note)).toList(),
    );
  }

  Widget _buildConsultationCard(DoctorConsultationNoteModel note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.medical_services_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.diagnosis ?? 'General Medical Review',
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${note.doctorName ?? 'Treating Doctor'} • ${note.formattedDate}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (note.prescriptions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${note.prescriptions.length} Rx',
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (note.notes != null && note.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              note.notes!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (note.prescriptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: note.prescriptions.take(3).map((p) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '${p.medicineName} (${p.dosage})',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicinesSection() {
    if (_isLoadingMedicines) {
      return Container(
        height: 90,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_medicinesError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.emergencySurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.emergency, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _medicinesError!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.emergency),
              ),
            ),
            TextButton(
              onPressed: () => _loadMedicines(_targetPatientId),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_medicines.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.medication_outlined, color: AppColors.textTertiary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No active medications recorded for this patient.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _medicines.map((med) => _buildMedicineCard(med)).toList(),
    );
  }

  Widget _buildMedicineCard(PatientMedicineModel med) {
    String? startStr;
    if (med.startDate != null) {
      final d = med.startDate!;
      startStr = '${d.day}/${d.month}/${d.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.medication_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        med.name,
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          color: Color(0xFF059669),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${med.dosage} • ${med.scheduledTime} (${med.instruction})',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (startStr != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Started: $startStr',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsSection() {
    if (_isLoadingReports) {
      return Container(
        height: 90,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_reportsError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.emergencySurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.emergency, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _reportsError!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.emergency),
              ),
            ),
            TextButton(
              onPressed: () => _loadReports(_targetPatientId),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_reports.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.description_outlined, color: AppColors.textTertiary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No medical reports uploaded by this patient.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _reports.map((rep) => _buildReportCard(rep)).toList(),
    );
  }

  Widget _buildReportCard(MedicalReportModel report) {
    final hasFile = report.storageFilePath != null && report.storageFilePath!.isNotEmpty;
    final isOpeningThis = _openingReportId == report.id;

    IconData catIcon;
    Color catBg;
    Color catFg;
    switch (report.category.toLowerCase()) {
      case 'bloodtest':
        catIcon = Icons.water_drop_outlined;
        catBg = const Color(0xFFFEE2E2);
        catFg = const Color(0xFFDC2626);
        break;
      case 'scan':
        catIcon = Icons.document_scanner_outlined;
        catBg = const Color(0xFFE0E7FF);
        catFg = const Color(0xFF4F46E5);
        break;
      default:
        catIcon = Icons.description_outlined;
        catBg = AppColors.primarySurface;
        catFg = AppColors.primary;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: catBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(catIcon, color: catFg, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.title,
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${report.labFacility} • ${report.formattedDate}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (report.formattedFileSize != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${report.categoryLabel} (${report.formattedFileSize})',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasFile)
            IconButton(
              icon: isOpeningThis
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Icon(Icons.open_in_new_rounded, color: AppColors.primary, size: 20),
              tooltip: 'View Report File',
              onPressed: isOpeningThis ? null : () => _handleViewReportFile(report),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  void _showFullRecordsModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DoctorFullRecordsModal(
        patientName: _patient?.name ?? 'Patient',
        consultations: _consultations,
        medicines: _medicines,
        reports: _reports,
        onViewReport: _handleViewReportFile,
        openingReportId: _openingReportId,
      ),
    );
  }
}

/// Dedicated bottom sheet modal showing the full medical records (Consultations, Medicines & Reports)
class _DoctorFullRecordsModal extends StatefulWidget {
  final String patientName;
  final List<DoctorConsultationNoteModel> consultations;
  final List<PatientMedicineModel> medicines;
  final List<MedicalReportModel> reports;
  final Function(MedicalReportModel) onViewReport;
  final String? openingReportId;

  const _DoctorFullRecordsModal({
    required this.patientName,
    this.consultations = const [],
    required this.medicines,
    required this.reports,
    required this.onViewReport,
    this.openingReportId,
  });

  @override
  State<_DoctorFullRecordsModal> createState() => _DoctorFullRecordsModalState();
}

class _DoctorFullRecordsModalState extends State<_DoctorFullRecordsModal>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.patientName} — Medical Records',
                        style: AppTextStyles.headingSmall,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Consultations, Prescribed Medications & Diagnostic Files',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: 'Consultations (${widget.consultations.length})'),
              Tab(text: 'Medications (${widget.medicines.length})'),
              Tab(text: 'Reports (${widget.reports.length})'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Consultations
                widget.consultations.isEmpty
                    ? const Center(child: Text('No consultation records found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: widget.consultations.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final note = widget.consultations[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySurface,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.medical_services_outlined,
                                          color: AppColors.primary, size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            note.diagnosis ?? 'General Consultation',
                                            style: AppTextStyles.labelLarge.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '${note.doctorName ?? 'Doctor'} • ${note.formattedDate}',
                                            style: AppTextStyles.caption.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (note.prescriptions.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${note.prescriptions.length} Rx',
                                          style: const TextStyle(
                                            color: Color(0xFF2563EB),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (note.notes != null && note.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    note.notes!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),

                // Tab 2: Medicines
                widget.medicines.isEmpty
                    ? const Center(child: Text('No active medications recorded.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: widget.medicines.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final med = widget.medicines[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySurface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.medication_rounded,
                                      color: AppColors.primary, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        med.name,
                                        style: AppTextStyles.labelLarge.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${med.dosage} • ${med.scheduledTime} (${med.instruction})',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // Tab 3: Reports
                widget.reports.isEmpty
                    ? const Center(child: Text('No medical reports recorded.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: widget.reports.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final rep = widget.reports[index];
                          final hasFile = rep.storageFilePath != null &&
                              rep.storageFilePath!.isNotEmpty;
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySurface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.description_outlined,
                                      color: AppColors.primary, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        rep.title,
                                        style: AppTextStyles.labelLarge.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${rep.labFacility} • ${rep.formattedDate}',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (hasFile)
                                  IconButton(
                                    icon: const Icon(Icons.open_in_new_rounded,
                                        color: AppColors.primary, size: 20),
                                    onPressed: () => widget.onViewReport(rep),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
