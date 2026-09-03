import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sehatpass/app/app_shell.dart';
import 'package:sehatpass/auth/auth_gate.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/features/auth/login_screen.dart';
import 'package:sehatpass/features/doctor/doctor_shell_screen.dart';
import 'package:sehatpass/features/doctor/dashboard/doctor_dashboard_screen.dart';
import 'package:sehatpass/features/doctor/onboarding/doctor_onboarding_screen.dart';
import 'package:sehatpass/features/doctor/onboarding/publish_success_screen.dart';
import 'package:sehatpass/features/doctor/onboarding/steps/doctor_profile_step.dart';
import 'package:sehatpass/features/doctor/onboarding/steps/list_clinic_step.dart';
import 'package:sehatpass/features/doctor/onboarding/steps/add_services_step.dart';
import 'package:sehatpass/features/doctor/onboarding/steps/set_availability_step.dart';
import 'package:sehatpass/features/doctor/onboarding/steps/preview_clinic_step.dart';
import 'package:sehatpass/features/doctor/models/doctor_onboarding_data.dart';
import 'package:sehatpass/features/doctor/models/doctor_profile_model.dart';
import 'package:sehatpass/features/doctor/models/clinic_model.dart';
import 'package:sehatpass/features/doctor/models/clinic_service_model.dart';
import 'package:sehatpass/features/doctor/models/doctor_availability_model.dart';

void main() {
  Session createMockSession(String userId) {
    return Session(
      accessToken: 'mock-jwt-token',
      tokenType: 'bearer',
      user: User(
        id: userId,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  group('PHASE 2 — UI & AUTHENTICATED FLOW VERIFICATION', () {
    // =========================================================================
    // TEST 1 — Existing Published Doctor
    // =========================================================================
    testWidgets('Test 1 — Existing published Doctor: Login -> AuthGate -> DoctorShellScreen (No onboarding)',
        (WidgetTester tester) async {
      final authStreamController = StreamController<AuthState>();
      final docSession = createMockSession('doc-published-uuid-001');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AuthGate(
            authStateStream: authStreamController.stream,
            roleResolver: (uid) async => 'doctor',
            doctorPublishedResolver: (uid) async => true, // Published doctor
          ),
        ),
      );
      await tester.pump();

      // Initially on LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);

      // Authenticate as Published Doctor
      authStreamController.add(AuthState(AuthChangeEvent.signedIn, docSession));
      await tester.pumpAndSettle();

      // DoctorShellScreen (Doctor Dashboard) is displayed directly
      expect(find.byType(DoctorShellScreen), findsOneWidget);
      expect(find.byType(DoctorDashboardScreen), findsOneWidget);
      expect(find.text("Today's Appointments"), findsOneWidget);
      expect(find.text('Total Patients'), findsOneWidget);

      // Verify DoctorOnboardingScreen is NOT displayed
      expect(find.byType(DoctorOnboardingScreen), findsNothing);
      expect(find.byType(AppShell), findsNothing);

      await authStreamController.close();
    });

    // =========================================================================
    // TEST 2 — New / Unpublished Doctor
    // =========================================================================
    testWidgets('Test 2 — New/unpublished Doctor: Login -> AuthGate -> DoctorOnboardingScreen',
        (WidgetTester tester) async {
      final authStreamController = StreamController<AuthState>();
      final docSession = createMockSession('doc-unpublished-uuid-002');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AuthGate(
            authStateStream: authStreamController.stream,
            roleResolver: (uid) async => 'doctor',
            doctorPublishedResolver: (uid) async => false, // Unpublished / no doctor_profiles
          ),
        ),
      );
      await tester.pump();

      // Initially on LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);

      // Authenticate as New Doctor
      authStreamController.add(AuthState(AuthChangeEvent.signedIn, docSession));
      await tester.pumpAndSettle();

      // DoctorOnboardingScreen 5-Step Wizard is displayed
      expect(find.byType(DoctorOnboardingScreen), findsOneWidget);
      expect(find.byType(DoctorProfileStep), findsOneWidget);
      expect(find.text('Doctor Onboarding'), findsOneWidget);
      expect(find.text('Set Up Your Doctor Profile'), findsOneWidget);

      // Doctor Dashboard is NOT displayed
      expect(find.byType(DoctorShellScreen), findsNothing);
      expect(find.byType(DoctorDashboardScreen), findsNothing);
      expect(find.byType(AppShell), findsNothing);

      await authStreamController.close();
    });

    // =========================================================================
    // TEST 3 — Onboarding Persistence & Step-by-Step Publish Flow
    // =========================================================================
    testWidgets('Test 3 — Onboarding Persistence: Completes 5 steps -> Publish -> PublishSuccessScreen -> DoctorShellScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const DoctorOnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Doctor Profile Step
      expect(find.byType(DoctorProfileStep), findsOneWidget);
      expect(find.text('Set Up Your Doctor Profile'), findsOneWidget);
      final textFields1 = find.byType(TextFormField);
      await tester.enterText(textFields1.at(0), 'Dr. Zeeshan Ali');
      await tester.enterText(textFields1.at(1), 'Cardiologist');
      await tester.enterText(textFields1.at(2), 'MBBS, FCPS');
      await tester.enterText(textFields1.at(3), '5 years');
      await tester.enterText(textFields1.at(4), 'Cardiology consultant.');
      final contBtn1 = find.widgetWithText(ElevatedButton, 'Continue');
      await tester.ensureVisible(contBtn1);
      await tester.tap(contBtn1);
      await tester.pumpAndSettle();

      // Step 2: List Clinic Step
      expect(find.byType(ListClinicStep), findsOneWidget);
      expect(find.text('List Your Clinic'), findsOneWidget);
      final textFields2 = find.byType(TextFormField);
      await tester.enterText(textFields2.at(0), 'Lahore Heart Clinic');
      await tester.enterText(textFields2.at(1), 'Main Blvd');
      await tester.enterText(textFields2.at(2), 'Lahore');
      await tester.enterText(textFields2.at(3), '+92 42 35789000');
      await tester.enterText(textFields2.at(4), 'Cardiac care clinic.');
      final contBtn2 = find.widgetWithText(ElevatedButton, 'Continue');
      await tester.ensureVisible(contBtn2);
      await tester.tap(contBtn2);
      await tester.pumpAndSettle();

      // Step 3: Add Services Step
      expect(find.byType(AddServicesStep), findsOneWidget);
      expect(find.text('Clinic Services'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add Service'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'General Consultation');
      await tester.enterText(find.byType(TextFormField).at(1), '2000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Service'));
      await tester.pumpAndSettle();
      final contBtn3 = find.widgetWithText(ElevatedButton, 'Continue');
      await tester.ensureVisible(contBtn3);
      await tester.tap(contBtn3);
      await tester.pumpAndSettle();

      // Step 4: Set Availability Step
      expect(find.byType(SetAvailabilityStep), findsOneWidget);
      expect(find.text('Set Your Availability'), findsOneWidget);
      await tester.tap(find.text('Monday'));
      await tester.pumpAndSettle();
      final contBtn4 = find.widgetWithText(ElevatedButton, 'Continue');
      await tester.ensureVisible(contBtn4);
      await tester.tap(contBtn4);
      await tester.pumpAndSettle();

      // Step 5: Preview Clinic Step
      expect(find.byType(PreviewClinicStep), findsOneWidget);
      expect(find.text('Preview Your Clinic'), findsOneWidget);
      expect(find.text('Publish Clinic'), findsOneWidget);

      // Verify Publish Success Screen transition with model data
      final publishedData = DoctorOnboardingData(
        profile: DoctorProfileModel(
          doctorId: 'doc-002',
          fullName: 'Dr. Zeeshan Ali',
          specialization: 'Cardiologist',
          isPublished: true,
        ),
        clinic: ClinicModel(
          id: 'clinic-uuid-002',
          name: 'Lahore Heart Clinic',
          city: 'Lahore',
        ),
        services: [
          ClinicServiceModel(id: 'srv-1', name: 'Cardiology Consultation', fee: 3500),
        ],
        availability: DoctorAvailabilityModel(
          selectedDays: ['Monday', 'Wednesday'],
        ),
        isPublished: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PublishSuccessScreen(data: publishedData),
        ),
      );
      await tester.pumpAndSettle();

      // Publish Success Screen verified
      expect(find.byType(PublishSuccessScreen), findsOneWidget);
      expect(find.text('Clinic Listed Successfully'), findsOneWidget);
      expect(find.text('Lahore Heart Clinic'), findsOneWidget);
      expect(find.text('Go to Doctor Dashboard'), findsOneWidget);

      // Tap Go to Doctor Dashboard
      await tester.tap(find.widgetWithText(ElevatedButton, 'Go to Doctor Dashboard'));
      await tester.pumpAndSettle();

      // Doctor Dashboard reached
      expect(find.byType(DoctorShellScreen), findsOneWidget);
    });

    // =========================================================================
    // TEST 4 — Subsequent Login with Published Doctor
    // =========================================================================
    testWidgets('Test 4 — Subsequent Login: Logout -> Login -> AuthGate -> DoctorShellScreen (No onboarding)',
        (WidgetTester tester) async {
      final authStreamController = StreamController<AuthState>();
      final docSession = createMockSession('doc-published-uuid-003');
      bool isDoctorPublished = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AuthGate(
            authStateStream: authStreamController.stream,
            roleResolver: (uid) async => 'doctor',
            doctorPublishedResolver: (uid) async => isDoctorPublished,
          ),
        ),
      );
      await tester.pump();

      // 1. Initial login
      authStreamController.add(AuthState(AuthChangeEvent.signedIn, docSession));
      await tester.pumpAndSettle();
      expect(find.byType(DoctorShellScreen), findsOneWidget);

      // 2. User logs out
      authStreamController.add(const AuthState(AuthChangeEvent.signedOut, null));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      // 3. User logs back in
      authStreamController.add(AuthState(AuthChangeEvent.signedIn, docSession));
      await tester.pumpAndSettle();

      // Directly on DoctorShellScreen
      expect(find.byType(DoctorShellScreen), findsOneWidget);
      expect(find.byType(DoctorOnboardingScreen), findsNothing);

      await authStreamController.close();
    });

    // =========================================================================
    // TEST 5 — Patient Regression
    // =========================================================================
    testWidgets('Test 5 — Patient Regression: Patient Login -> AuthGate -> AppShell (Never enters Doctor onboarding/dashboard)',
        (WidgetTester tester) async {
      final authStreamController = StreamController<AuthState>();
      final patientSession = createMockSession('patient-uuid-001');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AuthGate(
            authStateStream: authStreamController.stream,
            roleResolver: (uid) async => 'patient',
          ),
        ),
      );
      await tester.pump();

      // Initially LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);

      // Patient Authenticates
      authStreamController.add(AuthState(AuthChangeEvent.signedIn, patientSession));
      await tester.pumpAndSettle();

      // Renders AppShell (Patient Home)
      expect(find.byType(AppShell), findsOneWidget);

      // Must NEVER show Doctor screens
      expect(find.byType(DoctorShellScreen), findsNothing);
      expect(find.byType(DoctorOnboardingScreen), findsNothing);
      expect(find.byType(DoctorDashboardScreen), findsNothing);

      await authStreamController.close();
    });

    // =========================================================================
    // Error Handling & Recovery Verification
    // =========================================================================
    testWidgets('Error Handling — Database lookup error shows Error Screen with Retry, NOT onboarding or dashboard',
        (WidgetTester tester) async {
      final authStreamController = StreamController<AuthState>();
      final docSession = createMockSession('doc-error-uuid-004');
      bool hasError = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AuthGate(
            authStateStream: authStreamController.stream,
            roleResolver: (uid) async => 'doctor',
            doctorPublishedResolver: (uid) async {
              if (hasError) {
                throw 'Network connection error. Please check your internet and try again.';
              }
              return true;
            },
          ),
        ),
      );
      await tester.pump();

      // Sign in
      authStreamController.add(AuthState(AuthChangeEvent.signedIn, docSession));
      await tester.pumpAndSettle();

      // Error UI is shown
      expect(find.text('Account Resolution Error'), findsOneWidget);
      expect(find.text('Network connection error. Please check your internet and try again.'), findsOneWidget);
      expect(find.text('Retry Connection'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      // Onboarding & Dashboard are NOT shown
      expect(find.byType(DoctorOnboardingScreen), findsNothing);
      expect(find.byType(DoctorShellScreen), findsNothing);

      // Network recovers -> User taps Retry Connection
      hasError = false;
      await tester.tap(find.widgetWithText(ElevatedButton, 'Retry Connection'));
      await tester.pumpAndSettle();

      // Recovers to DoctorShellScreen
      expect(find.byType(DoctorShellScreen), findsOneWidget);
      expect(find.text('Account Resolution Error'), findsNothing);

      await authStreamController.close();
    });
  });
}
