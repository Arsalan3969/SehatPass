import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/notification_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/section_header.dart';
import '../notifications/notifications_screen.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_info_row.dart';
import 'widgets/profile_menu_row.dart';
import '../emergency_qr/emergency_qr_screen.dart';
import '../emergency_qr/manage_emergency_info_screen.dart';
import 'widgets/edit_profile_bottom_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String _fullName = 'Patient';
  String _email = '';
  String? _avatarPathOrUrl;
  String? _resolvedAvatarUrl;
  bool _isUploadingAvatar = false;
  String _dateOfBirth = 'Not specified';
  String _gender = 'Not specified';
  String _bloodGroup = 'Not specified';
  String _emergencyContact = 'Not set';
  String _emergencyRelationship = 'Not set';
  String _emergencyPhone = 'Not set';
  String _allergies = 'None added';
  String _medicalConditions = 'None added';
  int _activeMedicinesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final userId = user.id;
    _email = user.email ?? '';

    try {
      final client = Supabase.instance.client;

      // 1. Fetch Profile
      try {
        final profile = await client
            .from('profiles')
            .select('full_name, email, avatar_url')
            .eq('id', userId)
            .maybeSingle();

        if (profile != null) {
          final name = profile['full_name']?.toString().trim();
          if (name != null && name.isNotEmpty) {
            _fullName = name;
          }
          final email = profile['email']?.toString().trim();
          if (email != null && email.isNotEmpty) {
            _email = email;
          }
          _avatarPathOrUrl = profile['avatar_url']?.toString();
          if (_avatarPathOrUrl != null && _avatarPathOrUrl!.isNotEmpty) {
            _resolvedAvatarUrl = await ImageUploadService.instance.resolveImageUrl(_avatarPathOrUrl);
          }
        }
      } catch (_) {}

      // Fallback name if needed
      if (_fullName == 'Patient' && _email.isNotEmpty && _email.contains('@')) {
        final uname = _email.split('@').first;
        _fullName = uname[0].toUpperCase() + uname.substring(1);
      }

      // 2. Fetch Patient Profile
      try {
        final patientProfile = await client
            .from('patient_profiles')
            .select('date_of_birth, gender, blood_group, allergies, medical_conditions')
            .eq('patient_id', userId)
            .maybeSingle();

        if (patientProfile != null) {
          if (patientProfile['date_of_birth'] != null) {
            _dateOfBirth = patientProfile['date_of_birth'].toString();
          }
          if (patientProfile['gender'] != null && patientProfile['gender'].toString().isNotEmpty) {
            _gender = patientProfile['gender'].toString();
          }
          if (patientProfile['blood_group'] != null && patientProfile['blood_group'].toString().isNotEmpty) {
            _bloodGroup = patientProfile['blood_group'].toString();
          }
          if (patientProfile['allergies'] != null && patientProfile['allergies'].toString().isNotEmpty) {
            _allergies = patientProfile['allergies'].toString();
          }
          if (patientProfile['medical_conditions'] != null && patientProfile['medical_conditions'].toString().isNotEmpty) {
            _medicalConditions = patientProfile['medical_conditions'].toString();
          }
        }
      } catch (_) {}

      // 3. Fetch Emergency Settings
      try {
        final emergency = await client
            .from('emergency_settings')
            .select('contact_name, contact_relationship, contact_phone')
            .eq('patient_id', userId)
            .maybeSingle();

        if (emergency != null) {
          if (emergency['contact_name'] != null && emergency['contact_name'].toString().isNotEmpty) {
            _emergencyContact = emergency['contact_name'].toString();
          }
          if (emergency['contact_relationship'] != null && emergency['contact_relationship'].toString().isNotEmpty) {
            _emergencyRelationship = emergency['contact_relationship'].toString();
          }
          if (emergency['contact_phone'] != null && emergency['contact_phone'].toString().isNotEmpty) {
            _emergencyPhone = emergency['contact_phone'].toString();
          }
        }
      } catch (_) {}

      // 4. Fetch Active Medicines Count
      try {
        final medicines = await client
            .from('patient_medicines')
            .select('id')
            .eq('patient_id', userId)
            .eq('is_active', true);
        _activeMedicinesCount = medicines.length;
      } catch (_) {}
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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

  Future<void> _showNotificationsDialog(BuildContext context) async {
    final hasPermission =
        await NotificationService.instance.isPermissionGranted();

    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    Icons.notifications_active_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Medicine Reminders',
                    style: AppTextStyles.headingSmall),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasPermission
                          ? Icons.check_circle_outline_rounded
                          : Icons.info_outline_rounded,
                      color: hasPermission
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasPermission
                            ? 'Notifications are active on this device.'
                            : 'Notifications are disabled on this device.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: hasPermission
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  hasPermission
                      ? 'You will receive daily reminders for your scheduled medications even when the app is closed.'
                      : 'Enable notifications to receive timely alerts for your scheduled medication doses.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              if (!hasPermission)
                TextButton(
                  onPressed: () async {
                    final granted =
                        await NotificationService.instance.requestPermission();
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      if (granted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                                'Medicine notifications enabled successfully!'),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          ),
                        );
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  child: const Text('Enable Notifications',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  foregroundColor:
                      hasPermission ? AppColors.primary : AppColors.textSecondary,
                ),
                child: Text(hasPermission ? 'Got it' : 'Close'),
              ),
            ],
          );
        },
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

  Future<void> _handleAvatarUpload() async {
    if (_isUploadingAvatar) return;

    final user = AuthService.instance.currentUser;
    if (user == null) return;

    try {
      final action = await ImageUploadService.instance.showImagePickerSheet(
        context,
        hasExistingImage: _avatarPathOrUrl != null && _avatarPathOrUrl!.isNotEmpty,
      );

      if (action == null || !mounted) return;

      final client = Supabase.instance.client;

      if (action == ImagePickerResultAction.remove) {
        setState(() => _isUploadingAvatar = true);
        await client.from('profiles').update({
          'avatar_url': null,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);

        if (!mounted) return;
        setState(() {
          _avatarPathOrUrl = null;
          _resolvedAvatarUrl = null;
          _isUploadingAvatar = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo removed.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final source = action == ImagePickerResultAction.camera
          ? ImageSource.camera
          : ImageSource.gallery;

      final xfile = await ImageUploadService.instance.pickImage(source);
      if (xfile == null || !mounted) return;

      final bytes = await xfile.readAsBytes();
      if (!mounted) return;

      setState(() => _isUploadingAvatar = true);

      final storagePath = await ImageUploadService.instance.uploadImage(
        imageBytes: bytes,
        fileNamePrefix: 'patient_avatar',
        userIdOverride: user.id,
      );

      await client.from('profiles').update({
        'avatar_url': storagePath,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      final resolvedUrl = await ImageUploadService.instance.resolveImageUrl(storagePath);

      if (!mounted) return;
      setState(() {
        _avatarPathOrUrl = storagePath;
        _resolvedAvatarUrl = resolvedUrl;
        _isUploadingAvatar = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated successfully!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.emergency,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                name: _isLoading ? 'Loading...' : _fullName,
                email: _isLoading ? '...' : _email,
                avatarUrl: _resolvedAvatarUrl,
                isUploadingAvatar: _isUploadingAvatar,
                onAvatarTap: _handleAvatarUpload,
                onEditProfile: () {
                  EditProfileBottomSheet.show(
                    context,
                    initialFullName: _fullName,
                    initialDob: _dateOfBirth,
                    initialGender: _gender,
                    initialBloodGroup: _bloodGroup,
                    initialAllergies: _allergies,
                    initialMedicalConditions: _medicalConditions,
                    onProfileUpdated: () {
                      _loadProfileData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Profile updated successfully!'),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          ),
                        );
                      }
                    },
                  );
                },
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
                        children: [
                          ProfileInfoRow(
                            label: 'Full Name',
                            value: _isLoading ? 'Loading...' : _fullName,
                          ),
                          ProfileInfoRow(
                            label: 'Date of Birth',
                            value: _isLoading ? '...' : _dateOfBirth,
                          ),
                          ProfileInfoRow(
                            label: 'Gender',
                            value: _isLoading ? '...' : _gender,
                          ),
                          ProfileInfoRow(
                            label: 'Blood Group',
                            value: _isLoading ? '...' : _bloodGroup,
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
                        children: [
                          ProfileInfoRow(
                            label: 'Emergency Contact',
                            value: _isLoading ? '...' : _emergencyContact,
                          ),
                          ProfileInfoRow(
                            label: 'Relationship',
                            value: _isLoading ? '...' : _emergencyRelationship,
                          ),
                          ProfileInfoRow(
                            label: 'Phone',
                            value: _isLoading ? '...' : _emergencyPhone,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ManageContactButton(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageEmergencyInfoScreen(),
                          ),
                        );
                        _loadProfileData();
                      },
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
                          ProfileInfoRow(
                            label: 'Blood Group',
                            value: _isLoading ? '...' : _bloodGroup,
                          ),
                          ProfileInfoRow(
                            label: 'Allergies',
                            value: _isLoading ? '...' : _allergies,
                          ),
                          ProfileInfoRow(
                            label: 'Medical Conditions',
                            value: _isLoading ? '...' : _medicalConditions,
                          ),
                          ProfileInfoRow(
                            label: 'Current Medicines',
                            value: _isLoading
                                ? '...'
                                : '$_activeMedicinesCount ${_activeMedicinesCount == 1 ? "medicine" : "medicines"}',
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
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            ),
                          ),
                          ProfileMenuRow(
                            icon: Icons.alarm_on_rounded,
                            label: 'Medicine Reminder Alerts',
                            onTap: () => _showNotificationsDialog(context),
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
              onPressed: null,
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
