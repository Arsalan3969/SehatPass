import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'models/medicine_item.dart';
import 'widgets/medicine_progress_card.dart';
import 'widgets/medicine_card.dart';
import 'widgets/medicine_status_summary.dart';

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  // Mutable copy of today's medicine list driven by local state.
  late List<MedicineItem> _medicines;

  @override
  void initState() {
    super.initState();
    _medicines = DummyMedicines.todayList;
  }

  // ── Computed counts ──────────────────────────────────────────────────────
  int get _takenCount =>
      _medicines.where((m) => m.status == MedicineStatus.taken).length;
  int get _upcomingCount =>
      _medicines.where((m) => m.status == MedicineStatus.upcoming).length;
  int get _missedCount =>
      _medicines.where((m) => m.status == MedicineStatus.missed).length;

  void _markTaken(int index) {
    setState(() {
      _medicines[index] =
          _medicines[index].copyWith(status: MedicineStatus.taken);
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        Text('My Medicines',
                            style: AppTextStyles.headingLarge),
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

            // ── Scrollable body ───────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                child: Column(
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
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
                          onMarkTaken: med.status == MedicineStatus.upcoming
                              ? () => _markTaken(index)
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
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Add Medicine FAB ──────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _showSnackBar('Add medicine functionality coming soon.'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          'Add Medicine',
          style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
