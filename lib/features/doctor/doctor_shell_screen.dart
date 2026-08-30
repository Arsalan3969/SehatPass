import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import 'models/doctor_onboarding_data.dart';
import 'models/doctor_appointment_model.dart';
import 'dashboard/doctor_dashboard_screen.dart';
import 'appointments/doctor_appointments_screen.dart';
import 'patients/doctor_patients_screen.dart';
import 'clinic/doctor_clinic_screen.dart';
import 'profile/doctor_profile_screen.dart';

class DoctorShellScreen extends StatefulWidget {
  final DoctorOnboardingData? data;

  const DoctorShellScreen({
    super.key,
    this.data,
  });

  @override
  State<DoctorShellScreen> createState() => _DoctorShellScreenState();
}

class _DoctorShellScreenState extends State<DoctorShellScreen> {
  int _currentIndex = 0;
  late final DoctorOnboardingData _data;
  late final List<DoctorAppointmentModel> _appointments;

  @override
  void initState() {
    super.initState();
    _data = widget.data ?? DoctorOnboardingData();
    _appointments = DoctorAppointmentModel.dummySchedule;
  }

  void _onAcceptAppointment(DoctorAppointmentModel appointment) {
    setState(() {
      appointment.status = DoctorAppointmentStatus.confirmed;
    });
  }

  void _onDeclineAppointment(DoctorAppointmentModel appointment) {
    setState(() {
      appointment.status = DoctorAppointmentStatus.cancelled;
    });
  }

  void _navigateToTab(int index) {
    if (index >= 0 && index < 5) {
      setState(() => _currentIndex = index);
    }
  }

  void _switchToPatientView() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
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
              onAcceptAppointment: _onAcceptAppointment,
              onDeclineAppointment: _onDeclineAppointment,
              onNavigateToTab: _navigateToTab,
              onSwitchToPatientView: _switchToPatientView,
            ),
            DoctorAppointmentsScreen(
              appointments: _appointments,
              onAcceptAppointment: _onAcceptAppointment,
              onDeclineAppointment: _onDeclineAppointment,
              onSwitchToPatientView: _switchToPatientView,
            ),
            DoctorPatientsScreen(
              onSwitchToPatientView: _switchToPatientView,
            ),
            DoctorClinicScreen(
              data: _data,
              onSwitchToPatientView: _switchToPatientView,
            ),
            DoctorProfileScreen(
              data: _data,
              onSwitchToPatientView: _switchToPatientView,
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
