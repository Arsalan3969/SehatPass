import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Emergency & First Aid banner card.
class EmergencyCard extends StatelessWidget {
  const EmergencyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.emergencySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.emergencyBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_hospital_outlined,
              color: AppColors.emergency,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency & First Aid',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.emergency,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Get quick access to emergency information and first-aid guidance.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: const Color(0xFF991B1B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Arrow
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFECACA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.emergency,
              size: 15,
            ),
          ),
        ],
      ),
    );
  }
}
