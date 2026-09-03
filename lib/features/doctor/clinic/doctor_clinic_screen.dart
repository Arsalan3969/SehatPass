import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/doctor_repository.dart';
import '../models/clinic_model.dart';
import '../models/doctor_availability_model.dart';
import '../models/doctor_onboarding_data.dart';
import '../onboarding/widgets/service_bottom_sheet.dart';

class DoctorClinicScreen extends StatefulWidget {
  final DoctorOnboardingData data;
  final DoctorRepository? repository;

  const DoctorClinicScreen({
    super.key,
    required this.data,
    this.repository,
  });

  @override
  State<DoctorClinicScreen> createState() => _DoctorClinicScreenState();
}

class _DoctorClinicScreenState extends State<DoctorClinicScreen> {
  late final DoctorRepository _repository;
  late DoctorAvailabilityModel _availability;
  bool _isLoadingAvailability = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DoctorRepository.instance;
    _availability = widget.data.availability;

    if (_repository.currentUserId != null) {
      _loadAvailabilityFromSupabase();
    }
  }

  Future<void> _loadAvailabilityFromSupabase() async {
    final doctorId = _repository.currentUserId;
    if (doctorId == null) return;

    setState(() => _isLoadingAvailability = true);

    try {
      final fetched = await _repository.getDoctorAvailability(
        doctorId: doctorId,
        clinicId: widget.data.clinic.id,
      );
      if (mounted) {
        setState(() {
          _availability = fetched;
          widget.data.availability = fetched;
          _isLoadingAvailability = false;
        });
      }
    } catch (e) {
      debugPrint('DoctorClinicScreen: Error fetching availability from Supabase: $e');
      if (mounted) {
        setState(() => _isLoadingAvailability = false);
      }
    }
  }

  void _openEditClinic() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditClinicBottomSheet(
        initialClinic: widget.data.clinic,
        repository: _repository,
        onSave: (updated) {
          setState(() {
            widget.data.clinic = updated;
          });
        },
      ),
    );
  }

  void _openAddService() {
    ServiceBottomSheet.show(
      context,
      onSave: (name, fee) {
        setState(() {
          widget.data.addService(name, fee);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name added successfully.'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _openEditAvailability() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditAvailabilityBottomSheet(
        initialAvailability: _availability,
        onSave: (updated) async {
          final doctorId = _repository.currentUserId;

          setState(() {
            _availability = updated;
            widget.data.availability = updated;
          });

          if (doctorId != null) {
            try {
              final persisted = await _repository.saveDoctorAvailability(
                doctorId: doctorId,
                clinicId: widget.data.clinic.id,
                availability: updated,
              );
              if (mounted) {
                setState(() {
                  _availability = persisted;
                  widget.data.availability = persisted;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Consultation availability updated and saved.'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to persist availability: $e'),
                    backgroundColor: AppColors.emergency,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Consultation availability updated.'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clinic = widget.data.clinic;
    final clinicName = clinic.name.trim().isNotEmpty
        ? clinic.name.trim()
        : 'Clinic not registered yet';
    final address = clinic.address.trim();
    final city = clinic.city.trim();
    final locationText = address.isNotEmpty && city.isNotEmpty
        ? '$address, $city'
        : (address.isNotEmpty
            ? address
            : (city.isNotEmpty ? city : 'Location not provided'));
    final descriptionText = clinic.description.trim().isNotEmpty
        ? clinic.description.trim()
        : 'No clinic description provided yet.';
    final phoneText = clinic.phone.trim().isNotEmpty
        ? clinic.phone.trim()
        : 'Phone not provided';
    final services = widget.data.services;
    final availability = _availability;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Manage Clinic',
          style: AppTextStyles.headingMedium,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _openEditClinic,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Clinic'),
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
              // Clinic Banner Card
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.local_hospital_rounded,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clinicName,
                                style: AppTextStyles.headingMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                locationText,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      descriptionText,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            phoneText,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Published',
                            style: TextStyle(
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openEditClinic,
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit Clinic Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Services Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Offered Services (${services.length})',
                      style: AppTextStyles.headingSmall.copyWith(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openAddService,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: services.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final service = services[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              service.name,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            service.formattedFee,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Availability / Schedule Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Consultation Availability',
                      style: AppTextStyles.headingSmall.copyWith(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openEditAvailability,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: _isLoadingAvailability
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    : Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.calendar_today_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Working Days',
                                        style: AppTextStyles.caption),
                                    const SizedBox(height: 2),
                                    Text(
                                      availability.formattedDays,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.schedule_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Consultation Hours',
                                        style: AppTextStyles.caption),
                                    const SizedBox(height: 2),
                                    Text(
                                      availability.formattedHours,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
}

class _EditAvailabilityBottomSheet extends StatefulWidget {
  final DoctorAvailabilityModel initialAvailability;
  final ValueChanged<DoctorAvailabilityModel> onSave;

  const _EditAvailabilityBottomSheet({
    required this.initialAvailability,
    required this.onSave,
  });

  @override
  State<_EditAvailabilityBottomSheet> createState() =>
      _EditAvailabilityBottomSheetState();
}

class _EditAvailabilityBottomSheetState
    extends State<_EditAvailabilityBottomSheet> {
  late List<String> _selectedDays;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    _selectedDays = List.from(widget.initialAvailability.selectedDays);
    _startTime = widget.initialAvailability.startTime;
    _endTime = widget.initialAvailability.endTime;
  }

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
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
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
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
      setState(() => _endTime = picked);
    }
  }

  void _handleSave() {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Please select at least one working day.'),
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

    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('End time must be after start time.'),
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

    final updated = widget.initialAvailability.copyWith(
      selectedDays: _selectedDays,
      startTime: _startTime,
      endTime: _endTime,
    );

    Navigator.pop(context);
    widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Availability',
                  style: AppTextStyles.headingSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Working Days
            Text(
              'Working Days',
              style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DoctorAvailabilityModel.allDays.map((day) {
                final isSelected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(day),
                  selected: isSelected,
                  onSelected: (_) => _toggleDay(day),
                  selectedColor: AppColors.primarySurface,
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Consultation Hours
            Text(
              'Consultation Hours',
              style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickStartTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Start Time', style: AppTextStyles.caption),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.initialAvailability.formatTime(_startTime),
                                style: AppTextStyles.headingSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const Icon(Icons.schedule_rounded,
                                  size: 16, color: AppColors.primary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickEndTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('End Time', style: AppTextStyles.caption),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.initialAvailability.formatTime(_endTime),
                                style: AppTextStyles.headingSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const Icon(Icons.schedule_rounded,
                                  size: 16, color: AppColors.primary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Availability',
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
    );
  }
}

class _EditClinicBottomSheet extends StatefulWidget {
  final ClinicModel initialClinic;
  final DoctorRepository repository;
  final ValueChanged<ClinicModel> onSave;

  const _EditClinicBottomSheet({
    required this.initialClinic,
    required this.repository,
    required this.onSave,
  });

  @override
  State<_EditClinicBottomSheet> createState() => _EditClinicBottomSheetState();
}

class _EditClinicBottomSheetState extends State<_EditClinicBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _phoneController;
  late final TextEditingController _descriptionController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialClinic.name);
    _addressController = TextEditingController(text: widget.initialClinic.address);
    _cityController = TextEditingController(text: widget.initialClinic.city);
    _phoneController = TextEditingController(text: widget.initialClinic.phone);
    _descriptionController = TextEditingController(text: widget.initialClinic.description);
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updatedClinic = widget.initialClinic.copyWith(
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      phone: _phoneController.text.trim(),
      description: _descriptionController.text.trim(),
    );

    final doctorId = widget.repository.currentUserId;
    if (doctorId != null && doctorId.isNotEmpty) {
      try {
        final persisted = await widget.repository.saveDoctorClinic(
          doctorId: doctorId,
          clinic: updatedClinic,
        );

        if (!mounted) return;
        widget.onSave(persisted);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clinic details updated successfully.'),
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
      widget.onSave(updatedClinic);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clinic details updated successfully.'),
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
                    'Edit Clinic Details',
                    style: AppTextStyles.headingSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textTertiary),
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Clinic Name
              const Text('Clinic Name', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration(
                  hint: 'Enter clinic or hospital name',
                  icon: Icons.local_hospital_outlined,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter the clinic name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Address
              const Text('Address', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              TextFormField(
                controller: _addressController,
                decoration: _inputDecoration(
                  hint: 'Street address, building, or area',
                  icon: Icons.location_on_outlined,
                ),
              ),
              const SizedBox(height: 16),

              // City
              const Text('City', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              TextFormField(
                controller: _cityController,
                decoration: _inputDecoration(
                  hint: 'e.g. Lahore, Karachi, Islamabad',
                  icon: Icons.location_city_outlined,
                ),
              ),
              const SizedBox(height: 16),

              // Phone Number
              const Text('Phone Number', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(
                  hint: 'e.g. +92 300 1234567',
                  icon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 16),

              // Description
              const Text('Clinic Description', style: AppTextStyles.labelMedium),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: _inputDecoration(
                  hint: 'Describe facilities, parking, landmarks, or special instructions...',
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
