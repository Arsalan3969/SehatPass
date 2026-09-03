import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/features/doctor/data/doctor_repository.dart';
import 'package:sehatpass/features/doctor/models/doctor_patient_model.dart';
import 'package:sehatpass/features/doctor/patients/doctor_patient_detail_screen.dart';
import 'package:sehatpass/features/home/models/patient_medicine_model.dart';
import 'package:sehatpass/features/home/models/medical_report_model.dart';
import 'package:sehatpass/features/doctor/models/doctor_consultation_note_model.dart';

class MockDoctorRecordsRepository extends DoctorRepository {
  DoctorPatientModel? patientToReturn;
  List<PatientMedicineModel> medicinesToReturn;
  List<MedicalReportModel> reportsToReturn;
  String? signedUrlToReturn;
  final String? medicinesError;
  final String? reportsError;

  int getMedicinesCallCount = 0;
  int getReportsCallCount = 0;
  int getSignedUrlCallCount = 0;
  String? lastSignedUrlPath;

  MockDoctorRecordsRepository({
    this.patientToReturn,
    this.medicinesToReturn = const [],
    this.reportsToReturn = const [],
    this.signedUrlToReturn = 'https://supabase.co/storage/v1/object/sign/medical-reports/sample.pdf?token=valid_1hr_token',
    this.medicinesError,
    this.reportsError,
  });

  @override
  String? get currentUserId => 'mock-doctor-uuid-4b';

  @override
  Future<DoctorPatientModel?> getDoctorPatientDetail(String patientId) async {
    return patientToReturn ??
        DoctorPatientModel(
          id: patientId,
          name: 'Ahmed Bilal',
          age: 36,
          gender: 'Male',
          phone: '+92 300 1234567',
          bloodGroup: 'B+',
          lastVisit: '3 Sep 2026',
          totalVisits: 2,
          primaryCondition: 'General Health Checkup',
        );
  }

  @override
  Future<List<PatientMedicineModel>> getDoctorPatientMedicines(String patientId) async {
    getMedicinesCallCount++;
    if (medicinesError != null) {
      throw medicinesError!;
    }
    return medicinesToReturn;
  }

  @override
  Future<List<MedicalReportModel>> getDoctorPatientReports(String patientId) async {
    getReportsCallCount++;
    if (reportsError != null) {
      throw reportsError!;
    }
    return reportsToReturn;
  }

  @override
  Future<List<DoctorConsultationNoteModel>> getPatientConsultationHistory(String patientId) async {
    return const [];
  }

  @override
  Future<String?> getDoctorReportSignedUrl(
    String storageFilePath, {
    int expiresInSeconds = 3600,
  }) async {
    getSignedUrlCallCount++;
    lastSignedUrlPath = storageFilePath;
    if (storageFilePath.startsWith('http://') ||
        storageFilePath.startsWith('https://') ||
        storageFilePath.contains('..')) {
      return null;
    }
    return signedUrlToReturn;
  }
}

void main() {
  group('Phase 4B Model Unit Tests', () {
    test('PatientMedicineModel parses complete database map and serializes correctly', () {
      final map = {
        'id': 'med-101',
        'patient_id': 'pat-202',
        'name': 'Metformin',
        'dosage': '500mg',
        'instruction': 'After Breakfast',
        'scheduled_time': '9:00 AM',
        'is_active': true,
        'start_date': '2026-08-01',
        'created_at': '2026-08-01T10:00:00Z',
      };

      final med = PatientMedicineModel.fromMap(map);
      expect(med.id, 'med-101');
      expect(med.patientId, 'pat-202');
      expect(med.name, 'Metformin');
      expect(med.dosage, '500mg');
      expect(med.instruction, 'After Breakfast');
      expect(med.scheduledTime, '9:00 AM');
      expect(med.isActive, isTrue);
      expect(med.startDate, DateTime(2026, 8, 1));

      final serialized = med.toMap();
      expect(serialized['id'], 'med-101');
      expect(serialized['name'], 'Metformin');
      expect(serialized['start_date'], '2026-08-01');
    });

    test('MedicalReportModel parses complete database map with storage metadata', () {
      final map = {
        'id': 'rep-301',
        'patient_id': 'pat-202',
        'title': 'Lipid Profile',
        'lab_facility': 'Chughtai Lab',
        'report_date': '2026-08-15',
        'category': 'bloodTest',
        'storage_file_path': 'pat-202/1723708800000_lipid_profile.pdf',
        'file_name': 'lipid_profile.pdf',
        'file_size_bytes': 1572864, // 1.5 MB
        'mime_type': 'application/pdf',
        'summary': 'Cholesterol levels within normal limits.',
      };

      final rep = MedicalReportModel.fromMap(map);
      expect(rep.id, 'rep-301');
      expect(rep.patientId, 'pat-202');
      expect(rep.title, 'Lipid Profile');
      expect(rep.labFacility, 'Chughtai Lab');
      expect(rep.category, 'bloodTest');
      expect(rep.categoryLabel, 'Blood Test');
      expect(rep.storageFilePath, 'pat-202/1723708800000_lipid_profile.pdf');
      expect(rep.formattedFileSize, '1.5 MB');
    });
  });

  group('Phase 4B DoctorPatientDetailScreen Widget Tests', () {
    testWidgets('renders active medications and medical reports from DoctorRepository', (tester) async {
      final mockRepo = MockDoctorRecordsRepository(
        medicinesToReturn: [
          const PatientMedicineModel(
            id: 'med-1',
            patientId: 'pat-101',
            name: 'Augmentin',
            dosage: '625mg',
            instruction: 'After Dinner',
            scheduledTime: '8:00 PM',
            isActive: true,
          ),
          const PatientMedicineModel(
            id: 'med-2',
            patientId: 'pat-101',
            name: 'Panadol',
            dosage: '500mg',
            instruction: 'When required',
            scheduledTime: '12:00 PM',
            isActive: true,
          ),
        ],
        reportsToReturn: [
          MedicalReportModel(
            id: 'rep-1',
            patientId: 'pat-101',
            title: 'Complete Blood Count (CBC)',
            labFacility: 'Excel Labs',
            reportDate: DateTime(2026, 8, 28),
            category: 'bloodTest',
            storageFilePath: 'pat-101/cbc.pdf',
            fileSizeBytes: 1048576,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorPatientDetailScreen(
            patientId: 'pat-101',
            repository: mockRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and clinical demographics
      expect(find.text('Patient Details'), findsOneWidget);
      expect(find.text('Ahmed Bilal'), findsOneWidget);

      // Check active medications section
      expect(find.text('Active Medications'), findsOneWidget);
      expect(find.text('Augmentin'), findsOneWidget);
      expect(find.textContaining('625mg • 8:00 PM (After Dinner)'), findsOneWidget);
      expect(find.text('Panadol'), findsOneWidget);
      expect(find.text('Active'), findsWidgets);

      // Check medical reports section
      expect(find.text('Medical & Diagnostic Reports'), findsOneWidget);
      expect(find.text('Complete Blood Count (CBC)'), findsOneWidget);
      expect(find.textContaining('Excel Labs • 28 Aug 2026'), findsOneWidget);
      expect(find.textContaining('Blood Test (1.0 MB)'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
    });

    testWidgets('renders empty states when patient has zero medicines and reports', (tester) async {
      final mockRepo = MockDoctorRecordsRepository(
        medicinesToReturn: [],
        reportsToReturn: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorPatientDetailScreen(
            patientId: 'pat-101',
            repository: mockRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('No active medications recorded for this patient.'),
        findsOneWidget,
      );
      expect(
        find.text('No medical reports uploaded by this patient.'),
        findsOneWidget,
      );
    });

    testWidgets('independent error handling: reports error does not hide medicines or demographics', (tester) async {
      final mockRepo = MockDoctorRecordsRepository(
        medicinesToReturn: [
          const PatientMedicineModel(
            id: 'med-1',
            patientId: 'pat-101',
            name: 'Lipitor',
            dosage: '20mg',
            instruction: 'At Bedtime',
            scheduledTime: '10:00 PM',
            isActive: true,
          ),
        ],
        reportsError: 'Unable to load medical reports. Access denied.',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorPatientDetailScreen(
            patientId: 'pat-101',
            repository: mockRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Demographics and Medicines still visible
      expect(find.text('Ahmed Bilal'), findsOneWidget);
      expect(find.text('Lipitor'), findsOneWidget);

      // Reports section displays error with retry button
      expect(
        find.text('Unable to load medical reports. Access denied.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('tapping report file icon invokes signed URL generation without public fallback', (tester) async {
      final mockRepo = MockDoctorRecordsRepository(
        reportsToReturn: [
          MedicalReportModel(
            id: 'rep-1',
            patientId: 'pat-101',
            title: 'Chest X-Ray',
            labFacility: 'IDC Islamabad',
            reportDate: DateTime(2026, 8, 20),
            category: 'scan',
            storageFilePath: 'pat-101/1724100000_xray.png',
            fileSizeBytes: 2097152,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorPatientDetailScreen(
            patientId: 'pat-101',
            repository: mockRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final fileButton = find.byIcon(Icons.open_in_new_rounded);
      expect(fileButton, findsOneWidget);

      await tester.ensureVisible(fileButton);
      await tester.tap(fileButton);
      await tester.pump();

      expect(mockRepo.getSignedUrlCallCount, 1);
      expect(mockRepo.lastSignedUrlPath, 'pat-101/1724100000_xray.png');
    });

    testWidgets('tapping View Full Records opens comprehensive bottom sheet with tabs', (tester) async {
      final mockRepo = MockDoctorRecordsRepository(
        medicinesToReturn: [
          const PatientMedicineModel(
            id: 'med-1',
            patientId: 'pat-101',
            name: 'Glucophage',
            dosage: '500mg',
            instruction: 'With Meals',
            scheduledTime: '8:00 AM',
            isActive: true,
          ),
        ],
        reportsToReturn: [
          MedicalReportModel(
            id: 'rep-1',
            patientId: 'pat-101',
            title: 'HbA1c Report',
            labFacility: 'Chughtai Lab',
            reportDate: DateTime(2026, 8, 10),
            category: 'bloodTest',
            storageFilePath: 'pat-101/hba1c.pdf',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorPatientDetailScreen(
            patientId: 'pat-101',
            repository: mockRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final fullRecordsBtn = find.text('View Full Records');
      await tester.ensureVisible(fullRecordsBtn);
      await tester.tap(fullRecordsBtn);
      await tester.pumpAndSettle();

      expect(find.text('Ahmed Bilal — Medical Records'), findsOneWidget);
      expect(find.text('Medications (1)'), findsOneWidget);
      expect(find.text('Reports (1)'), findsOneWidget);

      // Switch to Reports Tab in modal
      await tester.tap(find.text('Reports (1)'));
      await tester.pumpAndSettle();

      expect(find.text('HbA1c Report'), findsWidgets);
    });
  });
}
