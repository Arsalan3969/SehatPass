/// Doctor data model for the appointment feature.
class DoctorService {
  final String name;
  final int fee;

  const DoctorService({required this.name, required this.fee});
}

class Doctor {
  final String id;
  final String name;
  final String specialization;
  final String clinic;
  final String location;
  final double rating;
  final int consultationFee;
  final String availability; // e.g. "Available Today", "Available Tomorrow"
  final String about;
  final List<String> availableDays;
  final String consultationHours;
  final List<DoctorService> services;

  const Doctor({
    required this.id,
    required this.name,
    required this.specialization,
    required this.clinic,
    required this.location,
    required this.rating,
    required this.consultationFee,
    required this.availability,
    required this.about,
    required this.availableDays,
    required this.consultationHours,
    required this.services,
  });
}
