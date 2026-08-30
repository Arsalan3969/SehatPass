import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/clinic_service_model.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/service_bottom_sheet.dart';

class AddServicesStep extends StatefulWidget {
  final List<ClinicServiceModel> initialServices;
  final Function(List<ClinicServiceModel> updatedServices) onNext;

  const AddServicesStep({
    super.key,
    required this.initialServices,
    required this.onNext,
  });

  @override
  State<AddServicesStep> createState() => _AddServicesStepState();
}

class _AddServicesStepState extends State<AddServicesStep> {
  late List<ClinicServiceModel> _services;

  @override
  void initState() {
    super.initState();
    _services = List.from(widget.initialServices);
  }

  void _openAddServiceDialog() {
    ServiceBottomSheet.show(
      context,
      onSave: (name, fee) {
        setState(() {
          _services.add(
            ClinicServiceModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: name,
              fee: fee,
            ),
          );
        });
      },
    );
  }

  void _openEditServiceDialog(ClinicServiceModel service) {
    ServiceBottomSheet.show(
      context,
      existingService: service,
      onSave: (name, fee) {
        setState(() {
          final index = _services.indexWhere((s) => s.id == service.id);
          if (index != -1) {
            _services[index] = ClinicServiceModel(
              id: service.id,
              name: name,
              fee: fee,
            );
          }
        });
      },
    );
  }

  void _deleteService(ClinicServiceModel service) {
    setState(() {
      _services.removeWhere((s) => s.id == service.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${service.name} removed'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.primaryLight,
          onPressed: () {
            setState(() {
              _services.add(service);
            });
          },
        ),
      ),
    );
  }

  void _handleContinue() {
    if (_services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Please add at least one service.'),
            ],
          ),
          backgroundColor: AppColors.emergency,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    widget.onNext(_services);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingHeader(
            icon: Icons.medical_information_outlined,
            title: 'Clinic Services',
            subtitle:
                'Add the services you offer and set your consultation fees.',
          ),
          const SizedBox(height: 24),

          // Add Service Button
          OutlinedButton.icon(
            onPressed: _openAddServiceDialog,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add Service'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Services List
          if (_services.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No services added yet',
                    style: AppTextStyles.headingSmall,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap "+ Add Service" to add your consultations and pricing.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _services.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final service = _services[index];
                return _buildServiceCard(service);
              },
            ),
          ],

          const SizedBox(height: 32),

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
    );
  }

  Widget _buildServiceCard(ClinicServiceModel service) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Icon badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.healing_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Name and Fee
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  service.formattedFee,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Edit Action
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: AppColors.textSecondary,
            tooltip: 'Edit Service',
            visualDensity: VisualDensity.compact,
            onPressed: () => _openEditServiceDialog(service),
          ),

          // Delete Action
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: AppColors.emergency,
            tooltip: 'Delete Service',
            visualDensity: VisualDensity.compact,
            onPressed: () => _deleteService(service),
          ),
        ],
      ),
    );
  }
}
