enum DoctorAppointmentStatus {
  pending,
  confirmed,
  completed,
  cancelled,
}

class DoctorAppointmentModel {
  final String id;
  final String referenceNo;
  final String patientId;
  final String patientName;
  final String? patientPhone;
  final int? patientAge;
  final String? patientGender;
  final String? serviceId;
  final String serviceName;
  final String? clinicId;
  final String clinicName;
  final String time;
  final String date;
  final DateTime? appointmentDate;
  final double fee;
  DoctorAppointmentStatus status;
  final String rawStatus;
  final String? cancellationReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DoctorAppointmentModel({
    required this.id,
    String? referenceNo,
    this.patientId = '',
    required this.patientName,
    this.patientPhone,
    this.patientAge,
    this.patientGender,
    this.serviceId,
    required this.serviceName,
    this.clinicId,
    this.clinicName = 'Clinic',
    required this.time,
    required this.date,
    this.appointmentDate,
    required this.fee,
    required this.status,
    this.rawStatus = 'pending',
    this.cancellationReason,
    this.createdAt,
    this.updatedAt,
  }) : referenceNo = referenceNo ?? id;

  String get formattedFee {
    final feeInt = fee.toInt();
    final formatted = feeInt.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return 'Rs. $formatted';
  }

  String get statusLabel {
    switch (status) {
      case DoctorAppointmentStatus.pending:
        return 'Pending';
      case DoctorAppointmentStatus.confirmed:
        return 'Confirmed';
      case DoctorAppointmentStatus.completed:
        return 'Completed';
      case DoctorAppointmentStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Evaluates whether the appointment is scheduled specifically for today's date.
  /// Uses authoritative [appointmentDate] when present, falling back to [date] string.
  bool isScheduledForToday([DateTime? now]) {
    final current = now ?? DateTime.now();
    if (appointmentDate != null) {
      return appointmentDate!.year == current.year &&
          appointmentDate!.month == current.month &&
          appointmentDate!.day == current.day;
    }
    return date.trim().toLowerCase() == 'today';
  }

  bool get isToday => isScheduledForToday();

  static DoctorAppointmentStatus parseStatus(dynamic value) {
    if (value == null) return DoctorAppointmentStatus.pending;
    final str = value.toString().trim().toLowerCase();
    switch (str) {
      case 'confirmed':
      case 'accepted':
        return DoctorAppointmentStatus.confirmed;
      case 'completed':
        return DoctorAppointmentStatus.completed;
      case 'cancelled':
      case 'canceled':
      case 'declined':
      case 'rejected':
        return DoctorAppointmentStatus.cancelled;
      case 'pending':
      default:
        return DoctorAppointmentStatus.pending;
    }
  }

  factory DoctorAppointmentModel.fromMap(Map<String, dynamic> map) {
    final id = map['id']?.toString() ?? '';
    final referenceNo = map['reference_no']?.toString() ?? id;
    final patientId = map['patient_id']?.toString() ?? '';

    // Extract basic profile if joined via profiles!patient_id
    final profileMap = map['profiles'] is Map
        ? Map<String, dynamic>.from(map['profiles'] as Map)
        : null;

    final rawPatientName = profileMap?['full_name']?.toString().trim() ??
        map['patient_name']?.toString().trim() ??
        map['patientName']?.toString().trim() ??
        '';

    final patientName =
        rawPatientName.isNotEmpty ? rawPatientName : 'Name not provided';

    final patientPhone = profileMap?['phone']?.toString() ??
        map['patient_phone']?.toString() ??
        map['patientPhone']?.toString();

    // Extract clinic if joined via clinics
    final clinicMap = map['clinics'] is Map
        ? Map<String, dynamic>.from(map['clinics'] as Map)
        : null;

    final clinicName = clinicMap?['name']?.toString() ??
        map['clinic_name']?.toString() ??
        map['clinicName']?.toString() ??
        'Clinic';

    final clinicId =
        clinicMap?['id']?.toString() ?? map['clinic_id']?.toString();
    final serviceId = map['service_id']?.toString();
    final serviceName = map['service_name']?.toString() ??
        map['serviceName']?.toString() ??
        'General Consultation';

    // Parse appointment date
    DateTime? parsedDate;
    String dateStr = 'Today';
    if (map['appointment_date'] != null) {
      final rawDate = map['appointment_date'].toString();
      parsedDate = DateTime.tryParse(rawDate);
      if (parsedDate != null) {
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        dateStr =
            '${parsedDate.day} ${months[parsedDate.month - 1]} ${parsedDate.year}';
      } else {
        dateStr = rawDate;
      }
    } else if (map['date'] != null) {
      dateStr = map['date'].toString();
      parsedDate = DateTime.tryParse(dateStr);
    }

    final timeStr = map['appointment_time']?.toString() ??
        map['time']?.toString() ??
        '10:00 AM';

    final feeVal = (map['consultation_fee'] as num?)?.toDouble() ??
        (map['fee'] as num?)?.toDouble() ??
        0.0;

    final rawStatus = map['status']?.toString().toLowerCase() ?? 'pending';
    final status = parseStatus(rawStatus);

    return DoctorAppointmentModel(
      id: id,
      referenceNo: referenceNo,
      patientId: patientId,
      patientName: patientName,
      patientPhone: patientPhone,
      patientAge: (map['patient_age'] as num?)?.toInt() ??
          (map['patientAge'] as num?)?.toInt(),
      patientGender: map['patient_gender']?.toString() ??
          map['patientGender']?.toString(),
      serviceId: serviceId,
      serviceName: serviceName,
      clinicId: clinicId,
      clinicName: clinicName,
      time: timeStr,
      date: dateStr,
      appointmentDate: parsedDate,
      fee: feeVal,
      status: status,
      rawStatus: rawStatus,
      cancellationReason: map['cancellation_reason']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reference_no': referenceNo,
      'patient_id': patientId,
      'patient_name': patientName,
      if (patientPhone != null) 'patient_phone': patientPhone,
      if (patientAge != null) 'patient_age': patientAge,
      if (patientGender != null) 'patient_gender': patientGender,
      if (serviceId != null) 'service_id': serviceId,
      'service_name': serviceName,
      if (clinicId != null) 'clinic_id': clinicId,
      'clinic_name': clinicName,
      'appointment_time': time,
      'appointment_date': appointmentDate?.toIso8601String().split('T').first ?? date,
      'consultation_fee': fee,
      'status': rawStatus,
      if (cancellationReason != null) 'cancellation_reason': cancellationReason,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  DoctorAppointmentModel copyWith({
    String? id,
    String? referenceNo,
    String? patientId,
    String? patientName,
    String? patientPhone,
    int? patientAge,
    String? patientGender,
    String? serviceId,
    String? serviceName,
    String? clinicId,
    String? clinicName,
    String? time,
    String? date,
    DateTime? appointmentDate,
    double? fee,
    DoctorAppointmentStatus? status,
    String? rawStatus,
    String? cancellationReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DoctorAppointmentModel(
      id: id ?? this.id,
      referenceNo: referenceNo ?? this.referenceNo,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
      patientAge: patientAge ?? this.patientAge,
      patientGender: patientGender ?? this.patientGender,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      clinicId: clinicId ?? this.clinicId,
      clinicName: clinicName ?? this.clinicName,
      time: time ?? this.time,
      date: date ?? this.date,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      fee: fee ?? this.fee,
      status: status ?? this.status,
      rawStatus: rawStatus ?? this.rawStatus,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static List<DoctorAppointmentModel> get dummySchedule => [
        // ── Pending Requests ───────────────────────────────────────────────
        DoctorAppointmentModel(
          id: 'apt-1',
          patientId: 'p-3',
          patientName: 'Usman Ali',
          patientPhone: '+92 333 7778899',
          patientAge: 45,
          patientGender: 'Male',
          serviceName: 'General Consultation',
          date: 'Today',
          time: '2:00 PM',
          clinicName: 'City Heart Clinic',
          fee: 2000,
          status: DoctorAppointmentStatus.pending,
        ),
        DoctorAppointmentModel(
          id: 'apt-2',
          patientId: 'p-6',
          patientName: 'Zainab Bibi',
          patientPhone: '+92 345 8889900',
          patientAge: 52,
          patientGender: 'Female',
          serviceName: 'ECG Consultation',
          date: 'Today',
          time: '3:30 PM',
          clinicName: 'City Heart Clinic',
          fee: 2500,
          status: DoctorAppointmentStatus.pending,
        ),

        // ── Upcoming (Confirmed) ────────────────────────────────────────────
        DoctorAppointmentModel(
          id: 'apt-3',
          patientId: 'p-1',
          patientName: 'Ali Khan',
          patientPhone: '+92 301 5551234',
          patientAge: 28,
          patientGender: 'Male',
          serviceName: 'General Consultation',
          date: '31 Aug 2026',
          time: '10:00 AM',
          clinicName: 'City Heart Clinic',
          fee: 2000,
          status: DoctorAppointmentStatus.confirmed,
        ),
        DoctorAppointmentModel(
          id: 'apt-4',
          patientId: 'p-2',
          patientName: 'Fatima Ahmed',
          patientPhone: '+92 321 4445678',
          patientAge: 30,
          patientGender: 'Female',
          serviceName: 'Follow-up Consultation',
          date: '31 Aug 2026',
          time: '11:30 AM',
          clinicName: 'City Heart Clinic',
          fee: 1500,
          status: DoctorAppointmentStatus.confirmed,
        ),
        DoctorAppointmentModel(
          id: 'apt-5',
          patientId: 'p-8',
          patientName: 'Hamza Tariq',
          patientPhone: '+92 312 9991122',
          patientAge: 29,
          patientGender: 'Male',
          serviceName: 'General Consultation',
          date: '31 Aug 2026',
          time: '4:15 PM',
          clinicName: 'City Heart Clinic',
          fee: 2000,
          status: DoctorAppointmentStatus.confirmed,
        ),

        // ── Completed ───────────────────────────────────────────────────────
        DoctorAppointmentModel(
          id: 'apt-6',
          patientId: 'p-4',
          patientName: 'Hassan Raza',
          patientPhone: '+92 345 1112233',
          patientAge: 38,
          patientGender: 'Male',
          serviceName: 'General Consultation',
          date: '28 Aug 2026',
          time: '3:00 PM',
          clinicName: 'City Heart Clinic',
          fee: 2000,
          status: DoctorAppointmentStatus.completed,
        ),

        // ── Cancelled ───────────────────────────────────────────────────────
        DoctorAppointmentModel(
          id: 'apt-7',
          patientId: 'p-5',
          patientName: 'Ayesha Malik',
          patientPhone: '+92 312 3334455',
          patientAge: 34,
          patientGender: 'Female',
          serviceName: 'Follow-up Consultation',
          date: '26 Aug 2026',
          time: '11:00 AM',
          clinicName: 'City Heart Clinic',
          fee: 1500,
          status: DoctorAppointmentStatus.cancelled,
        ),
      ];
}
