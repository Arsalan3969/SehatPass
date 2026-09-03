import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/doctor_repository.dart';
import '../../models/doctor_appointment_model.dart';
import '../../models/doctor_consultation_note_model.dart';
import '../../models/prescription_item_model.dart';

class WriteConsultationNoteSheet extends StatefulWidget {
  final DoctorAppointmentModel appointment;
  final DoctorConsultationNoteModel? existingNote;
  final DoctorRepository? repository;
  final void Function(DoctorConsultationNoteModel savedNote, bool isCompleted)?
      onSaveSuccess;

  const WriteConsultationNoteSheet({
    super.key,
    required this.appointment,
    this.existingNote,
    this.repository,
    this.onSaveSuccess,
  });

  @override
  State<WriteConsultationNoteSheet> createState() =>
      _WriteConsultationNoteSheetState();
}

class _WriteConsultationNoteSheetState
    extends State<WriteConsultationNoteSheet> {
  late final DoctorRepository _repository;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _diagnosisController;
  late final TextEditingController _notesController;

  List<PrescriptionItemModel> _prescriptions = [];
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DoctorRepository.instance;

    final existing = widget.existingNote;
    _diagnosisController =
        TextEditingController(text: existing?.diagnosis ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');

    if (existing != null && existing.prescriptions.isNotEmpty) {
      _prescriptions = List.from(existing.prescriptions);
    }
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _openAddEditPrescriptionDialog({
    PrescriptionItemModel? itemToEdit,
    int? editIndex,
  }) {
    final isEditing = itemToEdit != null && editIndex != null;
    final nameCtrl =
        TextEditingController(text: itemToEdit?.medicineName ?? '');
    final dosageCtrl = TextEditingController(text: itemToEdit?.dosage ?? '');
    final freqCtrl =
        TextEditingController(text: itemToEdit?.frequency ?? 'Twice daily (BD)');
    final durCtrl = TextEditingController(text: itemToEdit?.duration ?? '5 days');
    final instCtrl =
        TextEditingController(text: itemToEdit?.instruction ?? 'After meals');
    final notesCtrl = TextEditingController(text: itemToEdit?.notes ?? '');
    final dialogFormKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.medication_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                isEditing ? 'Edit Medication' : 'Add Medication',
                style: AppTextStyles.headingSmall,
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: dialogFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Medicine Name *',
                      hintText: 'e.g., Augmentin, Panadol',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter medicine name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dosageCtrl,
                    decoration: InputDecoration(
                      labelText: 'Dosage *',
                      hintText: 'e.g., 625mg, 1 tablet, 5ml',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter dosage';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: freqCtrl,
                          decoration: InputDecoration(
                            labelText: 'Frequency',
                            hintText: 'e.g., TDS, OD',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: durCtrl,
                          decoration: InputDecoration(
                            labelText: 'Duration',
                            hintText: 'e.g., 5 days',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: instCtrl,
                    decoration: InputDecoration(
                      labelText: 'Instructions',
                      hintText: 'e.g., After meals, with plenty of water',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Special Notes / Cautions',
                      hintText: 'Optional instructions or warnings',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!dialogFormKey.currentState!.validate()) return;

                final newItem = PrescriptionItemModel(
                  medicineName: nameCtrl.text.trim(),
                  dosage: dosageCtrl.text.trim(),
                  frequency: freqCtrl.text.trim(),
                  duration: durCtrl.text.trim(),
                  instruction: instCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                );

                setState(() {
                  if (isEditing) {
                    _prescriptions[editIndex] = newItem;
                  } else {
                    _prescriptions.add(newItem);
                  }
                });

                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave({required bool completeAppointment}) async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final diagnosisText = _diagnosisController.text.trim();
    final notesText = _notesController.text.trim();

    if (diagnosisText.isEmpty &&
        notesText.isEmpty &&
        _prescriptions.isEmpty) {
      setState(() {
        _errorMessage =
            'Please provide a diagnosis, clinical observation, or prescription.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final notePayload = DoctorConsultationNoteModel(
        id: widget.existingNote?.id ?? '',
        appointmentId: widget.appointment.id,
        doctorId: _repository.currentUserId ?? '',
        patientId: widget.appointment.patientId,
        diagnosis: diagnosisText.isNotEmpty ? diagnosisText : null,
        notes: notesText.isNotEmpty ? notesText : null,
        prescriptions: _prescriptions,
      );

      final saved = await _repository.saveConsultationNote(
        note: notePayload,
        completeAppointment: completeAppointment,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              completeAppointment
                  ? 'Consultation saved and appointment marked as completed!'
                  : 'Consultation note saved successfully.',
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (widget.onSaveSuccess != null) {
          widget.onSaveSuccess!(saved, completeAppointment);
        }

        Navigator.pop(context, saved);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Clinical Consultation & Rx',
                        style: AppTextStyles.headingSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Patient: ${widget.appointment.patientName} (${widget.appointment.serviceName})',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Form Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.emergencySurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.emergencyBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.emergency, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.emergency),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 1. Diagnosis Input Card
                    Text(
                      'Clinical Diagnosis',
                      style: AppTextStyles.labelLarge
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextFormField(
                        controller: _diagnosisController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText:
                              'Enter primary diagnosis or clinical impression (e.g., Acute Upper Respiratory Tract Infection, Essential Hypertension)',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 2. Clinical Notes & Observations
                    Text(
                      'Clinical Observations & Examination Notes',
                      style: AppTextStyles.labelLarge
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextFormField(
                        controller: _notesController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText:
                              'Document symptoms, vital signs, physical exam findings, and follow-up guidance...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 3. Prescriptions Builder Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Prescribed Medications',
                              style: AppTextStyles.labelLarge
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (_prescriptions.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_prescriptions.length}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              _openAddEditPrescriptionDialog(),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Medicine'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_prescriptions.isEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.medication_liquid_outlined,
                                color: AppColors.textTertiary, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              'No medications added yet.',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "+ Add Medicine" to prescribe medications.',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _prescriptions.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _prescriptions[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySurface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.medication_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.medicineName,
                                        style: AppTextStyles.labelLarge
                                            .copyWith(
                                                fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.dosage} • ${item.frequency} • ${item.duration}',
                                        style: AppTextStyles.bodySmall
                                            .copyWith(
                                                color:
                                                    AppColors.textSecondary),
                                      ),
                                      if (item.instruction.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Instruction: ${item.instruction}',
                                          style: AppTextStyles.caption
                                              .copyWith(
                                                  color:
                                                      AppColors.textTertiary),
                                        ),
                                      ],
                                      if (item.notes.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Note: ${item.notes}',
                                          style: AppTextStyles.caption
                                              .copyWith(
                                                  color:
                                                      AppColors.textTertiary,
                                                  fontStyle:
                                                      FontStyle.italic),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18,
                                      color: AppColors.textSecondary),
                                  tooltip: 'Edit item',
                                  onPressed: () =>
                                      _openAddEditPrescriptionDialog(
                                    itemToEdit: item,
                                    editIndex: index,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 18,
                                      color: AppColors.emergency),
                                  tooltip: 'Remove item',
                                  onPressed: () {
                                    setState(() {
                                      _prescriptions.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Actions Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving
                                ? null
                                : () => _handleSave(completeAppointment: false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(
                                  color: AppColors.primary, width: 1.2),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : const Text(
                                    'Save Note',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving
                                ? null
                                : () => _handleSave(completeAppointment: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Save & Complete',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
