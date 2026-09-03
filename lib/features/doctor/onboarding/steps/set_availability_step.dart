import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/doctor_availability_model.dart';
import '../widgets/onboarding_header.dart';

class SetAvailabilityStep extends StatefulWidget {
  final DoctorAvailabilityModel initialData;
  final Function(DoctorAvailabilityModel updatedAvailability) onNext;

  const SetAvailabilityStep({
    super.key,
    required this.initialData,
    required this.onNext,
  });

  @override
  State<SetAvailabilityStep> createState() => _SetAvailabilityStepState();
}

class _SetAvailabilityStepState extends State<SetAvailabilityStep> {
  late List<String> _selectedDays;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    _selectedDays = List.from(widget.initialData.selectedDays);
    _startTime = widget.initialData.startTime;
    _endTime = widget.initialData.endTime;
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

  void _handleContinue() {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Please select at least one available day.'),
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

    final updated = widget.initialData.copyWith(
      selectedDays: _selectedDays,
      startTime: _startTime,
      endTime: _endTime,
    );
    widget.onNext(updated);
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
            icon: Icons.access_time_filled_rounded,
            title: 'Set Your Availability',
            subtitle: 'Choose when patients can book appointments.',
          ),
          const SizedBox(height: 24),

          // Days Section
          Text(
            'Available Days',
            style: AppTextStyles.headingSmall.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Select the working days for your clinic consultations.',
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 14),

          // Days Wrap Chips
          Wrap(
            spacing: 8,
            runSpacing: 10,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          // Consultation Hours Section
          Text(
            'Consultation Hours',
            style: AppTextStyles.headingSmall.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Set your starting and ending consultation hours.',
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 14),

          // Hours Selection Cards
          Row(
            children: [
              // Start Time
              Expanded(
                child: _buildTimeSelectorCard(
                  label: 'Start Time',
                  time: widget.initialData.formatTime(_startTime),
                  icon: Icons.wb_sunny_outlined,
                  onTap: _pickStartTime,
                ),
              ),
              const SizedBox(width: 12),

              // End Time
              Expanded(
                child: _buildTimeSelectorCard(
                  label: 'End Time',
                  time: widget.initialData.formatTime(_endTime),
                  icon: Icons.nightlight_round_outlined,
                  onTap: _pickEndTime,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Summary Pill
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_available_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_selectedDays.length} days active • ${widget.initialData.formatTime(_startTime)} - ${widget.initialData.formatTime(_endTime)}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

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

  Widget _buildTimeSelectorCard({
    required String label,
    required String time,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time,
                  style: AppTextStyles.headingSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Icon(
                  Icons.schedule_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
