import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import 'models/doctor_model.dart';
import 'book_appointment_screen.dart';

class DoctorProfileScreen extends StatelessWidget {
  final Doctor doctor;
  const DoctorProfileScreen({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header (Avatar, Name, Specialization) ──────────────
                    Container(
                      width: double.infinity,
                      color: AppColors.surface,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                width: 2,
                              ),
                            ),
                            child: doctor.photoUrl != null &&
                                    doctor.photoUrl!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Image.network(
                                      doctor.photoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.person_rounded,
                                        size: 42,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.person_rounded,
                                    size: 42,
                                    color: AppColors.primary,
                                  ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            doctor.name,
                            style: AppTextStyles.headingMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            doctor.qualifications.isNotEmpty
                                ? '${doctor.specialization} • ${doctor.qualifications}'
                                : doctor.specialization,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // ── Body content ───────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Quick info row
                          AppCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                _infoChip(
                                  Icons.location_on_outlined,
                                  doctor.location,
                                  AppColors.primary,
                                  AppColors.primarySurface,
                                ),
                                const Spacer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Consultation',
                                        style: AppTextStyles.bodySmall),
                                    Text(
                                      'Rs. ${doctor.consultationFee}',
                                      style: AppTextStyles.labelLarge.copyWith(
                                        color: AppColors.primary,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // About
                          _sectionTitle('About'),
                          const SizedBox(height: 10),
                          AppCard(
                            child: Text(
                              doctor.about,
                              style: AppTextStyles.bodyMedium.copyWith(
                                height: 1.6,
                                fontSize: 14,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Services
                          _sectionTitle('Services'),
                          const SizedBox(height: 10),
                          AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: doctor.services.asMap().entries.map((e) {
                                final isLast =
                                    e.key == doctor.services.length - 1;
                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 13),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              e.value.name,
                                              style: AppTextStyles.labelLarge
                                                  .copyWith(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            'Rs. ${e.value.fee}',
                                            style: AppTextStyles.labelLarge
                                                .copyWith(
                                              color: AppColors.primary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isLast)
                                      const Divider(
                                          height: 1, color: AppColors.divider),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Clinic Information
                          _sectionTitle('Clinic Information'),
                          const SizedBox(height: 10),
                          AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                _clinicRow(Icons.business_outlined, 'Clinic',
                                    doctor.clinic),
                                const Divider(
                                    height: 1, color: AppColors.divider),
                                _clinicRow(Icons.location_on_outlined,
                                    'Location', doctor.location),
                                const Divider(
                                    height: 1, color: AppColors.divider),
                                _clinicRow(
                                  Icons.calendar_today_outlined,
                                  'Available Days',
                                  doctor.availableDays.length == 6
                                      ? 'Mon – Sat'
                                      : doctor.availableDays
                                          .map((d) => d.substring(0, 3))
                                          .join(', '),
                                ),
                                const Divider(
                                    height: 1, color: AppColors.divider),
                                _clinicRow(
                                  Icons.access_time_outlined,
                                  'Consultation Hours',
                                  doctor.consultationHours,
                                  isLast: true,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom Book Button ─────────────────────────────────────────
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookAppointmentScreen(doctor: doctor),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Book Appointment'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) =>
      Text(title, style: AppTextStyles.headingSmall);

  Widget _infoChip(
      IconData icon, String label, Color iconColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: iconColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clinicRow(IconData icon, String label, String value,
      {bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label,
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
