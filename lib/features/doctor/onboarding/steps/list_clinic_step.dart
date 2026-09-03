import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/clinic_model.dart';
import '../widgets/onboarding_header.dart';

class ListClinicStep extends StatefulWidget {
  final ClinicModel initialData;
  final Function(ClinicModel updatedClinic) onNext;

  const ListClinicStep({
    super.key,
    required this.initialData,
    required this.onNext,
  });

  @override
  State<ListClinicStep> createState() => _ListClinicStepState();
}

class _ListClinicStepState extends State<ListClinicStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _phoneController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData.name);
    _addressController = TextEditingController(text: widget.initialData.address);
    _cityController = TextEditingController(text: widget.initialData.city);
    _phoneController = TextEditingController(text: widget.initialData.phone);
    _descriptionController =
        TextEditingController(text: widget.initialData.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleImageUpload() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Clinic image upload will be available soon.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleContinue() {
    if (_formKey.currentState?.validate() ?? false) {
      final updated = widget.initialData.copyWith(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        phone: _phoneController.text.trim(),
        description: _descriptionController.text.trim(),
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
              icon: Icons.local_hospital_outlined,
              title: 'List Your Clinic',
              subtitle: 'Add your clinic so patients can find you.',
            ),
            const SizedBox(height: 20),

            // Clinic image / logo placeholder banner
            InkWell(
              onTap: _handleImageUpload,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_outlined,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Upload Clinic Logo or Photo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'PNG, JPG up to 5MB (Optional)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Clinic Name
            _buildInputField(
              label: 'Clinic Name',
              controller: _nameController,
              hint: 'e.g. Al-Razi Healthcare Clinic',
              icon: Icons.storefront_outlined,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Clinic name is required' : null,
            ),
            const SizedBox(height: 16),

            // Clinic Address
            _buildInputField(
              label: 'Clinic Address',
              controller: _addressController,
              hint: 'e.g. Plot 12-A, Main Boulevard, Gulberg III',
              icon: Icons.location_on_outlined,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Address is required' : null,
            ),
            const SizedBox(height: 16),

            // City
            _buildInputField(
              label: 'City',
              controller: _cityController,
              hint: 'e.g. Lahore, Karachi, Islamabad',
              icon: Icons.location_city_outlined,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'City is required' : null,
            ),
            const SizedBox(height: 16),

            // Clinic Phone
            _buildInputField(
              label: 'Clinic Phone',
              controller: _phoneController,
              hint: 'e.g. +92 42 35789000',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Phone number is required' : null,
            ),
            const SizedBox(height: 16),

            // Clinic Description
            _buildInputField(
              label: 'Clinic Description',
              controller: _descriptionController,
              hint:
                  'Brief overview of clinic services, facilities, and patient care.',
              icon: Icons.description_outlined,
              maxLines: 3,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Clinic description is required'
                  : null,
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
    TextInputType? keyboardType,
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
          keyboardType: keyboardType,
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
