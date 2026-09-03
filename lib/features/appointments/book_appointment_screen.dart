import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'appointment_confirmation_screen.dart';
import 'data/appointment_repository.dart';
import 'models/doctor_model.dart';

class BookAppointmentScreen extends StatefulWidget {
  final Doctor doctor;
  const BookAppointmentScreen({super.key, required this.doctor});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  DoctorService? _selectedService;
  DateTime? _selectedDate;
  String? _selectedTime;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.doctor.services.isNotEmpty) {
      _selectedService = widget.doctor.services.first;
    }
  }

  /// Generate next 7 days starting today.
  List<DateTime> get _dates {
    final today = DateTime.now();
    return List.generate(7, (i) => today.add(Duration(days: i)));
  }

  static const List<String> _timeSlots = [
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '2:00 PM',
    '3:00 PM',
  ];

  int get _currentFee =>
      _selectedService?.fee ?? widget.doctor.consultationFee;

  bool get _canContinue =>
      _selectedDate != null &&
      _selectedTime != null &&
      _selectedService != null &&
      !_isSubmitting;

  String _dayLabel(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }

  String _monthLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[d.month - 1];
  }

  Future<void> _handleRequestAppointment() async {
    if (!_canContinue) return;

    setState(() => _isSubmitting = true);

    try {
      final appointment = await AppointmentRepository.instance.bookAppointment(
        doctor: widget.doctor,
        date: _selectedDate!,
        time: _selectedTime!,
        serviceId: _selectedService?.id,
        serviceName: _selectedService?.name ?? 'General Consultation',
        consultationFee: _currentFee,
        clinicId: widget.doctor.clinicId,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AppointmentConfirmationScreen(
            appointment: appointment,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is String ? e : 'Unable to request appointment. Please try again.',
          ),
          backgroundColor: AppColors.emergency,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dates = _dates;
    final services = widget.doctor.services;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Book Appointment'),
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
                    // ── Doctor summary card ──────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x07000000),
                              blurRadius: 12,
                              offset: Offset(0, 4)),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
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
                                Text(widget.doctor.name,
                                    style: AppTextStyles.labelLarge
                                        .copyWith(fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(widget.doctor.specialization,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text(widget.doctor.clinic,
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textTertiary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Select Service ───────────────────────────────────
                    if (services.isNotEmpty) ...[
                      Text('Select Service', style: AppTextStyles.headingSmall),
                      const SizedBox(height: 12),
                      Column(
                        children: services.map((service) {
                          final isSelected = _selectedService?.id != null
                              ? _selectedService?.id == service.id
                              : _selectedService?.name == service.name;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedService = service;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primarySurface
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textTertiary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      service.name,
                                      style: AppTextStyles.labelLarge.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${service.fee}',
                                    style: AppTextStyles.labelLarge.copyWith(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Select Date ──────────────────────────────────────
                    Text('Select Date', style: AppTextStyles.headingSmall),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: dates.length,
                        separatorBuilder: (_, i) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final d = dates[i];
                          final selected = _selectedDate != null &&
                              _selectedDate!.year == d.year &&
                              _selectedDate!.month == d.month &&
                              _selectedDate!.day == d.day;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedDate = d),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 60,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                                boxShadow: selected
                                    ? [
                                        const BoxShadow(
                                          color: Color(0x252E7D5E),
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _dayLabel(d),
                                    style: AppTextStyles.caption.copyWith(
                                      color: selected
                                          ? Colors.white70
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${d.day}',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: selected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _monthLabel(d),
                                    style: AppTextStyles.caption.copyWith(
                                      color: selected
                                          ? Colors.white70
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Select Time ──────────────────────────────────────
                    Text('Select Time', style: AppTextStyles.headingSmall),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _timeSlots.map((slot) {
                        final selected = slot == _selectedTime;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedTime = slot),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                              boxShadow: selected
                                  ? [
                                      const BoxShadow(
                                        color: Color(0x252E7D5E),
                                        blurRadius: 8,
                                        offset: Offset(0, 3),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Text(
                              slot,
                              style: AppTextStyles.labelLarge.copyWith(
                                color: selected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // ── Appointment Summary & Cash Notice ─────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Service',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textSecondary)),
                              Text(
                                _selectedService?.name ?? 'General Consultation',
                                style: AppTextStyles.labelLarge,
                              ),
                            ],
                          ),
                          const Divider(height: 20, color: AppColors.divider),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Consultation Fee',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textSecondary)),
                              Text(
                                'Rs. $_currentFee',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20, color: AppColors.divider),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Payment',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textSecondary)),
                              Text(
                                'Cash at clinic',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Cash Payment Notice ──────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.payments_outlined,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Payment: Cash at Clinic',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Payment is made directly to the doctor/clinic in cash upon your visit.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Note: Submitting this request creates a pending appointment. Dr. ${widget.doctor.name} will review and accept or decline your request.',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // ── Request Appointment button ────────────────────────────────
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _canContinue ? _handleRequestAppointment : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    disabledForegroundColor: AppColors.textTertiary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Request Appointment'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
