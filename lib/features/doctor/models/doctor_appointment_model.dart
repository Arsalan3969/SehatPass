enum DoctorAppointmentStatus {
  pending,
  confirmed,
  completed,
  cancelled,
}

class DoctorAppointmentModel {
  final String id;
  final String patientName;
  final String patientPhone;
  final int patientAge;
  final String patientGender;
  final String serviceName;
  final String time;
  final String date;
  final String clinicName;
  final double fee;
  DoctorAppointmentStatus status;

  DoctorAppointmentModel({
    required this.id,
    required this.patientName,
    this.patientPhone = '+92 300 1234567',
    this.patientAge = 28,
    this.patientGender = 'Male',
    required this.serviceName,
    required this.time,
    required this.date,
    this.clinicName = 'City Heart Clinic',
    required this.fee,
    required this.status,
  });

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

  static List<DoctorAppointmentModel> get dummySchedule => [
        // ── Pending Requests ───────────────────────────────────────────────
        DoctorAppointmentModel(
          id: 'apt-1',
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
