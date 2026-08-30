import 'doctor_model.dart';

/// Appointment status values.
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

/// Appointment data model.
class Appointment {
  final String id;
  final Doctor doctor;
  final DateTime date;
  final String time;
  final int consultationFee;
  final int platformFee;
  PaymentStatus paymentStatus;
  AppointmentStatus status;

  Appointment({
    required this.id,
    required this.doctor,
    required this.date,
    required this.time,
    required this.consultationFee,
    this.platformFee = 100,
    this.paymentStatus = PaymentStatus.paid,
    this.status = AppointmentStatus.upcoming,
  });

  int get total => consultationFee + platformFee;

  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
