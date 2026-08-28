import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/dummy_data.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/app_card.dart';

/// Today's schedule section showing dummy medicine items.
class TodayScheduleSection extends StatelessWidget {
  const TodayScheduleSection({super.key});

  @override
  Widget build(BuildContext context) {
    final schedule = DummyData.todaySchedule;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: "Today's Schedule",
          onViewAll: () {},
        ),
        const SizedBox(height: 12),
        ...schedule.map((med) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Time pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        med.time,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Medicine info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(med.name,
                              style: AppTextStyles.labelLarge),
                          const SizedBox(height: 2),
                          Text(
                            '${med.dose} • ${med.mealNote}',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    // Medicine icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.medication_outlined,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}
