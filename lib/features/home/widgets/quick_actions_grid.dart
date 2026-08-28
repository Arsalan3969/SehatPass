import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/section_header.dart';

class _QuickAction {
  final IconData icon;
  final String label;

  const _QuickAction({
    required this.icon,
    required this.label,
  });
}

/// 2×2 grid of quick action cards.
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(icon: Icons.upload_file_outlined, label: 'Upload Report'),
      _QuickAction(icon: Icons.document_scanner_outlined, label: 'Scan Prescription'),
      _QuickAction(icon: Icons.add_circle_outline, label: 'Add Medicine'),
      _QuickAction(icon: Icons.smart_toy_outlined, label: 'Ask Sehat AI'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Quick Actions'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: actions
              .map((action) => _QuickActionCard(action: action))
              .toList(),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final _QuickAction action;
  const _QuickActionCard({required this.action});

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: _pressed
            ? Matrix4.diagonal3Values(0.96, 0.96, 1.0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: _pressed ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pressed ? AppColors.primaryLight : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: _pressed
                  ? const Color(0x142E7D5E)
                  : const Color(0x08000000),
              blurRadius: _pressed ? 8 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                widget.action.icon,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            Text(
              widget.action.label,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
