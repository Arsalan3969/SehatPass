import 'doctor_model.dart';

/// Appointment status values in the Flutter UI.
enum AppointmentStatus { upcoming, past, cancelled }

extension AppointmentStatusLabel on AppointmentStatus {
  String get label {
    switch (this) {
      case AppointmentStatus.upcoming:
        return 'Upcoming';
      case AppointmentStatus.past:
        return 'Past';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Payment status values.
enum PaymentStatus { paid, pending, refunded }

extension PaymentStatusLabel on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }
}

/// Appointment data model backed by `public.appointments` in Supabase.
class Appointment {
  final String id;
  final String referenceNo;
  final String patientId;
  final Doctor doctor;
  final String? clinicId;
  final String? serviceId;
  final String serviceName;
  final DateTime date;
  final String time;
  final int consultationFee;
  final int platformFee;
  final int totalAmount;
  PaymentStatus paymentStatus;
  final String paymentMethod;
  AppointmentStatus status;
  final String rawStatus; // 'pending' | 'confirmed' | 'completed' | 'cancelled'
  final String? cancellationReason;
  final DateTime? createdAt;

  Appointment({
    required this.id,
    String? referenceNo,
    this.patientId = '',
    required this.doctor,
    this.clinicId,
    this.serviceId,
    this.serviceName = 'General Consultation',
    required this.date,
    required this.time,
    required this.consultationFee,
    this.platformFee = 0,
    int? totalAmount,
    this.paymentStatus = PaymentStatus.pending,
    this.paymentMethod = 'cash',
    this.status = AppointmentStatus.upcoming,
    this.rawStatus = 'pending',
    this.cancellationReason,
    this.createdAt,
  })  : referenceNo = referenceNo ?? id,
        totalAmount = totalAmount ?? (consultationFee + platformFee);

  int get total => totalAmount;

  String get displayStatus {
    switch (rawStatus.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
      case 'accepted':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'rejected':
      case 'declined':
        return 'Declined';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.label;
    }
  }

  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    final id = map['id']?.toString() ?? '';
    final referenceNo = map['reference_no']?.toString() ?? id;
    final patientId = map['patient_id']?.toString() ?? '';
    final clinicId = map['clinic_id']?.toString();
    final serviceId = map['service_id']?.toString();
    final serviceName = map['service_name']?.toString() ?? 'General Consultation';

    // Parse date
    DateTime parsedDate = DateTime.now();
    if (map['appointment_date'] != null) {
      final dateStr = map['appointment_date'].toString();
      parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    } else if (map['date'] is DateTime) {
      parsedDate = map['date'] as DateTime;
    }

    final time = map['appointment_time']?.toString() ??
        map['time']?.toString() ??
        '10:00 AM';

    final consultationFee = (map['consultation_fee'] as num?)?.toInt() ??
        (map['consultationFee'] as num?)?.toInt() ??
        0;
    final platformFee = (map['platform_fee'] as num?)?.toInt() ??
        (map['platformFee'] as num?)?.toInt() ??
        100;
    final totalAmount = (map['total_amount'] as num?)?.toInt() ??
        (consultationFee + platformFee);

    // Payment Status
    final paymentStatusStr = (map['payment_status']?.toString() ??
            map['paymentStatus']?.toString() ??
            'paid')
        .toLowerCase();
    PaymentStatus paymentStatus = PaymentStatus.paid;
    if (paymentStatusStr.contains('pending')) {
      paymentStatus = PaymentStatus.pending;
    } else if (paymentStatusStr.contains('refund')) {
      paymentStatus = PaymentStatus.refunded;
    }

    final paymentMethod = map['payment_method']?.toString() ?? 'card';

    // Appointment Status
    final rawStatus = (map['status']?.toString() ?? 'pending').toLowerCase();
    AppointmentStatus uiStatus = AppointmentStatus.upcoming;
    if (rawStatus == 'cancelled') {
      uiStatus = AppointmentStatus.cancelled;
    } else if (rawStatus == 'completed') {
      uiStatus = AppointmentStatus.past;
    } else {
      // 'pending' or 'confirmed'
      // If the appointment date was before today and not cancelled, can be treated as past
      final today = DateTime.now();
      final justDateToday = DateTime(today.year, today.month, today.day);
      final justDateApt = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
      if (justDateApt.isBefore(justDateToday)) {
        uiStatus = AppointmentStatus.past;
      } else {
        uiStatus = AppointmentStatus.upcoming;
      }
    }

    // Doctor parsing
    Doctor doctor;
    if (map['doctor'] is Doctor) {
      doctor = map['doctor'] as Doctor;
    } else if (map['doctor'] is Map) {
      doctor = Doctor.fromMap(Map<String, dynamic>.from(map['doctor'] as Map));
    } else {
      doctor = Doctor.fromMap(map);
    }

    final cancellationReason = map['cancellation_reason']?.toString();
    DateTime? createdAt;
    if (map['created_at'] != null) {
      createdAt = DateTime.tryParse(map['created_at'].toString());
    }

    return Appointment(
      id: id,
      referenceNo: referenceNo,
      patientId: patientId,
      doctor: doctor,
      clinicId: clinicId,
      serviceId: serviceId,
      serviceName: serviceName,
      date: parsedDate,
      time: time,
      consultationFee: consultationFee,
      platformFee: platformFee,
      totalAmount: totalAmount,
      paymentStatus: paymentStatus,
      paymentMethod: paymentMethod,
      status: uiStatus,
      rawStatus: rawStatus,
      cancellationReason: cancellationReason,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toInsertMap() {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return {
      'reference_no': referenceNo,
      'patient_id': patientId,
      'doctor_id': doctor.id,
      if (clinicId != null || doctor.clinicId != null)
        'clinic_id': clinicId ?? doctor.clinicId,
      if (serviceId != null) 'service_id': serviceId,
      'service_name': serviceName,
      'appointment_date': dateStr,
      'appointment_time': time,
      'consultation_fee': consultationFee,
      'platform_fee': platformFee,
      'total_amount': totalAmount,
      'payment_status': paymentStatus == PaymentStatus.paid ? 'paid' : 'pending',
      'payment_method': paymentMethod,
      'status': rawStatus.isNotEmpty ? rawStatus : 'pending',
      if (cancellationReason != null) 'cancellation_reason': cancellationReason,
    };
  }

  Appointment copyWith({
    String? id,
    String? referenceNo,
    String? patientId,
    Doctor? doctor,
    String? clinicId,
    String? serviceId,
    String? serviceName,
    DateTime? date,
    String? time,
    int? consultationFee,
    int? platformFee,
    int? totalAmount,
    PaymentStatus? paymentStatus,
    String? paymentMethod,
    AppointmentStatus? status,
    String? rawStatus,
    String? cancellationReason,
    DateTime? createdAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      referenceNo: referenceNo ?? this.referenceNo,
      patientId: patientId ?? this.patientId,
      doctor: doctor ?? this.doctor,
      clinicId: clinicId ?? this.clinicId,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      date: date ?? this.date,
      time: time ?? this.time,
      consultationFee: consultationFee ?? this.consultationFee,
      platformFee: platformFee ?? this.platformFee,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      rawStatus: rawStatus ?? this.rawStatus,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
