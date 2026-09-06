import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../app/app_shell.dart';
import '../appointments/my_appointments_screen.dart';
import '../doctor/appointments/doctor_appointment_details_screen.dart';
import '../doctor/data/doctor_repository.dart';
import '../doctor/patients/doctor_patient_detail_screen.dart';
import 'data/notification_repository.dart';
import 'models/app_notification_model.dart';

/// In-app Notification Center screen for patient and doctor alerts, updates, and reminders.
class NotificationsScreen extends StatefulWidget {
  final NotificationRepository? repository;
  final bool? isDoctor;

  const NotificationsScreen({
    super.key,
    this.repository,
    this.isDoctor,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationRepository get _repo =>
      widget.repository ?? NotificationRepository.instance;

  List<AppNotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedFilterIndex = 0; // 0: All, 1: Unread

  bool get _isDoctor => widget.isDoctor ?? false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _repo.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is String ? e : 'Unable to load notifications.';
        _isLoading = false;
      });
    }
  }

  List<AppNotificationModel> get _filteredNotifications {
    if (_selectedFilterIndex == 1) {
      return _notifications.where((n) => !n.isRead).toList();
    }
    return _notifications;
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> _handleMarkAllAsRead() async {
    try {
      await _repo.markAllAsRead();
      if (mounted) {
        setState(() {
          _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.emergency,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleNotificationTap(AppNotificationModel notification) async {
    // 1. Mark as read if not already
    if (!notification.isRead) {
      try {
        await _repo.markAsRead(notification.id);
        if (mounted) {
          setState(() {
            _notifications = _notifications.map((n) {
              if (n.id == notification.id) {
                return n.copyWith(isRead: true);
              }
              return n;
            }).toList();
          });
        }
      } catch (_) {}
    }

    if (!mounted) return;

    // 2. Role-aware deep navigation
    if (_isDoctor) {
      await _handleDoctorNavigation(notification);
    } else {
      await _handlePatientNavigation(notification);
    }
  }

  Future<void> _handleDoctorNavigation(AppNotificationModel notification) async {
    switch (notification.type) {
      case AppNotificationType.appointment:
        final appointmentId = notification.payload['appointment_id']?.toString();
        if (appointmentId != null && appointmentId.isNotEmpty) {
          try {
            final apt = await DoctorRepository.instance.getDoctorAppointmentById(appointmentId);
            if (!mounted) return;
            if (apt != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DoctorAppointmentDetailsScreen(
                    appointment: apt,
                  ),
                ),
              );
              return;
            }
          } catch (_) {}
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appointment details are unavailable or no longer exist.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;

      case AppNotificationType.report:
        final patientId = notification.payload['patient_id']?.toString();
        if (patientId != null && patientId.isNotEmpty) {
          try {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DoctorPatientDetailScreen(
                  patientId: patientId,
                ),
              ),
            );
            return;
          } catch (_) {}
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient record is unavailable.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;

      case AppNotificationType.consultation:
      case AppNotificationType.medicine:
      case AppNotificationType.system:
        // Already marked as read
        break;
    }
  }

  Future<void> _handlePatientNavigation(AppNotificationModel notification) async {
    switch (notification.type) {
      case AppNotificationType.appointment:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MyAppointmentsScreen(),
          ),
        );
        break;

      case AppNotificationType.consultation:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MyAppointmentsScreen(),
          ),
        );
        break;

      case AppNotificationType.medicine:
        Navigator.pop(context); // Pop notifications
        AppShell.switchTab(2); // Medicines tab
        break;

      case AppNotificationType.report:
        Navigator.pop(context); // Pop notifications
        AppShell.switchTab(1); // Reports tab
        break;

      case AppNotificationType.system:
        // Already marked as read, no navigation needed
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: AppTextStyles.headingMedium,
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _handleMarkAllAsRead,
              child: Text(
                'Mark all as read',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Chips Bar
            _buildFilterBar(),
            const SizedBox(height: 8),

            // Content Area
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadNotifications,
                color: AppColors.primary,
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'All',
            count: _notifications.length,
            isSelected: _selectedFilterIndex == 0,
            onTap: () => setState(() => _selectedFilterIndex = 0),
          ),
          const SizedBox(width: 10),
          _buildFilterChip(
            label: 'Unread',
            count: _unreadCount,
            isSelected: _selectedFilterIndex == 1,
            onTap: () => setState(() => _selectedFilterIndex = 1),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.caption.copyWith(
                    color: isSelected ? Colors.white : AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.emergencySurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.emergency,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load notifications',
                style: AppTextStyles.headingSmall.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadNotifications,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final items = _filteredNotifications;

    if (items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryLight),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _selectedFilterIndex == 1
                    ? 'No unread notifications'
                    : 'No notifications yet',
                style: AppTextStyles.headingMedium.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedFilterIndex == 1
                    ? 'You have reviewed all your health and appointment alerts.'
                    : 'We will notify you about upcoming appointments, medical reports, and health updates.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildNotificationCard(item);
      },
    );
  }

  Widget _buildNotificationCard(AppNotificationModel item) {
    final type = item.type;
    final isUnread = !item.isRead;

    return GestureDetector(
      onTap: () => _handleNotificationTap(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isUnread ? const Color(0xFFF0FDF4) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread ? AppColors.primaryLight : AppColors.border,
            width: isUnread ? 1.5 : 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Icon Container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: type.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                type.icon,
                color: type.primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Content Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: type.surfaceColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          type.label,
                          style: AppTextStyles.caption.copyWith(
                            color: type.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item.formatRelativeTime(),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight:
                          isUnread ? FontWeight.w700 : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
