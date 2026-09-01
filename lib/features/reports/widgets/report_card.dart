import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/dummy_data.dart';
import '../../home/models/medical_report_model.dart';

/// Maps a [ReportCategory] to a badge color pair (background, text).
({Color bg, Color text}) _categoryColors(ReportCategory cat) {
  switch (cat) {
    case ReportCategory.bloodTest:
      return (bg: AppColors.primarySurface, text: AppColors.primary);
    case ReportCategory.scan:
      return (
        bg: const Color(0xFFEEF2FF),
        text: const Color(0xFF4338CA),
      );
    case ReportCategory.other:
      return (
        bg: const Color(0xFFFFF7ED),
        text: const Color(0xFFB45309),
      );
    case ReportCategory.all:
      return (bg: AppColors.surfaceSecondary, text: AppColors.textSecondary);
  }
}

IconData _categoryIcon(ReportCategory cat) {
  switch (cat) {
    case ReportCategory.bloodTest:
      return Icons.science_outlined;
    case ReportCategory.scan:
      return Icons.crop_free_outlined;
    default:
      return Icons.description_outlined;
  }
}

/// A card representing a patient medical report from `public.medical_reports`.
class ReportCard extends StatelessWidget {
  final MedicalReportModel report;
  final VoidCallback? onTap;

  const ReportCard({
    super.key,
    required this.report,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _categoryColors(report.reportCategory);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x07000000),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                _categoryIcon(report.reportCategory),
                color: colors.text,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Text block
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(report.title, style: AppTextStyles.labelLarge),
                  const SizedBox(height: 3),
                  Text(
                    report.labFacility,
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Date
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
                      const SizedBox(width: 10),
                      // Category badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.bg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          report.categoryLabel,
                          style: AppTextStyles.caption.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      if (report.storageFilePath != null &&
                          report.storageFilePath!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.attach_file_rounded,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Chevron
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
