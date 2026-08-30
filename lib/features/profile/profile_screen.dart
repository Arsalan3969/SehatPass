import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/section_header.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_info_row.dart';
import 'widgets/profile_menu_row.dart';
import '../emergency_qr/emergency_qr_screen.dart';
import '../doctor/onboarding/doctor_onboarding_screen.dart';
import '../doctor/doctor_shell_screen.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _showComingSoon(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.access_time_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Coming Soon', style: AppTextStyles.headingSmall),
          ],
        ),
        content: Text(message, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.emergencySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.emergency,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Log Out', style: AppTextStyles.headingSmall),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of SehatPass?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.instance.signOut();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.emergency,
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── App Bar ──────────────────────────────────────────────────
              _buildAppBar(),

              // ── Profile Header ───────────────────────────────────────────
              ProfileHeader(
                name: 'Abdul Wahab',
                email: 'abdul@example.com',
                onEditProfile: () => _showComingSoon(
                  context,
                  'Profile editing will be available soon.',
                ),
              ),

              const SizedBox(height: 24),

              // ── Personal Information ─────────────────────────────────────
              _buildSection(
                context: context,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Personal Information'),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: const [
                          ProfileInfoRow(
                            label: 'Full Name',
                            value: 'Abdul Wahab',
                          ),
                          ProfileInfoRow(
                            label: 'Date of Birth',
                            value: '15 March 2005',
                          ),
                          ProfileInfoRow(
                            label: 'Gender',
                            value: 'Male',
                          ),
                          ProfileInfoRow(
                            label: 'Blood Group',
                            value: 'O+',
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Emergency Information ────────────────────────────────────
              _buildSection(
                context: context,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Emergency Information'),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: const [
                          ProfileInfoRow(
                            label: 'Emergency Contact',
                            value: 'Muhammad Arsalan',
                          ),
                          ProfileInfoRow(
                            label: 'Relationship',
                            value: 'Friend',
                          ),
                          ProfileInfoRow(
                            label: 'Phone',
                            value: '+92 XXX XXXXXXX',
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ManageContactButton(
                      onTap: () => _showComingSoon(
                        context,
                        'Emergency contact management will be available soon.',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Health Information ───────────────────────────────────────
              _buildSection(
                context: context,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Health Information'),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          const ProfileInfoRow(
                            label: 'Blood Group',
                            value: 'O+',
                          ),
                          const ProfileInfoRow(
                            label: 'Allergies',
                            value: 'None added',
                          ),
                          const ProfileInfoRow(
                            label: 'Medical Conditions',
                            value: 'None added',
                          ),
                          ProfileInfoRow(
                            label: 'Current Medicines',
                            value: '3 medicines',
                            isLast: true,
                            valueColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Emergency QR ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _EmergencyQrCard(
                  onViewQr: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmergencyQrScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // ── Healthcare Providers (Doctor Portal) ──────────────────────
              _buildSection(
                context: context,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Healthcare Providers'),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ProfileMenuRow(
                            icon: Icons.dashboard_outlined,
                            label: 'Doctor Dashboard (Live Portal)',
                            iconColor: AppColors.primary,
                            iconBgColor: AppColors.primarySurface,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DoctorShellScreen(),
                                ),
                              );
                            },
                          ),
                          ProfileMenuRow(
                            icon: Icons.medical_services_outlined,
                            label: 'Doctor Onboarding (Setup Flow)',
                            iconColor: AppColors.primary,
                            iconBgColor: AppColors.primarySurface,
                            isLast: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DoctorOnboardingScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Account & Settings ───────────────────────────────────────
              _buildSection(
                context: context,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Account & Settings'),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ProfileMenuRow(
                            icon: Icons.lock_outline_rounded,
                            label: 'Privacy & Security',
                            onTap: () => _showComingSoon(
                              context,
                              'Privacy & Security settings will be available soon.',
                            ),
                          ),
                          ProfileMenuRow(
                            icon: Icons.notifications_none_rounded,
                            label: 'Notifications',
                            onTap: () => _showComingSoon(
                              context,
                              'Notification settings will be available soon.',
                            ),
                          ),
                          ProfileMenuRow(
                            icon: Icons.help_outline_rounded,
                            label: 'Help & Support',
                            onTap: () => _showComingSoon(
                              context,
                              'Help & Support will be available soon.',
                            ),
                          ),
                          ProfileMenuRow(
                            icon: Icons.logout_rounded,
                            label: 'Log Out',
                            iconColor: AppColors.emergency,
                            iconBgColor: AppColors.emergencySurface,
                            labelColor: AppColors.emergency,
                            isLast: true,
                            onTap: () => _showLogoutDialog(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── App bar row ────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Text('Profile', style: AppTextStyles.headingLarge),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.settings_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: null, // settings tap reserved
              visualDensity: VisualDensity.compact,
              tooltip: 'Settings',
            ),
          ),
        ],
      ),
    );
  }

  // ── Generic padded section wrapper ────────────────────────────────────────
  Widget _buildSection({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 16),
  }) {
    return Padding(
      padding: padding,
      child: child,
    );
  }
}

// =============================================================================
// Private helper widgets
// =============================================================================

class _ManageContactButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ManageContactButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.contacts_outlined, size: 16),
        label: const Text('Manage Emergency Contact'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EmergencyQrCard extends StatelessWidget {
  final VoidCallback onViewQr;
  const _EmergencyQrCard({required this.onViewQr});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.emergencySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.emergencyBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: AppColors.emergency,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Emergency QR',
                style: AppTextStyles.headingSmall.copyWith(
                  color: AppColors.emergency,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            'Your QR code can help others access selected emergency information when you need help.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: const Color(0xFF991B1B),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Button
          Material(
            color: AppColors.emergency,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onViewQr,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'View My QR Code',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
