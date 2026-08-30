import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import 'models/doctor_model.dart';
import 'payment_screen.dart';

class ReviewAppointmentScreen extends StatelessWidget {
  final Doctor doctor;
  final DateTime date;
  final String time;

  const ReviewAppointmentScreen({
    super.key,
    required this.doctor,
    required this.date,
    required this.time,
  });

  String get _formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static const int _platformFee = 100;

  @override
  Widget build(BuildContext context) {
    final total = doctor.consultationFee + _platformFee;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Review Appointment'),
        centerTitle: false,
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Doctor summary ───────────────────────────────────
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.person_rounded,
                                size: 28, color: AppColors.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(doctor.name,
                                    style: AppTextStyles.labelLarge
                                        .copyWith(fontSize: 15)),
                                const SizedBox(height: 3),
                                Text(doctor.specialization,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 13,
                                        color: AppColors.textTertiary),
                                    const SizedBox(width: 3),
                                    Text('${doctor.clinic}, ${doctor.location}',
                                        style: AppTextStyles.bodySmall),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Appointment details ──────────────────────────────
                    Text('Appointment Details',
                        style: AppTextStyles.headingSmall),
                    const SizedBox(height: 10),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _detailRow(
                              Icons.calendar_today_outlined, 'Date', _formattedDate),
                          const Divider(height: 1, color: AppColors.divider),
                          _detailRow(
                              Icons.access_time_outlined, 'Time', time),
                          const Divider(height: 1, color: AppColors.divider),
                          _detailRow(
                              Icons.medical_services_outlined,
                              'Specialization',
                              doctor.specialization,
                              isLast: true),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Fee breakdown ────────────────────────────────────
                    Text('Fee Breakdown', style: AppTextStyles.headingSmall),
                    const SizedBox(height: 10),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _feeRow('Consultation Fee',
                              'Rs. ${doctor.consultationFee}'),
                          const Divider(height: 1, color: AppColors.divider),
                          _feeRow('Platform Fee', 'Rs. $_platformFee'),
                          const Divider(height: 1, color: AppColors.divider),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: [
                                Text('Total',
                                    style: AppTextStyles.labelLarge.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    )),
                                const Spacer(),
                                Text(
                                  'Rs. $total',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Note
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This is a prototype. No real payment will be processed.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Proceed to Payment button ─────────────────────────────────
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
                      builder: (_) => PaymentScreen(
                        doctor: doctor,
                        date: date,
                        time: time,
                        platformFee: _platformFee,
                      ),
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
                  child: const Text('Proceed to Payment'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
      {bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label,
              style:
                  AppTextStyles.bodyMedium.copyWith(fontSize: 13)),
          const Spacer(),
          Text(value,
              style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _feeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.bodyMedium.copyWith(fontSize: 13)),
          const Spacer(),
          Text(value, style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}
