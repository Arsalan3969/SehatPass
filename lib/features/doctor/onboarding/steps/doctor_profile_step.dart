import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../services/image_upload_service.dart';
import '../../models/doctor_profile_model.dart';
import '../widgets/onboarding_header.dart';

class DoctorProfileStep extends StatefulWidget {
  final DoctorProfileModel initialData;
  final Function(DoctorProfileModel updatedProfile) onNext;

  const DoctorProfileStep({
    super.key,
    required this.initialData,
    required this.onNext,
  });

  @override
  State<DoctorProfileStep> createState() => _DoctorProfileStepState();
}

class _DoctorProfileStepState extends State<DoctorProfileStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _specializationController;
  late final TextEditingController _qualificationsController;
  late final TextEditingController _experienceController;
  late final TextEditingController _bioController;

  String? _photoPathOrUrl;
  Uint8List? _localPhotoBytes;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData.fullName);
    _specializationController =
        TextEditingController(text: widget.initialData.specialization);
    _qualificationsController =
        TextEditingController(text: widget.initialData.qualifications);
    _experienceController =
        TextEditingController(text: widget.initialData.experienceYears);
    _bioController = TextEditingController(text: widget.initialData.bio);
    _photoPathOrUrl = widget.initialData.photoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specializationController.dispose();
    _qualificationsController.dispose();
    _experienceController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handlePhotoUpload() async {
    if (_isUploadingPhoto) return;

    try {
      final action = await ImageUploadService.instance.showImagePickerSheet(
        context,
        hasExistingImage: _photoPathOrUrl != null || _localPhotoBytes != null,
      );

      if (action == null || !mounted) return;

      if (action == ImagePickerResultAction.remove) {
        setState(() {
          _photoPathOrUrl = null;
          _localPhotoBytes = null;
        });
        return;
      }

      final source = action == ImagePickerResultAction.camera
          ? ImageSource.camera
          : ImageSource.gallery;

      final xfile = await ImageUploadService.instance.pickImage(source);
      if (xfile == null || !mounted) return;

      final bytes = await xfile.readAsBytes();
      if (!mounted) return;

      setState(() {
        _isUploadingPhoto = true;
        _localPhotoBytes = bytes;
      });

      final storagePath = await ImageUploadService.instance.uploadImage(
        imageBytes: bytes,
        fileNamePrefix: 'doctor_avatar',
      );

      if (!mounted) return;
      setState(() {
        _photoPathOrUrl = storagePath;
        _isUploadingPhoto = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Doctor photo uploaded successfully.'),
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

  void _handleContinue() {
    if (_formKey.currentState?.validate() ?? false) {
      final updated = widget.initialData.copyWith(
        fullName: _nameController.text.trim(),
        specialization: _specializationController.text.trim(),
        qualifications: _qualificationsController.text.trim(),
        experienceYears: _experienceController.text.trim(),
        bio: _bioController.text.trim(),
        photoUrl: _photoPathOrUrl,
      );
      widget.onNext(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const OnboardingHeader(
              icon: Icons.person_pin_rounded,
              title: 'Set Up Your Doctor Profile',
              subtitle: 'Tell patients a little about yourself.',
            ),
            const SizedBox(height: 24),

            // Profile photo selector & preview
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
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
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : _localPhotoBytes != null
                            ? ClipOval(
                                child: Image.memory(
                                  _localPhotoBytes!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.person_rounded,
                                size: 56,
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
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _handlePhotoUpload,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  _photoPathOrUrl != null || _localPhotoBytes != null
                      ? 'Change Photo'
                      : 'Add Photo',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Full Name
            _buildInputField(
              label: 'Full Name',
              controller: _nameController,
              hint: 'e.g. Dr. Sarah Ahmed',
              icon: Icons.badge_outlined,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Full name is required' : null,
            ),
            const SizedBox(height: 16),

            // Specialization
            _buildInputField(
              label: 'Specialization',
              controller: _specializationController,
              hint: 'e.g. Cardiologist, Dermatologist',
              icon: Icons.medical_services_outlined,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Specialization is required'
                  : null,
            ),
            const SizedBox(height: 16),

            // Qualifications
            _buildInputField(
              label: 'Qualifications',
              controller: _qualificationsController,
              hint: 'e.g. MBBS, FCPS',
              icon: Icons.school_outlined,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Qualifications are required'
                  : null,
            ),
            const SizedBox(height: 16),

            // Years of Experience
            _buildInputField(
              label: 'Years of Experience',
              controller: _experienceController,
              hint: 'e.g. 5 years',
              icon: Icons.timeline_rounded,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Years of experience is required'
                  : null,
            ),
            const SizedBox(height: 16),

            // Short Bio
            _buildInputField(
              label: 'Short Bio',
              controller: _bioController,
              hint:
                  'Brief summary of your clinical practice and expertise.',
              icon: Icons.notes_rounded,
              maxLines: 3,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Short bio is required' : null,
            ),
            const SizedBox(height: 28),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
              fontSize: 13,
            ),
            prefixIcon: maxLines == 1
                ? Icon(icon, color: AppColors.textSecondary, size: 20)
                : null,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          ),
          validator: validator,
        ),
      ],
    );
  }
}
