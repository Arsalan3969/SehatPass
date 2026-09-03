import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'data/doctor_repository.dart';
import 'models/doctor_onboarding_data.dart';
import 'models/doctor_appointment_model.dart';
import 'models/doctor_patient_model.dart';
import 'dashboard/doctor_dashboard_screen.dart';
import 'appointments/doctor_appointments_screen.dart';
import 'patients/doctor_patients_screen.dart';
import 'clinic/doctor_clinic_screen.dart';
import 'profile/doctor_profile_screen.dart';

class DoctorShellScreen extends StatefulWidget {
  final DoctorOnboardingData? data;
  final DoctorRepository? repository;
  final List<DoctorAppointmentModel>? initialAppointments;
  final List<DoctorPatientModel>? initialPatients;

  const DoctorShellScreen({
    super.key,
    this.data,
    this.repository,
    this.initialAppointments,
    this.initialPatients,
  });

  @override
  State<DoctorShellScreen> createState() => _DoctorShellScreenState();
}

class _DoctorShellScreenState extends State<DoctorShellScreen> {
  int _currentIndex = 0;
  late final DoctorRepository _repository;
  DoctorOnboardingData _data = DoctorOnboardingData();
  List<DoctorAppointmentModel> _appointments = [];
  List<DoctorPatientModel> _patients = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DoctorRepository.instance;
    _data = widget.data ?? DoctorOnboardingData();

    if (widget.initialAppointments != null) {
      _appointments = List.from(widget.initialAppointments!);
    }
    if (widget.initialPatients != null) {
      _patients = List.from(widget.initialPatients!);
    }

    if (_repository.currentUserId != null) {
      _fetchDashboardData();
    }
  }

  @override
  void didUpdateWidget(covariant DoctorShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != null && widget.data != oldWidget.data) {
      _data = widget.data!;
    }
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _repository.getDoctorAppointments(),
        _repository.getDoctorPatients(),
        _repository.loadExistingOnboardingData(),
      ]);
      if (mounted) {
        setState(() {
          _appointments = results[0] as List<DoctorAppointmentModel>;
          _patients = results[1] as List<DoctorPatientModel>;
          final loadedOnboarding = results[2] as DoctorOnboardingData;
          if (widget.data == null) {
            _data = loadedOnboarding;
          } else {
            _data = widget.data!;
          }
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

  Future<void> _onAcceptAppointment(DoctorAppointmentModel appointment) async {
    try {
      if (_repository.currentUserId != null) {
        final updated = await _repository.acceptAppointment(appointment.id);
        if (mounted) {
          setState(() {
            final index =
                _appointments.indexWhere((a) => a.id == appointment.id);
            if (index != -1) {
              _appointments[index] = updated;
            } else {
              appointment.status = DoctorAppointmentStatus.confirmed;
            }
          });
        }
      } else {
        setState(() {
          appointment.status = DoctorAppointmentStatus.confirmed;
        });
      }
    } catch (e) {
      debugPrint('DoctorShellScreen: Error accepting appointment: $e');
      rethrow;
    }
  }

  Future<void> _onDeclineAppointment(DoctorAppointmentModel appointment,
      {String? reason}) async {
    try {
      if (_repository.currentUserId != null) {
        final updated = await _repository.declineAppointment(appointment.id,
            reason: reason);
        if (mounted) {
          setState(() {
            final index =
                _appointments.indexWhere((a) => a.id == appointment.id);
            if (index != -1) {
              _appointments[index] = updated;
            } else {
              appointment.status = DoctorAppointmentStatus.cancelled;
            }
          });
        }
      } else {
        setState(() {
          appointment.status = DoctorAppointmentStatus.cancelled;
        });
      }
    } catch (e) {
      debugPrint('DoctorShellScreen: Error declining appointment: $e');
      rethrow;
    }
  }

  void _navigateToTab(int index) {
    if (index >= 0 && index < 5) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null && _data.profile.fullName.isEmpty && widget.data == null && _repository.currentUserId != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.emergencySurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.emergency,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Unable to load doctor profile',
                    style: AppTextStyles.headingSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _fetchDashboardData,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            DoctorDashboardScreen(
              data: _data,
              appointments: _appointments,
              patients: _patients,
              repository: _repository,
              onAcceptAppointment: _onAcceptAppointment,
              onDeclineAppointment: _onDeclineAppointment,
              onNavigateToTab: _navigateToTab,
            ),
            DoctorAppointmentsScreen(
              appointments: _appointments,
              onAcceptAppointment: _onAcceptAppointment,
              onDeclineAppointment: _onDeclineAppointment,
              onRefresh: _fetchDashboardData,
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              onRetry: _fetchDashboardData,
            ),
            DoctorPatientsScreen(
              repository: _repository,
              initialPatients: widget.initialPatients,
            ),
            DoctorClinicScreen(
              data: _data,
              repository: _repository,
            ),
            DoctorProfileScreen(
              data: _data,
              repository: _repository,
              onProfileUpdated: _fetchDashboardData,
            ),
          ],
        ),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarTheme.of(context).copyWith(
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
                letterSpacing: -0.3,
                height: 1.1,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            height: 68,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month_rounded),
                label: 'Appointments',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_alt_outlined),
                selectedIcon: Icon(Icons.people_alt_rounded),
                label: 'Patients',
              ),
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: 'Clinic',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
