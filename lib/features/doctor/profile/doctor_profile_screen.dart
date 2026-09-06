import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/auth_service.dart';
import '../../../services/image_upload_service.dart';
import '../../notifications/notifications_screen.dart';
import '../data/doctor_repository.dart';
import '../models/doctor_onboarding_data.dart';
import '../models/doctor_profile_model.dart';

class DoctorProfileScreen extends StatefulWidget {
  final DoctorOnboardingData data;
  final DoctorRepository? repository;
  final VoidCallback? onProfileUpdated;

  const DoctorProfileScreen({
    super.key,
    required this.data,
    this.repository,
    this.onProfileUpdated,
  });

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  late final DoctorRepository _repository;
  late DoctorProfileModel _profile;
  String? _resolvedPhotoUrl;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DoctorRepository.instance;
    _profile = widget.data.profile;
    _resolveAvatar();
  }

  @override
  void didUpdateWidget(covariant DoctorProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.profile != oldWidget.data.profile) {
      _profile = widget.data.profile;
      _resolveAvatar();
    }
  }

  Future<void> _resolveAvatar() async {
    final photo = _profile.photoUrl;
    if (photo != null && photo.isNotEmpty) {
      final url = await ImageUploadService.instance.resolveImageUrl(photo);
      if (mounted) {
        setState(() => _resolvedPhotoUrl = url);
      }
    } else {
      if (mounted) {
        setState(() => _resolvedPhotoUrl = null);
      }
    }
  }

  Future<void> _handlePhotoUpload() async {
    if (_isUploadingPhoto) return;

    try {
      final action = await ImageUploadService.instance.showImagePickerSheet(
        context,
        hasExistingImage: _profile.photoUrl != null && _profile.photoUrl!.isNotEmpty,
      );

      if (action == null || !mounted) return;

      if (action == ImagePickerResultAction.remove) {
        setState(() => _isUploadingPhoto = true);
        final doctorId = _repository.currentUserId;
        if (doctorId != null && doctorId.isNotEmpty) {
          final updated = _profile.copyWith(photoUrl: '');
          await _repository.saveDoctorProfile(doctorId: doctorId, profile: updated);
        }
        if (!mounted) return;
        setState(() {
          _profile.photoUrl = null;
          _resolvedPhotoUrl = null;
          _isUploadingPhoto = false;
        });
        widget.data.profile = _profile;
        widget.onProfileUpdated?.call();
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

      setState(() => _isUploadingPhoto = true);

      final storagePath = await ImageUploadService.instance.uploadImage(
        imageBytes: bytes,
        fileNamePrefix: 'doctor_avatar',
      );

      final doctorId = _repository.currentUserId;
      if (doctorId != null && doctorId.isNotEmpty) {
        final updated = _profile.copyWith(photoUrl: storagePath);
        await _repository.saveDoctorProfile(doctorId: doctorId, profile: updated);
      }

      final resolvedUrl = await ImageUploadService.instance.resolveImageUrl(storagePath);

      if (!mounted) return;
      setState(() {
        _profile.photoUrl = storagePath;
        _resolvedPhotoUrl = resolvedUrl;
        _isUploadingPhoto = false;
      });
      widget.data.profile = _profile;
      widget.onProfileUpdated?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Doctor photo updated successfully.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.emergency,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
              try {
                await AuthService.instance.signOut();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to log out: $e'),
                      backgroundColor: AppColors.emergency,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
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

  void _showNotice(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: const Text('Doctor Portal', style: AppTextStyles.headingSmall),
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

  void _openEditProfile() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProfileBottomSheet(
        initialProfile: _profile,
        repository: _repository,
        onSave: (updated) {
          setState(() {
            _profile = updated;
            widget.data.profile = updated;
          });
          widget.onProfileUpdated?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final rawName = profile.fullName.trim();
    final String displayName;
    if (rawName.isEmpty) {
      displayName = 'Name not provided';
    } else if (rawName.toLowerCase().startsWith('dr.') ||
        rawName.toLowerCase().startsWith('dr ')) {
      displayName = rawName;
    } else {
      displayName = 'Dr. $rawName';
    }

    final specializationText = profile.specialization.trim().isNotEmpty
        ? profile.specialization.trim()
        : 'Specialization not provided';

    final qualifications = profile.qualifications.trim();
    final experience = profile.experienceYears.trim();
    final String metaText;
    if (qualifications.isNotEmpty && experience.isNotEmpty) {
      metaText = '$qualifications • $experience Experience';
    } else if (qualifications.isNotEmpty) {
      metaText = qualifications;
    } else if (experience.isNotEmpty) {
      metaText = '$experience Experience';
    } else {
      metaText = 'Qualifications not provided';
    }

    final bioText = profile.bio.trim().isNotEmpty
        ? profile.bio.trim()
        : 'No biography provided yet.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Doctor Profile',
          style: AppTextStyles.headingMedium,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _openEditProfile,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor Bio Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x05000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Interactive Doctor Avatar with Camera Badge
                    Stack(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: _isUploadingPhoto
                              ? const Center(
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                )
                              : _resolvedPhotoUrl != null
                                  ? ClipOval(
                                      child: Image.network(
                                        _resolvedPhotoUrl!,
                                        width: 84,
                                        height: 84,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.person_rounded,
                                          size: 48,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_rounded,
                                      size: 48,
                                      color: AppColors.primary,
                                    ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Material(
                            color: AppColors.primary,
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: InkWell(
                              onTap: _handlePhotoUpload,
                              customBorder: const CircleBorder(),
                              child: const Padding(
                                padding: EdgeInsets.all(7),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName,
                      style: AppTextStyles.headingMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specializationText,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metaText,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openEditProfile,
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // About Doctor Card
              Text(
                'About',
                style: AppTextStyles.headingSmall.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  bioText,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Account & Preferences
              Text(
                'Doctor Settings',
                style: AppTextStyles.headingSmall.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildSettingRow(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      subtitle: 'View appointment and patient updates',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(isDoctor: true),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    _buildSettingRow(
                      icon: Icons.schedule_outlined,
                      title: 'Availability Preferences',
                      subtitle: 'Working days and appointment slots',
                      onTap: () => _showNotice(
                        context,
                        'Use the Clinic tab to manage working hours.',
                      ),
                    ),
                    const Divider(height: 1),
                    _buildSettingRow(
                      icon: Icons.logout_rounded,
                      title: 'Log Out',
                      subtitle: 'Sign out of your account',
                      iconColor: AppColors.emergency,
                      textColor: AppColors.emergency,
                      isLast: true,
                      onTap: () => _showLogoutDialog(context),
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

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(16))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textColor ?? AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileBottomSheet extends StatefulWidget {
  final DoctorProfileModel initialProfile;
  final DoctorRepository repository;
  final ValueChanged<DoctorProfileModel> onSave;

  const _EditProfileBottomSheet({
    required this.initialProfile,
    required this.repository,
    required this.onSave,
  });

  @override
  State<_EditProfileBottomSheet> createState() => _EditProfileBottomSheetState();
}

class _EditProfileBottomSheetState extends State<_EditProfileBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _specializationController;
  late final TextEditingController _qualificationsController;
  late final TextEditingController _experienceController;
  late final TextEditingController _bioController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.initialProfile.fullName);
    _specializationController = TextEditingController(text: widget.initialProfile.specialization);
    _qualificationsController = TextEditingController(text: widget.initialProfile.qualifications);
    _experienceController = TextEditingController(text: widget.initialProfile.experienceYears);
    _bioController = TextEditingController(text: widget.initialProfile.bio);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _specializationController.dispose();
    _qualificationsController.dispose();
    _experienceController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updatedProfile = widget.initialProfile.copyWith(
      fullName: _fullNameController.text.trim(),
      specialization: _specializationController.text.trim(),
      qualifications: _qualificationsController.text.trim(),
      experienceYears: _experienceController.text.trim(),
      bio: _bioController.text.trim(),
    );

    final doctorId = widget.repository.currentUserId;
    if (doctorId != null && doctorId.isNotEmpty) {
      try {
        final persisted = await widget.repository.saveDoctorProfile(
          doctorId: doctorId,
          profile: updatedProfile,
        );

        if (!mounted) return;
        widget.onSave(persisted);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doctor profile updated successfully.'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.emergency,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Local/mock save for testing
      widget.onSave(updatedProfile);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Doctor profile updated successfully.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Doctor Profile',
                    style: AppTextStyles.headingSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textTertiary),
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Full Name
              const Text('Full Name', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              TextFormField(
                controller: _fullNameController,
                decoration: _inputDecoration(
                  hint: 'Dr. Full Name',
                  icon: Icons.person_outline_rounded,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Specialization
              const Text('Specialization', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              TextFormField(
                controller: _specializationController,
                decoration: _inputDecoration(
                  hint: 'e.g. Cardiologist, General Physician',
                  icon: Icons.medical_services_outlined,
                ),
              ),
              const SizedBox(height: 16),

              // Qualifications
              const Text('Qualifications', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              TextFormField(
                controller: _qualificationsController,
                decoration: _inputDecoration(
                  hint: 'e.g. MBBS, FCPS',
                  icon: Icons.school_outlined,
                ),
              ),
              const SizedBox(height: 16),

              // Experience
              const Text('Experience', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              TextFormField(
                controller: _experienceController,
                decoration: _inputDecoration(
                  hint: 'e.g. 5 years',
                  icon: Icons.work_outline_rounded,
                ),
              ),
              const SizedBox(height: 16),

              // Bio
              const Text('Biography / About', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              TextFormField(
                controller: _bioController,
                minLines: 3,
                maxLines: 5,
                decoration: _inputDecoration(
                  hint: 'Write a brief description about your medical background and care philosophy...',
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    IconData? icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
      prefixIcon: icon != null ? Icon(icon, color: AppColors.textTertiary, size: 20) : null,
      filled: true,
      fillColor: AppColors.surfaceSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
