import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import 'data/emergency_repository.dart';
import 'models/emergency_info_model.dart';

/// Screen representing what a responder or scanner sees after scanning
/// the patient's Emergency QR code according to the patient's privacy settings.
class EmergencyInfoPreviewScreen extends StatefulWidget {
  final EmergencyRepository? repository;
  final EmergencyInfoData? initialData;

  const EmergencyInfoPreviewScreen({
    super.key,
    this.repository,
    this.initialData,
  });

  @override
  State<EmergencyInfoPreviewScreen> createState() =>
      _EmergencyInfoPreviewScreenState();
}

class _EmergencyInfoPreviewScreenState
    extends State<EmergencyInfoPreviewScreen> {
  EmergencyRepository get _repo =>
      widget.repository ?? EmergencyRepository.instance;

  late EmergencyInfoData _data;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _data = widget.initialData!;
    } else {
      _data = const EmergencyInfoData();
      _loadData();
    }
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
        _data = info;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is String
            ? e
            : 'Unable to load emergency preview information.';
        _isLoading = false;
      });
    }
  }

  void _onContactEmergency(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _data.emergencyContactPhone.isNotEmpty
                    ? 'Calling ${_data.emergencyContactName} (${_data.emergencyContactPhone})...'
                    : 'No emergency phone number available.',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.emergency,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyInfo = _data.hasAnySharedInfo;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Emergency Information'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.emergencySurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.emergencyBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.emergency,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Public View',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.emergency,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.emergency),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Emergency Banner
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.emergencySurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.emergencyBorder),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x06000000),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.warning_amber_rounded,
                                      color: AppColors.emergency,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Emergency Information',
                                          style: AppTextStyles.headingSmall
                                              .copyWith(
                                            color: AppColors.emergency,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Permitted health data shared by patient.',
                                          style:
                                              AppTextStyles.bodySmall.copyWith(
                                            color: const Color(0xFF991B1B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_data.shareName &&
                                  _data.fullName.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Divider(
                                    height: 1, color: AppColors.emergencyBorder),
                                const SizedBox(height: 14),
                                Text(
                                  'PATIENT NAME',
                                  style: AppTextStyles.caption.copyWith(
                                    color: const Color(0xFF991B1B),
                                    letterSpacing: 0.8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _data.fullName,
                                  style: AppTextStyles.headingMedium.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Incomplete info advisory
                        if (!_data.isComplete) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFFDE68A)),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 18, color: Color(0xFFD97706)),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Emergency information is incomplete.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        if (!hasAnyInfo)
                          AppCard(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.visibility_off_outlined,
                                    size: 40,
                                    color: AppColors.textTertiary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No Information Shared',
                                    style: AppTextStyles.headingSmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'The patient has turned off all emergency sharing toggles.',
                                    style: AppTextStyles.bodySmall,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // ── Critical Health Details Card ───────────────────────────
                        if (_data.shareBloodGroup ||
                            _data.shareAllergies ||
                            _data.shareMedicalConditions ||
                            _data.shareImportantMedicines) ...[
                          Text(
                            'Medical Details',
                            style: AppTextStyles.headingSmall,
                          ),
                          const SizedBox(height: 10),
                          AppCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                if (_data.shareBloodGroup)
                                  _buildInfoRow(
                                    label: 'Blood Group',
                                    value: _data.bloodGroup.isNotEmpty
                                        ? _data.bloodGroup
                                        : 'None added',
                                    valueColor: AppColors.emergency,
                                    isHighlight: true,
                                    icon: Icons.water_drop_outlined,
                                  ),
                                if (_data.shareAllergies)
                                  _buildInfoRow(
                                    label: 'Allergies',
                                    value: _data.allergies.isNotEmpty
                                        ? _data.allergies
                                        : 'None added',
                                    icon: Icons.warning_amber_rounded,
                                  ),
                                if (_data.shareMedicalConditions)
                                  _buildInfoRow(
                                    label: 'Medical Conditions',
                                    value: _data.medicalConditions.isNotEmpty
                                        ? _data.medicalConditions
                                        : 'None added',
                                    icon: Icons.favorite_border_rounded,
                                  ),
                                if (_data.shareImportantMedicines)
                                  _buildInfoRow(
                                    label: 'Important Medicines',
                                    value: _data.importantMedicines.isNotEmpty
                                        ? _data.importantMedicines
                                        : 'None added',
                                    icon: Icons.medication_outlined,
                                    isLast: true,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ── Emergency Contact Card ─────────────────────────────────
                        if (_data.shareEmergencyContact) ...[
                          Text(
                            'Emergency Contact',
                            style: AppTextStyles.headingSmall,
                          ),
                          const SizedBox(height: 10),
                          AppCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySurface,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.contact_phone_outlined,
                                        color: AppColors.primary,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _data.emergencyContactName.isNotEmpty
                                                ? _data.emergencyContactName
                                                : 'No Contact Configured',
                                            style: AppTextStyles.labelLarge
                                                .copyWith(fontSize: 15),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _data.emergencyContactPhone
                                                    .isNotEmpty
                                                ? '${_data.emergencyContactRelationship.isNotEmpty ? "${_data.emergencyContactRelationship} • " : ""}${_data.emergencyContactPhone}'
                                                : 'No phone number provided',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (_data.emergencyContactPhone.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 46,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _onContactEmergency(context),
                                      icon: const Icon(Icons.phone_rounded,
                                          size: 18),
                                      label: const Text(
                                          'Contact Emergency Contact'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.emergency,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
    bool isHighlight = false,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (isHighlight)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.emergencySurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.emergencyBorder),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: valueColor ?? AppColors.emergency,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                Text(
                  value,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: AppColors.divider),
      ],
    );
  }
}
