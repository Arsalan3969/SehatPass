import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/core/constants/dummy_data.dart';
import 'package:sehatpass/features/home/models/medical_report_model.dart';
import 'package:sehatpass/features/reports/data/medical_reports_repository.dart';
import 'package:sehatpass/features/reports/reports_screen.dart';
import 'package:sehatpass/features/reports/widgets/report_card.dart';
import 'package:sehatpass/features/reports/widgets/upload_report_bottom_sheet.dart';
import 'package:sehatpass/features/reports/widgets/report_details_bottom_sheet.dart';

class MockMedicalReportsRepository extends MedicalReportsRepository {
  List<MedicalReportModel> reportsToReturn;
  final String? errorToThrow;
  int getReportsCallCount = 0;
  int createReportCallCount = 0;
  int deleteReportCallCount = 0;
  int signedUrlCallCount = 0;

  String? lastCreatedTitle;
  String? lastDeletedId;
  String? signedUrlToReturn;

  MockMedicalReportsRepository({
    this.reportsToReturn = const [],
    this.errorToThrow,
    this.signedUrlToReturn = 'https://supabase.co/storage/v1/object/sign/medical-reports/sample.pdf?token=abc',
  });

  @override
  Future<List<MedicalReportModel>> getPatientReports({
    String? category,
    String? searchQuery,
  }) async {
    getReportsCallCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }

    var list = reportsToReturn;
    if (category != null &&
        category.isNotEmpty &&
        category.toLowerCase() != 'all') {
      list = list.where((r) => r.category.toLowerCase() == category.toLowerCase()).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list
          .where((r) =>
              r.title.toLowerCase().contains(q) ||
              r.labFacility.toLowerCase().contains(q))
          .toList();
    }

    return list;
  }

  @override
  Future<List<MedicalReportModel>> getRecentReports({int limit = 10}) async {
    return getPatientReports();
  }

  @override
  Future<MedicalReportModel> createReport({
    required String title,
    required String labFacility,
    required DateTime reportDate,
    required String category,
    String? storageFilePath,
    String? fileName,
    int? fileSizeBytes,
    String? mimeType,
    String? summary,
    String? extractedText,
  }) async {
    createReportCallCount++;
    lastCreatedTitle = title;
    final newReport = MedicalReportModel(
      id: 'rep-new-${DateTime.now().millisecondsSinceEpoch}',
      patientId: 'patient-test-auth',
      title: title,
      labFacility: labFacility,
      reportDate: reportDate,
      category: category,
      storageFilePath: storageFilePath,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      mimeType: mimeType,
      summary: summary,
      extractedText: extractedText,
      createdAt: DateTime.now(),
    );
    reportsToReturn = [newReport, ...reportsToReturn];
    return newReport;
  }

  @override
  Future<String?> getReportSignedUrl(
    String storageFilePath, {
    int expiresInSeconds = 3600,
  }) async {
    signedUrlCallCount++;
    return signedUrlToReturn;
  }

  @override
  Future<void> deleteReport({
    required String reportId,
    String? storageFilePath,
  }) async {
    deleteReportCallCount++;
    lastDeletedId = reportId;
    reportsToReturn =
        reportsToReturn.where((r) => r.id != reportId).toList();
  }
}

void main() {
  group('MedicalReportModel Unit Tests', () {
    test('MedicalReportModel parsing, serialization, and copyWith', () {
      final map = {
        'id': 'rep-777',
        'patient_id': 'pat-888',
        'title': 'Complete Blood Count',
        'lab_facility': 'Chughtai Lab',
        'report_date': '2026-08-28',
        'category': 'bloodTest',
        'storage_file_path': 'pat-888/cbc.pdf',
        'file_name': 'cbc.pdf',
        'file_size_bytes': 1572864, // ~1.5 MB
        'mime_type': 'application/pdf',
        'summary': 'WBC count is slightly elevated',
        'created_at': '2026-08-28T14:00:00Z',
      };

      final report = MedicalReportModel.fromMap(map);
      expect(report.id, 'rep-777');
      expect(report.patientId, 'pat-888');
      expect(report.title, 'Complete Blood Count');
      expect(report.labFacility, 'Chughtai Lab');
      expect(report.categoryLabel, 'Blood Test');
      expect(report.formattedDate, '28 Aug 2026');
      expect(report.formattedDateLong, '28 August 2026');
      expect(report.formattedFileSize, '1.5 MB');
      expect(report.reportCategory, ReportCategory.bloodTest);

      final toMapResult = report.toMap();
      expect(toMapResult['id'], 'rep-777');
      expect(toMapResult['title'], 'Complete Blood Count');

      final updated = report.copyWith(title: 'Updated CBC', category: 'scan');
      expect(updated.title, 'Updated CBC');
      expect(updated.category, 'scan');
      expect(updated.categoryLabel, 'Scan');
      expect(updated.reportCategory, ReportCategory.scan);
    });
  });

  group('ReportsScreen Widget Tests', () {
    Widget buildTestScreen(MedicalReportsRepository repo) {
      return MaterialApp(
        theme: AppTheme.light,
        home: ReportsScreen(repository: repo),
      );
    }

    testWidgets('ReportsScreen renders report list, cards, and report count',
        (WidgetTester tester) async {
      final mockReports = [
        MedicalReportModel(
          id: 'r1',
          patientId: 'p1',
          title: 'Liver Function Test',
          labFacility: 'City Laboratory',
          reportDate: DateTime(2026, 8, 25),
          category: 'bloodTest',
          storageFilePath: 'p1/lft.pdf',
          fileName: 'lft.pdf',
        ),
        MedicalReportModel(
          id: 'r2',
          patientId: 'p1',
          title: 'Chest X-Ray',
          labFacility: 'General Hospital',
          reportDate: DateTime(2026, 8, 20),
          category: 'scan',
        ),
      ];

      final repo = MockMedicalReportsRepository(reportsToReturn: mockReports);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pumpAndSettle();

      // Header and count
      expect(find.text('My Reports'), findsOneWidget);
      expect(find.text('2 reports found'), findsOneWidget);

      // Report cards
      expect(find.byType(ReportCard), findsNWidgets(2));
      expect(find.text('Liver Function Test'), findsOneWidget);
      expect(find.text('City Laboratory'), findsOneWidget);
      expect(find.text('Chest X-Ray'), findsOneWidget);
      expect(find.text('General Hospital'), findsOneWidget);
    });

    testWidgets('ReportsScreen displays clean empty state when no reports exist',
        (WidgetTester tester) async {
      final repo = MockMedicalReportsRepository(reportsToReturn: []);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pumpAndSettle();

      expect(find.text('No medical reports yet'), findsOneWidget);
      expect(find.text('Upload lab tests or diagnostic reports to keep them organized.'),
          findsOneWidget);
      expect(find.text('Upload Report'), findsWidgets);
    });

    testWidgets('ReportsScreen displays error state with retry mechanism',
        (WidgetTester tester) async {
      final repo = MockMedicalReportsRepository(
        errorToThrow: 'Unable to load your medical reports. Please try again.',
      );

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load your medical reports'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(repo.getReportsCallCount, 1);

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(repo.getReportsCallCount, 2);
    });

    testWidgets('Search bar filters reports in real-time',
        (WidgetTester tester) async {
      final mockReports = [
        MedicalReportModel(
          id: 'r1',
          patientId: 'p1',
          title: 'Lipid Profile',
          labFacility: 'Aga Khan Lab',
          reportDate: DateTime(2026, 8, 25),
          category: 'bloodTest',
        ),
        MedicalReportModel(
          id: 'r2',
          patientId: 'p1',
          title: 'Pelvis Ultrasound',
          labFacility: 'Doctors Hospital',
          reportDate: DateTime(2026, 8, 10),
          category: 'scan',
        ),
      ];

      final repo = MockMedicalReportsRepository(reportsToReturn: mockReports);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pumpAndSettle();

      expect(find.text('Lipid Profile'), findsOneWidget);
      expect(find.text('Pelvis Ultrasound'), findsOneWidget);

      // Type in search bar
      await tester.enterText(find.byType(TextField), 'Ultrasound');
      await tester.pumpAndSettle();

      expect(find.text('Pelvis Ultrasound'), findsOneWidget);
      expect(find.text('Lipid Profile'), findsNothing);
      expect(find.text('1 report found'), findsOneWidget);
    });

    testWidgets('Category filter chips filter reports correctly',
        (WidgetTester tester) async {
      final mockReports = [
        MedicalReportModel(
          id: 'r1',
          patientId: 'p1',
          title: 'CBC Blood Test',
          labFacility: 'Chughtai Lab',
          reportDate: DateTime(2026, 8, 25),
          category: 'bloodTest',
        ),
        MedicalReportModel(
          id: 'r2',
          patientId: 'p1',
          title: 'MRI Brain',
          labFacility: 'General Hospital',
          reportDate: DateTime(2026, 8, 10),
          category: 'scan',
        ),
      ];

      final repo = MockMedicalReportsRepository(reportsToReturn: mockReports);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pumpAndSettle();

      // Tap 'Scans' filter chip
      await tester.tap(find.text('Scans'));
      await tester.pumpAndSettle();

      expect(find.text('MRI Brain'), findsOneWidget);
      expect(find.text('CBC Blood Test'), findsNothing);
      expect(find.text('1 report found'), findsOneWidget);
    });

    testWidgets('Upload Report FAB opens bottom sheet and saves report',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = MockMedicalReportsRepository(reportsToReturn: []);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pumpAndSettle();

      // Tap FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(UploadReportBottomSheet), findsOneWidget);
      expect(find.text('Upload Medical Report'), findsOneWidget);

      // Fill in fields
      await tester.enterText(
          find.widgetWithText(TextFormField, 'e.g. Complete Blood Count (CBC)'),
          'Thyroid Function Test');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'e.g. Chughtai Lab, Aga Khan Hospital'),
          'Excel Labs');

      // Tap submit
      await tester.ensureVisible(find.text('Save & Upload Report'));
      await tester.tap(find.text('Save & Upload Report'));
      await tester.pumpAndSettle();

      expect(repo.createReportCallCount, 1);
      expect(repo.lastCreatedTitle, 'Thyroid Function Test');
      expect(find.text('Thyroid Function Test uploaded successfully.'),
          findsOneWidget);
    });

    testWidgets('Tapping report card opens details and allows deletion',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockReports = [
        MedicalReportModel(
          id: 'rep-delete-1',
          patientId: 'p1',
          title: 'ECG Report',
          labFacility: 'Punjab Institute of Cardiology',
          reportDate: DateTime(2026, 8, 15),
          category: 'scan',
          storageFilePath: 'p1/ecg.pdf',
          fileName: 'ecg.pdf',
          summary: 'Normal sinus rhythm',
        ),
      ];

      final repo = MockMedicalReportsRepository(reportsToReturn: mockReports);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pumpAndSettle();

      // Tap card
      await tester.tap(find.text('ECG Report'));
      await tester.pumpAndSettle();

      expect(find.byType(ReportDetailsBottomSheet), findsOneWidget);
      expect(find.text('Punjab Institute of Cardiology'), findsWidgets);
      expect(find.text('Normal sinus rhythm'), findsOneWidget);
      expect(find.text('Open PDF Document'), findsOneWidget);

      // Tap access report document
      await tester.tap(find.text('Open PDF Document'));
      await tester.pumpAndSettle();
      expect(repo.signedUrlCallCount, 1);

      // Tap Delete Report
      await tester.ensureVisible(find.text('Delete Report'));
      await tester.tap(find.text('Delete Report'));
      await tester.pumpAndSettle();

      // Dialog
      expect(find.text('Delete Medical Report'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(repo.deleteReportCallCount, 1);
      expect(repo.lastDeletedId, 'rep-delete-1');
      expect(find.text('ECG Report deleted.'), findsOneWidget);
    });
  });
}
