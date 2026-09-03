import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/features/doctor/data/doctor_repository.dart';
import 'package:sehatpass/features/doctor/models/doctor_patient_model.dart';
import 'package:sehatpass/features/doctor/patients/doctor_patient_detail_screen.dart';
import 'package:sehatpass/features/doctor/patients/doctor_patients_screen.dart';

class MockDoctorPatientRepository extends DoctorRepository {
  List<DoctorPatientModel> patientsToReturn;
  final String? errorToThrow;
  int getDoctorPatientsCallCount = 0;
  int getDoctorPatientDetailCallCount = 0;
  String? lastDetailPatientId;

  MockDoctorPatientRepository({
    this.patientsToReturn = const [],
    this.errorToThrow,
  });

  @override
  String? get currentUserId => 'mock-doctor-uuid-123';

  @override
  Future<List<DoctorPatientModel>> getDoctorPatients() async {
    getDoctorPatientsCallCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return patientsToReturn;
  }

  @override
  Future<DoctorPatientModel?> getDoctorPatientDetail(String patientId) async {
    getDoctorPatientDetailCallCount++;
    lastDetailPatientId = patientId;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    try {
      return patientsToReturn.firstWhere((p) => p.id == patientId);
    } catch (_) {
      return null;
    }
  }
}

void main() {
  group('Phase 4A DoctorPatientModel Unit Tests', () {
    test('fromMap parses complete profile and patient_profile data with calculated age', () {
      final dbMap = {
        'id': 'patient-uuid-101',
        'profiles': {
          'id': 'patient-uuid-101',
          'full_name': 'Hamza Sheikh',
          'profile_photo_url': 'https://example.com/avatar.jpg',
          'phone': '+92 300 1234567',
        },
        'patient_profiles': {
          'patient_id': 'patient-uuid-101',
          'date_of_birth': '1995-05-15',
          'gender': 'Male',
          'blood_group': 'B+',
          'allergies': 'Dust, Pollen',
          'medical_conditions': 'Asthma',
        },
      };

      final model = DoctorPatientModel.fromMap(
        dbMap,
        totalVisits: 3,
        lastAppointmentDate: DateTime(2026, 8, 20),
        latestServiceName: 'Pulmonology Consultation',
      );

      expect(model.id, 'patient-uuid-101');
      expect(model.patientId, 'patient-uuid-101');
      expect(model.name, 'Hamza Sheikh');
      expect(model.phone, '+92 300 1234567');
      expect(model.gender, 'Male');
      expect(model.bloodGroup, 'B+');
      expect(model.allergies, 'Dust, Pollen');
      expect(model.medicalConditions, 'Asthma');
      expect(model.totalVisits, 3);
      expect(model.appointmentCount, 3);
      expect(model.primaryCondition, 'Pulmonology Consultation');
      expect(model.lastVisit, '20 Aug 2026');
      expect(model.age, greaterThanOrEqualTo(30)); // 1995 -> 2026 is 31
      expect(model.currentMedicines, isEmpty); // Phase 4A does not invent mock medicines
      expect(model.medicalReports, isEmpty); // Phase 4A does not invent mock reports
    });

    test('fromMap handles null and missing fields gracefully without throwing', () {
      final sparseMap = <String, dynamic>{
        'patient_id': 'patient-uuid-sparse',
      };

      final model = DoctorPatientModel.fromMap(sparseMap);

      expect(model.id, 'patient-uuid-sparse');
      expect(model.name, 'Patient');
      expect(model.phone, 'Not provided');
      expect(model.gender, 'Not specified');
      expect(model.bloodGroup, 'Not specified');
      expect(model.allergies, 'None added');
      expect(model.medicalConditions, 'None added');
      expect(model.totalVisits, 1);
      expect(model.age, 0);
      expect(model.lastVisit, 'Recent');
    });

    test('calculateAge correctly determines age based on date of birth', () {
      final now = DateTime.now();
      final exactly25YearsAgo = DateTime(now.year - 25, now.month, now.day);
      expect(DoctorPatientModel.calculateAge(exactly25YearsAgo), 25);

      final birthdayTomorrow = DateTime(now.year - 25, now.month, now.day + 1);
      expect(DoctorPatientModel.calculateAge(birthdayTomorrow), 24);

      expect(DoctorPatientModel.calculateAge(null, fallbackAge: 40), 40);
    });

    test('formatDate produces clean user-facing date string', () {
      final date = DateTime(2026, 9, 3);
      expect(DoctorPatientModel.formatDate(date), '3 Sep 2026');
      expect(DoctorPatientModel.formatDate(null), 'No visits yet');
    });

    test('copyWith produces modified copy with updated fields', () {
      final original = DoctorPatientModel(
        id: 'p-1',
        name: 'Original Name',
        age: 30,
        gender: 'Male',
        phone: '123',
        bloodGroup: 'O+',
        lastVisit: 'Today',
        totalVisits: 1,
        primaryCondition: 'Checkup',
      );

      final modified = original.copyWith(
        name: 'Modified Name',
        allergies: 'Peanuts',
      );

      expect(modified.id, 'p-1');
      expect(modified.name, 'Modified Name');
      expect(modified.allergies, 'Peanuts');
      expect(modified.bloodGroup, 'O+');
    });
  });

  group('Phase 4A DoctorPatientsScreen Widget Tests', () {
    testWidgets('renders patient list from DoctorRepository', (tester) async {
      final mockRepo = MockDoctorPatientRepository(
        patientsToReturn: [
          DoctorPatientModel(
            id: 'pat-1',
            name: 'Bilal Tariq',
            age: 29,
            gender: 'Male',
            phone: '+92 300 9991122',
            bloodGroup: 'A+',
            lastVisit: '1 Sep 2026',
            totalVisits: 2,
            primaryCondition: 'Cardiology Consultation',
            medicalConditions: 'Hypertension',
            allergies: 'None added',
          ),
          DoctorPatientModel(
            id: 'pat-2',
            name: 'Sadia Imran',
            age: 35,
            gender: 'Female',
            phone: '+92 321 8883344',
            bloodGroup: 'O+',
            lastVisit: '25 Aug 2026',
            totalVisits: 1,
            primaryCondition: 'General Health Checkup',
            medicalConditions: 'None added',
            allergies: 'Penicillin',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorPatientsScreen(repository: mockRepo),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Patients'), findsOneWidget);
      expect(find.text('2 Patients Total'), findsOneWidget);
      expect(find.text('Bilal Tariq'), findsOneWidget);
      expect(find.text('Sadia Imran'), findsOneWidget);
      expect(find.textContaining('Cardiology Consultation'), findsOneWidget);
      expect(find.textContaining('Blood A+'), findsOneWidget);
      expect(find.textContaining('Blood O+'), findsOneWidget);
    });

    testWidgets('renders empty state when no patients exist', (tester) async {
      final mockRepo = MockDoctorPatientRepository(patientsToReturn: []);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorPatientsScreen(repository: mockRepo),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('0 Patients Total'), findsOneWidget);
      expect(find.text('No patients found'), findsOneWidget);
      expect(
        find.text('Patients with confirmed or past appointments will appear here.'),
        findsOneWidget,
      );
    });

    testWidgets('search filtering dynamically filters patient list', (tester) async {
      final mockRepo = MockDoctorPatientRepository(
        patientsToReturn: [
          DoctorPatientModel(
            id: 'pat-1',
            name: 'Bilal Tariq',
            age: 29,
            gender: 'Male',
            phone: '+92 300 9991122',
            bloodGroup: 'A+',
            lastVisit: '1 Sep 2026',
            totalVisits: 2,
            primaryCondition: 'Cardiology Consultation',
          ),
          DoctorPatientModel(
            id: 'pat-2',
            name: 'Sadia Imran',
            age: 35,
            gender: 'Female',
            phone: '+92 321 8883344',
            bloodGroup: 'O+',
            lastVisit: '25 Aug 2026',
            totalVisits: 1,
            primaryCondition: 'General Health Checkup',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorPatientsScreen(repository: mockRepo),
        ),
      );

      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Sadia');
      await tester.pumpAndSettle();

      expect(find.text('Sadia Imran'), findsOneWidget);
      expect(find.text('Bilal Tariq'), findsNothing);
      expect(find.text('1 Patients Total'), findsOneWidget);
    });

    testWidgets('error state displays friendly error and retry button', (tester) async {
      final mockRepo = MockDoctorPatientRepository(
        errorToThrow: 'Unable to load patients roster. Please check connection.',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorPatientsScreen(repository: mockRepo),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Unable to load patients roster. Please check connection.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('Phase 4A DoctorPatientDetailScreen Widget Tests', () {
    testWidgets('renders real patient demographics and Phase 4B notices', (tester) async {
      final patient = DoctorPatientModel(
        id: 'patient-uuid-101',
        name: 'Zubair Qureshi',
        age: 42,
        gender: 'Male',
        phone: '+92 333 4567890',
        bloodGroup: 'AB+',
        lastVisit: '2 Sep 2026',
        totalVisits: 5,
        primaryCondition: 'Hypertension Follow-up',
        medicalConditions: 'Chronic Hypertension, Hyperlipidemia',
        allergies: 'Aspirin',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorPatientDetailScreen(patient: patient),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Patient Details'), findsOneWidget);
      expect(find.text('Zubair Qureshi'), findsOneWidget);
      expect(find.textContaining('42 yrs • Male • Blood Group: AB+'), findsOneWidget);
      expect(find.text('+92 333 4567890'), findsOneWidget);
      expect(find.text('Aspirin'), findsWidgets);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('2 Sep 2026'), findsOneWidget);
      expect(find.text('Chronic Hypertension, Hyperlipidemia'), findsOneWidget);
      expect(find.text('Active Medications'), findsOneWidget);
      expect(find.text('Medical & Diagnostic Reports'), findsOneWidget);
      expect(find.text('View Full Records'), findsOneWidget);
    });

    testWidgets('tapping View Full Records opens records modal', (tester) async {
      final patient = DoctorPatientModel(
        id: 'patient-uuid-101',
        name: 'Zubair Qureshi',
        age: 42,
        gender: 'Male',
        phone: '+92 333 4567890',
        bloodGroup: 'AB+',
        lastVisit: '2 Sep 2026',
        totalVisits: 5,
        primaryCondition: 'Hypertension Follow-up',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorPatientDetailScreen(patient: patient),
        ),
      );

      await tester.pumpAndSettle();

      final buttonFinder = find.text('View Full Records');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('Medical Records'), findsOneWidget);
      expect(find.text('Medications (0)'), findsOneWidget);
    });
  });
}
