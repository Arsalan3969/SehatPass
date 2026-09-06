import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Notification categories supported by SehatPass.
enum AppNotificationType {
  appointment,
  consultation,
  medicine,
  report,
  system;

  static AppNotificationType fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'appointment':
      case 'appointment_booked':
      case 'appointment_confirmed':
      case 'appointment_cancelled':
        return AppNotificationType.appointment;
      case 'consultation':
      case 'consultation_completed':
      case 'prescription':
        return AppNotificationType.consultation;
      case 'medicine':
      case 'medicine_reminder':
      case 'medicine_added':
        return AppNotificationType.medicine;
      case 'report':
      case 'report_uploaded':
      case 'report_ready':
        return AppNotificationType.report;
      case 'system':
      case 'security':
      default:
        return AppNotificationType.system;
    }
  }

  String get label {
    switch (this) {
      case AppNotificationType.appointment:
        return 'Appointment';
      case AppNotificationType.consultation:
        return 'Consultation';
      case AppNotificationType.medicine:
        return 'Medicine';
      case AppNotificationType.report:
        return 'Medical Report';
      case AppNotificationType.system:
        return 'System';
    }
  }

  IconData get icon {
    switch (this) {
      case AppNotificationType.appointment:
        return Icons.calendar_month_rounded;
      case AppNotificationType.consultation:
        return Icons.medical_services_rounded;
      case AppNotificationType.medicine:
        return Icons.medication_rounded;
      case AppNotificationType.report:
        return Icons.description_rounded;
      case AppNotificationType.system:
        return Icons.notifications_rounded;
    }
  }

  Color get primaryColor {
    switch (this) {
      case AppNotificationType.appointment:
        return const Color(0xFF1E88E5); // Blue
      case AppNotificationType.consultation:
        return const Color(0xFF00897B); // Teal
      case AppNotificationType.medicine:
        return AppColors.primary; // Forest Green
      case AppNotificationType.report:
        return const Color(0xFF8E24AA); // Purple
      case AppNotificationType.system:
        return const Color(0xFF546E7A); // Slate Grey
    }
  }

  Color get surfaceColor {
    switch (this) {
      case AppNotificationType.appointment:
        return const Color(0xFFE3F2FD);
      case AppNotificationType.consultation:
        return const Color(0xFFE0F2F1);
      case AppNotificationType.medicine:
        return AppColors.primarySurface;
      case AppNotificationType.report:
        return const Color(0xFFF3E5F5);
      case AppNotificationType.system:
        return const Color(0xFFECEFF1);
    }
  }
}

/// Data model representing an in-app notification stored in Supabase.
class AppNotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String rawType;
  final bool isRead;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppNotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.rawType,
    required this.isRead,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
  });

  AppNotificationType get type => AppNotificationType.fromString(rawType);

  /// Safe deserialization from Supabase JSON record.
  factory AppNotificationModel.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> safePayload = {};
    if (map['payload'] != null && map['payload'] is Map) {
      safePayload = Map<String, dynamic>.from(map['payload'] as Map);
    }

    final createdAtStr = map['created_at']?.toString();
    final updatedAtStr = map['updated_at']?.toString();

    return AppNotificationModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      rawType: map['type']?.toString() ?? 'system',
      isRead: map['is_read'] == true,
      payload: safePayload,
      createdAt: createdAtStr != null
          ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: updatedAtStr != null
          ? DateTime.tryParse(updatedAtStr) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'type': rawType,
      'is_read': isRead,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AppNotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? rawType,
    bool? isRead,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      rawType: rawType ?? this.rawType,
      isRead: isRead ?? this.isRead,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Formats relative timestamp (e.g. "Just now", "5m ago", "2h ago", "Yesterday", "3d ago", "DD MMM").
  String formatRelativeTime({DateTime? nowOverride}) {
    final now = nowOverride ?? DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.isNegative || difference.inSeconds < 45) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '${mins}m ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '${hours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final month = months[createdAt.month - 1];
      return '${createdAt.day} $month';
    }
  }

  /// Target appointment ID from payload if present.
  String? get appointmentId => payload['appointment_id']?.toString();

  /// Target report ID from payload if present.
  String? get reportId => payload['report_id']?.toString();

  /// Target medicine ID from payload if present.
  String? get medicineId => payload['medicine_id']?.toString();

  /// Target tab index if explicitly specified in payload.
  int? get targetTab {
    final rawTab = payload['target_tab'];
    if (rawTab is int) return rawTab;
    if (rawTab is String) return int.tryParse(rawTab);
    return null;
  }
}
