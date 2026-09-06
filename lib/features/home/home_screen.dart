import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../notifications/data/notification_repository.dart';
import '../reports/data/medical_reports_repository.dart';
import '../reports/widgets/report_details_bottom_sheet.dart';
import 'data/patient_home_repository.dart';
import 'models/medical_report_model.dart';
import 'models/patient_home_data.dart';
import 'widgets/home_greeting_bar.dart';
import 'widgets/health_overview_card.dart';
import 'widgets/quick_actions_grid.dart';
import 'widgets/appointments_home_card.dart';
import 'widgets/emergency_card.dart';
import 'widgets/today_schedule_section.dart';
import 'widgets/recent_reports_section.dart';
import '../../app/app_shell.dart';

class HomeScreen extends StatefulWidget {
  final PatientHomeRepository? repository;
  final NotificationRepository? notificationRepository;

  const HomeScreen({
    super.key,
    this.repository,
    this.notificationRepository,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PatientHomeRepository get _repo =>
      widget.repository ?? PatientHomeRepository.instance;

  NotificationRepository get _notificationRepo =>
      widget.notificationRepository ?? NotificationRepository.instance;

  PatientHomeData? _data;
  int _unreadNotificationsCount = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _notificationRepo.addListener(_onNotificationRepoChanged);
    _loadData();
    AppShell.tabNotifier.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _notificationRepo.removeListener(_onNotificationRepoChanged);
    AppShell.tabNotifier.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onNotificationRepoChanged() {
    if (mounted) {
      setState(() {
        _unreadNotificationsCount = _notificationRepo.unreadCount;
      });
    }
  }

  void _onTabChanged() {
    if (AppShell.tabNotifier.value == 0 && mounted) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _repo.getPatientHomeData(),
        _notificationRepo.getUnreadCount(),
      ]);

      if (!mounted) return;
      setState(() {
        _data = results[0] as PatientHomeData;
        _unreadNotificationsCount = results[1] as int;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is String
            ? e
            : 'Unable to load your health information. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _openReportDetails(MedicalReportModel report) {
    ReportDetailsBottomSheet.show(
      context,
      report: report,
      repository: MedicalReportsRepository.instance,
      onDeleted: () async {
        await _loadData();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                HomeGreetingBar(
                  patientName: _data?.patientName,
                  isLoading: _isLoading,
                  unreadCount: _unreadNotificationsCount,
                ),
                const SizedBox(height: 20),
                if (_errorMessage != null)
                  _buildErrorBanner()
                else ...[
                  HealthOverviewCard(
                    nextMedicine: _data?.nextMedicine,
                    latestReport: _data?.latestReport,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 24),
                  const QuickActionsGrid(),
                  const SizedBox(height: 20),
                  const AppointmentsHomeCard(),
                  const SizedBox(height: 20),
                  const EmergencyCard(),
                  const SizedBox(height: 24),
                  TodayScheduleSection(
                    medicines: _data?.medicines ?? const [],
                    isLoading: _isLoading,
                    onViewAll: () => AppShell.switchTab(2),
                  ),
                  const SizedBox(height: 24),
                  RecentReportsSection(
                    reports: _data?.reports ?? const [],
                    isLoading: _isLoading,
                    onViewAll: () => AppShell.switchTab(1),
                    onReportTap: _openReportDetails,
                  ),
                  const SizedBox(height: 28),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.emergencySurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.emergencyBorder),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.emergency,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Unable to load your health information',
              style: AppTextStyles.headingSmall.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Please check your connection and try again.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
