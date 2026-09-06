import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/features/home/widgets/home_greeting_bar.dart';
import 'package:sehatpass/features/notifications/data/notification_repository.dart';
import 'package:sehatpass/features/notifications/models/app_notification_model.dart';
import 'package:sehatpass/features/notifications/notifications_screen.dart';

/// Fake In-Memory Notification Repository for fast and isolated unit & widget testing.
class FakeNotificationRepository extends NotificationRepository {
  List<AppNotificationModel> items;
  final String? errorToThrow;
  int getNotificationsCallCount = 0;
  int getUnreadCountCallCount = 0;
  int markAsReadCallCount = 0;
  int markAllAsReadCallCount = 0;
  String? lastMarkedReadId;

  FakeNotificationRepository({
    this.items = const [],
    this.errorToThrow,
  });

  @override
  String? get currentUserId => 'test-patient-user-123';

  @override
  List<AppNotificationModel> get notifications => List.unmodifiable(items);

  @override
  int get unreadCount => items.where((n) => !n.isRead).length;

  @override
  Future<List<AppNotificationModel>> getNotifications({bool unreadOnly = false}) async {
    getNotificationsCallCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    if (unreadOnly) {
      return items.where((n) => !n.isRead).toList();
    }
    return items;
  }

  @override
  Future<int> getUnreadCount() async {
    getUnreadCountCallCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return items.where((n) => !n.isRead).length;
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    markAsReadCallCount++;
    lastMarkedReadId = notificationId;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    items = items.map((n) {
      if (n.id == notificationId) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
    notifyListeners();
  }

  @override
  Future<void> markAllAsRead() async {
    markAllAsReadCallCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    items = items.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }
}

void main() {
  group('A. AppNotificationModel Unit Tests', () {
    test('deserializes safely from Supabase map with all standard fields', () {
      final map = {
        'id': 'notif-001',
        'user_id': 'user-123',
        'title': 'Appointment Confirmed',
        'message': 'Your appointment with Dr. Sara Khan is confirmed.',
        'type': 'appointment_confirmed',
        'is_read': false,
        'payload': {
          'appointment_id': 'apt-999',
          'target_tab': 0,
        },
        'created_at': '2026-09-06T10:00:00Z',
        'updated_at': '2026-09-06T10:00:00Z',
      };

      final model = AppNotificationModel.fromMap(map);

      expect(model.id, equals('notif-001'));
      expect(model.userId, equals('user-123'));
      expect(model.title, equals('Appointment Confirmed'));
      expect(model.message, equals('Your appointment with Dr. Sara Khan is confirmed.'));
      expect(model.type, equals(AppNotificationType.appointment));
      expect(model.isRead, isFalse);
      expect(model.appointmentId, equals('apt-999'));
      expect(model.targetTab, equals(0));
      expect(model.createdAt.year, equals(2026));
    });

    test('handles null, empty, and non-map payload defensively without crashing', () {
      final map = {
        'id': 'notif-002',
        'user_id': 'user-123',
        'title': 'Welcome to SehatPass',
        'message': 'Your emergency digital ID is ready.',
        'type': 'system',
        'is_read': true,
        'payload': null,
      };

      final model = AppNotificationModel.fromMap(map);

      expect(model.id, equals('notif-002'));
      expect(model.payload, isEmpty);
      expect(model.appointmentId, isNull);
      expect(model.reportId, isNull);
      expect(model.medicineId, isNull);
      expect(model.targetTab, isNull);
      expect(model.type, equals(AppNotificationType.system));
    });

    test('parses notification types and returns appropriate labels, icons, and colors', () {
      expect(AppNotificationType.fromString('appointment').label, equals('Appointment'));
      expect(AppNotificationType.fromString('consultation_completed').label, equals('Consultation'));
      expect(AppNotificationType.fromString('medicine_reminder').label, equals('Medicine'));
      expect(AppNotificationType.fromString('report_uploaded').label, equals('Medical Report'));
      expect(AppNotificationType.fromString('unknown_type').label, equals('System'));
      expect(AppNotificationType.fromString(null).label, equals('System'));
    });

    test('formatRelativeTime formats durations accurately', () {
      final refTime = DateTime(2026, 9, 6, 12, 0, 0);

      // Just now (< 45s)
      final notifJustNow = AppNotificationModel(
        id: '1',
        userId: 'u1',
        title: 'T1',
        message: 'M1',
        rawType: 'system',
        isRead: false,
        payload: const {},
        createdAt: refTime.subtract(const Duration(seconds: 20)),
        updatedAt: refTime,
      );
      expect(notifJustNow.formatRelativeTime(nowOverride: refTime), equals('Just now'));

      // Minutes ago (5m)
      final notif5m = notifJustNow.copyWith(
        createdAt: refTime.subtract(const Duration(minutes: 5)),
      );
      expect(notif5m.formatRelativeTime(nowOverride: refTime), equals('5m ago'));

      // Hours ago (3h)
      final notif3h = notifJustNow.copyWith(
        createdAt: refTime.subtract(const Duration(hours: 3)),
      );
      expect(notif3h.formatRelativeTime(nowOverride: refTime), equals('3h ago'));

      // Yesterday (1 day)
      final notifYesterday = notifJustNow.copyWith(
        createdAt: refTime.subtract(const Duration(days: 1)),
      );
      expect(notifYesterday.formatRelativeTime(nowOverride: refTime), equals('Yesterday'));

      // Days ago (4 days)
      final notif4d = notifJustNow.copyWith(
        createdAt: refTime.subtract(const Duration(days: 4)),
      );
      expect(notif4d.formatRelativeTime(nowOverride: refTime), equals('4d ago'));
    });
  });

  group('B. NotificationRepository Logic Tests', () {
    test('marks individual notification as read in repository', () async {
      final initial = [
        AppNotificationModel(
          id: 'n1',
          userId: 'test-patient-user-123',
          title: 'Prescription Added',
          message: 'Dr. Ahmad prescribed Amoxicillin.',
          rawType: 'consultation',
          isRead: false,
          payload: const {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        AppNotificationModel(
          id: 'n2',
          userId: 'test-patient-user-123',
          title: 'Report Uploaded',
          message: 'CBC blood test report is ready.',
          rawType: 'report',
          isRead: false,
          payload: const {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final repo = FakeNotificationRepository(items: initial);

      expect(repo.unreadCount, equals(2));
      await repo.markAsRead('n1');

      expect(repo.markAsReadCallCount, equals(1));
      expect(repo.lastMarkedReadId, equals('n1'));
      expect(repo.unreadCount, equals(1));
      expect(repo.notifications.firstWhere((n) => n.id == 'n1').isRead, isTrue);
      expect(repo.notifications.firstWhere((n) => n.id == 'n2').isRead, isFalse);
    });

    test('marks all notifications as read in repository', () async {
      final initial = [
        AppNotificationModel(
          id: 'n1',
          userId: 'test-patient-user-123',
          title: 'N1',
          message: 'M1',
          rawType: 'system',
          isRead: false,
          payload: const {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        AppNotificationModel(
          id: 'n2',
          userId: 'test-patient-user-123',
          title: 'N2',
          message: 'M2',
          rawType: 'medicine',
          isRead: false,
          payload: const {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final repo = FakeNotificationRepository(items: initial);

      expect(repo.unreadCount, equals(2));
      await repo.markAllAsRead();

      expect(repo.markAllAsReadCallCount, equals(1));
      expect(repo.unreadCount, equals(0));
      expect(repo.notifications.every((n) => n.isRead), isTrue);
    });
  });

  group('C. NotificationsScreen Widget Tests', () {
    Widget buildTestScreen(NotificationRepository repo) {
      return MaterialApp(
        theme: AppTheme.light,
        home: NotificationsScreen(repository: repo),
      );
    }

    testWidgets('renders empty state when no notifications exist', (tester) async {
      final repo = FakeNotificationRepository(items: []);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('No notifications yet'), findsOneWidget);
      expect(find.text('We will notify you about upcoming appointments, medical reports, and health updates.'), findsOneWidget);
    });

    testWidgets('renders list of notifications with unread counts and filter chips', (tester) async {
      final testItems = [
        AppNotificationModel(
          id: 'n1',
          userId: 'user-1',
          title: 'Appointment Confirmed',
          message: 'Dr. Sara is ready for consultation.',
          rawType: 'appointment',
          isRead: false,
          payload: const {'appointment_id': 'apt-101'},
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
          updatedAt: DateTime.now(),
        ),
        AppNotificationModel(
          id: 'n2',
          userId: 'user-1',
          title: 'Blood Test Results',
          message: 'Your lipid panel report is available.',
          rawType: 'report',
          isRead: true,
          payload: const {'report_id': 'rep-202'},
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          updatedAt: DateTime.now(),
        ),
      ];

      final repo = FakeNotificationRepository(items: testItems);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pumpAndSettle();

      // App bar and unread badge
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Mark all as read'), findsOneWidget);

      // Filter chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);

      // Cards
      expect(find.text('Appointment Confirmed'), findsOneWidget);
      expect(find.text('Blood Test Results'), findsOneWidget);

      // Tap "Unread" filter chip
      await tester.tap(find.text('Unread'));
      await tester.pumpAndSettle();

      // Only unread item should be visible
      expect(find.text('Appointment Confirmed'), findsOneWidget);
      expect(find.text('Blood Test Results'), findsNothing);
    });

    testWidgets('tapping "Mark all as read" marks all notifications read', (tester) async {
      final testItems = [
        AppNotificationModel(
          id: 'n1',
          userId: 'user-1',
          title: 'Alert 1',
          message: 'Message 1',
          rawType: 'system',
          isRead: false,
          payload: const {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final repo = FakeNotificationRepository(items: testItems);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pumpAndSettle();

      expect(find.text('Mark all as read'), findsOneWidget);

      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();

      expect(repo.markAllAsReadCallCount, equals(1));
      expect(find.text('All notifications marked as read.'), findsOneWidget);
    });

    testWidgets('tapping an unread notification calls markAsRead on repository', (tester) async {
      final testItems = [
        AppNotificationModel(
          id: 'n-sys',
          userId: 'user-1',
          title: 'System Notice',
          message: 'Your emergency settings have been updated.',
          rawType: 'system',
          isRead: false,
          payload: const {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final repo = FakeNotificationRepository(items: testItems);

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('System Notice'));
      await tester.pumpAndSettle();

      expect(repo.markAsReadCallCount, equals(1));
      expect(repo.lastMarkedReadId, equals('n-sys'));
    });
  });

  group('D. HomeGreetingBar Interactive Tests', () {
    testWidgets('renders unread indicator dot when unreadCount > 0 and invokes tap callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: HomeGreetingBar(
              patientName: 'Ali',
              unreadCount: 3,
              onNotificationTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ali 👋'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);

      // Unread dot container exists via Positioned widget inside Stack
      expect(find.byType(Positioned), findsOneWidget);

      // Tap notification bell
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('hides unread dot when unreadCount is 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomeGreetingBar(
              patientName: 'Ali',
              unreadCount: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      // No unread dot Positioned widget exists
      expect(find.byType(Positioned), findsNothing);
    });
  });

  group('E. Doctor Notification Center & Dashboard Tests', () {
    test('parses doctor appointment requested and cancelled notification payloads', () {
      final reqMap = {
        'id': 'doc-notif-001',
        'user_id': 'doc-123',
        'title': 'New Appointment Request',
        'message': 'Ali requested an appointment for General Consultation on Sep 10, 2026 at 10:00 AM.',
        'type': 'appointment',
        'is_read': false,
        'payload': {
          'appointment_id': 'apt-doc-001',
          'event': 'requested',
          'patient_id': 'patient-001',
        },
        'created_at': '2026-09-06T10:00:00Z',
        'updated_at': '2026-09-06T10:00:00Z',
      };

      final reqModel = AppNotificationModel.fromMap(reqMap);
      expect(reqModel.title, equals('New Appointment Request'));
      expect(reqModel.appointmentId, equals('apt-doc-001'));
      expect(reqModel.payload['event'], equals('requested'));
      expect(reqModel.payload['patient_id'], equals('patient-001'));

      final cancelMap = {
        'id': 'doc-notif-002',
        'user_id': 'doc-123',
        'title': 'Appointment Cancelled',
        'message': 'Appointment with Ali on Sep 10, 2026 at 10:00 AM has been cancelled by the patient.',
        'type': 'appointment',
        'is_read': false,
        'payload': {
          'appointment_id': 'apt-doc-001',
          'event': 'cancelled_by_patient',
          'patient_id': 'patient-001',
        },
        'created_at': '2026-09-06T11:00:00Z',
        'updated_at': '2026-09-06T11:00:00Z',
      };

      final cancelModel = AppNotificationModel.fromMap(cancelMap);
      expect(cancelModel.title, equals('Appointment Cancelled'));
      expect(cancelModel.payload['event'], equals('cancelled_by_patient'));
    });

    test('parses doctor patient report notification payload', () {
      final reportMap = {
        'id': 'doc-notif-003',
        'user_id': 'doc-123',
        'title': 'New Patient Report',
        'message': 'Patient Ali uploaded report "CBC Blood Test".',
        'type': 'report',
        'is_read': false,
        'payload': {
          'report_id': 'rep-doc-001',
          'event': 'patient_report_uploaded',
          'patient_id': 'patient-001',
        },
        'created_at': '2026-09-06T12:00:00Z',
        'updated_at': '2026-09-06T12:00:00Z',
      };

      final reportModel = AppNotificationModel.fromMap(reportMap);
      expect(reportModel.title, equals('New Patient Report'));
      expect(reportModel.payload['event'], equals('patient_report_uploaded'));
      expect(reportModel.payload['patient_id'], equals('patient-001'));
    });

    testWidgets('NotificationsScreen with isDoctor: true renders doctor notifications correctly', (tester) async {
      final testItems = [
        AppNotificationModel(
          id: 'doc-n1',
          userId: 'doc-123',
          title: 'New Appointment Request',
          message: 'Ali requested General Consultation.',
          rawType: 'appointment',
          isRead: false,
          payload: {'appointment_id': 'apt-1', 'event': 'requested', 'patient_id': 'p-1'},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        AppNotificationModel(
          id: 'doc-n2',
          userId: 'doc-123',
          title: 'New Patient Report',
          message: 'Patient Ali uploaded CBC report.',
          rawType: 'report',
          isRead: true,
          payload: {'report_id': 'rep-1', 'event': 'patient_report_uploaded', 'patient_id': 'p-1'},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final repo = FakeNotificationRepository(items: testItems);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: NotificationsScreen(
            repository: repo,
            isDoctor: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('New Appointment Request'), findsOneWidget);
      expect(find.text('New Patient Report'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2)); // Header count and filter chip
    });

    testWidgets('Doctor tapping notification marks as read and shows fallback when object not found', (tester) async {
      final testItems = [
        AppNotificationModel(
          id: 'doc-n1',
          userId: 'doc-123',
          title: 'New Appointment Request',
          message: 'Ali requested General Consultation.',
          rawType: 'appointment',
          isRead: false,
          payload: {'appointment_id': 'apt-missing', 'event': 'requested'},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final repo = FakeNotificationRepository(items: testItems);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: NotificationsScreen(
            repository: repo,
            isDoctor: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Appointment Request'));
      await tester.pumpAndSettle();

      expect(repo.markAsReadCallCount, equals(1));
      expect(repo.lastMarkedReadId, equals('doc-n1'));
    });
  });
}
