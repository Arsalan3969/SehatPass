import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import 'models/appointment_model.dart';
import 'data/appointment_repository.dart';
import '../doctor/models/doctor_consultation_note_model.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final Appointment appointment;
  final DoctorConsultationNoteModel? initialConsultationNote;

  const AppointmentDetailScreen({
    super.key,
    required this.appointment,
    this.initialConsultationNote,
  });

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  late AppointmentStatus _currentStatus;
  DoctorConsultationNoteModel? _consultationNote;
  bool _isLoadingConsultation = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.appointment.status;
    _consultationNote = widget.initialConsultationNote;

    if (_consultationNote == null &&
        (_currentStatus == AppointmentStatus.upcoming ||
            _currentStatus == AppointmentStatus.past)) {
      _loadConsultationNote();
    }
  }

  Future<void> _loadConsultationNote() async {
    setState(() => _isLoadingConsultation = true);
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('doctor_consultation_notes')
          .select()
          .eq('appointment_id', widget.appointment.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (response != null) {
            _consultationNote = DoctorConsultationNoteModel.fromMap(
                Map<String, dynamic>.from(response as Map));
          }
          _isLoadingConsultation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingConsultation = false);
      }
    }
  }

  bool _isCancelling = false;

  void _confirmCancel() {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.emergencySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cancel_outlined,
                    color: AppColors.emergency, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Cancel Appointment',
                  style: AppTextStyles.headingSmall),
            ],
          ),
          content: Text(
            'Are you sure you want to cancel your appointment with ${widget.appointment.doctor.name}? This action cannot be undone.',
            style: AppTextStyles.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: _isCancelling ? null : () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary),
              child: const Text('Keep Appointment'),
            ),
              TextButton(
                onPressed: _isCancelling
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(ctx);
                        setDialogState(() => _isCancelling = true);
                        try {
                          await AppointmentRepository.instance
                              .cancelAppointment(
                                  appointmentId: widget.appointment.id);
                          if (!mounted) return;
                          setState(
                              () => _currentStatus = AppointmentStatus.cancelled);
                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.check_circle_outline_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 10),
                                  Text('Appointment cancelled.'),
                                ],
                              ),
                              backgroundColor: AppColors.emergency,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => _isCancelling = false);
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: AppColors.emergency,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.emergency),
              child: _isCancelling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.emergency),
                    )
                  : const Text('Cancel Appointment',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (_currentStatus) {
      case AppointmentStatus.upcoming:
        return AppColors.primary;
      case AppointmentStatus.past:
        return AppColors.textSecondary;
      case AppointmentStatus.cancelled:
        return AppColors.emergency;
    }
  }

  Color get _statusBg {
    switch (_currentStatus) {
      case AppointmentStatus.upcoming:
        return AppColors.primarySurface;
      case AppointmentStatus.past:
        return AppColors.surfaceSecondary;
      case AppointmentStatus.cancelled:
        return AppColors.emergencySurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final apt = widget.appointment;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Appointment Details'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Doctor & Status ──────────────────────────────────
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.person_rounded,
                                size: 28, color: AppColors.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(apt.doctor.name,
                                    style: AppTextStyles.labelLarge
                                        .copyWith(fontSize: 15)),
                                const SizedBox(height: 3),
                                Text(apt.doctor.specialization,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    )),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 13,
                                        color: AppColors.textTertiary),
                                    const SizedBox(width: 3),
                                    Text(
                                        '${apt.doctor.clinic}, ${apt.doctor.location}',
                                        style: AppTextStyles.bodySmall),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _statusBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _currentStatus.label,
                              style: AppTextStyles.caption.copyWith(
                                color: _statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Appointment Info ─────────────────────────────────
                    Text('Appointment Information',
                        style: AppTextStyles.headingSmall),
                    const SizedBox(height: 10),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _detailRow(Icons.confirmation_number_outlined,
                              'Appointment ID', apt.referenceNo),
                          const Divider(height: 1, color: AppColors.divider),
                          _detailRow(Icons.medical_services_outlined,
                              'Service', apt.serviceName),
                          const Divider(height: 1, color: AppColors.divider),
                          _detailRow(Icons.calendar_today_outlined, 'Date',
                              apt.formattedDate),
                          const Divider(height: 1, color: AppColors.divider),
                          _detailRow(
                              Icons.access_time_outlined, 'Time', apt.time),
                          const Divider(height: 1, color: AppColors.divider),
                          _detailRow(
                            Icons.business_outlined,
                            'Clinic',
                            apt.doctor.clinic,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Payment Info ─────────────────────────────────────
                    Text('Payment Information',
                        style: AppTextStyles.headingSmall),
                    const SizedBox(height: 10),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _detailRow(
                            Icons.payments_outlined,
                            'Consultation Fee',
                            'Rs. ${apt.consultationFee}',
                            valueColor: AppColors.primary,
                          ),
                          const Divider(height: 1, color: AppColors.divider),
                          _detailRow(
                            Icons.point_of_sale_rounded,
                            'Payment',
                            'Cash at clinic (Pay upon visit)',
                            valueColor: AppColors.textPrimary,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Doctor Consultation & Prescriptions (Phase 4C) ────
                    if (_consultationNote != null || _isLoadingConsultation) ...[
                      Text('Doctor Consultation & Prescription',
                          style: AppTextStyles.headingSmall),
                      const SizedBox(height: 10),
                      if (_isLoadingConsultation) ...[
                        Container(
                          height: 70,
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
                        AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_consultationNote!.diagnosis != null &&
                                  _consultationNote!.diagnosis!.isNotEmpty) ...[
                                Row(
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
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Diagnosis',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                              color: AppColors.textTertiary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            _consultationNote!.diagnosis!,
                                            style: AppTextStyles.labelLarge
                                                .copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(
                                    height: 18, color: AppColors.divider),
                              ],
                              if (_consultationNote!.notes != null &&
                                  _consultationNote!.notes!.isNotEmpty) ...[
                                Text(
                                  'Doctor Notes & Advice',
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
                                const Divider(
                                    height: 18, color: AppColors.divider),
                              ],
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Prescription',
                                      style: AppTextStyles.labelMedium.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${_consultationNote!.prescriptions.length} Meds',
                                      style: const TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_consultationNote!.prescriptions.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ..._consultationNote!.prescriptions.map((p) =>
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                            color: AppColors.border),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.medication_rounded,
                                              size: 16,
                                              color: AppColors.primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  p.medicineName,
                                                  style: AppTextStyles
                                                      .labelLarge
                                                      .copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${p.dosage} • ${p.frequency} • ${p.duration}',
                                                  style: AppTextStyles.caption
                                                      .copyWith(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                                if (p.instruction.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Instruction: ${p.instruction}',
                                                    style: AppTextStyles
                                                        .caption
                                                        .copyWith(
                                                      color: AppColors
                                                          .textTertiary,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Cancel button (only for upcoming) ────────────────────────
            if (_currentStatus == AppointmentStatus.upcoming)
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _confirmCancel,
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel Appointment'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.emergency,
                      side: const BorderSide(
                          color: AppColors.emergency, width: 1.2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.labelLarge.copyWith(
                color: valueColor ?? AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
