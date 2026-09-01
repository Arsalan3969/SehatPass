import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../app/app_shell.dart';
import '../models/patient_medicine_model.dart';
import '../models/medical_report_model.dart';

/// "Your Health Overview" card showing next medicine and latest report.
class HealthOverviewCard extends StatelessWidget {
  final PatientMedicineModel? nextMedicine;
  final MedicalReportModel? latestReport;
  final bool isLoading;
  final VoidCallback? onViewAll;

  const HealthOverviewCard({
    super.key,
    this.nextMedicine,
    this.latestReport,
    this.isLoading = false,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final medTitle = isLoading
        ? 'Loading...'
        : (nextMedicine != null
            ? nextMedicine!.name
            : 'No medicines scheduled');
    final medSubtitle = isLoading
        ? 'Checking schedule'
        : (nextMedicine != null
            ? '${nextMedicine!.dosage} • ${nextMedicine!.scheduledTime}'
            : 'Tap to view schedule');

    final reportTitle = isLoading
        ? 'Loading...'
        : (latestReport != null
            ? latestReport!.title
            : 'No medical reports yet');
    final reportSubtitle = isLoading
        ? 'Checking reports'
        : (latestReport != null
            ? latestReport!.formattedDateLong
            : 'Tap to view reports');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.favorite_border_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Your Health Overview',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onViewAll ?? () => AppShell.switchTab(2),
                  child: Text(
                    'View All →',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Next medicine
                Expanded(
                  child: InkWell(
                    onTap: () => AppShell.switchTab(2), // Medicines tab
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: _OverviewItem(
                        icon: Icons.medication_outlined,
                        label: 'Next Medicine',
                        title: medTitle,
                        subtitle: medSubtitle,
                      ),
                    ),
                  ),
                ),
                // Divider
                Container(
                  width: 1,
                  height: 56,
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                // Latest report
                Expanded(
                  child: InkWell(
                    onTap: () => AppShell.switchTab(1), // Reports tab
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: _OverviewItem(
                        icon: Icons.description_outlined,
                        label: 'Latest Report',
                        title: reportTitle,
                        subtitle: reportSubtitle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String title;
  final String subtitle;

  const _OverviewItem({
    required this.icon,
    required this.label,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: AppTextStyles.labelLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppTextStyles.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
