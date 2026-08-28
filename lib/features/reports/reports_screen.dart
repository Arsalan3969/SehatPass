import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/dummy_data.dart';
import 'widgets/report_card.dart';
import 'widgets/report_filter_chips.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportCategory _selectedFilter = ReportCategory.all;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ReportItem> get _filteredReports {
    return DummyData.allReports.where((r) {
      final matchesFilter = _selectedFilter == ReportCategory.all ||
          r.category == _selectedFilter;
      return matchesFilter;
    }).toList();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reports = _filteredReports;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Reports', style: AppTextStyles.headingLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Keep track of your medical reports in one place.',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 18),

                  // ── Search bar ───────────────────────────────────────
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x06000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: AppTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Search reports',
                        hintStyle: AppTextStyles.bodyMedium,
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textTertiary,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Filter chips ──────────────────────────────────────────────
            ReportFilterChips(
              selected: _selectedFilter,
              onSelected: (cat) => setState(() => _selectedFilter = cat),
            ),

            const SizedBox(height: 16),

            // ── Report count label ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${reports.length} ${reports.length == 1 ? 'report' : 'reports'} found',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Report list ───────────────────────────────────────────────
            Expanded(
              child: reports.isEmpty
                  ? _EmptyState(filter: _selectedFilter)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: reports.length,
                      physics: const BouncingScrollPhysics(),
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return ReportCard(
                          report: reports[index],
                          onTap: () =>
                              _showSnackBar('Report details coming soon.'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // ── FAB ───────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _showSnackBar('Report upload will be available soon.'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.upload_file_outlined, size: 20),
        label: Text(
          'Upload Report',
          style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

/// Shown when no reports match the selected filter.
class _EmptyState extends StatelessWidget {
  final ReportCategory filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.folder_open_outlined,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No ${filter.label} found',
            style: AppTextStyles.headingSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Upload a report to get started.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}
