import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'data/appointment_repository.dart';
import 'models/appointment_model.dart';
import 'appointment_detail_screen.dart';
import 'find_doctor_screen.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Listen to repository changes to rebuild the list
    AppointmentRepository.instance.addListener(_onRepoChanged);
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AppointmentRepository.instance.getPatientAppointments();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    AppointmentRepository.instance.removeListener(_onRepoChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Appointments'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: AppTextStyles.labelLarge.copyWith(
              fontSize: 13, color: AppColors.primary),
          unselectedLabelStyle: AppTextStyles.bodyMedium.copyWith(
              fontSize: 13),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.emergencySurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.emergency,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load appointments',
                style: AppTextStyles.headingSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadAppointments,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _AppointmentList(
          appointments: AppointmentRepository.instance.upcoming,
          emptyMessage: 'No upcoming appointments',
          emptySubtitle: 'Book an appointment to get started.',
          showFindDoctor: true,
          onRefresh: _loadAppointments,
        ),
        _AppointmentList(
          appointments: AppointmentRepository.instance.past,
          emptyMessage: 'No past appointments',
          emptySubtitle: 'Your completed appointments will appear here.',
          onRefresh: _loadAppointments,
        ),
        _AppointmentList(
          appointments: AppointmentRepository.instance.cancelled,
          emptyMessage: 'No cancelled appointments',
          emptySubtitle: 'Appointments you cancel will appear here.',
          onRefresh: _loadAppointments,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Appointment list tab
// ─────────────────────────────────────────────────────────────────────────────

class _AppointmentList extends StatelessWidget {
  final List<Appointment> appointments;
  final String emptyMessage;
  final String emptySubtitle;
  final bool showFindDoctor;
  final Future<void> Function()? onRefresh;

  const _AppointmentList({
    required this.appointments,
    required this.emptyMessage,
    required this.emptySubtitle,
    this.showFindDoctor = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      final emptyChild = SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Container(
          height: 400,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.calendar_month_outlined,
                    size: 40, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 16),
              Text(emptyMessage, style: AppTextStyles.headingSmall),
              const SizedBox(height: 6),
              Text(emptySubtitle,
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center),
              if (showFindDoctor) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FindDoctorScreen()),
                  ),
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('Find a Doctor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      );

      if (onRefresh != null) {
        return RefreshIndicator(
          onRefresh: onRefresh!,
          color: AppColors.primary,
          child: emptyChild,
        );
      }
      return emptyChild;
    }

    final listChild = ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: appointments.length,
      separatorBuilder: (_, i) => const SizedBox(height: 12),
      itemBuilder: (context, i) =>
          _AppointmentCard(appointment: appointments[i]),
    );

    if (onRefresh != null) {
      return RefreshIndicator(
        onRefresh: onRefresh!,
        color: AppColors.primary,
        child: listChild,
      );
    }
    return listChild;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Appointment card
// ─────────────────────────────────────────────────────────────────────────────

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  const _AppointmentCard({required this.appointment});

  Color get _statusColor {
    switch (appointment.status) {
      case AppointmentStatus.upcoming:
        return AppColors.primary;
      case AppointmentStatus.past:
        return AppColors.textSecondary;
      case AppointmentStatus.cancelled:
        return AppColors.emergency;
    }
  }

  Color get _statusBg {
    switch (appointment.status) {
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000), blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_rounded,
                    size: 26, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appointment.doctor.name,
                        style:
                            AppTextStyles.labelLarge.copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(appointment.doctor.specialization,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        )),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  appointment.status.label,
                  style: AppTextStyles.caption.copyWith(
                    color: _statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(appointment.formattedDate,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(width: 14),
              const Icon(Icons.access_time_outlined,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(appointment.time,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  )),
              const Spacer(),
              // Paid badge
              Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(appointment.paymentStatus.label,
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(appointment.doctor.clinic,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  )),
              const Spacer(),
              // View Details button
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AppointmentDetailScreen(
                          appointment: appointment),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                        color: AppColors.primary, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  child: const Text('View Details'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
