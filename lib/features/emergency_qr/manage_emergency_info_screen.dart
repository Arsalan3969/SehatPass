import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/section_header.dart';
import 'models/emergency_info_model.dart';

class ManageEmergencyInfoScreen extends StatefulWidget {
  const ManageEmergencyInfoScreen({super.key});

  @override
  State<ManageEmergencyInfoScreen> createState() =>
      _ManageEmergencyInfoScreenState();
}

class _ManageEmergencyInfoScreenState extends State<ManageEmergencyInfoScreen> {
  late bool _shareName;
  late bool _shareBloodGroup;
  late bool _shareAllergies;
  late bool _shareMedicalConditions;
  late bool _shareImportantMedicines;
  late bool _shareEmergencyContact;

  @override
  void initState() {
    super.initState();
    final data = EmergencyInfoRepository.instance.data;
    _shareName = data.shareName;
    _shareBloodGroup = data.shareBloodGroup;
    _shareAllergies = data.shareAllergies;
    _shareMedicalConditions = data.shareMedicalConditions;
    _shareImportantMedicines = data.shareImportantMedicines;
    _shareEmergencyContact = data.shareEmergencyContact;
  }

  void _saveChanges() {
    final current = EmergencyInfoRepository.instance.data;
    final updated = current.copyWith(
      shareName: _shareName,
      shareBloodGroup: _shareBloodGroup,
      shareAllergies: _shareAllergies,
      shareMedicalConditions: _shareMedicalConditions,
      shareImportantMedicines: _shareImportantMedicines,
      shareEmergencyContact: _shareEmergencyContact,
    );

    EmergencyInfoRepository.instance.update(updated);

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

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final data = EmergencyInfoRepository.instance.data;

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
        child: SingleChildScrollView(
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
                        'Choose the information that can be shared through your Emergency QR.',
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
                      subtitle: data.fullName,
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
                      subtitle: data.bloodGroup,
                      icon: Icons.water_drop_outlined,
                      value: _shareBloodGroup,
                      onChanged: (val) => setState(() => _shareBloodGroup = val),
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
                      subtitle: data.allergies,
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
                      subtitle: data.medicalConditions,
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
                      subtitle: data.importantMedicines,
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
              const SectionHeader(title: 'Emergency Contact'),
              const SizedBox(height: 10),
              AppCard(
                padding: EdgeInsets.zero,
                child: _buildToggleRow(
                  title: data.emergencyContactName,
                  subtitle:
                      '${data.emergencyContactRelationship} • ${data.emergencyContactPhone}',
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
                  onPressed: _saveChanges,
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
                  child: const Text('Save Changes'),
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
