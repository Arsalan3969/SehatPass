import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/section_header.dart';

/// Horizontally-scrollable suggestion chips that pre-fill the chat input.
class AiSuggestedChips extends StatelessWidget {
  final ValueChanged<String> onSuggestionTapped;

  static const _suggestions = [
    'Explain my blood test',
    'What is Panadol used for?',
    'What does low hemoglobin mean?',
    'Is Amoxicillin safe after meals?',
    'What is a normal blood pressure?',
  ];

  const AiSuggestedChips({super.key, required this.onSuggestionTapped});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Try asking'),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _suggestions.map((text) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _SuggestionChip(
                  text: text,
                  onTap: () => onSuggestionTapped(text),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SuggestionChip extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _SuggestionChip({required this.text, required this.onTap});

  @override
  State<_SuggestionChip> createState() => _SuggestionChipState();
}

class _SuggestionChipState extends State<_SuggestionChip> {
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
        duration: const Duration(milliseconds: 120),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: _pressed ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _pressed ? AppColors.primary : AppColors.border,
          ),
          boxShadow: _pressed
              ? null
              : [
                  const BoxShadow(
                    color: Color(0x07000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 13,
              color: _pressed ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 5),
            Text(
              widget.text,
              style: AppTextStyles.labelMedium.copyWith(
                color: _pressed ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
