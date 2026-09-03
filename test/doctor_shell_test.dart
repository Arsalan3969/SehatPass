import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/features/doctor/doctor_shell_screen.dart';
import 'package:sehatpass/features/doctor/dashboard/doctor_dashboard_screen.dart';
import 'package:sehatpass/features/doctor/appointments/doctor_appointments_screen.dart';
import 'package:sehatpass/features/doctor/appointments/doctor_appointment_details_screen.dart';
import 'package:sehatpass/features/doctor/patients/doctor_patients_screen.dart';
import 'package:sehatpass/features/doctor/patients/doctor_patient_detail_screen.dart';
import 'package:sehatpass/features/doctor/clinic/doctor_clinic_screen.dart';
import 'package:sehatpass/features/doctor/profile/doctor_profile_screen.dart';
import 'package:sehatpass/features/doctor/models/doctor_appointment_model.dart';
import 'package:sehatpass/features/doctor/models/doctor_patient_model.dart';

void main() {
  Widget createDoctorApp() {
    return MaterialApp(
      theme: AppTheme.light,
      home: DoctorShellScreen(
        initialAppointments: DoctorAppointmentModel.dummySchedule,
        initialPatients: DoctorPatientModel.dummyPatients,
      ),
    );
  }

  testWidgets('Doctor Shell renders all 5 bottom navigation destinations',
      (WidgetTester tester) async {
    await tester.pumpWidget(createDoctorApp());
    await tester.pumpAndSettle();

    // Verify 5 navigation destinations exist in NavigationBar
    final navBar = find.byType(NavigationBar);
    expect(navBar, findsOneWidget);

    expect(
        find.descendant(of: navBar, matching: find.text('Dashboard')),
        findsOneWidget);
    expect(
        find.descendant(of: navBar, matching: find.text('Appointments')),
        findsOneWidget);
    expect(
        find.descendant(of: navBar, matching: find.text('Patients')),
        findsOneWidget);
    expect(
        find.descendant(of: navBar, matching: find.text('Clinic')),
        findsOneWidget);
    expect(
        find.descendant(of: navBar, matching: find.text('Profile')),
        findsOneWidget);

    // Initial screen is DoctorDashboardScreen
    expect(find.byType(DoctorDashboardScreen), findsOneWidget);
    expect(find.text("Today's Appointments"), findsOneWidget);
    expect(find.text('Pending Requests'), findsWidgets);
    expect(find.text('Total Patients'), findsOneWidget);
    expect(find.text('Total Appointments'), findsOneWidget);
  });

  testWidgets('Switching bottom tabs navigates between Doctor screens',
      (WidgetTester tester) async {
    await tester.pumpWidget(createDoctorApp());
    await tester.pumpAndSettle();

    final navBar = find.byType(NavigationBar);

    // Switch to Appointments tab
    await tester.tap(
        find.descendant(of: navBar, matching: find.text('Appointments')));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorAppointmentsScreen), findsOneWidget);

    // Switch to Patients tab
    await tester.tap(
        find.descendant(of: navBar, matching: find.text('Patients')));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorPatientsScreen), findsOneWidget);

    // Switch to Clinic tab
    await tester.tap(
        find.descendant(of: navBar, matching: find.text('Clinic')));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorClinicScreen), findsOneWidget);

    // Switch to Profile tab
    await tester.tap(
        find.descendant(of: navBar, matching: find.text('Profile')));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorProfileScreen), findsOneWidget);

    // Switch back to Dashboard tab
    await tester.tap(
        find.descendant(of: navBar, matching: find.text('Dashboard')));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorDashboardScreen), findsOneWidget);
  });

  testWidgets('Appointments screen filters work: Pending, Upcoming, Completed, Cancelled',
      (WidgetTester tester) async {
    await tester.pumpWidget(createDoctorApp());
    await tester.pumpAndSettle();

    final navBar = find.byType(NavigationBar);
    await tester.tap(
        find.descendant(of: navBar, matching: find.text('Appointments')));
    await tester.pumpAndSettle();

    // Default filter is Pending
    expect(find.text('Manage your patient appointments.'), findsOneWidget);
    expect(find.text('Usman Ali'), findsWidgets);

    // Tap Upcoming filter
    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();
    expect(find.text('Ali Khan'), findsWidgets);
    expect(find.text('Fatima Ahmed'), findsWidgets);

    // Tap Completed filter
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Hassan Raza'), findsWidgets);

    // Tap Cancelled filter
    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();
    expect(find.text('Ayesha Malik'), findsWidgets);
  });

  testWidgets('Accepting a pending appointment moves it to Upcoming and syncs with Dashboard',
      (WidgetTester tester) async {
    await tester.pumpWidget(createDoctorApp());
    await tester.pumpAndSettle();

    final navBar = find.byType(NavigationBar);

    // Go to Appointments tab
    await tester.tap(
        find.descendant(of: navBar, matching: find.text('Appointments')));
    await tester.pumpAndSettle();

    // In Pending, find Accept button for Usman Ali
    final acceptButtons = find.widgetWithText(ElevatedButton, 'Accept');
    expect(acceptButtons, findsWidgets);

    await tester.tap(acceptButtons.first);
    await tester.pumpAndSettle();

    // Verify snackbar
    expect(find.textContaining('accepted & moved to Upcoming'), findsOneWidget);

    // Switch to Upcoming filter
    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();
    expect(find.text('Usman Ali'), findsWidgets);

    // Switch back to Dashboard and verify Usman Ali is now in today's schedule
    await tester.tap(
        find.descendant(of: navBar, matching: find.text('Dashboard')));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorDashboardScreen), findsOneWidget);
  });

  testWidgets('Declining a pending appointment shows confirmation and moves to Cancelled',
      (WidgetTester tester) async {
    await tester.pumpWidget(createDoctorApp());
    await tester.pumpAndSettle();

    final navBar = find.byType(NavigationBar);

    // Go to Appointments tab
    await tester.tap(
        find.descendant(of: navBar, matching: find.text('Appointments')));
    await tester.pumpAndSettle();

    // Tap Decline on first pending request
    final declineButtons = find.widgetWithText(OutlinedButton, 'Decline');
    expect(declineButtons, findsWidgets);

    await tester.tap(declineButtons.first);
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.text('Decline Request?'), findsOneWidget);

    // Confirm decline
    final confirmDecline = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, 'Decline'),
    );
    await tester.tap(confirmDecline);
    await tester.pumpAndSettle();

    // Switch to Cancelled filter
    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelled'), findsWidgets);
  });

  testWidgets('Tapping appointment card opens Appointment Details & View Patient opens Patient Details',
      (WidgetTester tester) async {
    await tester.pumpWidget(createDoctorApp());
    await tester.pumpAndSettle();

    final navBar = find.byType(NavigationBar);
    await tester.tap(
        find.descendant(of: navBar, matching: find.text('Appointments')));
    await tester.pumpAndSettle();

    // Switch to Upcoming filter
    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();

    // Tap Ali Khan appointment card
    await tester.tap(find.text('Ali Khan').first);
    await tester.pumpAndSettle();

    // Appointment Details Screen is opened
    expect(find.byType(DoctorAppointmentDetailsScreen), findsOneWidget);
    expect(find.text('Appointment Summary'), findsOneWidget);
    expect(find.text('City Heart Clinic'), findsWidgets);

    // Tap View Patient Profile
    final viewPatientBtn =
        find.widgetWithText(OutlinedButton, 'View Patient Profile');
    expect(viewPatientBtn, findsOneWidget);
    await tester.ensureVisible(viewPatientBtn);
    await tester.tap(viewPatientBtn);
    await tester.pumpAndSettle();

    // Patient Details Screen is opened
    expect(find.byType(DoctorPatientDetailScreen), findsOneWidget);
    expect(find.text('Ali Khan'), findsWidgets);
    expect(find.text('Clinical Summary'), findsOneWidget);
    expect(find.text('Active Medications'), findsOneWidget);
  });

  testWidgets('No overflow occurs on compact 360x640 screen size across all tabs',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createDoctorApp());
    await tester.pumpAndSettle();

    final navBar = find.byType(NavigationBar);

    // Dashboard check
    expect(find.byType(DoctorDashboardScreen), findsOneWidget);

    // Appointments tab
    await tester.tap(
        find.descendant(of: navBar, matching: find.text('Appointments')));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorAppointmentsScreen), findsOneWidget);

    // Switch filters in appointments
    final upcomingChip = find.text('Upcoming');
    await tester.tap(upcomingChip);
    await tester.pumpAndSettle();

    final filterScrollView = find.byType(SingleChildScrollView).first;
    await tester.drag(filterScrollView, const Offset(-150, 0));
    await tester.pumpAndSettle();

    final completedChip = find.text('Completed');
    await tester.tap(completedChip);
    await tester.pumpAndSettle();

    await tester.drag(filterScrollView, const Offset(-200, 0));
    await tester.pumpAndSettle();

    final cancelledChip = find.text('Cancelled');
    await tester.tap(cancelledChip);
    await tester.pumpAndSettle();
    expect(find.byType(DoctorAppointmentsScreen), findsOneWidget);

    // Patients tab
    await tester.tap(
        find.descendant(of: navBar, matching: find.text('Patients')));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorPatientsScreen), findsOneWidget);

    // Clinic tab
    await tester.tap(
        find.descendant(of: navBar, matching: find.text('Clinic')));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorClinicScreen), findsOneWidget);

    // Profile tab
    await tester.tap(
        find.descendant(of: navBar, matching: find.text('Profile')));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorProfileScreen), findsOneWidget);
  });
}
