import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/features/doctor/models/doctor_profile_model.dart';
import 'package:sehatpass/features/doctor/models/clinic_model.dart';
import 'package:sehatpass/features/doctor/models/clinic_service_model.dart';
import 'package:sehatpass/features/doctor/models/doctor_availability_model.dart';
import 'package:sehatpass/features/doctor/models/doctor_onboarding_data.dart';
import 'package:sehatpass/features/doctor/onboarding/doctor_onboarding_screen.dart';
import 'package:sehatpass/features/doctor/onboarding/steps/doctor_profile_step.dart';
import 'package:sehatpass/features/doctor/onboarding/steps/list_clinic_step.dart';
import 'package:sehatpass/features/doctor/onboarding/steps/add_services_step.dart';
import 'package:sehatpass/features/doctor/onboarding/steps/set_availability_step.dart';
import 'package:sehatpass/features/doctor/onboarding/steps/preview_clinic_step.dart';

void main() {
  group('Doctor Models & Serialization Unit Tests', () {
    test('DoctorProfileModel serializes toMap and parses fromMap correctly', () {
      final model = DoctorProfileModel(
        doctorId: 'doc-uuid-123',
        fullName: 'Dr. Sarah Tariq',
        specialization: 'Neurologist',
        qualifications: 'MBBS, FCPS Neurology',
        experienceYears: '10 years',
        bio: 'Specialist in neurological disorders.',
        isPublished: true,
        rating: 4.9,
        totalReviews: 24,
      );

      final map = model.toMap();
      expect(map['doctor_id'], 'doc-uuid-123');
      expect(map['full_name'], 'Dr. Sarah Tariq');
      expect(map['specialization'], 'Neurologist');
      expect(map['qualifications'], 'MBBS, FCPS Neurology');
      expect(map['experience_years'], '10 years');
      expect(map['bio'], 'Specialist in neurological disorders.');
      expect(map['is_published'], true);
      expect(map['rating'], 4.9);
      expect(map['total_reviews'], 24);

      final fromDb = DoctorProfileModel.fromMap(
        {
          'doctor_id': 'doc-uuid-123',
          'specialization': 'Neurologist',
          'qualifications': 'MBBS, FCPS Neurology',
          'experience_years': '10 years',
          'bio': 'Specialist in neurological disorders.',
          'is_published': true,
          'rating': 4.9,
          'total_reviews': 24,
        },
        fullName: 'Dr. Sarah Tariq',
        profilePhotoUrl: 'https://example.com/photo.jpg',
      );

      expect(fromDb.doctorId, 'doc-uuid-123');
      expect(fromDb.fullName, 'Dr. Sarah Tariq');
      expect(fromDb.photoUrl, 'https://example.com/photo.jpg');
      expect(fromDb.isPublished, true);
    });

    test('ClinicModel serializes toMap and parses fromMap correctly', () {
      final clinic = ClinicModel(
        id: 'clinic-uuid-456',
        doctorId: 'doc-uuid-123',
        name: 'Brain & Spine Clinic',
        address: '12 Gulberg III',
        city: 'Lahore',
        phone: '+92 42 35780000',
        description: 'Comprehensive neurological clinic.',
        isActive: true,
      );

      final map = clinic.toMap();
      expect(map['id'], 'clinic-uuid-456');
      expect(map['doctor_id'], 'doc-uuid-123');
      expect(map['name'], 'Brain & Spine Clinic');
      expect(map['city'], 'Lahore');
      expect(map['is_active'], true);

      final fromDb = ClinicModel.fromMap(map);
      expect(fromDb.id, 'clinic-uuid-456');
      expect(fromDb.doctorId, 'doc-uuid-123');
      expect(fromDb.name, 'Brain & Spine Clinic');
      expect(fromDb.address, '12 Gulberg III');
    });

    test('ClinicServiceModel parses fromMap, computes formattedFee, and generates toInsertMap', () {
      final service = ClinicServiceModel(
        id: 'c56a4180-65aa-42ec-a945-5fd21dec0538',
        name: 'Neurology Consultation',
        fee: 3500.0,
      );

      expect(service.formattedFee, 'Rs. 3,500');

      final insertMap = service.toInsertMap(
        clinicId: 'clinic-uuid-456',
        doctorId: 'doc-uuid-123',
      );

      expect(insertMap['id'], 'c56a4180-65aa-42ec-a945-5fd21dec0538');
      expect(insertMap['clinic_id'], 'clinic-uuid-456');
      expect(insertMap['doctor_id'], 'doc-uuid-123');
      expect(insertMap['name'], 'Neurology Consultation');
      expect(insertMap['fee'], 3500.0);
      expect(insertMap['is_active'], true);

      final parsed = ClinicServiceModel.fromMap({
        'id': 'srv-1',
        'clinic_id': 'clinic-uuid-456',
        'doctor_id': 'doc-uuid-123',
        'name': 'Follow-up Consultation',
        'fee': 2000,
        'is_active': true,
      });

      expect(parsed.id, 'srv-1');
      expect(parsed.fee, 2000.0);
      expect(parsed.formattedFee, 'Rs. 2,000');
    });

    test('DoctorAvailabilityModel generates SQL rows and parses from db rows', () {
      final availability = DoctorAvailabilityModel(
        selectedDays: ['Monday', 'Wednesday', 'Friday'],
        startTime: const TimeOfDay(hour: 14, minute: 30),
        endTime: const TimeOfDay(hour: 18, minute: 0),
      );

      expect(availability.formattedDays, 'Monday, Wednesday, Friday');
      expect(availability.formattedHours, '2:30 PM - 6:00 PM');

      final rows = availability.toInsertRows(
        doctorId: 'doc-uuid-123',
        clinicId: 'clinic-uuid-456',
      );

      expect(rows.length, 3);
      expect(rows[0]['doctor_id'], 'doc-uuid-123');
      expect(rows[0]['clinic_id'], 'clinic-uuid-456');
      expect(rows[0]['day_of_week'], 'Monday');
      expect(rows[0]['start_time'], '14:30:00');
      expect(rows[0]['end_time'], '18:00:00');
      expect(rows[0]['is_available'], true);

      // Parse back from DB rows
      final parsed = DoctorAvailabilityModel.fromDbRows(rows);
      expect(parsed.selectedDays, ['Monday', 'Wednesday', 'Friday']);
      expect(parsed.startTime.hour, 14);
      expect(parsed.startTime.minute, 30);
      expect(parsed.endTime.hour, 18);
      expect(parsed.endTime.minute, 0);
    });

    test('DoctorOnboardingData manages service items and initializes from persisted state', () {
      final data = DoctorOnboardingData();
      expect(data.services.isEmpty, true);

      data.addService('MRI Review', 4000);
      expect(data.services.length, 1);

      final addedId = data.services.last.id;
      data.updateService(addedId, 'MRI Detailed Review', 4500);
      expect(data.services.last.name, 'MRI Detailed Review');
      expect(data.services.last.fee, 4500);

      data.removeService(addedId);
      expect(data.services.length, 0);

      final persistedData = DoctorOnboardingData.fromPersistedState(
        profile: DoctorProfileModel(
          doctorId: 'doc-1',
          fullName: 'Dr. Test',
          isPublished: true,
        ),
        clinic: ClinicModel(name: 'Test Clinic'),
      );

      expect(persistedData.isPublished, true);
      expect(persistedData.profile.fullName, 'Dr. Test');
      expect(persistedData.clinic.name, 'Test Clinic');
    });
  });

  group('Doctor Onboarding Widget & Steps Tests', () {
    Widget createOnboardingApp() {
      return MaterialApp(
        theme: AppTheme.light,
        home: const DoctorOnboardingScreen(),
      );
    }

    testWidgets('DoctorOnboardingScreen renders Step 1 (Profile) by default and navigates steps',
        (WidgetTester tester) async {
      await tester.pumpWidget(createOnboardingApp());
      await tester.pumpAndSettle();

      // Step 1: Doctor Profile Step
      expect(find.byType(DoctorProfileStep), findsOneWidget);
      expect(find.text('Set Up Your Doctor Profile'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Specialization'), findsOneWidget);

      // Fill Step 1 and tap Continue
      final textFields1 = find.byType(TextFormField);
      await tester.enterText(textFields1.at(0), 'Dr. Sarah Ahmed');
      await tester.enterText(textFields1.at(1), 'Cardiologist');
      await tester.enterText(textFields1.at(2), 'MBBS, FCPS');
      await tester.enterText(textFields1.at(3), '6 years');
      await tester.enterText(textFields1.at(4), 'Cardiologist consultant.');
      final continueBtn1 = find.widgetWithText(ElevatedButton, 'Continue');
      expect(continueBtn1, findsOneWidget);
      await tester.ensureVisible(continueBtn1);
      await tester.tap(continueBtn1);
      await tester.pumpAndSettle();

      // Step 2: List Clinic Step
      expect(find.byType(ListClinicStep), findsOneWidget);
      expect(find.text('List Your Clinic'), findsOneWidget);
      expect(find.text('Clinic Name'), findsOneWidget);

      // Fill Step 2 and tap Continue
      final textFields2 = find.byType(TextFormField);
      await tester.enterText(textFields2.at(0), 'Al-Razi Healthcare');
      await tester.enterText(textFields2.at(1), 'Main Blvd');
      await tester.enterText(textFields2.at(2), 'Lahore');
      await tester.enterText(textFields2.at(3), '+92 42 35789000');
      await tester.enterText(textFields2.at(4), 'Primary care clinic.');
      final continueBtn2 = find.widgetWithText(ElevatedButton, 'Continue');
      await tester.ensureVisible(continueBtn2);
      await tester.tap(continueBtn2);
      await tester.pumpAndSettle();

      // Step 3: Add Services Step
      expect(find.byType(AddServicesStep), findsOneWidget);
      expect(find.text('Clinic Services'), findsOneWidget);

      // Add service and tap Continue
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add Service'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'General Consultation');
      await tester.enterText(find.byType(TextFormField).at(1), '2000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Service'));
      await tester.pumpAndSettle();
      final continueBtn3 = find.widgetWithText(ElevatedButton, 'Continue');
      await tester.ensureVisible(continueBtn3);
      await tester.tap(continueBtn3);
      await tester.pumpAndSettle();

      // Step 4: Set Availability Step
      expect(find.byType(SetAvailabilityStep), findsOneWidget);
      expect(find.text('Set Your Availability'), findsOneWidget);

      // Select day and tap Continue
      await tester.tap(find.text('Monday'));
      await tester.pumpAndSettle();
      final continueBtn4 = find.widgetWithText(ElevatedButton, 'Continue');
      await tester.ensureVisible(continueBtn4);
      await tester.tap(continueBtn4);
      await tester.pumpAndSettle();

      // Step 5: Preview Clinic Step
      expect(find.byType(PreviewClinicStep), findsOneWidget);
      expect(find.text('Preview Your Clinic'), findsOneWidget);
      expect(find.text('Publish Clinic'), findsOneWidget);
    });

    testWidgets('Clicking Exit opens confirmation dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(createOnboardingApp());
      await tester.pumpAndSettle();

      final exitIcon = find.byIcon(Icons.close_rounded);
      expect(exitIcon, findsOneWidget);
      await tester.tap(exitIcon);
      await tester.pumpAndSettle();

      expect(find.text('Exit Setup?'), findsOneWidget);
      expect(find.text('Continue Setup'), findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);

      await tester.tap(find.text('Continue Setup'));
      await tester.pumpAndSettle();
      expect(find.text('Exit Setup?'), findsNothing);
    });
  });
}
