import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'data/appointment_repository.dart';
import 'models/doctor_model.dart';
import 'appointment_confirmation_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Doctor doctor;
  final DateTime date;
  final String time;
  final int platformFee;

  const PaymentScreen({
    super.key,
    required this.doctor,
    required this.date,
    required this.time,
    required this.platformFee,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  int _selectedMethod = 0; // 0 = Card, 1 = Mobile Wallet
  bool _loading = false;

  int get _total => widget.doctor.consultationFee + widget.platformFee;

  Future<void> _pay() async {
    setState(() => _loading = true);

    try {
      final method = _selectedMethod == 0 ? 'card' : 'wallet';
      final appointment = await AppointmentRepository.instance.bookAppointment(
        doctor: widget.doctor,
        date: widget.date,
        time: widget.time,
        consultationFee: widget.doctor.consultationFee,
        platformFee: widget.platformFee,
        clinicId: widget.doctor.clinicId,
        serviceId: widget.doctor.services.isNotEmpty
            ? widget.doctor.services.first.id
            : null,
        serviceName: widget.doctor.services.isNotEmpty
            ? widget.doctor.services.first.name
            : 'General Consultation',
        paymentMethod: method,
      );

      if (!mounted) return;

      setState(() => _loading = false);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AppointmentConfirmationScreen(appointment: appointment),
        ),
        // Remove all screens in the booking flow back to home
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  e.toString(),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.emergency,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payment'),
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
                    // ── Fee summary ──────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x07000000),
                              blurRadius: 12,
                              offset: Offset(0, 4))
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _feeRow('Appointment Fee',
                              'Rs. ${widget.doctor.consultationFee}'),
                          const Divider(height: 1, color: AppColors.divider),
                          _feeRow(
                              'Platform Fee', 'Rs. ${widget.platformFee}'),
                          const Divider(height: 1, color: AppColors.divider),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: [
                                Text('Total',
                                    style: AppTextStyles.labelLarge.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                                const Spacer(),
                                Text(
                                  'Rs. $_total',
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

                    const SizedBox(height: 24),

                    // ── Payment method ───────────────────────────────────
                    Text('Payment Method',
                        style: AppTextStyles.headingSmall),
                    const SizedBox(height: 12),
                    _paymentMethodTile(
                      index: 0,
                      icon: Icons.credit_card_rounded,
                      label: 'Card',
                      subtitle: 'Credit / Debit Card',
                    ),
                    const SizedBox(height: 10),
                    _paymentMethodTile(
                      index: 1,
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Mobile Wallet',
                      subtitle: 'JazzCash / EasyPaisa',
                    ),

                    const SizedBox(height: 12),

                    // Prototype notice
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
                              'No real payment gateway is connected. This is a prototype simulation.',
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

            // ── Pay button ────────────────────────────────────────────────
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _pay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text('Pay Rs. $_total'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentMethodTile({
    required int index,
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    final selected = _selectedMethod == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x07000000),
                blurRadius: 10,
                offset: Offset(0, 3))
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 22,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 6 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Text(label,
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 13)),
          const Spacer(),
          Text(value,
              style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}
