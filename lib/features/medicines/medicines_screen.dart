import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import 'data/medicine_repository.dart';
import 'models/medicine_item.dart';
import 'widgets/add_edit_medicine_bottom_sheet.dart';
import 'widgets/medicine_card.dart';
import 'widgets/medicine_progress_card.dart';
import 'widgets/medicine_status_summary.dart';

class MedicinesScreen extends StatefulWidget {
  final MedicineRepository? repository;

  const MedicinesScreen({super.key, this.repository});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  MedicineRepository get _repo => widget.repository ?? MedicineRepository.instance;

  List<MedicineItem> _medicines = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final schedule = await _repo.getTodayMedicineSchedule();
      if (!mounted) return;
      setState(() {
        _medicines = schedule;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is String
            ? e
            : 'Unable to load your medicines. Please try again.';
        _isLoading = false;
      });
    }
  }

  // ── Computed counts ──────────────────────────────────────────────────────
  int get _takenCount =>
      _medicines.where((m) => m.status == MedicineStatus.taken).length;
  int get _upcomingCount =>
      _medicines.where((m) => m.status == MedicineStatus.upcoming).length;
  int get _missedCount =>
      _medicines.where((m) => m.status == MedicineStatus.missed).length;

  Future<void> _markTaken(MedicineItem med) async {
    try {
      await _repo.markDoseTaken(medicineId: med.id);
      await _loadMedicines();
      if (mounted) {
        _showSnackBar('${med.name} marked as taken!');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
            e is String ? e : 'Unable to update dose status. Please try again.');
      }
    }
  }

  void _openAddMedicine() {
    AddEditMedicineBottomSheet.show(
      context,
      onSave: ({
        required String name,
        required String dosage,
        required String instruction,
        required String scheduledTime,
        DateTime? startDate,
      }) async {
        await _repo.addMedicine(
          name: name,
          dosage: dosage,
          instruction: instruction,
          scheduledTime: scheduledTime,
          startDate: startDate,
        );
        await _loadMedicines();
        if (mounted) {
          _showSnackBar('$name added to your schedule.');
        }
      },
    );
  }

  void _openEditMedicine(MedicineItem med) {
    AddEditMedicineBottomSheet.show(
      context,
      existingMedicine: med,
      onSave: ({
        required String name,
        required String dosage,
        required String instruction,
        required String scheduledTime,
        DateTime? startDate,
      }) async {
        await _repo.updateMedicine(
          medicineId: med.id,
          name: name,
          dosage: dosage,
          instruction: instruction,
          scheduledTime: scheduledTime,
          startDate: startDate,
        );
        await _loadMedicines();
        if (mounted) {
          _showSnackBar('$name updated successfully.');
        }
      },
      onDeactivate: (medicineId) async {
        await _repo.deactivateMedicine(medicineId);
        await _loadMedicines();
        if (mounted) {
          _showSnackBar('${med.name} removed from active schedule.');
        }
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Medicines', style: AppTextStyles.headingLarge),
                        const SizedBox(height: 4),
                        Text(
                          'Manage your medicines and stay on schedule.',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  // Notification icon — consistent with Home screen
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x06000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.notifications_outlined,
                          color: AppColors.textPrimary,
                          size: 22,
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Scrollable body with RefreshIndicator ─────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadMedicines,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                  child: _buildBody(),
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Add Medicine FAB ──────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddMedicine,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          'Add Medicine',
          style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading your medicines...',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_medicines.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress card
        MedicineProgressCard(
          taken: _takenCount,
          total: _medicines.length,
        ),

        const SizedBox(height: 24),

        // Section header
        Row(
          children: [
            Text(
              "Today's Medicines",
              style: AppTextStyles.headingSmall,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_medicines.length}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Medicine cards
        ...List.generate(_medicines.length, (index) {
          final med = _medicines[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MedicineCard(
              medicine: med,
              onTap: () => _openEditMedicine(med),
              onMarkTaken: med.status == MedicineStatus.upcoming
                  ? () => _markTaken(med)
                  : null,
            ),
          );
        }),

        const SizedBox(height: 24),

        // Status summary
        MedicineStatusSummary(
          taken: _takenCount,
          upcoming: _upcomingCount,
          missed: _missedCount,
        ),

        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.medication_outlined,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No medicines added yet',
            style: AppTextStyles.headingSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your prescribed medications to track daily doses and stay on schedule.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _openAddMedicine,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Add Medicine',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.emergencySurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.emergencyBorder),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.emergency,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Unable to load your medicines',
              style: AppTextStyles.headingSmall.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Please check your connection and try again.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _loadMedicines,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
