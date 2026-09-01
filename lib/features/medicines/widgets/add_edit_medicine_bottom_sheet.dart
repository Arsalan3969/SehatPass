import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/medicine_item.dart';

typedef SaveMedicineCallback = Future<void> Function({
  required String name,
  required String dosage,
  required String instruction,
  required String scheduledTime,
  DateTime? startDate,
});

/// Modal bottom sheet for adding or editing a patient medication.
class AddEditMedicineBottomSheet extends StatefulWidget {
  final MedicineItem? existingMedicine;
  final SaveMedicineCallback onSave;
  final Future<void> Function(String medicineId)? onDeactivate;

  const AddEditMedicineBottomSheet({
    super.key,
    this.existingMedicine,
    required this.onSave,
    this.onDeactivate,
  });

  static Future<void> show(
    BuildContext context, {
    MedicineItem? existingMedicine,
    required SaveMedicineCallback onSave,
    Future<void> Function(String medicineId)? onDeactivate,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditMedicineBottomSheet(
        existingMedicine: existingMedicine,
        onSave: onSave,
        onDeactivate: onDeactivate,
      ),
    );
  }

  @override
  State<AddEditMedicineBottomSheet> createState() =>
      _AddEditMedicineBottomSheetState();
}

class _AddEditMedicineBottomSheetState
    extends State<AddEditMedicineBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  late final TextEditingController _instructionController;
  late final TextEditingController _timeController;
  late final TextEditingController _startDateController;

  DateTime _startDate = DateTime.now();
  bool _isSaving = false;
  bool _isDeleting = false;
  String? _errorMessage;

  static const List<String> _instructionPresets = [
    'After Breakfast',
    'After Lunch',
    'After Dinner',
    'Before Breakfast',
    'Before Sleep',
    'As Needed',
  ];

  @override
  void initState() {
    super.initState();
    final med = widget.existingMedicine;
    _nameController = TextEditingController(text: med?.name ?? '');
    _dosageController = TextEditingController(text: med?.dosage ?? '');
    _instructionController =
        TextEditingController(text: med?.instruction ?? 'After Meal');
    _timeController = TextEditingController(text: med?.time ?? '8:00 PM');
    _startDate = med?.startDate ?? DateTime.now();
    _startDateController =
        TextEditingController(text: _formatDisplayDate(_startDate));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _instructionController.dispose();
    _timeController.dispose();
    _startDateController.dispose();
    super.dispose();
  }

  String _formatDisplayDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _pickTime() async {
    // Parse current time in text controller or fallback to now
    TimeOfDay initialTime = TimeOfDay.now();
    final text = _timeController.text.trim();
    if (text.isNotEmpty) {
      try {
        final match =
            RegExp(r'(\d+):(\d+)\s*(AM|PM)?', caseSensitive: false).firstMatch(text);
        if (match != null) {
          int h = int.parse(match.group(1)!);
          final m = int.parse(match.group(2)!);
          final p = match.group(3)?.toUpperCase();
          if (p == 'PM' && h < 12) h += 12;
          if (p == 'AM' && h == 12) h = 0;
          initialTime = TimeOfDay(hour: h, minute: m);
        }
      } catch (_) {}
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
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
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      setState(() {
        _timeController.text = '$hour:$minute $period';
      });
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
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
        _startDate = picked;
        _startDateController.text = _formatDisplayDate(picked);
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSaving || _isDeleting) return;
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });

      try {
        await widget.onSave(
          name: _nameController.text.trim(),
          dosage: _dosageController.text.trim(),
          instruction: _instructionController.text.trim(),
          scheduledTime: _timeController.text.trim(),
          startDate: _startDate,
        );
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSaving = false;
            _errorMessage =
                e is String ? e : 'Failed to save medicine. Please try again.';
          });
        }
      }
    }
  }

  Future<void> _handleDeactivate() async {
    final medId = widget.existingMedicine?.id;
    if (medId == null || medId.isEmpty || widget.onDeactivate == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: const Text(
          'Remove Medicine',
          style: AppTextStyles.headingSmall,
        ),
        content: Text(
          'Are you sure you want to remove "${widget.existingMedicine?.name}" from your active medicines schedule?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergency,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isDeleting = true;
        _errorMessage = null;
      });

      try {
        await widget.onDeactivate!(medId);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isDeleting = false;
            _errorMessage = e is String
                ? e
                : 'Failed to remove medicine. Please try again.';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingMedicine != null;
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
                      isEditing ? 'Edit Medicine' : 'Add New Medicine',
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

                // Medicine Name Field
                Text(
                  'Medicine Name',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g. Panadol, Augmentin 625mg',
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
                      return 'Please enter medicine name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Dosage Field
                Text(
                  'Dosage',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _dosageController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'e.g. 1 Tablet, 500mg, 1 Capsule, 5ml',
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
                      return 'Please enter dosage';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Instruction Field with presets
                Text(
                  'Instruction',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _instructionController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'e.g. After Dinner, With Water',
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
                      return 'Please enter instruction';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _instructionPresets.map((preset) {
                    final isSelected =
                        _instructionController.text.trim() == preset;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _instructionController.text = preset;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primarySurface
                              : AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          preset,
                          style: AppTextStyles.caption.copyWith(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Scheduled Time Field (Clock only -> TimePicker)
                Text(
                  'Daily Scheduled Time',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _timeController,
                  readOnly: true,
                  onTap: _pickTime,
                  decoration: InputDecoration(
                    hintText: 'Tap to select time (e.g. 8:00 PM)',
                    prefixIcon: const Icon(Icons.access_time_rounded,
                        color: AppColors.primary, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.schedule_rounded,
                          size: 20, color: AppColors.primary),
                      onPressed: _pickTime,
                      tooltip: 'Select Time',
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
                      return 'Please select scheduled time';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Start Date Field (Calendar only -> DatePicker)
                Text(
                  'Prescription Start Date',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _startDateController,
                  readOnly: true,
                  onTap: _pickStartDate,
                  decoration: InputDecoration(
                    hintText: 'Tap to select start date',
                    prefixIcon: const Icon(Icons.calendar_today_outlined,
                        color: AppColors.primary, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.edit_calendar_rounded,
                          size: 18, color: AppColors.primary),
                      onPressed: _pickStartDate,
                      tooltip: 'Select Date',
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
                    onPressed: _isSaving ? null : _handleSubmit,
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
                        : Text(
                            isEditing ? 'Save Changes' : 'Save Medicine',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                // Remove Medicine Button (editing only)
                if (isEditing && widget.onDeactivate != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton.icon(
                      onPressed: _isDeleting ? null : _handleDeactivate,
                      icon: _isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.emergency),
                              ),
                            )
                          : const Icon(Icons.delete_outline_rounded,
                              color: AppColors.emergency, size: 18),
                      label: Text(
                        _isDeleting ? 'Removing...' : 'Remove from Schedule',
                        style: const TextStyle(
                          color: AppColors.emergency,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
