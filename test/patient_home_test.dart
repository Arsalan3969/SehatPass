import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/features/home/home_screen.dart';
import 'package:sehatpass/features/home/data/patient_home_repository.dart';
import 'package:sehatpass/features/home/models/patient_home_data.dart';
import 'package:sehatpass/features/home/models/patient_medicine_model.dart';
import 'package:sehatpass/features/home/models/medical_report_model.dart';
import 'package:sehatpass/features/home/widgets/home_greeting_bar.dart';
import 'package:sehatpass/features/home/widgets/health_overview_card.dart';
import 'package:sehatpass/features/home/widgets/today_schedule_section.dart';
import 'package:sehatpass/features/home/widgets/recent_reports_section.dart';

class MockPatientHomeRepository extends PatientHomeRepository {
  final PatientHomeData? dataToReturn;
  final String? errorToThrow;
  int callCount = 0;

  MockPatientHomeRepository({
    this.dataToReturn,
    this.errorToThrow,
  });

  @override
  Future<PatientHomeData> getPatientHomeData() async {
    callCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return dataToReturn ??
        const PatientHomeData(
          patientName: 'Test Patient',
          email: 'test@example.com',
          medicines: [],
          reports: [],
        );
  }
}

void main() {
  group('Patient Home Models Unit Tests', () {
    test('PatientMedicineModel fromMap and toMedicineItem', () {
      final map = {
        'id': 'med-123',
        'patient_id': 'pat-456',
        'name': 'Augmentin 625mg',
        'dosage': '1 Tablet',
        'instruction': 'After Breakfast',
        'scheduled_time': '9:00 AM',
        'is_active': true,
        'created_at': '2026-08-30T10:00:00Z',
      };

      final model = PatientMedicineModel.fromMap(map);
      expect(model.id, 'med-123');
      expect(model.patientId, 'pat-456');
      expect(model.name, 'Augmentin 625mg');
      expect(model.dosage, '1 Tablet');
      expect(model.instruction, 'After Breakfast');
      expect(model.scheduledTime, '9:00 AM');
      expect(model.isActive, true);

      final item = model.toMedicineItem();
      expect(item.name, 'Augmentin 625mg');
      expect(item.dosage, '1 Tablet');
      expect(item.time, '9:00 AM');
    });

    test('MedicalReportModel fromMap and date formatting', () {
      final map = {
        'id': 'rep-123',
        'patient_id': 'pat-456',
        'title': 'Lipid Profile',
        'lab_facility': 'Chughtai Lab',
        'report_date': '2026-08-25',
        'category': 'bloodTest',
      };

      final report = MedicalReportModel.fromMap(map);
      expect(report.id, 'rep-123');
      expect(report.patientId, 'pat-456');
      expect(report.title, 'Lipid Profile');
      expect(report.labFacility, 'Chughtai Lab');
      expect(report.categoryLabel, 'Blood Test');
      expect(report.formattedDate, '25 Aug 2026');
      expect(report.formattedDateLong, '25 August 2026');
    });

    test('PatientHomeData computed getters', () {
      const dataEmpty = PatientHomeData(
        patientName: 'Zainab',
        email: 'zainab@example.com',
      );
      expect(dataEmpty.nextMedicine, isNull);
      expect(dataEmpty.latestReport, isNull);

      final dataWithItems = PatientHomeData(
        patientName: 'Zainab',
        email: 'zainab@example.com',
        medicines: const [
          PatientMedicineModel(
            id: '1',
            patientId: 'p1',
            name: 'Paracetamol',
            dosage: '500mg',
            instruction: 'SOS',
            scheduledTime: '2:00 PM',
          ),
        ],
        reports: [
          MedicalReportModel(
            id: 'r1',
            patientId: 'p1',
            title: 'Chest X-Ray',
            labFacility: 'General Hospital',
            reportDate: DateTime(2026, 8, 20),
            category: 'scan',
          ),
        ],
      );

      expect(dataWithItems.nextMedicine?.name, 'Paracetamol');
      expect(dataWithItems.latestReport?.title, 'Chest X-Ray');
    });
  });

  group('HomeScreen Widget Tests', () {
    Widget buildTestScreen(PatientHomeRepository repo) {
      return MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(repository: repo),
      );
    }

    testWidgets('HomeScreen renders authenticated patient name and data from Supabase',
        (WidgetTester tester) async {
      final mockData = PatientHomeData(
        patientName: 'Sarah Fatima',
        email: 'sarah@example.com',
        medicines: const [
          PatientMedicineModel(
            id: 'm1',
            patientId: 'u1',
            name: 'Metformin',
            dosage: '500mg',
            instruction: 'After Dinner',
            scheduledTime: '8:30 PM',
          ),
          PatientMedicineModel(
            id: 'm2',
            patientId: 'u1',
            name: 'Vitamin D3',
            dosage: '1 Drop',
            instruction: 'Morning',
            scheduledTime: '10:00 AM',
          ),
        ],
        reports: [
          MedicalReportModel(
            id: 'r1',
            patientId: 'u1',
            title: 'HbA1c Blood Test',
            labFacility: 'Aga Khan Lab',
            reportDate: DateTime(2026, 8, 28),
            category: 'bloodTest',
          ),
        ],
      );

      final mockRepo = MockPatientHomeRepository(dataToReturn: mockData);

      await tester.pumpWidget(buildTestScreen(mockRepo));
      await tester.pumpAndSettle();

      // Verify patient name appears in greeting
      expect(find.textContaining('Sarah Fatima'), findsOneWidget);
      expect(find.byType(HomeGreetingBar), findsOneWidget);

      // Verify HealthOverviewCard displays real medication and report
      expect(find.byType(HealthOverviewCard), findsOneWidget);
      expect(find.text('Metformin'), findsWidgets);
      expect(find.text('HbA1c Blood Test'), findsWidgets);

      // Verify Today's Schedule displays real medicines
      expect(find.byType(TodayScheduleSection), findsOneWidget);
      expect(find.text('500mg • After Dinner'), findsOneWidget);
      expect(find.text('Vitamin D3'), findsOneWidget);

      // Verify Recent Reports section displays real reports
      expect(find.byType(RecentReportsSection), findsOneWidget);
      expect(find.text('Blood Test'), findsWidgets);
    });

    testWidgets('HomeScreen displays clean empty states when patient has no medicines or reports',
        (WidgetTester tester) async {
      const emptyData = PatientHomeData(
        patientName: 'Ali Raza',
        email: 'ali@example.com',
        medicines: [],
        reports: [],
      );

      final mockRepo = MockPatientHomeRepository(dataToReturn: emptyData);

      await tester.pumpWidget(buildTestScreen(mockRepo));
      await tester.pumpAndSettle();

      // Verify patient greeting
      expect(find.textContaining('Ali Raza'), findsOneWidget);

      // Verify empty states in Overview Card
      expect(find.text('No medicines scheduled'), findsWidgets);
      expect(find.text('No medical reports yet'), findsWidgets);

      // Verify empty states in Schedule section
      expect(find.text('Your scheduled medications will appear here.'),
          findsOneWidget);

      // Verify empty states in Recent Reports section
      expect(find.text('Uploaded lab and diagnostic reports will appear here.'),
          findsOneWidget);
    });

    testWidgets('HomeScreen handles errors gracefully with retry functionality',
        (WidgetTester tester) async {
      final mockRepo = MockPatientHomeRepository(
        errorToThrow: 'Unable to load your health information. Please try again.',
      );

      await tester.pumpWidget(buildTestScreen(mockRepo));
      await tester.pumpAndSettle();

      // Verify error banner is shown and app does NOT crash
      expect(find.text('Unable to load your health information'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(mockRepo.callCount, 1);

      // Tap Try Again
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(mockRepo.callCount, 2);
    });
  });
}
