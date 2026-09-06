import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../features/home/models/patient_medicine_model.dart';

/// Service responsible for local application notifications, scheduled medicine reminders,
/// and Android notification channel management.
///
/// Emergency QR notification (channel: `sehatpass_emergency_medical_id_channel`, ID: 9110)
/// is kept completely separate and isolated in native Kotlin code.
class NotificationService {
  static const String medicinesChannelId = 'sehatpass_medicines_channel';
  static const String medicinesChannelName = 'Medicine Reminders';
  static const String medicinesChannelDescription =
      'Daily reminders for scheduled patient medications';

  static const String defaultNotificationTitle = 'Medication Reminder';
  static const String defaultNotificationBody =
      "It's time to take your scheduled medicine.";

  /// Reserved Notification ID used exclusively by native Android Emergency QR.
  static const int emergencyQrReservedNotificationId = 9110;

  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _isInitialized = false;

  /// Stream controller for notification tap events.
  final StreamController<String?> _tapPayloadController =
      StreamController<String?>.broadcast();

  Stream<String?> get onNotificationTap => _tapPayloadController.stream;

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _notificationsPlugin = plugin ?? FlutterLocalNotificationsPlugin();

  static final NotificationService instance = NotificationService();

  bool get isInitialized => _isInitialized;

  /// Initializes timezone database and local notifications plugin.
  Future<bool> initialize({
    void Function(NotificationResponse)? onDidReceiveNotificationResponse,
  }) async {
    if (_isInitialized) return true;

    try {
      // 1. Initialize timezone database
      tz_data.initializeTimeZones();
      _configureLocalTimezone();

      // 2. Configure Android & iOS initialization settings
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      final initialized = await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse:
            onDidReceiveNotificationResponse ?? _handleNotificationTap,
      );

      // 3. Create Android notification channel
      if (!kIsWeb && Platform.isAndroid) {
        await _createAndroidChannels();
      }

      _isInitialized = initialized ?? true;
      return _isInitialized;
    } catch (e) {
      debugPrint('NotificationService.initialize error: $e');
      return false;
    }
  }

  /// Configures local timezone safely.
  void _configureLocalTimezone() {
    try {
      final now = DateTime.now();
      final offsetMs = now.timeZoneOffset.inMilliseconds;
      final locationName = now.timeZoneName;

      // 1. Direct Olson match
      if (tz.timeZoneDatabase.locations.containsKey(locationName)) {
        tz.setLocalLocation(tz.getLocation(locationName));
        return;
      }

      // 2. Known regional alias (e.g. Pakistan Standard Time)
      if (locationName == 'PKT' || offsetMs == 5 * 3600 * 1000) {
        if (tz.timeZoneDatabase.locations.containsKey('Asia/Karachi')) {
          tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
          return;
        }
      }

      // 3. Match by offset in database
      final match = tz.timeZoneDatabase.locations.values.firstWhere(
        (loc) => loc.currentTimeZone.offset == offsetMs,
        orElse: () => tz.local,
      );
      tz.setLocalLocation(match);
    } catch (_) {
      // Default to existing tz.local
    }
  }

  /// Internal handler for notification tap.
  void _handleNotificationTap(NotificationResponse response) {
    debugPrint(
        'NotificationService: notification tapped with payload: ${response.payload}');
    _tapPayloadController.add(response.payload);
  }

  /// Creates required Android notification channels.
  Future<void> _createAndroidChannels() async {
    final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl == null) return;

    const medicinesChannel = AndroidNotificationChannel(
      medicinesChannelId,
      medicinesChannelName,
      description: medicinesChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await androidImpl.createNotificationChannel(medicinesChannel);
  }

  /// Checks if notification permission is granted on Android 13+ (or iOS).
  Future<bool> isPermissionGranted() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final areEnabled = await androidImpl.areNotificationsEnabled();
        return areEnabled ?? false;
      }
      return true;
    } else if (Platform.isIOS || Platform.isMacOS) {
      final darwinImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (darwinImpl != null) {
        final permissions = await darwinImpl.checkPermissions();
        return permissions?.isEnabled ?? false;
      }
    }
    return true;
  }

  /// Requests notification permission from the user on Android 13+ / iOS.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          final granted =
              await androidImpl.requestNotificationsPermission();
          return granted ?? false;
        }
      } else if (Platform.isIOS) {
        final darwinImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        if (darwinImpl != null) {
          final granted = await darwinImpl.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          return granted ?? false;
        }
      }
    } catch (e) {
      debugPrint('NotificationService.requestPermission error: $e');
    }
    return false;
  }

  /// Generates a deterministic positive 31-bit integer notification ID from a medicine ID string.
  ///
  /// Guarantees:
  /// 1. Consistent integer output for identical medicine ID.
  /// 2. Positive integer between 1000 and 2,147,483,647.
  /// 3. Never collides with [emergencyQrReservedNotificationId] (9110).
  static int getNotificationIdForMedicine(String medicineId) {
    if (medicineId.isEmpty) return 1001;

    // FNV-1a 32-bit hash
    var hash = 0x811c9dc5;
    for (var i = 0; i < medicineId.length; i++) {
      hash ^= medicineId.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }

    // Ensure range [1000, 2147483647]
    var id = (hash % (0x7FFFFFFF - 1000)) + 1000;

    // Explicitly protect against Emergency QR ID collision
    if (id == emergencyQrReservedNotificationId) {
      id = 9111;
    }

    return id;
  }

  /// Parses various scheduled time string formats into hour and minute.
  ///
  /// Supported formats:
  /// - 12-hour: `"08:00 AM"`, `"8:00 AM"`, `"12:30 PM"`, `"8:00 pm"`, `"9:15am"`
  /// - 24-hour: `"08:00"`, `"20:30"`, `"8:0"`, `"14:15"`
  ///
  /// Returns `null` for invalid or unparseable inputs.
  static ({int hour, int minute})? parseScheduledTime(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;

    final trimmed = timeStr.trim().toUpperCase();

    // Check for 12-hour AM/PM format
    final is12Hour = trimmed.contains('AM') || trimmed.contains('PM');
    final isPM = trimmed.contains('PM');

    final cleanStr =
        trimmed.replaceAll('AM', '').replaceAll('PM', '').trim();
    final parts = cleanStr.split(':');
    if (parts.length != 2) return null;

    final rawHour = int.tryParse(parts[0].trim());
    final rawMinute = int.tryParse(parts[1].trim());

    if (rawHour == null || rawMinute == null) return null;
    if (rawMinute < 0 || rawMinute > 59) return null;

    if (is12Hour) {
      if (rawHour < 1 || rawHour > 12) return null;
      int hour24;
      if (isPM) {
        hour24 = (rawHour == 12) ? 12 : rawHour + 12;
      } else {
        hour24 = (rawHour == 12) ? 0 : rawHour;
      }
      return (hour: hour24, minute: rawMinute);
    } else {
      if (rawHour < 0 || rawHour > 23) return null;
      return (hour: rawHour, minute: rawMinute);
    }
  }

  /// Calculates the next TZDateTime instance for a given daily hour and minute.
  ///
  /// Minute-level evaluation:
  /// - If [startDate] is strictly in the future, begins on [startDate] at hour:minute.
  /// - If scheduled minute is the current minute or later today, schedules for TODAY.
  ///   (If scheduled within the exact same minute and seconds have elapsed, adds 5 seconds
  ///   so Android AlarmManager receives a valid future timestamp).
  /// - Only rolls to TOMORROW if the scheduled minute has genuinely passed today.
  static tz.TZDateTime calculateNextScheduledDate({
    required int hour,
    required int minute,
    DateTime? startDate,
    tz.Location? location,
    DateTime? nowOverride,
  }) {
    final loc = location ?? tz.local;
    final now = nowOverride != null
        ? tz.TZDateTime.from(nowOverride, loc)
        : tz.TZDateTime.now(loc);

    // 1. Check if startDate is strictly in the future
    if (startDate != null) {
      final tzStartDate = tz.TZDateTime(
          loc, startDate.year, startDate.month, startDate.day, hour, minute);
      final todayDate = tz.TZDateTime(loc, now.year, now.month, now.day);
      final startOnlyDate =
          tz.TZDateTime(loc, startDate.year, startDate.month, startDate.day);
      if (startOnlyDate.isAfter(todayDate)) {
        return tzStartDate;
      }
    }

    // 2. Minute-level comparison for today
    final scheduledMinutes = hour * 60 + minute;
    final nowMinutes = now.hour * 60 + now.minute;

    if (scheduledMinutes >= nowMinutes) {
      // Scheduled time is today
      var scheduled =
          tz.TZDateTime(loc, now.year, now.month, now.day, hour, minute);
      if (!scheduled.isAfter(now)) {
        // Current minute in progress — schedule 5 seconds in future to ensure AlarmManager fires
        scheduled = now.add(const Duration(seconds: 5));
      }
      return scheduled;
    } else {
      // Scheduled minute has passed for today -> schedule for tomorrow
      final tomorrow = now.add(const Duration(days: 1));
      return tz.TZDateTime(
          loc, tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
    }
  }

  /// Schedules a recurring daily medicine reminder notification.
  ///
  /// [showMedicineName]: If true, includes the medicine name in the body.
  /// Defaults to false for lock-screen privacy.
  Future<bool> scheduleMedicineReminder(
    PatientMedicineModel medicine, {
    bool showMedicineName = false,
  }) async {
    if (!medicine.isActive) {
      await cancelMedicineReminder(medicine.id);
      return false;
    }

    final parsedTime = parseScheduledTime(medicine.scheduledTime);
    if (parsedTime == null) {
      debugPrint(
          'NotificationService: Invalid scheduled time "${medicine.scheduledTime}" for medicine ${medicine.id}');
      return false;
    }

    final notifId = getNotificationIdForMedicine(medicine.id);
    final scheduledDate = calculateNextScheduledDate(
      hour: parsedTime.hour,
      minute: parsedTime.minute,
      startDate: medicine.startDate,
    );

    final notificationBody = showMedicineName && medicine.name.isNotEmpty
        ? 'It\'s time to take your medicine: ${medicine.name}.'
        : defaultNotificationBody;

    final payload = jsonEncode({
      'type': 'medicine_reminder',
      'medicine_id': medicine.id,
      'patient_id': medicine.patientId,
      'scheduled_time': medicine.scheduledTime,
    });

    const androidDetails = AndroidNotificationDetails(
      medicinesChannelId,
      medicinesChannelName,
      channelDescription: medicinesChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.private,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        notifId,
        defaultNotificationTitle,
        notificationBody,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );

      debugPrint(
          'NotificationService: Scheduled daily reminder for medicine "${medicine.name}" (ID: $notifId) at ${parsedTime.hour}:${parsedTime.minute}');
      return true;
    } catch (e) {
      debugPrint('NotificationService.scheduleMedicineReminder error: $e');
      // Fallback for devices without exact alarm permission
      try {
        await _notificationsPlugin.zonedSchedule(
          notifId,
          defaultNotificationTitle,
          notificationBody,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
        return true;
      } catch (fallbackError) {
        debugPrint(
            'NotificationService: Inexact alarm fallback also failed: $fallbackError');
        return false;
      }
    }
  }

  /// Cancels an active medicine reminder by medicine ID.
  Future<void> cancelMedicineReminder(String medicineId) async {
    if (medicineId.isEmpty) return;
    final notifId = getNotificationIdForMedicine(medicineId);
    try {
      await _notificationsPlugin.cancel(notifId);
      debugPrint(
          'NotificationService: Cancelled reminder for medicine ID $medicineId (Notif ID: $notifId)');
    } catch (e) {
      debugPrint('NotificationService.cancelMedicineReminder error: $e');
    }
  }

  /// Cancels all medicine reminders for a given list of medicine IDs.
  Future<void> cancelAllMedicineReminders(List<String> medicineIds) async {
    for (final id in medicineIds) {
      await cancelMedicineReminder(id);
    }
  }

  /// Synchronizes all medicine reminders for the authenticated patient.
  ///
  /// Iterates through [medicines]:
  /// - If [isActive] == true and time is valid -> schedules reminder.
  /// - If [isActive] == false -> cancels reminder.
  Future<void> syncMedicineReminders(
    List<PatientMedicineModel> medicines, {
    bool showMedicineName = false,
  }) async {
    debugPrint(
        'NotificationService: Syncing ${medicines.length} medicine reminders...');
    for (final med in medicines) {
      if (med.isActive) {
        await scheduleMedicineReminder(med,
            showMedicineName: showMedicineName);
      } else {
        await cancelMedicineReminder(med.id);
      }
    }
  }

  /// Disposes resources.
  void dispose() {
    _tapPayloadController.close();
  }
}
