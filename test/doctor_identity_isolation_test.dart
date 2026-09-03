import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/features/doctor/dashboard/doctor_dashboard_screen.dart';
import 'package:sehatpass/features/doctor/profile/doctor_profile_screen.dart';
import 'package:sehatpass/features/doctor/clinic/doctor_clinic_screen.dart';
import 'package:sehatpass/features/doctor/models/doctor_profile_model.dart';
import 'package:sehatpass/features/doctor/models/clinic_model.dart';
import 'package:sehatpass/features/doctor/models/clinic_service_model.dart';
import 'package:sehatpass/features/doctor/models/doctor_availability_model.dart';
import 'package:sehatpass/features/doctor/models/doctor_onboarding_data.dart';
import 'package:sehatpass/features/doctor/doctor_shell_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5A.2: Doctor Identity Isolation & Real Data Tests', () {
    // Fixture for Doctor A (Dr. Arsalan)
    final doctorAData = DoctorOnboardingData(
      profile: DoctorProfileModel(
        doctorId: 'doctor-arsalan-id',
        fullName: 'Arsalan',
        specialization: 'Neurologist',
        qualifications: 'MBBS, MD',
        experienceYears: '6 years',
        bio: 'Consultant neurologist specializing in neuro-care.',
        isPublished: true,
      ),
      clinic: ClinicModel(
        id: 'clinic-arsalan-id',
        doctorId: 'doctor-arsalan-id',
        name: 'Arsalan Neuro Care',
        address: 'DHA Phase 5',
        city: 'Lahore',
        phone: '+92 300 1234567',
        description: 'Comprehensive neurological consultation.',
      ),
      services: [
        ClinicServiceModel(id: 's1', name: 'Neuro Consultation', fee: 3000),
      ],
      availability: DoctorAvailabilityModel(
        selectedDays: ['Monday', 'Wednesday'],
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 14, minute: 0),
      ),
      isPublished: true,
    );

    // Fixture for Doctor B (Dr. Ahmed Khan)
    final doctorBData = DoctorOnboardingData(
      profile: DoctorProfileModel(
        doctorId: 'doctor-ahmed-id',
        fullName: 'Dr. Ahmed Khan',
        specialization: 'Cardiologist',
        qualifications: 'MBBS, FCPS (Cardiology)',
        experienceYears: '12 years',
        bio: 'Cardiologist providing advanced cardiac diagnostics.',
        isPublished: true,
      ),
      clinic: ClinicModel(
        id: 'clinic-ahmed-id',
        doctorId: 'doctor-ahmed-id',
        name: 'Heart & Rhythm Center',
        address: 'Jail Road',
        city: 'Lahore',
        phone: '+92 42 35789000',
        description: 'Advanced cardiac care and ECG center.',
      ),
      services: [
        ClinicServiceModel(id: 's2', name: 'Cardiac Assessment', fee: 4000),
      ],
      availability: DoctorAvailabilityModel(
        selectedDays: ['Tuesday', 'Thursday'],
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 16, minute: 0),
      ),
      isPublished: true,
    );

    // Fixture for Doctor with Empty / Unset profile fields
    final doctorEmptyData = DoctorOnboardingData(
      profile: DoctorProfileModel(
        doctorId: 'doctor-empty-id',
        fullName: 'Arsalan',
        specialization: '',
        qualifications: '',
        experienceYears: '',
        bio: '',
        isPublished: false,
      ),
      clinic: ClinicModel(
        id: 'clinic-empty-id',
        doctorId: 'doctor-empty-id',
        name: '',
        address: '',
        city: '',
        phone: '',
        description: '',
      ),
      services: [],
      availability: DoctorAvailabilityModel(
        selectedDays: [],
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 17, minute: 0),
      ),
      isPublished: false,
    );

    testWidgets('1. Doctor A ("Arsalan") Dashboard displays "Dr. Arsalan" and never renders Doctor B data',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DoctorDashboardScreen(
            data: doctorAData,
            appointments: const [],
            patients: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified: Doctor A name rendered with Dr. prefix
      expect(find.textContaining('Dr. Arsalan'), findsOneWidget);
      // Verified: Doctor B name and details are NOT rendered
      expect(find.textContaining('Ahmed Khan'), findsNothing);
      expect(find.textContaining('Cardiologist'), findsNothing);
      expect(find.textContaining('Heart & Rhythm'), findsNothing);
    });

    testWidgets('2. Doctor B ("Ahmed Khan") Dashboard displays "Dr. Ahmed Khan" and never renders Doctor A data',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DoctorDashboardScreen(
            data: doctorBData,
            appointments: const [],
            patients: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified: Doctor B name rendered without double "Dr. Dr."
      expect(find.textContaining('Dr. Ahmed Khan'), findsOneWidget);
      expect(find.textContaining('Dr. Dr. Ahmed Khan'), findsNothing);
      // Verified: Doctor A name and details are NOT rendered
      expect(find.textContaining('Arsalan'), findsNothing);
      expect(find.textContaining('Neurologist'), findsNothing);
    });

    testWidgets('3. Doctor A Profile screen renders Doctor A credentials and bio with zero fallback to Doctor B',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DoctorProfileScreen(data: doctorAData),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dr. Arsalan'), findsOneWidget);
      expect(find.text('Neurologist'), findsOneWidget);
      expect(find.text('MBBS, MD • 6 years Experience'), findsOneWidget);
      expect(find.text('Consultant neurologist specializing in neuro-care.'), findsOneWidget);

      // Verify no Ahmed Khan or Cardiologist fallback
      expect(find.textContaining('Ahmed Khan'), findsNothing);
      expect(find.textContaining('Cardiologist'), findsNothing);
      expect(find.textContaining('8 years'), findsNothing);
      expect(find.textContaining('FCPS'), findsNothing);
    });

    testWidgets('4. Empty Doctor Profile renders honest missing data without fabricated placeholders',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DoctorProfileScreen(data: doctorEmptyData),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dr. Arsalan'), findsOneWidget);
      // Honest representation for missing specialization
      expect(find.text('Specialization not provided'), findsOneWidget);
      // Honest representation for missing qualifications
      expect(find.text('Qualifications not provided'), findsOneWidget);
      // Honest representation for missing bio
      expect(find.text('No biography provided yet.'), findsOneWidget);

      // Verify NO fabricated defaults
      expect(find.text('General Physician'), findsNothing);
      expect(find.text('Cardiologist'), findsNothing);
      expect(find.text('MBBS'), findsNothing);
      expect(find.text('8 years'), findsNothing);
      expect(find.text('1 year'), findsNothing);
      expect(find.textContaining('Ahmed Khan'), findsNothing);
    });

    testWidgets('5. Empty Clinic screen renders honest empty states without defaulting to City Heart Clinic',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DoctorClinicScreen(data: doctorEmptyData),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clinic not registered yet'), findsOneWidget);
      expect(find.text('Location not provided'), findsOneWidget);
      expect(find.text('No clinic description provided yet.'), findsOneWidget);
      expect(find.text('Phone not provided'), findsOneWidget);

      // Verify NO hardcoded City Heart Clinic
      expect(find.textContaining('City Heart Clinic'), findsNothing);
      expect(find.textContaining('Main Boulevard, Lahore'), findsNothing);
    });

    testWidgets('6. Doctor Profile Model default constructor produces clean empty values',
        (tester) async {
      final defaultModel = DoctorProfileModel();

      expect(defaultModel.fullName, isEmpty);
      expect(defaultModel.specialization, isEmpty);
      expect(defaultModel.qualifications, isEmpty);
      expect(defaultModel.experienceYears, isEmpty);
      expect(defaultModel.bio, isEmpty);
      expect(defaultModel.isPublished, isFalse);
    });

    testWidgets('7. Clinic Model default constructor produces clean empty values',
        (tester) async {
      final defaultClinic = ClinicModel();

      expect(defaultClinic.name, isEmpty);
      expect(defaultClinic.address, isEmpty);
      expect(defaultClinic.phone, isEmpty);
      expect(defaultClinic.description, isEmpty);
    });

    testWidgets('8. Doctor Shell initialized with Doctor A renders Doctor A profile and navigation',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DoctorShellScreen(
            data: doctorAData,
            initialAppointments: const [],
            initialPatients: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Dashboard shows Dr. Arsalan
      expect(find.textContaining('Dr. Arsalan'), findsOneWidget);

      // Switch to Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Dr. Arsalan'), findsOneWidget);
      expect(find.text('Neurologist'), findsOneWidget);
      expect(find.textContaining('Ahmed Khan'), findsNothing);
    });

    testWidgets('9. Doctor Shell without initial data initializes safely without LateInitializationError',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DoctorShellScreen(
            initialAppointments: [],
            initialPatients: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DoctorShellScreen), findsOneWidget);
      expect(find.byType(DoctorDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('10. Doctor Shell rebuild and widget.data update safely replaces _data without LateInitializationError',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DoctorShellScreen(
            data: doctorAData,
            initialAppointments: const [],
            initialPatients: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Dr. Arsalan'), findsOneWidget);

      // Rebuild with updated Doctor B data (testing didUpdateWidget)
      await tester.pumpWidget(
        MaterialApp(
          home: DoctorShellScreen(
            data: doctorBData,
            initialAppointments: const [],
            initialPatients: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Dr. Ahmed Khan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
