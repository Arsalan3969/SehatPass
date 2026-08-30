import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/doctor_appointment_model.dart';
import '../models/doctor_patient_model.dart';
import '../patients/doctor_patient_detail_screen.dart';

class DoctorAppointmentDetailsScreen extends StatefulWidget {
  final DoctorAppointmentModel appointment;
  final Function(DoctorAppointmentModel appointment)? onAccept;
  final Function(DoctorAppointmentModel appointment)? onDecline;

  const DoctorAppointmentDetailsScreen({
    super.key,
    required this.appointment,
    this.onAccept,
    this.onDecline,
  });

  @override
  State<DoctorAppointmentDetailsScreen> createState() =>
      _DoctorAppointmentDetailsScreenState();
}

class _DoctorAppointmentDetailsScreenState
    extends State<DoctorAppointmentDetailsScreen> {
  late DoctorAppointmentModel _appointment;

  @override
  void initState() {
    super.initState();
    _appointment = widget.appointment;
  }

  void _handleAccept() {
    setState(() {
      _appointment.status = DoctorAppointmentStatus.confirmed;
    });
    widget.onAccept?.call(_appointment);

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
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _appointment.status = DoctorAppointmentStatus.cancelled;
              });
              widget.onDecline?.call(_appointment);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Appointment for ${_appointment.patientName} was declined.',
                  ),
                  backgroundColor: AppColors.textPrimary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
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
    final patient = DoctorPatientModel.getPatientByName(_appointment.patientName);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorPatientDetailScreen(patient: patient),
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
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _appointment.patientName.isNotEmpty
                                  ? _appointment.patientName[0]
                                  : 'P',
                              style: AppTextStyles.headingLarge.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
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
                                '${_appointment.patientAge} yrs • ${_appointment.patientGender}',
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
                      icon: Icons.person_outline_rounded,
                      label: 'Patient',
                      value: _appointment.patientName,
                    ),
                    const Divider(height: 20),
                    _buildDetailRow(
                      icon: Icons.medical_services_outlined,
                      label: 'Appointment',
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
                      icon: Icons.info_outline_rounded,
                      label: 'Status',
                      value: _appointment.statusLabel,
                      valueColor: statusColor,
                      isBoldValue: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Action Buttons
              if (_appointment.status == DoctorAppointmentStatus.pending) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _showDeclineConfirmation,
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
                        child: const Text(
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
                        onPressed: _handleAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
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
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: isBoldValue ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
