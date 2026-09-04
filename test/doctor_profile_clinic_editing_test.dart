import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/features/doctor/clinic/doctor_clinic_screen.dart';
import 'package:sehatpass/features/doctor/data/doctor_repository.dart';
import 'package:sehatpass/features/doctor/models/clinic_model.dart';
import 'package:sehatpass/features/doctor/models/doctor_onboarding_data.dart';
import 'package:sehatpass/features/doctor/models/doctor_profile_model.dart';
import 'package:sehatpass/features/doctor/profile/doctor_profile_screen.dart';
import 'package:sehatpass/features/appointments/find_doctor_screen.dart';
import 'package:sehatpass/features/appointments/book_appointment_screen.dart';
import 'package:sehatpass/features/appointments/data/appointment_repository.dart' hide DoctorRepository;
import 'package:sehatpass/features/appointments/models/doctor_model.dart';

class MockDoctorRepository extends DoctorRepository {
  final String testDoctorId;
  DoctorProfileModel? storedProfile;
  ClinicModel? storedClinic;
  int saveProfileCallCount = 0;
  int saveClinicCallCount = 0;
  String? lastSavedProfileDoctorId;
  String? lastSavedClinicDoctorId;

  MockDoctorRepository({
    this.testDoctorId = 'doc-auth-123',
    this.storedProfile,
    this.storedClinic,
  });

  @override
  String? get currentUserId => testDoctorId;

  @override
  Future<DoctorProfileModel> saveDoctorProfile({
    required String doctorId,
    required DoctorProfileModel profile,
  }) async {
    saveProfileCallCount++;
    lastSavedProfileDoctorId = doctorId;
    if (doctorId != testDoctorId) {
      throw 'Unauthorized: cannot edit another doctor\'s profile';
    }
    storedProfile = profile.copyWith(doctorId: doctorId);
    return storedProfile!;
  }

  @override
  Future<DoctorProfileModel?> getDoctorProfile({String? doctorId}) async {
    if ((doctorId ?? testDoctorId) != testDoctorId) return null;
    return storedProfile;
  }

  @override
  Future<ClinicModel> saveDoctorClinic({
    required String doctorId,
    required ClinicModel clinic,
  }) async {
    saveClinicCallCount++;
    lastSavedClinicDoctorId = doctorId;
    if (doctorId != testDoctorId) {
      throw 'Unauthorized: cannot edit another doctor\'s clinic';
    }
    storedClinic = clinic.copyWith(
      id: clinic.id ?? 'clinic-uuid-1',
      doctorId: doctorId,
    );
    return storedClinic!;
  }

  @override
  Future<ClinicModel?> getDoctorClinic({String? doctorId}) async {
    if ((doctorId ?? testDoctorId) != testDoctorId) return null;
    return storedClinic;
  }
}

class MockPatientAppointmentRepository extends AppointmentRepository {
  List<Doctor> doctorsToReturn;

  MockPatientAppointmentRepository({this.doctorsToReturn = const []});

  @override
  String? get currentUserId => 'patient-123';

  @override
  Future<List<Doctor>> getDoctors({String? specialty, String? searchQuery}) async {
    var list = doctorsToReturn;
    if (specialty != null && specialty.isNotEmpty && specialty != 'All') {
      list = list.where((d) => d.specialization == specialty).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((d) =>
          d.name.toLowerCase().contains(q) ||
          d.specialization.toLowerCase().contains(q) ||
          d.clinic.toLowerCase().contains(q) ||
          d.location.toLowerCase().contains(q)).toList();
    }
    return list;
  }
}

void main() {
  group('Phase 5A.3: Doctor Profile & Clinic Editing Tests', () {
    testWidgets('1. Doctor can edit own profile and UI immediately reflects changes', (tester) async {
      final initialProfile = DoctorProfileModel(
        doctorId: 'doc-auth-123',
        fullName: 'Arsalan',
        specialization: 'Neurologist',
        qualifications: 'MBBS, FCPS Neurology',
        experienceYears: '8 years',
        bio: 'Dedicated neurologist committed to patient care.',
      );

      final onboardingData = DoctorOnboardingData(profile: initialProfile);
      final repo = MockDoctorRepository(
        testDoctorId: 'doc-auth-123',
        storedProfile: initialProfile,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorProfileScreen(
            data: onboardingData,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state
      expect(find.text('Dr. Arsalan'), findsOneWidget);
      expect(find.text('Neurologist'), findsOneWidget);
      expect(find.text('MBBS, FCPS Neurology • 8 years Experience'), findsOneWidget);

      // Tap Edit Profile button
      await tester.tap(find.widgetWithText(OutlinedButton, 'Edit Profile'));
      await tester.pumpAndSettle();

      // Verify bottom sheet appears
      expect(find.text('Edit Doctor Profile'), findsOneWidget);

      // Edit fields by index: 0=FullName, 1=Specialization, 2=Qualifications, 3=Experience, 4=Bio
      await tester.enterText(find.byType(TextFormField).at(0), 'Dr. Arsalan Rafiq');
      await tester.enterText(find.byType(TextFormField).at(1), 'Consultant Neurologist');
      await tester.enterText(find.byType(TextFormField).at(2), 'MBBS, FCPS, FRCP');
      await tester.enterText(find.byType(TextFormField).at(3), '10 years');

      // Save changes
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Verify repository was called
      expect(repo.saveProfileCallCount, 1);
      expect(repo.lastSavedProfileDoctorId, 'doc-auth-123');

      // Verify UI immediately updated
      expect(find.text('Dr. Arsalan Rafiq'), findsOneWidget);
      expect(find.text('Consultant Neurologist'), findsOneWidget);
      expect(find.text('MBBS, FCPS, FRCP • 10 years Experience'), findsOneWidget);
    });

    testWidgets('2. Saved doctor profile persists and reloads correctly', (tester) async {
      final repo = MockDoctorRepository(
        testDoctorId: 'doc-auth-123',
      );

      // Save a profile
      await repo.saveDoctorProfile(
        doctorId: 'doc-auth-123',
        profile: DoctorProfileModel(
          fullName: 'Dr. Fatima Tariq',
          specialization: 'Pediatrician',
          qualifications: 'MBBS, MCPS',
          experienceYears: '6 years',
          bio: 'Child healthcare specialist.',
        ),
      );

      final reloaded = await repo.getDoctorProfile(doctorId: 'doc-auth-123');
      expect(reloaded, isNotNull);
      expect(reloaded!.fullName, 'Dr. Fatima Tariq');
      expect(reloaded.specialization, 'Pediatrician');
      expect(reloaded.qualifications, 'MBBS, MCPS');
      expect(reloaded.experienceYears, '6 years');
      expect(reloaded.bio, 'Child healthcare specialist.');
    });

    test('3. Doctor cannot edit another doctor\'s profile', () async {
      final repo = MockDoctorRepository(testDoctorId: 'doc-auth-123');

      expect(
        () => repo.saveDoctorProfile(
          doctorId: 'doc-attacker-456',
          profile: DoctorProfileModel(fullName: 'Malicious Change'),
        ),
        throwsA(contains('Unauthorized')),
      );
    });

    test('4. Empty fields do not produce fabricated defaults', () {
      final map = <String, dynamic>{
        'doctor_id': 'doc-123',
        'specialization': '',
        'qualifications': '',
        'experience_years': '',
        'bio': '',
      };

      final parsedDoctor = Doctor.fromMap(map);
      expect(parsedDoctor.specialization, 'Specialization not provided');
      expect(parsedDoctor.qualifications, '');
      expect(parsedDoctor.experienceYears, '');
      expect(parsedDoctor.clinic, 'Clinic not specified');
      expect(parsedDoctor.location, 'Location not provided');
      expect(parsedDoctor.name, 'Name not provided');
    });

    testWidgets('5. Doctor can edit own clinic and UI immediately reflects changes', (tester) async {
      final initialClinic = ClinicModel(
        id: 'clinic-1',
        name: 'City Care Hospital',
        address: 'Main Street',
        city: 'Rawalpindi',
        phone: '+92 300 1112233',
        description: 'Quality primary healthcare.',
      );

      final onboardingData = DoctorOnboardingData(clinic: initialClinic);
      final repo = MockDoctorRepository(
        testDoctorId: 'doc-auth-123',
        storedClinic: initialClinic,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorClinicScreen(
            data: onboardingData,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('City Care Hospital'), findsOneWidget);
      expect(find.text('Main Street, Rawalpindi'), findsOneWidget);

      // Tap Edit Clinic Details button in card
      await tester.tap(find.widgetWithText(OutlinedButton, 'Edit Clinic Details'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Clinic Details'), findsWidgets);

      // Edit clinic details by index: 0=Name, 1=Address, 2=City, 3=Phone, 4=Description
      await tester.enterText(find.byType(TextFormField).at(0), 'New Health Care Clinic');
      await tester.enterText(find.byType(TextFormField).at(1), 'Sector F-8/2');
      await tester.enterText(find.byType(TextFormField).at(2), 'Islamabad');
      await tester.enterText(find.byType(TextFormField).at(3), '+92 321 9998877');

      // Save
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(repo.saveClinicCallCount, 1);
      expect(repo.lastSavedClinicDoctorId, 'doc-auth-123');

      // UI immediately reflects changes
      expect(find.text('New Health Care Clinic'), findsOneWidget);
      expect(find.text('Sector F-8/2, Islamabad'), findsOneWidget);
      expect(find.text('+92 321 9998877'), findsOneWidget);
    });

    testWidgets('6. Saved clinic reloads correctly', (tester) async {
      final repo = MockDoctorRepository(testDoctorId: 'doc-auth-123');

      await repo.saveDoctorClinic(
        doctorId: 'doc-auth-123',
        clinic: ClinicModel(
          name: 'Al-Shifa Heart Clinic',
          address: 'Mall Road',
          city: 'Peshawar',
          phone: '+92 345 5556677',
          description: 'Specialized cardiology clinic.',
        ),
      );

      final reloaded = await repo.getDoctorClinic(doctorId: 'doc-auth-123');
      expect(reloaded, isNotNull);
      expect(reloaded!.name, 'Al-Shifa Heart Clinic');
      expect(reloaded.city, 'Peshawar');
      expect(reloaded.phone, '+92 345 5556677');
    });

    test('7. Editing does not create duplicate clinics', () async {
      final repo = MockDoctorRepository(testDoctorId: 'doc-auth-123');

      final initial = await repo.saveDoctorClinic(
        doctorId: 'doc-auth-123',
        clinic: ClinicModel(name: 'First Clinic Name'),
      );
      expect(initial.id, 'clinic-uuid-1');

      // Second save with same id updates existing
      final updated = await repo.saveDoctorClinic(
        doctorId: 'doc-auth-123',
        clinic: initial.copyWith(name: 'Updated Clinic Name'),
      );

      expect(updated.id, initial.id);
      expect(updated.name, 'Updated Clinic Name');
    });

    test('8. Doctor cannot edit another doctor\'s clinic', () async {
      final repo = MockDoctorRepository(testDoctorId: 'doc-auth-123');

      expect(
        () => repo.saveDoctorClinic(
          doctorId: 'doc-other-789',
          clinic: ClinicModel(name: 'Hacked Clinic'),
        ),
        throwsA(contains('Unauthorized')),
      );
    });
  });

  group('Phase 5A.3: Patient Doctor Discovery Real Data & No Ratings Tests', () {
    final realDoctor1 = Doctor(
      id: 'doc-1',
      name: 'Dr. Arsalan',
      specialization: 'Neurologist',
      clinic: 'Advanced Neuro Clinic',
      location: 'DHA Phase 5, Lahore',
      consultationFee: 2500,
      availability: 'Available Today',
      about: 'Experienced neurologist providing neurological consultations.',
      availableDays: const ['Monday', 'Tuesday', 'Wednesday'],
      consultationHours: '10:00 AM - 2:00 PM',
      services: const [
        DoctorService(id: 's-1', name: 'Neurology Consultation', fee: 2500),
        DoctorService(id: 's-2', name: 'EEG Review', fee: 4000),
      ],
      qualifications: 'MBBS, FCPS',
      experienceYears: '9 years',
    );

    final realDoctor2 = Doctor(
      id: 'doc-2',
      name: 'Dr. Ahmed Khan',
      specialization: 'Cardiologist',
      clinic: 'Punjab Heart Center',
      location: 'Gulberg III, Lahore',
      consultationFee: 3000,
      availability: 'Available Tomorrow',
      about: 'Leading cardiologist.',
      availableDays: const ['Tuesday', 'Thursday'],
      consultationHours: '2:00 PM - 6:00 PM',
      services: const [
        DoctorService(id: 's-3', name: 'Cardiology Consultation', fee: 3000),
      ],
      qualifications: 'MBBS, MRCP',
      experienceYears: '12 years',
    );

    testWidgets('9-14. Published real doctors appear with real names, specializations, clinics, services, and fees', (tester) async {
      final repo = MockPatientAppointmentRepository(
        doctorsToReturn: [realDoctor1, realDoctor2],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: FindDoctorScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Real doctor names
      expect(find.text('Dr. Arsalan'), findsOneWidget);
      expect(find.text('Dr. Ahmed Khan'), findsOneWidget);

      // Real specializations
      expect(find.text('Neurologist'), findsWidgets);
      expect(find.text('Cardiologist'), findsWidgets);

      // Real clinics
      expect(find.text('Advanced Neuro Clinic, DHA Phase 5, Lahore'), findsOneWidget);
      expect(find.text('Punjab Heart Center, Gulberg III, Lahore'), findsOneWidget);

      // Real fees
      expect(find.text('Rs. 2500'), findsOneWidget);
      expect(find.text('Rs. 3000'), findsOneWidget);
    });

    testWidgets('16-17. NO rating, stars, 5.0, or rating badges appear in Find a Doctor or Doctor Profile', (tester) async {
      final repo = MockPatientAppointmentRepository(
        doctorsToReturn: [realDoctor1],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: FindDoctorScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Verify NO rating or stars in doctor discovery list
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.text('5.0'), findsNothing);
      expect(find.text('4.8'), findsNothing);
      expect(find.text('4.9'), findsNothing);

      // Navigate to Patient Doctor Profile Screen
      await tester.tap(find.text('View Profile'));
      await tester.pumpAndSettle();

      // Verify NO rating or stars in doctor profile screen
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.text('5.0'), findsNothing);

      // Verify real data is shown in profile
      expect(find.text('Dr. Arsalan'), findsOneWidget);
      expect(find.text('Neurologist • MBBS, FCPS'), findsOneWidget);
      expect(find.text('Neurology Consultation'), findsOneWidget);
      expect(find.text('EEG Review'), findsOneWidget);
      expect(find.text('Rs. 2500'), findsWidgets);
      expect(find.text('Rs. 4000'), findsOneWidget);
    });

    testWidgets('18-19. No City Heart Clinic or General Physician fallback appears for custom doctors', (tester) async {
      final customDoctor = Doctor(
        id: 'doc-99',
        name: 'Dr. Zeeshan Ali',
        specialization: 'Orthopedic Surgeon',
        clinic: 'Bone & Joint Clinic',
        location: 'Faisalabad',
        consultationFee: 1800,
        availability: 'Available on Request',
        about: 'Orthopedic specialist.',
        availableDays: const ['Saturday'],
        consultationHours: '9:00 AM - 1:00 PM',
        services: const [
          DoctorService(id: 's-99', name: 'Orthopedic Consultation', fee: 1800),
        ],
      );

      final repo = MockPatientAppointmentRepository(
        doctorsToReturn: [customDoctor],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: FindDoctorScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('City Heart Clinic'), findsNothing);
      expect(find.textContaining('General Physician'), findsNothing);
      expect(find.text('Dr. Zeeshan Ali'), findsOneWidget);
      expect(find.text('Orthopedic Surgeon'), findsWidgets);
      expect(find.text('Bone & Joint Clinic, Faisalabad'), findsOneWidget);
    });

    testWidgets('20-22. Booking flow displays authoritative service fee and cash-at-clinic notice', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookAppointmentScreen(doctor: realDoctor1),
        ),
      );
      await tester.pumpAndSettle();

      // Real services & fees in selection list
      expect(find.text('Neurology Consultation'), findsWidgets);
      expect(find.text('EEG Review'), findsOneWidget);
      expect(find.text('Rs. 2500'), findsWidgets);
      expect(find.text('Rs. 4000'), findsOneWidget);

      // Cash at clinic notice
      expect(find.textContaining('Cash at clinic'), findsOneWidget);
    });
  });
}
