import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_user_avatar.dart';
import '../data/doctor_repository.dart';
import '../models/doctor_appointment_model.dart';
import '../models/doctor_patient_model.dart';
import '../models/doctor_consultation_note_model.dart';
import '../patients/doctor_patient_detail_screen.dart';
import 'widgets/write_consultation_note_sheet.dart';

class DoctorAppointmentDetailsScreen extends StatefulWidget {
  final DoctorAppointmentModel appointment;
  final DoctorRepository? repository;
  final DoctorConsultationNoteModel? initialNote;
  final dynamic Function(DoctorAppointmentModel appointment)? onAccept;
  final dynamic Function(DoctorAppointmentModel appointment)? onDecline;

  const DoctorAppointmentDetailsScreen({
    super.key,
    required this.appointment,
    this.repository,
    this.initialNote,
    this.onAccept,
    this.onDecline,
  });

  @override
  State<DoctorAppointmentDetailsScreen> createState() =>
      _DoctorAppointmentDetailsScreenState();
}

class _DoctorAppointmentDetailsScreenState
    extends State<DoctorAppointmentDetailsScreen> {
  late final DoctorRepository _repository;
  late DoctorAppointmentModel _appointment;
  DoctorConsultationNoteModel? _consultationNote;
  bool _isLoadingNote = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DoctorRepository.instance;
    _appointment = widget.appointment;
    _consultationNote = widget.initialNote;

    if (_consultationNote == null &&
        (_appointment.status == DoctorAppointmentStatus.confirmed ||
            _appointment.status == DoctorAppointmentStatus.completed)) {
      _loadConsultationNote();
    }
  }

  Future<void> _loadConsultationNote() async {
    setState(() => _isLoadingNote = true);
    try {
      final note =
          await _repository.getConsultationNoteForAppointment(_appointment.id);
      if (mounted) {
        setState(() {
          _consultationNote = note;
          _isLoadingNote = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingNote = false);
      }
    }
  }

  void _openConsultationNoteSheet() {
    showModalBottomSheet<DoctorConsultationNoteModel?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WriteConsultationNoteSheet(
        appointment: _appointment,
        existingNote: _consultationNote,
        repository: _repository,
        onSaveSuccess: (savedNote, isCompleted) {
          setState(() {
            _consultationNote = savedNote;
            if (isCompleted) {
              _appointment.status = DoctorAppointmentStatus.completed;
            }
          });
        },
      ),
    ).then((saved) {
      if (saved != null && mounted) {
        setState(() => _consultationNote = saved);
      }
    });
  }

  Future<void> _handleAccept() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      if (widget.onAccept != null) {
        await widget.onAccept!(_appointment);
      } else {
        await _repository.acceptAppointment(_appointment.id);
      }
      if (mounted) {
        setState(() {
          _appointment.status = DoctorAppointmentStatus.confirmed;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Appointment for ${_appointment.patientName} accepted & confirmed.',
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept appointment: $e'),
            backgroundColor: AppColors.emergency,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showDeclineConfirmation() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.emergencySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cancel_outlined,
                color: AppColors.emergency,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Decline Request?', style: AppTextStyles.headingSmall),
          ],
        ),
        content: Text(
          'Are you sure you want to decline the appointment request for ${_appointment.patientName}?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (_isProcessing) return;
              setState(() => _isProcessing = true);

              try {
                if (widget.onDecline != null) {
                  await widget.onDecline!(_appointment);
                } else {
                  await _repository.declineAppointment(_appointment.id);
                }
                if (mounted) {
                  setState(() {
                    _appointment.status = DoctorAppointmentStatus.cancelled;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Appointment for ${_appointment.patientName} was declined.',
                      ),
                      backgroundColor: AppColors.textPrimary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to decline appointment: $e'),
                      backgroundColor: AppColors.emergency,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isProcessing = false);
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.emergency,
            ),
            child: const Text(
              'Decline',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _openPatientProfile() {
    final patientId = _appointment.patientId;
    if (patientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient identifier is unavailable for this appointment.'),
          backgroundColor: AppColors.emergency,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final initialModel = DoctorPatientModel(
      id: patientId,
      name: _appointment.patientName,
      age: _appointment.patientAge ?? 0,
      gender: _appointment.patientGender ?? 'Not specified',
      phone: _appointment.patientPhone ?? 'Not provided',
      bloodGroup: 'Not specified',
      lastVisit: _appointment.date,
      totalVisits: 1,
      primaryCondition: _appointment.serviceName,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorPatientDetailScreen(
          patient: initialModel,
          patientId: patientId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    Color statusBg;
    switch (_appointment.status) {
      case DoctorAppointmentStatus.pending:
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFFFFBEB);
        break;
      case DoctorAppointmentStatus.confirmed:
        statusColor = const Color(0xFF059669);
        statusBg = const Color(0xFFECFDF5);
        break;
      case DoctorAppointmentStatus.completed:
        statusColor = const Color(0xFF2563EB);
        statusBg = const Color(0xFFEFF6FF);
        break;
      case DoctorAppointmentStatus.cancelled:
        statusColor = AppColors.textSecondary;
        statusBg = AppColors.surfaceSecondary;
        break;
    }

    final hasDemographics =
        _appointment.patientAge != null && _appointment.patientGender != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Appointment Details',
          style: AppTextStyles.headingMedium,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card with Patient and Status
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
                          imageUrlOrPath: _appointment.patientAvatarUrl,
                          name: _appointment.patientName,
                          size: 56,
                          isCircle: true,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _appointment.patientName,
                                style: AppTextStyles.headingMedium.copyWith(
                                   fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hasDemographics
                                    ? '${_appointment.patientAge} yrs • ${_appointment.patientGender}'
                                    : (_appointment.referenceNo.isNotEmpty
                                        ? 'Ref: ${_appointment.referenceNo}'
                                        : ''),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _appointment.statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Details Information Card
              Text(
                'Appointment Summary',
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
                    _buildDetailRow(
                      icon: Icons.tag_rounded,
                      label: 'Reference No',
                      value: _appointment.referenceNo,
                      isBoldValue: true,
                    ),
                    const Divider(height: 20),
                    _buildDetailRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Patient',
                      value: _appointment.patientName,
                    ),
                    const Divider(height: 20),
                    _buildDetailRow(
                      icon: Icons.medical_services_outlined,
                      label: 'Service',
                      value: _appointment.serviceName,
                    ),
                    const Divider(height: 20),
                    _buildDetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value: _appointment.date,
                    ),
                    const Divider(height: 20),
                    _buildDetailRow(
                      icon: Icons.schedule_rounded,
                      label: 'Time',
                      value: _appointment.time,
                    ),
                    const Divider(height: 20),
                    _buildDetailRow(
                      icon: Icons.storefront_outlined,
                      label: 'Clinic',
                      value: _appointment.clinicName,
                    ),
                    const Divider(height: 20),
                    _buildDetailRow(
                      icon: Icons.payments_outlined,
                      label: 'Consultation Fee',
                      value: _appointment.formattedFee,
                      valueColor: AppColors.primary,
                      isBoldValue: true,
                    ),
                    const Divider(height: 20),
                    _buildDetailRow(
                      icon: Icons.point_of_sale_rounded,
                      label: 'Payment',
                      value: 'Cash at clinic',
                      valueColor: AppColors.textPrimary,
                    ),
                    const Divider(height: 20),
                    _buildDetailRow(
                      icon: Icons.info_outline_rounded,
                      label: 'Status',
                      value: _appointment.statusLabel,
                      valueColor: statusColor,
                      isBoldValue: true,
                    ),
                    if (_appointment.cancellationReason != null &&
                        _appointment.cancellationReason!.isNotEmpty) ...[
                      const Divider(height: 20),
                      _buildDetailRow(
                        icon: Icons.cancel_outlined,
                        label: 'Reason',
                        value: _appointment.cancellationReason!,
                        valueColor: AppColors.emergency,
                      ),
                    ],
                  ],
                ),
              ),                // ── Clinical Consultation & Prescriptions (Phase 4C) ─────────
              if (_appointment.status == DoctorAppointmentStatus.confirmed ||
                  _appointment.status == DoctorAppointmentStatus.completed) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Consultation & Prescription',
                        style: AppTextStyles.headingSmall.copyWith(fontSize: 16),
                      ),
                    ),
                    if (_consultationNote != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Authored',
                          style: TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                if (_isLoadingNote) ...[
                  Container(
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const CircularProgressIndicator(
                        color: AppColors.primary),
                  ),
                ] else if (_consultationNote != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x04000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_consultationNote!.diagnosis != null &&
                            _consultationNote!.diagnosis!.isNotEmpty) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.medical_services_outlined,
                                    size: 16, color: AppColors.primary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Diagnosis',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textTertiary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _consultationNote!.diagnosis!,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                        ],
                        if (_consultationNote!.notes != null &&
                            _consultationNote!.notes!.isNotEmpty) ...[
                          Text(
                            'Clinical Observations',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _consultationNote!.notes!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Divider(height: 20),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Prescribed Medications (${_consultationNote!.prescriptions.length})',
                                style: AppTextStyles.labelMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: _openConsultationNoteSheet,
                              icon: const Icon(Icons.edit_outlined, size: 15),
                              label: const Text('Edit Note / Rx'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                visualDensity: VisualDensity.compact,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_consultationNote!.prescriptions.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ..._consultationNote!.prescriptions.map((p) =>
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.medication_rounded,
                                        size: 14, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${p.medicineName} (${p.dosage}) • ${p.frequency}',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openConsultationNoteSheet,
                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                      label: const Text('Start Consultation & Write Rx'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 28),

              // Action Buttons
              if (_appointment.status == DoctorAppointmentStatus.pending) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isProcessing ? null : _showDeclineConfirmation,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.emergency,
                          side: const BorderSide(
                            color: AppColors.emergencyBorder,
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.emergency,
                                ),
                              )
                            : const Text(
                                'Decline',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _handleAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Accept',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // View Patient Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openPatientProfile,
                  icon: const Icon(Icons.person_search_outlined, size: 18),
                  label: const Text('View Patient Profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side:
                        const BorderSide(color: AppColors.primary, width: 1.2),
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
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBoldValue = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: isBoldValue ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
