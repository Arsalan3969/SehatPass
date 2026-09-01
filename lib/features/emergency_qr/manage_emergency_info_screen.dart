import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/section_header.dart';
import 'data/emergency_repository.dart';
import 'models/emergency_info_model.dart';

class ManageEmergencyInfoScreen extends StatefulWidget {
  final EmergencyRepository? repository;
  final EmergencyInfoData? initialData;

  const ManageEmergencyInfoScreen({
    super.key,
    this.repository,
    this.initialData,
  });

  @override
  State<ManageEmergencyInfoScreen> createState() =>
      _ManageEmergencyInfoScreenState();
}

class _ManageEmergencyInfoScreenState extends State<ManageEmergencyInfoScreen> {
  EmergencyRepository get _repo =>
      widget.repository ?? EmergencyRepository.instance;

  late EmergencyInfoData _data;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  late bool _shareName;
  late bool _shareBloodGroup;
  late bool _shareAllergies;
  late bool _shareMedicalConditions;
  late bool _shareImportantMedicines;
  late bool _shareEmergencyContact;

  late String _contactName;
  late String _contactRelationship;
  late String _contactPhone;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _applyData(widget.initialData!);
    } else {
      _data = const EmergencyInfoData();
      _applyData(_data);
      _loadData();
    }
  }

  void _applyData(EmergencyInfoData data) {
    _data = data;
    _shareName = data.shareName;
    _shareBloodGroup = data.shareBloodGroup;
    _shareAllergies = data.shareAllergies;
    _shareMedicalConditions = data.shareMedicalConditions;
    _shareImportantMedicines = data.shareImportantMedicines;
    _shareEmergencyContact = data.shareEmergencyContact;

    _contactName = data.emergencyContactName;
    _contactRelationship = data.emergencyContactRelationship;
    _contactPhone = data.emergencyContactPhone;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final info = await _repo.getEmergencyInfo();
      if (!mounted) return;
      setState(() {
        _applyData(info);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is String ? e : 'Unable to load emergency settings.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openEditContactDialog() async {
    final nameCtrl = TextEditingController(text: _contactName);
    final relationCtrl = TextEditingController(text: _contactRelationship);
    final phoneCtrl = TextEditingController(text: _contactPhone);
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<Map<String, String>>(
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
                Icons.edit_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Emergency Contact',
              style: AppTextStyles.headingSmall,
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Contact Full Name',
                    hintText: 'e.g. Ali Khan',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter contact name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: relationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Relationship',
                    hintText: 'e.g. Brother, Spouse, Friend',
                    prefixIcon: Icon(Icons.people_outline, size: 20),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter relationship'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'e.g. +92 300 1234567',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter phone number'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, {
                  'name': nameCtrl.text.trim(),
                  'relation': relationCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (updated != null) {
      setState(() {
        _contactName = updated['name'] ?? _contactName;
        _contactRelationship = updated['relation'] ?? _contactRelationship;
        _contactPhone = updated['phone'] ?? _contactPhone;
      });
    }
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    final updated = _data.copyWith(
      shareName: _shareName,
      shareBloodGroup: _shareBloodGroup,
      shareAllergies: _shareAllergies,
      shareMedicalConditions: _shareMedicalConditions,
      shareImportantMedicines: _shareImportantMedicines,
      shareEmergencyContact: _shareEmergencyContact,
      emergencyContactName: _contactName,
      emergencyContactRelationship: _contactRelationship,
      emergencyContactPhone: _contactPhone,
    );

    try {
      final saved = await _repo.saveEmergencySettings(updated);

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _applyData(saved);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Emergency information updated.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is String ? e : 'Failed to update emergency settings.'),
          backgroundColor: AppColors.emergency,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Emergency Information'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 40, color: AppColors.emergency),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: AppTextStyles.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    // Info Banner
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.emergencySurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.emergencyBorder),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.shield_outlined,
                              color: AppColors.emergency,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Choose the information that can be shared through your Emergency QR code.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: const Color(0xFF991B1B),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Personal Information ─────────────────────────────────────
                    const SectionHeader(title: 'Personal Information'),
                    const SizedBox(height: 10),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _buildToggleRow(
                            title: 'Name',
                            subtitle: _data.fullName.isNotEmpty
                                ? _data.fullName
                                : 'Not specified',
                            icon: Icons.person_outline_rounded,
                            value: _shareName,
                            onChanged: (val) => setState(() => _shareName = val),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 56),
                            child: Divider(height: 1, color: AppColors.divider),
                          ),
                          _buildToggleRow(
                            title: 'Blood Group',
                            subtitle: _data.bloodGroup.isNotEmpty
                                ? _data.bloodGroup
                                : 'None added',
                            icon: Icons.water_drop_outlined,
                            value: _shareBloodGroup,
                            onChanged: (val) =>
                                setState(() => _shareBloodGroup = val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Medical Information ──────────────────────────────────────
                    const SectionHeader(title: 'Medical Information'),
                    const SizedBox(height: 10),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _buildToggleRow(
                            title: 'Allergies',
                            subtitle: _data.allergies.isNotEmpty
                                ? _data.allergies
                                : 'None added',
                            icon: Icons.warning_amber_rounded,
                            value: _shareAllergies,
                            onChanged: (val) => setState(() => _shareAllergies = val),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 56),
                            child: Divider(height: 1, color: AppColors.divider),
                          ),
                          _buildToggleRow(
                            title: 'Medical Conditions',
                            subtitle: _data.medicalConditions.isNotEmpty
                                ? _data.medicalConditions
                                : 'None added',
                            icon: Icons.favorite_border_rounded,
                            value: _shareMedicalConditions,
                            onChanged: (val) =>
                                setState(() => _shareMedicalConditions = val),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 56),
                            child: Divider(height: 1, color: AppColors.divider),
                          ),
                          _buildToggleRow(
                            title: 'Important Medicines',
                            subtitle: _data.importantMedicines.isNotEmpty
                                ? _data.importantMedicines
                                : 'None added',
                            icon: Icons.medication_outlined,
                            value: _shareImportantMedicines,
                            onChanged: (val) =>
                                setState(() => _shareImportantMedicines = val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Emergency Contact ────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SectionHeader(title: 'Emergency Contact'),
                        TextButton.icon(
                          onPressed: _openEditContactDialog,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit Contact'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: _buildToggleRow(
                        title: _contactName.isNotEmpty
                            ? _contactName
                            : 'No Contact Configured',
                        subtitle: _contactPhone.isNotEmpty
                            ? '${_contactRelationship.isNotEmpty ? "$_contactRelationship • " : ""}$_contactPhone'
                            : 'Tap "Edit Contact" to add emergency phone',
                        icon: Icons.phone_in_talk_outlined,
                        value: _shareEmergencyContact,
                        onChanged: (val) =>
                            setState(() => _shareEmergencyContact = val),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Save Changes Button ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: value
                    ? AppColors.primarySurface
                    : AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: value ? AppColors.primary : AppColors.textTertiary,
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
                      color: value
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primarySurface,
            ),
          ],
        ),
      ),
    );
  }
}
