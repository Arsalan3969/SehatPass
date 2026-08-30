import 'package:flutter/foundation.dart';
import '../models/doctor_model.dart';
import '../models/appointment_model.dart';

/// Local in-memory repository for appointments, shared across screens.
class AppointmentRepository extends ChangeNotifier {
  AppointmentRepository._();
  static final AppointmentRepository instance = AppointmentRepository._();

  final List<Appointment> _appointments = [];

  List<Appointment> get all => List.unmodifiable(_appointments);

  List<Appointment> get upcoming => _appointments
      .where((a) => a.status == AppointmentStatus.upcoming)
      .toList();

  List<Appointment> get past => _appointments
      .where((a) => a.status == AppointmentStatus.past)
      .toList();

  List<Appointment> get cancelled => _appointments
      .where((a) => a.status == AppointmentStatus.cancelled)
      .toList();

  void addAppointment(Appointment appointment) {
    _appointments.insert(0, appointment);
    notifyListeners();
  }

  void cancelAppointment(String id) {
    final index = _appointments.indexWhere((a) => a.id == id);
    if (index != -1) {
      _appointments[index].status = AppointmentStatus.cancelled;
      notifyListeners();
    }
  }

  String generateId() {
    return 'SP-APT-${(_appointments.length + 1).toString().padLeft(4, '0')}';
  }
}

/// All dummy doctors available in the app.
class DoctorRepository {
  DoctorRepository._();

  static const List<Doctor> doctors = [
    Doctor(
      id: 'doc-001',
      name: 'Dr. Ahmed Khan',
      specialization: 'Cardiologist',
      clinic: 'City Heart Clinic',
      location: 'Lahore',
      rating: 4.8,
      consultationFee: 2000,
      availability: 'Available Today',
      about:
          'Experienced cardiologist providing general and specialized cardiac consultation. Over 12 years of clinical experience managing heart conditions and preventive cardiology.',
      availableDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      consultationHours: '10:00 AM - 4:00 PM',
      services: [
        DoctorService(name: 'General Consultation', fee: 2000),
        DoctorService(name: 'Follow-up Consultation', fee: 1500),
        DoctorService(name: 'ECG Review', fee: 1000),
      ],
    ),
    Doctor(
      id: 'doc-002',
      name: 'Dr. Sarah Ali',
      specialization: 'Dermatologist',
      clinic: 'Skin Care Clinic',
      location: 'Lahore',
      rating: 4.7,
      consultationFee: 1500,
      availability: 'Available Tomorrow',
      about:
          'Specialist in skin, hair, and nail conditions with extensive experience in cosmetic and medical dermatology. Focused on patient-centered care and evidence-based treatments.',
      availableDays: ['Monday', 'Wednesday', 'Thursday', 'Saturday'],
      consultationHours: '11:00 AM - 5:00 PM',
      services: [
        DoctorService(name: 'Skin Consultation', fee: 1500),
        DoctorService(name: 'Follow-up Visit', fee: 1000),
        DoctorService(name: 'Skin Biopsy', fee: 3000),
      ],
    ),
    Doctor(
      id: 'doc-003',
      name: 'Dr. Bilal Hassan',
      specialization: 'General Physician',
      clinic: 'Medicos Clinic',
      location: 'Lahore',
      rating: 4.6,
      consultationFee: 1000,
      availability: 'Available Today',
      about:
          'General practitioner with 8+ years of experience in primary healthcare, chronic disease management, and preventive medicine.',
      availableDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
      consultationHours: '9:00 AM - 7:00 PM',
      services: [
        DoctorService(name: 'General Consultation', fee: 1000),
        DoctorService(name: 'Follow-up Consultation', fee: 800),
      ],
    ),
    Doctor(
      id: 'doc-004',
      name: 'Dr. Fatima Noor',
      specialization: 'Dentist',
      clinic: 'Bright Smile Dental',
      location: 'Lahore',
      rating: 4.9,
      consultationFee: 1200,
      availability: 'Available Today',
      about:
          'Experienced dentist specializing in cosmetic and restorative dentistry. Passionate about helping patients achieve healthy and beautiful smiles.',
      availableDays: ['Tuesday', 'Wednesday', 'Friday', 'Saturday'],
      consultationHours: '10:00 AM - 3:00 PM',
      services: [
        DoctorService(name: 'Dental Check-up', fee: 1200),
        DoctorService(name: 'Teeth Cleaning', fee: 2000),
        DoctorService(name: 'Tooth Extraction', fee: 2500),
      ],
    ),
    Doctor(
      id: 'doc-005',
      name: 'Dr. Usman Raza',
      specialization: 'Cardiologist',
      clinic: 'Punjab Heart Institute',
      location: 'Lahore',
      rating: 4.5,
      consultationFee: 2500,
      availability: 'Available Tomorrow',
      about:
          'Senior cardiologist with 18+ years of experience in interventional cardiology and heart failure management.',
      availableDays: ['Monday', 'Wednesday', 'Friday'],
      consultationHours: '2:00 PM - 6:00 PM',
      services: [
        DoctorService(name: 'Cardiac Consultation', fee: 2500),
        DoctorService(name: 'Echocardiography Review', fee: 2000),
        DoctorService(name: 'Follow-up', fee: 1500),
      ],
    ),
  ];

  static List<Doctor> filterBySpecialty(String specialty) {
    if (specialty == 'All') return doctors;
    return doctors.where((d) => d.specialization == specialty).toList();
  }

  static List<Doctor> search(String query) {
    final q = query.toLowerCase();
    return doctors.where((d) =>
        d.name.toLowerCase().contains(q) ||
        d.specialization.toLowerCase().contains(q) ||
        d.clinic.toLowerCase().contains(q)).toList();
  }
}
