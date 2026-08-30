import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/section_header.dart';
import '../../appointments/my_appointments_screen.dart';
import '../../appointments/find_doctor_screen.dart';

/// Appointments overview card shown on the Home screen.
class AppointmentsHomeCard extends StatelessWidget {
  const AppointmentsHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Appointments',
          onViewAll: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyAppointmentsScreen()),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // My Appointments card
            Expanded(
              child: _AppointmentActionCard(
                icon: Icons.calendar_month_rounded,
                title: 'My Appointments',
                subtitle: 'View your upcoming appointments',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MyAppointmentsScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Find a Doctor card
            Expanded(
              child: _AppointmentActionCard(
                icon: Icons.person_search_rounded,
                title: 'Find a Doctor',
                subtitle: 'Search doctors and clinics',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const FindDoctorScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AppointmentActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AppointmentActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_AppointmentActionCard> createState() => _AppointmentActionCardState();
}

class _AppointmentActionCardState extends State<_AppointmentActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: _pressed
            ? Matrix4.diagonal3Values(0.97, 0.97, 1.0)
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon,
                  size: 20, color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            Text(
              widget.title,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.subtitle,
              style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
