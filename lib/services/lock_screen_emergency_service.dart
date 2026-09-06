import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LockScreenEmergencyService {
  static const MethodChannel _channel =
      MethodChannel('com.example.sehatpass/lockscreen_emergency');

  static LockScreenEmergencyService instance = LockScreenEmergencyService();

  /// Check whether lock-screen emergency access is currently enabled on the device.
  Future<bool> isEnabled() async {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }
    try {
      final bool? enabled = await _channel.invokeMethod<bool>('isEnabled');
      return enabled ?? false;
    } catch (e) {
      debugPrint('LockScreenEmergencyService.isEnabled error: $e');
      return false;
    }
  }

  /// Check if notification permission (POST_NOTIFICATIONS on Android 13+) is granted.
  Future<bool> isNotificationPermissionGranted() async {
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }
    try {
      final bool? granted =
          await _channel.invokeMethod<bool>('isNotificationPermissionGranted');
      return granted ?? false;
    } catch (e) {
      debugPrint(
          'LockScreenEmergencyService.isNotificationPermissionGranted error: $e');
      return true;
    }
  }

  /// Request notification permission on Android 13+ (API 33+).
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }
    try {
      final bool? granted =
          await _channel.invokeMethod<bool>('requestNotificationPermission');
      return granted ?? false;
    } catch (e) {
      debugPrint(
          'LockScreenEmergencyService.requestNotificationPermission error: $e');
      return true;
    }
  }

  /// Enables the lock-screen emergency QR notification and saves patient emergency data locally.
  Future<bool> enable({
    required String qrUrl,
    required String patientName,
    required String bloodGroup,
    String? emergencyContact,
    String? token,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }
    try {
      final bool? success = await _channel.invokeMethod<bool>('enable', {
        'qrUrl': qrUrl,
        'patientName': patientName,
        'bloodGroup': bloodGroup,
        'emergencyContact': emergencyContact,
        'token': token,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('LockScreenEmergencyService.enable error: $e');
      return false;
    }
  }

  /// Updates emergency data if lock-screen emergency access is active.
  Future<bool> updateData({
    required String qrUrl,
    required String patientName,
    required String bloodGroup,
    String? emergencyContact,
    String? token,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }
    try {
      final bool? success = await _channel.invokeMethod<bool>('updateData', {
        'qrUrl': qrUrl,
        'patientName': patientName,
        'bloodGroup': bloodGroup,
        'emergencyContact': emergencyContact,
        'token': token,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('LockScreenEmergencyService.updateData error: $e');
      return false;
    }
  }

  /// Disables lock-screen emergency access, removes persistent notification, and clears stored data.
  Future<bool> disable() async {
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }
    try {
      final bool? success = await _channel.invokeMethod<bool>('disable');
      return success ?? true;
    } catch (e) {
      debugPrint('LockScreenEmergencyService.disable error: $e');
      return false;
    }
  }
}
