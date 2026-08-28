import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/medicine_item.dart';

/// Summary row showing Taken / Upcoming / Missed counts.
class MedicineStatusSummary extends StatelessWidget {
  final int taken;
  final int upcoming;
  final int missed;

  const MedicineStatusSummary({
    super.key,
    required this.taken,
    required this.upcoming,
    required this.missed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Medicine Status',
              style: AppTextStyles.headingSmall,
            ),
          ),
          const Divider(height: 1),

          // Status rows
          _StatusRow(
            dot: AppColors.primary,
            label: 'Taken',
            count: taken,
            status: MedicineStatus.taken,
          ),
          const Divider(height: 1, indent: 52),
          _StatusRow(
            dot: const Color(0xFFB45309),
            label: 'Upcoming',
            count: upcoming,
            status: MedicineStatus.upcoming,
          ),
          const Divider(height: 1, indent: 52),
          _StatusRow(
            dot: AppColors.emergency,
            label: 'Missed',
            count: missed,
            status: MedicineStatus.missed,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final Color dot;
  final String label;
  final int count;
  final MedicineStatus status;

  const _StatusRow({
    required this.dot,
    required this.label,
    required this.count,
    required this.status,
  });

  Color get _badgeBg {
    switch (status) {
      case MedicineStatus.taken:
        return AppColors.primarySurface;
      case MedicineStatus.upcoming:
        return const Color(0xFFFFF7ED);
      case MedicineStatus.missed:
        return AppColors.emergencySurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Dot indicator
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.bodyLarge),
          const Spacer(),
          // Count badge
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Container(
              key: ValueKey(count),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _badgeBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: AppTextStyles.labelLarge.copyWith(
                  color: dot,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
