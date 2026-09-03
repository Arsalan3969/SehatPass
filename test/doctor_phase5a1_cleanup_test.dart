import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/features/doctor/dashboard/doctor_dashboard_screen.dart';
import 'package:sehatpass/features/doctor/profile/doctor_profile_screen.dart';
import 'package:sehatpass/features/doctor/clinic/doctor_clinic_screen.dart';
import 'package:sehatpass/features/doctor/onboarding/steps/preview_clinic_step.dart';
import 'package:sehatpass/features/doctor/onboarding/steps/set_availability_step.dart';
import 'package:sehatpass/features/doctor/models/doctor_onboarding_data.dart';
import 'package:sehatpass/features/doctor/models/doctor_availability_model.dart';

void main() {
  group('Phase 5A.1 Doctor UI Cleanup & Real Data Tests', () {
    testWidgets('Doctor Dashboard shows real zero state and no mock data or patient view switch',
        (WidgetTester tester) async {
      final data = DoctorOnboardingData();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorDashboardScreen(
            data: data,
            appointments: const [],
            patients: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Total Patients = 0
      expect(find.text('Total Patients'), findsOneWidget);
      expect(find.text('0'), findsWidgets);

      // Verify Total Appointments = 0
      expect(find.text('Total Appointments'), findsOneWidget);

      // Verify honest empty state for Recent Patients
      expect(find.text('Recent Patients'), findsOneWidget);
      expect(find.text('No patients yet'), findsOneWidget);

      // Verify honest empty state for Today's Schedule
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.text('No confirmed appointments for today.'), findsOneWidget);

      // Verify NO fake mock patients
      expect(find.text('Ali Khan'), findsNothing);
      expect(find.text('Fatima Ahmed'), findsNothing);
      expect(find.text('Usman Ali'), findsNothing);

      // Verify NO Patient View button in AppBar
      expect(find.text('Patient View'), findsNothing);
    });

    testWidgets('Doctor Profile has no rating, no license/PMDC row, and no switch to patient view',
        (WidgetTester tester) async {
      final data = DoctorOnboardingData();
      data.profile.fullName = 'Dr. Sarah Ahmed';
      data.profile.specialization = 'Cardiologist';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorProfileScreen(
            data: data,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Doctor details
      expect(find.text('Dr. Sarah Ahmed'), findsOneWidget);
      expect(find.text('Cardiologist'), findsOneWidget);

      // Verify NO fabricated rating
      expect(find.text('4.8'), findsNothing);
      expect(find.text('(New)'), findsNothing);
      expect(find.textContaining('Verified Doctor'), findsNothing);

      // Verify NO License & Verification row / PMDC badge
      expect(find.text('License & Verification'), findsNothing);
      expect(find.textContaining('PMC / PMDC'), findsNothing);

      // Verify NO Switch to Patient View
      expect(find.text('Switch to Patient View'), findsNothing);
      expect(find.text('Patient View'), findsNothing);

      // Verify Log Out button is present
      final logOutBtn = find.text('Log Out');
      expect(logOutBtn, findsOneWidget);

      // Scroll to Log Out button and tap it to open confirmation dialog
      await tester.ensureVisible(logOutBtn);
      await tester.tap(logOutBtn);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Are you sure you want to log out of SehatPass?'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Log Out'), findsOneWidget);
    });

    testWidgets('PreviewClinicStep has no fabricated rating badge',
        (WidgetTester tester) async {
      final data = DoctorOnboardingData();
      data.profile.fullName = 'Dr. Sarah Ahmed';
      data.profile.specialization = 'Cardiology';
      data.profile.qualifications = 'MBBS, FCPS';
      data.profile.experienceYears = '8 Years Experience';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PreviewClinicStep(
              data: data,
              onPublish: () {},
              onEdit: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify doctor info is rendered
      expect(find.text('Dr. Sarah Ahmed'), findsOneWidget);
      expect(find.text('MBBS, FCPS • 8 Years Experience'), findsOneWidget);

      // Verify NO 4.8 or (New)
      expect(find.text('4.8'), findsNothing);
      expect(find.text('(New)'), findsNothing);
    });

    testWidgets('Doctor Clinic screen renders Availability and allows editing with validation',
        (WidgetTester tester) async {
      final data = DoctorOnboardingData();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorClinicScreen(
            data: data,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Consultation Availability section
      expect(find.text('Consultation Availability'), findsOneWidget);
      expect(find.text('Working Days'), findsOneWidget);
      expect(find.text('Consultation Hours'), findsOneWidget);

      // Verify Edit button exists
      final editBtn = find.widgetWithText(TextButton, 'Edit');
      expect(editBtn, findsOneWidget);

      // Open Edit Availability Sheet
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Availability'), findsOneWidget);
      expect(find.text('Save Availability'), findsOneWidget);

      // Toggle off all selected days to test validation
      for (final day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']) {
        final chip = find.widgetWithText(FilterChip, day);
        if (chip.evaluate().isNotEmpty) {
          await tester.tap(chip.first);
          await tester.pumpAndSettle();
        }
      }

      // Tap Save with 0 days selected
      final saveBtn = find.text('Save Availability');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify SnackBar validation
      expect(find.text('Please select at least one working day.'), findsOneWidget);
    });

    testWidgets('SetAvailabilityStep validates time order (end time must be after start time)',
        (WidgetTester tester) async {
      final initialAv = DoctorAvailabilityModel(
        selectedDays: ['Monday'],
        startTime: const TimeOfDay(hour: 17, minute: 0),
        endTime: const TimeOfDay(hour: 9, minute: 0), // End before start
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SetAvailabilityStep(
              initialData: initialAv,
              onNext: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Continue
      final continueBtn = find.text('Continue');
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Verify validation error
      expect(find.text('End time must be after start time.'), findsOneWidget);
    });
  });
}
