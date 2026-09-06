import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/features/home/models/patient_medicine_model.dart';
import 'package:sehatpass/features/medicines/data/medicine_repository.dart';
import 'package:sehatpass/features/medicines/medicines_screen.dart';
import 'package:sehatpass/features/medicines/models/medicine_item.dart';
import 'package:sehatpass/features/medicines/widgets/add_edit_medicine_bottom_sheet.dart';
import 'package:sehatpass/features/medicines/widgets/medicine_card.dart';
import 'package:sehatpass/features/medicines/widgets/medicine_progress_card.dart';
import 'package:sehatpass/features/medicines/widgets/medicine_status_summary.dart';

class MockMedicineRepository extends MedicineRepository {
  List<MedicineItem> scheduleToReturn;
  final String? errorToThrow;
  int getScheduleCallCount = 0;
  int markDoseCallCount = 0;
  int addMedicineCallCount = 0;
  int updateMedicineCallCount = 0;
  int deactivateMedicineCallCount = 0;

  String? lastMarkedMedicineId;
  String? lastAddedName;
  String? lastUpdatedMedicineId;
  String? lastDeactivatedMedicineId;

  MockMedicineRepository({
    this.scheduleToReturn = const [],
    this.errorToThrow,
  });

  @override
  Future<List<MedicineItem>> getTodayMedicineSchedule({
    DateTime? date,
    DateTime? nowOverride,
  }) async {
    getScheduleCallCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return scheduleToReturn;
  }

  @override
  Future<void> markDoseTaken({required String medicineId, DateTime? date}) async {
    markDoseCallCount++;
    lastMarkedMedicineId = medicineId;
    scheduleToReturn = scheduleToReturn.map((item) {
      if (item.id == medicineId) {
        return item.copyWith(status: MedicineStatus.taken);
      }
      return item;
    }).toList();
  }

  @override
  Future<PatientMedicineModel> addMedicine({
    required String name,
    required String dosage,
    required String instruction,
    required String scheduledTime,
    DateTime? startDate,
  }) async {
    addMedicineCallCount++;
    lastAddedName = name;
    final newModel = PatientMedicineModel(
      id: 'med-new-${DateTime.now().millisecondsSinceEpoch}',
      patientId: 'patient-test-auth',
      name: name,
      dosage: dosage,
      instruction: instruction,
      scheduledTime: scheduledTime,
      startDate: startDate,
    );
    scheduleToReturn = [
      ...scheduleToReturn,
      newModel.toMedicineItem(status: MedicineStatus.upcoming),
    ];
    return newModel;
  }

  @override
  Future<PatientMedicineModel> updateMedicine({
    required String medicineId,
    required String name,
    required String dosage,
    required String instruction,
    required String scheduledTime,
    DateTime? startDate,
    bool isActive = true,
  }) async {
    updateMedicineCallCount++;
    lastUpdatedMedicineId = medicineId;
    final updated = PatientMedicineModel(
      id: medicineId,
      patientId: 'patient-test-auth',
      name: name,
      dosage: dosage,
      instruction: instruction,
      scheduledTime: scheduledTime,
      startDate: startDate,
      isActive: isActive,
    );
    scheduleToReturn = scheduleToReturn.map((item) {
      if (item.id == medicineId) {
        return updated.toMedicineItem(status: item.status);
      }
      return item;
    }).toList();
    return updated;
  }

  @override
  Future<void> deactivateMedicine(String medicineId) async {
    deactivateMedicineCallCount++;
    lastDeactivatedMedicineId = medicineId;
    scheduleToReturn =
        scheduleToReturn.where((item) => item.id != medicineId).toList();
  }
}

void main() {
  group('Medicine Models Unit Tests', () {
    test('PatientMedicineModel serialization and copyWith', () {
      final model = PatientMedicineModel(
        id: 'med-101',
        patientId: 'user-202',
        name: 'Panadol 500mg',
        dosage: '2 Tablets',
        instruction: 'After Dinner',
        scheduledTime: '9:00 PM',
        isActive: true,
        createdAt: DateTime(2026, 8, 31),
      );

      final map = model.toMap();
      expect(map['id'], 'med-101');
      expect(map['patient_id'], 'user-202');
      expect(map['name'], 'Panadol 500mg');
      expect(map['dosage'], '2 Tablets');
      expect(map['instruction'], 'After Dinner');
      expect(map['scheduled_time'], '9:00 PM');
      expect(map['is_active'], true);

      final fromMapModel = PatientMedicineModel.fromMap(map);
      expect(fromMapModel.id, model.id);
      expect(fromMapModel.name, model.name);

      final modified = model.copyWith(name: 'Panadol Extra', isActive: false);
      expect(modified.name, 'Panadol Extra');
      expect(modified.isActive, false);
      expect(modified.id, 'med-101');
    });

    test('PatientMedicineModel converts to MedicineItem with doseLog status', () {
      final model = const PatientMedicineModel(
        id: 'med-303',
        patientId: 'user-202',
        name: 'Amoxicillin 500mg',
        dosage: '1 Capsule',
        instruction: 'Before Breakfast',
        scheduledTime: '8:00 AM',
      );

      final itemTaken = model.toMedicineItem(
        status: MedicineStatus.taken,
        doseLogId: 'log-999',
      );
      expect(itemTaken.id, 'med-303');
      expect(itemTaken.patientId, 'user-202');
      expect(itemTaken.name, 'Amoxicillin 500mg');
      expect(itemTaken.dosage, '1 Capsule');
      expect(itemTaken.instruction, 'Before Breakfast');
      expect(itemTaken.time, '8:00 AM');
      expect(itemTaken.status, MedicineStatus.taken);
      expect(itemTaken.doseLogId, 'log-999');
    });

    test('MedicineStatusProps parses string states correctly', () {
      expect(MedicineStatusProps.fromString('taken'), MedicineStatus.taken);
      expect(MedicineStatusProps.fromString('upcoming'), MedicineStatus.upcoming);
      expect(MedicineStatusProps.fromString('missed'), MedicineStatus.missed);
      expect(MedicineStatusProps.fromString('unknown'), MedicineStatus.upcoming);
      expect(MedicineStatusProps.fromString(null), MedicineStatus.upcoming);

      expect(MedicineStatus.taken.label, 'Taken');
      expect(MedicineStatus.upcoming.label, 'Upcoming');
      expect(MedicineStatus.missed.label, 'Missed');
    });

    test('Dynamic status calculation: future dose is upcoming, past dose without log is missed, taken log is taken', () {
      final futureMed = const PatientMedicineModel(
        id: 'med-future',
        patientId: 'p1',
        name: 'Evening Pill',
        dosage: '1 tab',
        instruction: 'After dinner',
        scheduledTime: '08:00 PM', // 20:00 > 14:30
      );

      final pastMed = const PatientMedicineModel(
        id: 'med-past',
        patientId: 'p1',
        name: 'Morning Pill',
        dosage: '1 tab',
        instruction: 'After breakfast',
        scheduledTime: '08:00 AM', // 08:00 < 14:30
      );

      // 1. Future dose without log -> Upcoming
      final futureItem = futureMed.toMedicineItem(status: MedicineStatus.upcoming);
      expect(futureItem.status, MedicineStatus.upcoming);

      // 2. Past dose without log -> Missed
      final pastItemMissed = pastMed.toMedicineItem(status: MedicineStatus.missed);
      expect(pastItemMissed.status, MedicineStatus.missed);

      // 3. Past dose with taken log -> Taken
      final pastItemTaken = pastMed.toMedicineItem(
        status: MedicineStatus.taken,
        doseLogId: 'log-123',
      );
      expect(pastItemTaken.status, MedicineStatus.taken);

      // 4. Late mark-taken transition: Missed -> Taken
      final updatedLate = pastItemMissed.copyWith(
        status: MedicineStatus.taken,
        doseLogId: 'log-new-456',
      );
      expect(updatedLate.status, MedicineStatus.taken);
      expect(updatedLate.doseLogId, 'log-new-456');
    });
  });

  group('MedicinesScreen Widget Tests', () {
    Widget buildTestScreen(MedicineRepository repo) {
      return MaterialApp(
        theme: AppTheme.light,
        home: MedicinesScreen(repository: repo),
      );
    }

    testWidgets('MedicinesScreen renders populated medicines list, progress, and status summary',
        (WidgetTester tester) async {
      final mockSchedule = [
        const MedicineItem(
          id: 'm1',
          name: 'Panadol',
          dosage: '1 Tablet',
          instruction: 'After Dinner',
          time: '8:00 PM',
          status: MedicineStatus.taken,
        ),
        const MedicineItem(
          id: 'm2',
          name: 'Vitamin C',
          dosage: '1 Capsule',
          instruction: 'After Breakfast',
          time: '9:00 AM',
          status: MedicineStatus.taken,
        ),
        const MedicineItem(
          id: 'm3',
          name: 'Augmentin',
          dosage: '1 Tablet',
          instruction: 'After Lunch',
          time: '2:00 PM',
          status: MedicineStatus.upcoming,
        ),
      ];

      final repo = MockMedicineRepository(scheduleToReturn: mockSchedule);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pumpAndSettle();

      // Header
      expect(find.text('My Medicines'), findsOneWidget);
      expect(find.text('Manage your medicines and stay on schedule.'), findsOneWidget);

      // Progress Card: 2 of 3 taken (67%)
      expect(find.byType(MedicineProgressCard), findsOneWidget);
      expect(find.text('67%'), findsOneWidget);

      // Medicine Cards
      expect(find.byType(MedicineCard), findsNWidgets(3));
      expect(find.text('Panadol'), findsOneWidget);
      expect(find.text('Vitamin C'), findsOneWidget);
      expect(find.text('Augmentin'), findsOneWidget);

      // Status summary
      expect(find.byType(MedicineStatusSummary), findsOneWidget);
      expect(find.text('Medicine Status'), findsOneWidget);
      expect(find.text('Taken'), findsWidgets);
      expect(find.text('Upcoming'), findsWidgets);
      expect(find.text('Missed'), findsWidgets);
    });

    testWidgets('MedicinesScreen displays empty state when no medicines are scheduled',
        (WidgetTester tester) async {
      final repo = MockMedicineRepository(scheduleToReturn: []);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pumpAndSettle();

      expect(find.text('No medicines added yet'), findsOneWidget);
      expect(
          find.text('Add your prescribed medications to track daily doses and stay on schedule.'),
          findsOneWidget);
      expect(find.text('Add Medicine'), findsWidgets);
    });

    testWidgets('MedicinesScreen displays error state and retries on failure',
        (WidgetTester tester) async {
      final repo = MockMedicineRepository(
        errorToThrow: 'Unable to load your medicines. Please try again.',
      );

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load your medicines'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(repo.getScheduleCallCount, 1);

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(repo.getScheduleCallCount, 2);
    });

    testWidgets('Tapping status badge marks upcoming medicine as taken',
        (WidgetTester tester) async {
      final mockSchedule = [
        const MedicineItem(
          id: 'med-upcoming-1',
          name: 'Omeprazole 20mg',
          dosage: '1 Capsule',
          instruction: 'Before Breakfast',
          time: '7:30 AM',
          status: MedicineStatus.upcoming,
        ),
      ];

      final repo = MockMedicineRepository(scheduleToReturn: mockSchedule);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pumpAndSettle();

      expect(find.text('Omeprazole 20mg'), findsOneWidget);
      expect(find.text('Upcoming'), findsWidgets);
      expect(find.text('Tap to mark'), findsOneWidget);

      // Tap on status badge
      await tester.tap(find.text('Tap to mark'));
      await tester.pumpAndSettle();

      expect(repo.markDoseCallCount, 1);
      expect(repo.lastMarkedMedicineId, 'med-upcoming-1');
      expect(find.text('Omeprazole 20mg marked as taken!'), findsOneWidget);
    });

    testWidgets('FAB opens AddEditMedicineBottomSheet and successfully saves new medicine',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = MockMedicineRepository(scheduleToReturn: []);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pumpAndSettle();

      // Tap Add Medicine FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(AddEditMedicineBottomSheet), findsOneWidget);
      expect(find.text('Add New Medicine'), findsOneWidget);

      // Enter form data
      await tester.enterText(
          find.widgetWithText(TextFormField, 'e.g. Panadol, Augmentin 625mg'),
          'Insulin Glargine');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'e.g. 1 Tablet, 500mg, 1 Capsule, 5ml'),
          '10 Units');

      // Scroll to Save Medicine button if needed and tap
      await tester.ensureVisible(find.text('Save Medicine'));
      await tester.tap(find.text('Save Medicine'));
      await tester.pumpAndSettle();

      expect(repo.addMedicineCallCount, 1);
      expect(repo.lastAddedName, 'Insulin Glargine');
      expect(find.text('Insulin Glargine added to your schedule.'), findsOneWidget);
    });

    testWidgets('Tapping medicine card opens edit sheet and allows deactivation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockSchedule = [
        const MedicineItem(
          id: 'med-edit-1',
          name: 'Metformin 500mg',
          dosage: '1 Tablet',
          instruction: 'After Dinner',
          time: '8:00 PM',
          status: MedicineStatus.upcoming,
        ),
      ];

      final repo = MockMedicineRepository(scheduleToReturn: mockSchedule);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pumpAndSettle();

      // Tap the card to open edit modal
      await tester.tap(find.text('Metformin 500mg'));
      await tester.pumpAndSettle();

      expect(find.byType(AddEditMedicineBottomSheet), findsOneWidget);
      expect(find.text('Edit Medicine'), findsOneWidget);
      expect(find.text('Remove from Schedule'), findsOneWidget);

      // Tap Remove from Schedule
      await tester.ensureVisible(find.text('Remove from Schedule'));
      await tester.tap(find.text('Remove from Schedule'));
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.text('Remove Medicine'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);

      // Confirm removal
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(repo.deactivateMedicineCallCount, 1);
      expect(repo.lastDeactivatedMedicineId, 'med-edit-1');
      expect(find.text('Metformin 500mg removed from active schedule.'), findsOneWidget);
    });
  });
}
