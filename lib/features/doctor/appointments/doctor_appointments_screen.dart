import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/doctor_repository.dart';
import '../models/doctor_appointment_model.dart';
import '../patients/doctor_patient_detail_screen.dart';
import 'doctor_appointment_details_screen.dart';

enum AppointmentFilter {
  pending,
  upcoming,
  completed,
  cancelled,
}

class DoctorAppointmentsScreen extends StatefulWidget {
  final List<DoctorAppointmentModel> appointments;
  final dynamic Function(DoctorAppointmentModel appointment)? onAcceptAppointment;
  final dynamic Function(DoctorAppointmentModel appointment)? onDeclineAppointment;
  final Future<void> Function()? onRefresh;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const DoctorAppointmentsScreen({
    super.key,
    required this.appointments,
    this.onAcceptAppointment,
    this.onDeclineAppointment,
    this.onRefresh,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  @override
  State<DoctorAppointmentsScreen> createState() =>
      _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  AppointmentFilter _selectedFilter = AppointmentFilter.pending;
  final Set<String> _updatingAppointmentIds = {};

  List<DoctorAppointmentModel> get _filteredAppointments {
    switch (_selectedFilter) {
      case AppointmentFilter.pending:
        return widget.appointments
            .where((a) => a.status == DoctorAppointmentStatus.pending)
            .toList();
      case AppointmentFilter.upcoming:
        return widget.appointments
            .where((a) => a.status == DoctorAppointmentStatus.confirmed)
            .toList();
      case AppointmentFilter.completed:
        return widget.appointments
            .where((a) => a.status == DoctorAppointmentStatus.completed)
            .toList();
      case AppointmentFilter.cancelled:
        return widget.appointments
            .where((a) => a.status == DoctorAppointmentStatus.cancelled)
            .toList();
    }
  }

  int _getCountForFilter(AppointmentFilter filter) {
    switch (filter) {
      case AppointmentFilter.pending:
        return widget.appointments
            .where((a) => a.status == DoctorAppointmentStatus.pending)
            .length;
      case AppointmentFilter.upcoming:
        return widget.appointments
            .where((a) => a.status == DoctorAppointmentStatus.confirmed)
            .length;
      case AppointmentFilter.completed:
        return widget.appointments
            .where((a) => a.status == DoctorAppointmentStatus.completed)
            .length;
      case AppointmentFilter.cancelled:
        return widget.appointments
            .where((a) => a.status == DoctorAppointmentStatus.cancelled)
            .length;
    }
  }

  Future<void> _handleAccept(DoctorAppointmentModel appointment) async {
    if (_updatingAppointmentIds.contains(appointment.id)) return;
    setState(() => _updatingAppointmentIds.add(appointment.id));

    try {
      if (widget.onAcceptAppointment != null) {
        await widget.onAcceptAppointment!(appointment);
      } else {
        await DoctorRepository.instance.acceptAppointment(appointment.id);
        appointment.status = DoctorAppointmentStatus.confirmed;
      }

      if (mounted) {
        setState(() {
          appointment.status = DoctorAppointmentStatus.confirmed;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Appointment for ${appointment.patientName} accepted & moved to Upcoming.',
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
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
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingAppointmentIds.remove(appointment.id));
      }
    }
  }

  void _showDeclineConfirmation(DoctorAppointmentModel appointment) {
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
          'Are you sure you want to decline the appointment request from ${appointment.patientName}?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (_updatingAppointmentIds.contains(appointment.id)) return;
              setState(() => _updatingAppointmentIds.add(appointment.id));

              try {
                if (widget.onDeclineAppointment != null) {
                  await widget.onDeclineAppointment!(appointment);
                } else {
                  await DoctorRepository.instance.declineAppointment(appointment.id);
                  appointment.status = DoctorAppointmentStatus.cancelled;
                }

                if (mounted) {
                  setState(() {
                    appointment.status = DoctorAppointmentStatus.cancelled;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Appointment for ${appointment.patientName} was declined.',
                      ),
                      backgroundColor: AppColors.textPrimary,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
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
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(
                      () => _updatingAppointmentIds.remove(appointment.id));
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

  void _openAppointmentDetails(DoctorAppointmentModel appointment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorAppointmentDetailsScreen(
          appointment: appointment,
          onAccept: (apt) async {
            await _handleAccept(apt);
          },
          onDecline: (apt) async {
            if (widget.onDeclineAppointment != null) {
              await widget.onDeclineAppointment!(apt);
            } else {
              apt.status = DoctorAppointmentStatus.cancelled;
            }
            if (mounted) {
              setState(() {
                apt.status = DoctorAppointmentStatus.cancelled;
              });
            }
          },
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openPatientProfile(DoctorAppointmentModel apt) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorPatientDetailScreen(
          patientId: apt.patientId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredAppointments;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Appointments',
          style: AppTextStyles.headingMedium,
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subtitle & Header Info
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage your patient appointments.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Chips (Pending, Upcoming, Completed, Cancelled)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'Pending',
                          filter: AppointmentFilter.pending,
                          count: _getCountForFilter(AppointmentFilter.pending),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Upcoming',
                          filter: AppointmentFilter.upcoming,
                          count: _getCountForFilter(AppointmentFilter.upcoming),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Completed',
                          filter: AppointmentFilter.completed,
                          count: _getCountForFilter(AppointmentFilter.completed),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Cancelled',
                          filter: AppointmentFilter.cancelled,
                          count: _getCountForFilter(AppointmentFilter.cancelled),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Appointments List or Empty / Error / Loading State
            Expanded(
              child: widget.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : widget.errorMessage != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: widget.onRefresh ?? () async {},
                          child: list.isEmpty
                              ? _buildEmptyState()
                              : ListView.separated(
                                  padding: const EdgeInsets.all(20),
                                  physics:
                                      const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  itemCount: list.length,
                                  separatorBuilder: (_, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final apt = list[index];
                                    return _buildAppointmentCard(apt);
                                  },
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.emergencySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: AppColors.emergency,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Appointments',
              style: AppTextStyles.headingSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              widget.errorMessage ?? 'Please check your connection and retry.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.onRetry != null || widget.onRefresh != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: widget.onRetry ?? () => widget.onRefresh?.call(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required AppointmentFilter filter,
    required int count,
  }) {
    final isSelected = _selectedFilter == filter;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(DoctorAppointmentModel apt) {
    Color statusColor;
    Color statusBg;
    switch (apt.status) {
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

    return InkWell(
      onTap: () => _openAppointmentDetails(apt),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x04000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row (Patient Avatar + Name/Details + Status Badge)
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: apt.status == DoctorAppointmentStatus.pending
                        ? const Color(0xFFFFFBEB)
                        : AppColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      apt.patientName.isNotEmpty ? apt.patientName[0] : 'P',
                      style: TextStyle(
                        color: apt.status == DoctorAppointmentStatus.pending
                            ? const Color(0xFFD97706)
                            : AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        apt.patientName,
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        apt.patientAge != null && apt.patientGender != null
                            ? '${apt.patientAge} yrs • ${apt.patientGender}'
                            : (apt.referenceNo.isNotEmpty
                                ? 'Ref: ${apt.referenceNo}'
                                : ''),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    apt.statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // Service & Clinic Info
            Row(
              children: [
                const Icon(
                  Icons.medical_services_outlined,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    apt.serviceName,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  apt.formattedFee,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Date, Time & Clinic Location
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${apt.date} • ${apt.time}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.storefront_outlined,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    apt.clinicName,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Actions for Pending Requests
            if (apt.status == DoctorAppointmentStatus.pending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _updatingAppointmentIds.contains(apt.id)
                          ? null
                          : () => _showDeclineConfirmation(apt),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.emergency,
                        side: const BorderSide(
                          color: AppColors.emergencyBorder,
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _updatingAppointmentIds.contains(apt.id)
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppColors.emergency,
                              ),
                            )
                          : const Text(
                              'Decline',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _updatingAppointmentIds.contains(apt.id)
                          ? null
                          : () => _handleAccept(apt),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: _updatingAppointmentIds.contains(apt.id)
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Accept',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],

            // Action for Upcoming & Completed
            if (apt.status == DoctorAppointmentStatus.confirmed ||
                apt.status == DoctorAppointmentStatus.completed) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _openPatientProfile(apt),
                    icon: const Icon(Icons.person_outline_rounded, size: 16),
                    label: const Text('View Patient'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String title;
    String subtitle;
    IconData icon;

    switch (_selectedFilter) {
      case AppointmentFilter.pending:
        title = 'No pending requests';
        subtitle = "You don't have any appointment requests right now.";
        icon = Icons.pending_actions_rounded;
        break;
      case AppointmentFilter.upcoming:
        title = 'No upcoming appointments';
        subtitle = 'Confirmed patient appointments will appear here.';
        icon = Icons.event_available_rounded;
        break;
      case AppointmentFilter.completed:
        title = 'No completed appointments';
        subtitle = 'Past consultations will be listed here.';
        icon = Icons.task_alt_rounded;
        break;
      case AppointmentFilter.cancelled:
        title = 'No cancelled appointments';
        subtitle = 'Declined or cancelled requests will be recorded here.';
        icon = Icons.event_busy_rounded;
        break;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.headingSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
