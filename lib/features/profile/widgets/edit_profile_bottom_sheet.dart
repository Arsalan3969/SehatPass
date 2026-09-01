import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Modal bottom sheet for editing patient profile information.
class EditProfileBottomSheet extends StatefulWidget {
  final String initialFullName;
  final String initialDob;
  final String initialGender;
  final String initialBloodGroup;
  final String initialAllergies;
  final String initialMedicalConditions;
  final VoidCallback onProfileUpdated;

  const EditProfileBottomSheet({
    super.key,
    required this.initialFullName,
    required this.initialDob,
    required this.initialGender,
    required this.initialBloodGroup,
    required this.initialAllergies,
    required this.initialMedicalConditions,
    required this.onProfileUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialFullName,
    required String initialDob,
    required String initialGender,
    required String initialBloodGroup,
    required String initialAllergies,
    required String initialMedicalConditions,
    required VoidCallback onProfileUpdated,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditProfileBottomSheet(
        initialFullName: initialFullName,
        initialDob: initialDob,
        initialGender: initialGender,
        initialBloodGroup: initialBloodGroup,
        initialAllergies: initialAllergies,
        initialMedicalConditions: initialMedicalConditions,
        onProfileUpdated: onProfileUpdated,
      ),
    );
  }

  @override
  State<EditProfileBottomSheet> createState() =>
      _EditProfileBottomSheetState();
}

class _EditProfileBottomSheetState extends State<EditProfileBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _dobController;
  late final TextEditingController _allergiesController;
  late final TextEditingController _conditionsController;

  String _selectedGender = 'Male';
  String _selectedBloodGroup = 'O+';
  DateTime? _selectedDob;
  bool _isSaving = false;
  String? _errorMessage;

  static const List<String> _genderOptions = ['Male', 'Female', 'Other'];
  static const List<String> _bloodGroupOptions = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.initialFullName == 'Patient' ? '' : widget.initialFullName);
    _dobController = TextEditingController(
        text: widget.initialDob == 'Not specified' ? '' : widget.initialDob);
    _allergiesController = TextEditingController(
        text: widget.initialAllergies == 'None added' ? '' : widget.initialAllergies);
    _conditionsController = TextEditingController(
        text: widget.initialMedicalConditions == 'None added'
            ? ''
            : widget.initialMedicalConditions);

    if (_genderOptions.contains(widget.initialGender)) {
      _selectedGender = widget.initialGender;
    }

    if (_bloodGroupOptions.contains(widget.initialBloodGroup)) {
      _selectedBloodGroup = widget.initialBloodGroup;
    }

    if (widget.initialDob.isNotEmpty && widget.initialDob != 'Not specified') {
      _selectedDob = DateTime.tryParse(widget.initialDob);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });

      try {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id;

        if (userId == null) {
          throw 'User session expired. Please sign in again.';
        }

        final updatedName = _nameController.text.trim();
        final allergies = _allergiesController.text.trim();
        final conditions = _conditionsController.text.trim();

        // 1. Update public.profiles
        await client.from('profiles').update({
          'full_name': updatedName,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);

        // 2. Upsert public.patient_profiles
        final patientProfilePayload = <String, dynamic>{
          'patient_id': userId,
          'gender': _selectedGender,
          'blood_group': _selectedBloodGroup,
          'allergies': allergies.isNotEmpty ? allergies : 'None added',
          'medical_conditions':
              conditions.isNotEmpty ? conditions : 'None added',
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (_selectedDob != null) {
          patientProfilePayload['date_of_birth'] = _formatDate(_selectedDob!);
        }

        await client.from('patient_profiles').upsert(
              patientProfilePayload,
              onConflict: 'patient_id',
            );

        widget.onProfileUpdated();

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSaving = false;
            _errorMessage =
                e is String ? e : 'Unable to update profile. Please try again.';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Profile',
                      style: AppTextStyles.headingMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.emergencySurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.emergencyBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.emergency, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.emergency,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Full Name Field
                Text(
                  'Full Name',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g. Arsalan',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Date of Birth
                Text(
                  'Date of Birth',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  onTap: _pickDob,
                  decoration: InputDecoration(
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: const Icon(Icons.cake_outlined,
                        color: AppColors.primary, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppColors.textSecondary),
                      onPressed: _pickDob,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 14),

                // Gender & Blood Group Row
                Row(
                  children: [
                    // Gender
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gender',
                            style:
                                AppTextStyles.labelLarge.copyWith(fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedGender,
                            items: _genderOptions
                                .map((g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(g),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedGender = val);
                              }
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surfaceSecondary,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Blood Group
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Blood Group',
                            style:
                                AppTextStyles.labelLarge.copyWith(fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedBloodGroup,
                            items: _bloodGroupOptions
                                .map((bg) => DropdownMenuItem(
                                      value: bg,
                                      child: Text(bg),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedBloodGroup = val);
                              }
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surfaceSecondary,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Allergies Field
                Text(
                  'Known Allergies',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _allergiesController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Penicillin, Peanuts, Dust (or None)',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 14),

                // Chronic / Medical Conditions Field
                Text(
                  'Medical Conditions / Chronic Diseases',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _conditionsController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Asthma, Hypertension (or None)',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
