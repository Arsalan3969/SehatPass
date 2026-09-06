import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/features/home/models/patient_medicine_model.dart';
import 'package:sehatpass/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Fake implementation of [FlutterLocalNotificationsPlugin] to record calls in test environment.
class FakeLocalNotificationsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  bool initialized = false;
  InitializationSettings? lastInitSettings;

  final Map<int, String> scheduledNotifications = {};
  final List<int> cancelledNotificationIds = [];

  @override
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    void Function(NotificationResponse)? onDidReceiveNotificationResponse,
    void Function(NotificationResponse)?
        onDidReceiveBackgroundNotificationResponse,
  }) async {
    initialized = true;
    lastInitSettings = initializationSettings;
    return true;
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required AndroidScheduleMode androidScheduleMode,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
    UILocalNotificationDateInterpretation
        uiLocalNotificationDateInterpretation =
        UILocalNotificationDateInterpretation.absoluteTime,
  }) async {
    scheduledNotifications[id] = payload ?? '';
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {
    scheduledNotifications.remove(id);
    cancelledNotificationIds.add(id);
  }
}

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  group('A. Notification Service Initialization', () {
    test('initializes cleanly and registers settings without error', () async {
      final fakePlugin = FakeLocalNotificationsPlugin();
      final service = NotificationService(plugin: fakePlugin);

      expect(service.isInitialized, isFalse);
      final result = await service.initialize();

      expect(result, isTrue);
      expect(service.isInitialized, isTrue);
      expect(fakePlugin.initialized, isTrue);
      expect(fakePlugin.lastInitSettings, isNotNull);
    });
  });

  group('B. Valid Medicine Scheduled Time Parsing', () {
    test('parses 12-hour AM/PM formats accurately', () {
      final t1 = NotificationService.parseScheduledTime('08:00 AM');
      expect(t1, isNotNull);
      expect(t1!.hour, equals(8));
      expect(t1.minute, equals(0));

      final t2 = NotificationService.parseScheduledTime('8:30 PM');
      expect(t2, isNotNull);
      expect(t2!.hour, equals(20));
      expect(t2.minute, equals(30));

      final t3 = NotificationService.parseScheduledTime('12:00 AM');
      expect(t3, isNotNull);
      expect(t3!.hour, equals(0)); // Midnight
      expect(t3.minute, equals(0));

      final t4 = NotificationService.parseScheduledTime('12:45 PM');
      expect(t4, isNotNull);
      expect(t4!.hour, equals(12)); // Noon
      expect(t4.minute, equals(45));

      final t5 = NotificationService.parseScheduledTime('11:59 pm');
      expect(t5, isNotNull);
      expect(t5!.hour, equals(23));
      expect(t5.minute, equals(59));
    });

    test('parses 24-hour formats accurately', () {
      final t1 = NotificationService.parseScheduledTime('00:15');
      expect(t1, isNotNull);
      expect(t1!.hour, equals(0));
      expect(t1.minute, equals(15));

      final t2 = NotificationService.parseScheduledTime('14:30');
      expect(t2, isNotNull);
      expect(t2!.hour, equals(14));
      expect(t2.minute, equals(30));

      final t3 = NotificationService.parseScheduledTime('23:59');
      expect(t3, isNotNull);
      expect(t3!.hour, equals(23));
      expect(t3.minute, equals(59));

      final t4 = NotificationService.parseScheduledTime('7:05');
      expect(t4, isNotNull);
      expect(t4!.hour, equals(7));
      expect(t4.minute, equals(5));
    });
  });

  group('C. Invalid Scheduled Time Handling', () {
    test('returns null for empty, null, or malformed time strings', () {
      expect(NotificationService.parseScheduledTime(null), isNull);
      expect(NotificationService.parseScheduledTime(''), isNull);
      expect(NotificationService.parseScheduledTime('   '), isNull);
      expect(NotificationService.parseScheduledTime('invalid_time'), isNull);
      expect(NotificationService.parseScheduledTime('12'), isNull);
      expect(NotificationService.parseScheduledTime('25:00'), isNull);
      expect(NotificationService.parseScheduledTime('10:65'), isNull);
      expect(NotificationService.parseScheduledTime('13:00 PM'), isNull);
      expect(NotificationService.parseScheduledTime('0:00 AM'), isNull);
    });
  });

  group('D. Deterministic Notification ID Generation', () {
    test('generates stable, positive integer ID for identical UUID', () {
      const medId = 'e2b34c56-789a-4bc0-9876-123456789abc';
      final id1 = NotificationService.getNotificationIdForMedicine(medId);
      final id2 = NotificationService.getNotificationIdForMedicine(medId);

      expect(id1, equals(id2));
      expect(id1, isPositive);
      expect(id1, greaterThanOrEqualTo(1000));
      expect(id1, lessThanOrEqualTo(0x7FFFFFFF));
    });

    test('never generates Emergency QR reserved ID (9110)', () {
      // Test across 1000 varied medicine IDs
      for (var i = 0; i < 1000; i++) {
        final medId = 'med-uuid-$i-test-${i * 37}';
        final notifId = NotificationService.getNotificationIdForMedicine(medId);
        expect(notifId, isNot(equals(NotificationService.emergencyQrReservedNotificationId)));
      }
    });
  });

  group('E. Scheduling an Active Medicine', () {
    test('schedules daily reminder for valid active medicine', () async {
      final fakePlugin = FakeLocalNotificationsPlugin();
      final service = NotificationService(plugin: fakePlugin);

      const med = PatientMedicineModel(
        id: 'med-active-001',
        patientId: 'patient-123',
        name: 'Panadol 500mg',
        dosage: '1 tablet',
        instruction: 'After meal',
        scheduledTime: '09:00 AM',
        isActive: true,
      );

      final success = await service.scheduleMedicineReminder(med);
      expect(success, isTrue);

      final expectedId = NotificationService.getNotificationIdForMedicine(med.id);
      expect(fakePlugin.scheduledNotifications.containsKey(expectedId), isTrue);
      expect(fakePlugin.scheduledNotifications[expectedId], contains('med-active-001'));
    });
  });

  group('F. Cancelling an Edited or Deactivated Medicine', () {
    test('cancels scheduled reminder by medicine ID', () async {
      final fakePlugin = FakeLocalNotificationsPlugin();
      final service = NotificationService(plugin: fakePlugin);

      const med = PatientMedicineModel(
        id: 'med-cancel-002',
        patientId: 'patient-123',
        name: 'Amoxicillin 250mg',
        dosage: '1 capsule',
        instruction: 'With water',
        scheduledTime: '02:00 PM',
        isActive: true,
      );

      await service.scheduleMedicineReminder(med);
      final expectedId = NotificationService.getNotificationIdForMedicine(med.id);
      expect(fakePlugin.scheduledNotifications.containsKey(expectedId), isTrue);

      await service.cancelMedicineReminder(med.id);
      expect(fakePlugin.scheduledNotifications.containsKey(expectedId), isFalse);
      expect(fakePlugin.cancelledNotificationIds, contains(expectedId));
    });
  });

  group('G. Multiple Medicines Do Not Collide', () {
    test('generates distinct IDs and schedules all medicines concurrently', () async {
      final fakePlugin = FakeLocalNotificationsPlugin();
      final service = NotificationService(plugin: fakePlugin);

      final medicines = [
        const PatientMedicineModel(
          id: 'med-101-alpha',
          patientId: 'patient-1',
          name: 'Aspirin',
          dosage: '75mg',
          instruction: 'Daily',
          scheduledTime: '08:00 AM',
          isActive: true,
        ),
        const PatientMedicineModel(
          id: 'med-102-beta',
          patientId: 'patient-1',
          name: 'Metformin',
          dosage: '500mg',
          instruction: 'Morning',
          scheduledTime: '09:00 AM',
          isActive: true,
        ),
        const PatientMedicineModel(
          id: 'med-103-gamma',
          patientId: 'patient-1',
          name: 'Lisinopril',
          dosage: '10mg',
          instruction: 'Evening',
          scheduledTime: '08:00 PM',
          isActive: true,
        ),
      ];

      await service.syncMedicineReminders(medicines);

      final id1 = NotificationService.getNotificationIdForMedicine('med-101-alpha');
      final id2 = NotificationService.getNotificationIdForMedicine('med-102-beta');
      final id3 = NotificationService.getNotificationIdForMedicine('med-103-gamma');

      expect(id1 != id2, isTrue);
      expect(id2 != id3, isTrue);
      expect(id1 != id3, isTrue);

      expect(fakePlugin.scheduledNotifications.length, equals(3));
      expect(fakePlugin.scheduledNotifications.containsKey(id1), isTrue);
      expect(fakePlugin.scheduledNotifications.containsKey(id2), isTrue);
      expect(fakePlugin.scheduledNotifications.containsKey(id3), isTrue);
    });
  });

  group('H. Inactive Medicines Are Not Scheduled', () {
    test('returns false and cancels reminder if medicine is inactive', () async {
      final fakePlugin = FakeLocalNotificationsPlugin();
      final service = NotificationService(plugin: fakePlugin);

      const medInactive = PatientMedicineModel(
        id: 'med-inactive-004',
        patientId: 'patient-123',
        name: 'Omeprazole',
        dosage: '20mg',
        instruction: 'Before breakfast',
        scheduledTime: '07:30 AM',
        isActive: false,
      );

      final success = await service.scheduleMedicineReminder(medInactive);
      expect(success, isFalse);

      final expectedId = NotificationService.getNotificationIdForMedicine(medInactive.id);
      expect(fakePlugin.scheduledNotifications.containsKey(expectedId), isFalse);
    });
  });

  group('I. Medicine Start Date and Minute-Level Scheduling Calculations', () {
    test('calculates future start date when startDate is in future', () {
      final futureDate = DateTime(2026, 9, 15, 8, 0);
      final nowOverride = DateTime(2026, 9, 6, 12, 0);
      final calculated = NotificationService.calculateNextScheduledDate(
        hour: 10,
        minute: 0,
        startDate: futureDate,
        nowOverride: nowOverride,
      );

      expect(calculated.year, equals(2026));
      expect(calculated.month, equals(9));
      expect(calculated.day, equals(15));
      expect(calculated.hour, equals(10));
      expect(calculated.minute, equals(0));
    });

    test('schedules for TODAY when scheduled minute is in the future today', () {
      // now = 16:54:30, scheduled = 16:55
      final nowOverride = DateTime(2026, 9, 6, 16, 54, 30);
      final calculated = NotificationService.calculateNextScheduledDate(
        hour: 16,
        minute: 55,
        nowOverride: nowOverride,
      );

      expect(calculated.year, equals(2026));
      expect(calculated.month, equals(9));
      expect(calculated.day, equals(6));
      expect(calculated.hour, equals(16));
      expect(calculated.minute, equals(55));
      expect(calculated.second, equals(0));
    });

    test('schedules for TODAY with 5-second offset when scheduled in current minute with seconds elapsed', () {
      // now = 16:55:20, scheduled = 16:55
      final nowOverride = DateTime(2026, 9, 6, 16, 55, 20);
      final calculated = NotificationService.calculateNextScheduledDate(
        hour: 16,
        minute: 55,
        nowOverride: nowOverride,
      );

      expect(calculated.year, equals(2026));
      expect(calculated.month, equals(9));
      expect(calculated.day, equals(6));
      expect(calculated.hour, equals(16));
      expect(calculated.minute, equals(55));
      expect(calculated.second, equals(25)); // now + 5s
    });

    test('schedules for TOMORROW when scheduled minute has already passed today', () {
      // now = 16:56:00, scheduled = 16:55
      final nowOverride = DateTime(2026, 9, 6, 16, 56, 0);
      final calculated = NotificationService.calculateNextScheduledDate(
        hour: 16,
        minute: 55,
        nowOverride: nowOverride,
      );

      expect(calculated.year, equals(2026));
      expect(calculated.month, equals(9));
      expect(calculated.day, equals(7)); // Tomorrow
      expect(calculated.hour, equals(16));
      expect(calculated.minute, equals(55));
      expect(calculated.second, equals(0));
    });

    test('handles midnight rollover correctly', () {
      // now = 23:59:30, scheduled = 00:05
      final nowOverride = DateTime(2026, 9, 6, 23, 59, 30);
      final calculated = NotificationService.calculateNextScheduledDate(
        hour: 0,
        minute: 5,
        nowOverride: nowOverride,
      );

      expect(calculated.year, equals(2026));
      expect(calculated.month, equals(9));
      expect(calculated.day, equals(7)); // Next day
      expect(calculated.hour, equals(0));
      expect(calculated.minute, equals(5));
    });
  });

  group('J. Emergency QR Notification Isolation & Channel Separation', () {
    test('medicines channel ID and Emergency QR channel ID are completely distinct', () {
      const emergencyChannelId = 'sehatpass_emergency_medical_id_channel';
      expect(NotificationService.medicinesChannelId, isNot(equals(emergencyChannelId)));
      expect(NotificationService.medicinesChannelId, equals('sehatpass_medicines_channel'));
    });

    test('Emergency QR reserved notification ID is 9110 and medicine notifications never use 9110', () {
      expect(NotificationService.emergencyQrReservedNotificationId, equals(9110));
      for (var i = 0; i < 500; i++) {
        final id = NotificationService.getNotificationIdForMedicine('test-key-$i');
        expect(id, isNot(equals(9110)));
      }
    });

    test('default medicine notification title and body respect privacy without clinical leakage', () {
      expect(NotificationService.defaultNotificationTitle, equals('Medication Reminder'));
      expect(NotificationService.defaultNotificationBody,
          equals("It's time to take your scheduled medicine."));
      expect(NotificationService.defaultNotificationBody.toLowerCase(),
          isNot(contains('diagnosis')));
      expect(NotificationService.defaultNotificationBody.toLowerCase(),
          isNot(contains('cancer')));
      expect(NotificationService.defaultNotificationBody.toLowerCase(),
          isNot(contains('emergency')));
    });
  });
}
