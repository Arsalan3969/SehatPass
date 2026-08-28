import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/section_header.dart';

class _AiAction {
  final IconData icon;
  final String title;
  final String description;

  const _AiAction({
    required this.icon,
    required this.title,
    required this.description,
  });
}

/// 2×2 grid of Sehat AI quick-action cards.
class AiQuickActionsGrid extends StatelessWidget {
  final ValueChanged<String> onActionTapped;

  const AiQuickActionsGrid({super.key, required this.onActionTapped});

  static const _actions = [
    _AiAction(
      icon: Icons.description_outlined,
      title: 'Explain My Report',
      description: 'Understand your medical reports in simple words',
    ),
    _AiAction(
      icon: Icons.medication_outlined,
      title: 'Medicine Information',
      description: 'Learn about usage and possible side effects',
    ),
    _AiAction(
      icon: Icons.favorite_border_rounded,
      title: 'My Health Summary',
      description: 'Get a summary of your health information',
    ),
    _AiAction(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Ask a Question',
      description: 'Ask Sehat AI anything about your health',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'How can I help?'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: _actions
              .map((a) => _AiActionCard(
                    action: a,
                    onTap: () => onActionTapped(a.title),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _AiActionCard extends StatefulWidget {
  final _AiAction action;
  final VoidCallback onTap;

  const _AiActionCard({required this.action, required this.onTap});

  @override
  State<_AiActionCard> createState() => _AiActionCardState();
}

class _AiActionCardState extends State<_AiActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
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
              color:
                  _pressed ? const Color(0x122E7D5E) : const Color(0x08000000),
              blurRadius: _pressed ? 6 : 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                widget.action.icon,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.action.title,
              style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              widget.action.description,
              style: AppTextStyles.bodySmall.copyWith(height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
