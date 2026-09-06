import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification_model.dart';

/// Repository responsible for loading and updating in-app notifications for the authenticated patient.
///
/// All database operations are authoritative and strictly scoped to
/// `Supabase.instance.client.auth.currentUser?.id`.
class NotificationRepository extends ChangeNotifier {
  final SupabaseClient? _clientOverride;

  NotificationRepository({SupabaseClient? client})
      : _clientOverride = client;

  static final NotificationRepository instance = NotificationRepository();

  SupabaseClient get _client {
    final override = _clientOverride;
    if (override != null) return override;
    return Supabase.instance.client;
  }

  /// Current authenticated user ID.
  String? get currentUserId {
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  List<AppNotificationModel> _notifications = [];
  int _unreadCount = 0;

  List<AppNotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _unreadCount;

  /// Fetches all notifications for the authenticated patient from Supabase.
  Future<List<AppNotificationModel>> getNotifications({
    bool unreadOnly = false,
  }) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      _notifications = [];
      _unreadCount = 0;
      notifyListeners();
      return [];
    }

    try {
      var query = _client
          .from('notifications')
          .select()
          .eq('user_id', userId);

      if (unreadOnly) {
        query = query.eq('is_read', false);
      }

      final response =
          await query.order('created_at', ascending: false);

      final items = (response as List)
          .map((item) => AppNotificationModel.fromMap(
              Map<String, dynamic>.from(item as Map)))
          .toList();

      if (!unreadOnly) {
        _notifications = items;
        _unreadCount = items.where((n) => !n.isRead).length;
        notifyListeners();
      }

      return items;
    } catch (e) {
      debugPrint('NotificationRepository: Error fetching notifications: $e');
      throw 'Unable to load notifications. Please check your connection.';
    }
  }

  /// Fetches the current count of unread notifications for the authenticated patient.
  Future<int> getUnreadCount() async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      _unreadCount = 0;
      notifyListeners();
      return 0;
    }

    try {
      final response = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      final count = (response as List).length;
      _unreadCount = count;
      notifyListeners();
      return count;
    } catch (e) {
      debugPrint('NotificationRepository: Error fetching unread count: $e');
      return _unreadCount;
    }
  }

  /// Marks a specific notification as read.
  Future<void> markAsRead(String notificationId) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty || notificationId.isEmpty) {
      return;
    }

    try {
      await _client
          .from('notifications')
          .update({
            'is_read': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId)
          .eq('user_id', userId);

      // Update local state
      _notifications = _notifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();

      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationRepository: Error marking notification as read: $e');
      throw 'Failed to update notification.';
    }
  }

  /// Marks all unread notifications as read for the authenticated patient.
  Future<void> markAllAsRead() async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      await _client
          .from('notifications')
          .update({
            'is_read': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_read', false);

      // Update local state
      _notifications = _notifications.map((n) {
        return n.copyWith(isRead: true);
      }).toList();

      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationRepository: Error marking all notifications as read: $e');
      throw 'Failed to mark all as read.';
    }
  }
}
