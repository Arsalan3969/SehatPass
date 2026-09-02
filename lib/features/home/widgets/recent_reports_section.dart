import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/app_card.dart';
import '../models/medical_report_model.dart';

/// Recent Reports section showing real patient reports.
class RecentReportsSection extends StatelessWidget {
  final List<MedicalReportModel> reports;
  final bool isLoading;
  final VoidCallback? onViewAll;
  final void Function(MedicalReportModel report)? onReportTap;

  const RecentReportsSection({
    super.key,
    this.reports = const [],
    this.isLoading = false,
    this.onViewAll,
    this.onReportTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayedReports = reports.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recent Reports',
          onViewAll: onViewAll ?? () {},
        ),
        const SizedBox(height: 12),
        if (isLoading)
          const AppCard(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          )
        else if (displayedReports.isEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: AppColors.textTertiary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No medical reports yet',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Uploaded lab and diagnostic reports will appear here.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: List.generate(displayedReports.length, (index) {
                final report = displayedReports[index];
                final isLast = index == displayedReports.length - 1;
                return Column(
                  children: [
                    InkWell(
                      onTap: onReportTap != null
                          ? () => onReportTap!(report)
                          : null,
                      borderRadius: isLast
                          ? const BorderRadius.vertical(bottom: Radius.circular(16))
                          : (index == 0
                              ? const BorderRadius.vertical(top: Radius.circular(16))
                              : BorderRadius.zero),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            // Report icon
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.description_outlined,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Report info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(report.title,
                                      style: AppTextStyles.labelLarge),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_outlined,
                                        size: 11,
                                        color: AppColors.textTertiary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(report.formattedDate,
                                          style: AppTextStyles.bodySmall),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Report type badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                report.categoryLabel,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      const Divider(
                        height: 1,
                        indent: 72,
                        endIndent: 0,
                      ),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }
}
