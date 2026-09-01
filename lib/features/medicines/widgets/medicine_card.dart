import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/medicine_item.dart';

/// Visual config for each status.
({Color bg, Color text, Color border, IconData icon}) _statusStyle(
    MedicineStatus status) {
  switch (status) {
    case MedicineStatus.taken:
      return (
        bg: AppColors.primarySurface,
        text: AppColors.primary,
        border: const Color(0xFFA7D9C0),
        icon: Icons.check_circle_rounded,
      );
    case MedicineStatus.upcoming:
      return (
        bg: const Color(0xFFFFF7ED),
        text: const Color(0xFFB45309),
        border: const Color(0xFFFED7AA),
        icon: Icons.access_time_rounded,
      );
    case MedicineStatus.missed:
      return (
        bg: AppColors.emergencySurface,
        text: AppColors.emergency,
        border: AppColors.emergencyBorder,
        icon: Icons.cancel_outlined,
      );
  }
}

/// A card representing a single medicine in today's schedule.
class MedicineCard extends StatefulWidget {
  final MedicineItem medicine;

  /// Called when an [upcoming] medicine's status badge is tapped to mark as taken.
  final VoidCallback? onMarkTaken;

  /// Called when the card is tapped to view or edit medication details.
  final VoidCallback? onTap;

  const MedicineCard({
    super.key,
    required this.medicine,
    this.onMarkTaken,
    this.onTap,
  });

  @override
  State<MedicineCard> createState() => _MedicineCardState();
}

class _MedicineCardState extends State<MedicineCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(widget.medicine.status);
    final isUpcoming = widget.medicine.status == MedicineStatus.upcoming;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      transform: _pressed
          ? Matrix4.diagonal3Values(0.98, 0.98, 1.0)
          : Matrix4.identity(),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Medicine icon container (tappable for edit)
          GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: style.bg,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.medication_rounded,
                color: AppColors.primary,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 13),

          // Medicine info (tappable for edit)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) {
                setState(() => _pressed = false);
                widget.onTap?.call();
              },
              onTapCancel: () => setState(() => _pressed = false),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.medicine.name, style: AppTextStyles.labelLarge),
                  const SizedBox(height: 3),
                  Text(
                    widget.medicine.instruction.isNotEmpty
                        ? '${widget.medicine.dosage} • ${widget.medicine.instruction}'
                        : widget.medicine.dosage,
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 5),
                  // Time chip
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_outlined,
                        size: 12,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.medicine.time.isNotEmpty
                            ? widget.medicine.time
                            : 'Scheduled',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Status badge - Dedicated tap target to mark dose taken
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (isUpcoming && widget.onMarkTaken != null) {
                widget.onMarkTaken!();
              } else if (widget.onTap != null) {
                widget.onTap!();
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: style.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: style.border, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(style.icon, size: 14, color: style.text),
                      const SizedBox(width: 4),
                      Text(
                        widget.medicine.status.label,
                        style: AppTextStyles.caption.copyWith(
                          color: style.text,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUpcoming) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Tap to mark',
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFFB45309),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),

          // Chevron (tappable for edit)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
