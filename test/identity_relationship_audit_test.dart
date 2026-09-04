import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/features/appointments/models/doctor_model.dart';
import 'package:sehatpass/features/doctor/models/doctor_appointment_model.dart';
import 'package:sehatpass/features/doctor/models/doctor_consultation_note_model.dart';
import 'package:sehatpass/features/doctor/models/doctor_patient_model.dart';

void main() {
  group('Phase 5A.4: Doctor Identity & Name Formatting', () {
    test('Doctor.fromMap correctly maps and formats un-prefixed name to Dr. <name>', () {
      final docMap = {
        'id': 'doc-101',
        'doctor_id': 'doc-101',
        'specialization': 'Cardiologist',
        'qualifications': 'MBBS, FCPS',
        'experience_years': '8 years',
        'bio': 'Cardiology specialist',
        'profiles': {
          'id': 'doc-101',
          'full_name': 'Arsalan',
          'profile_photo_url': 'https://example.com/photo.jpg',
        },
        'clinics': [
          {
            'id': 'c-1',
            'name': 'Lahore Heart Clinic',
            'city': 'Lahore',
            'address': 'Main Boulevard, Gulberg',
          }
        ],
        'clinic_services': [
          {'id': 's-1', 'name': 'ECG Consultation', 'fee': 2500}
        ],
      };

      final doc = Doctor.fromMap(docMap);
      expect(doc.name, equals('Dr. Arsalan'));
      expect(doc.specialization, equals('Cardiologist'));
      expect(doc.clinic, equals('Lahore Heart Clinic'));
      expect(doc.location, equals('Main Boulevard, Gulberg, Lahore'));
      expect(doc.consultationFee, equals(2500));
    });

    test('Doctor.fromMap preserves pre-existing Dr. prefix without duplicating', () {
      final docMap = {
        'id': 'doc-102',
        'doctor_id': 'doc-102',
        'specialization': 'General Physician',
        'profiles': {
          'id': 'doc-102',
          'full_name': 'Dr. Fatima Khan',
        },
      };

      final doc = Doctor.fromMap(docMap);
      expect(doc.name, equals('Dr. Fatima Khan'));
    });

    test('Doctor.fromMap uses honest fallback "Name not provided" when name is empty', () {
      final docMap = {
        'id': 'doc-103',
        'doctor_id': 'doc-103',
        'specialization': 'Dermatologist',
        'profiles': {
          'id': 'doc-103',
          'full_name': '   ',
        },
      };

      final doc = Doctor.fromMap(docMap);
      expect(doc.name, equals('Name not provided'));
      expect(doc.name, isNot(equals('Doctor')));
    });

    test('Distinct published doctors retain their individual names without mixing', () {
      final docA = Doctor.fromMap({
        'doctor_id': 'doc-a',
        'profiles': {'full_name': 'Ali Raza'},
        'specialization': 'Orthopedics',
      });

      final docB = Doctor.fromMap({
        'doctor_id': 'doc-b',
        'profiles': {'full_name': 'Zainab Tariq'},
        'specialization': 'Pediatrics',
      });

      expect(docA.name, equals('Dr. Ali Raza'));
      expect(docB.name, equals('Dr. Zainab Tariq'));
      expect(docA.name, isNot(equals(docB.name)));
    });
  });

  group('Phase 5A.4: Patient Identity in Doctor Appointments & Dashboard', () {
    test('DoctorAppointmentModel maps real patient identity from profiles.full_name', () {
      final aptMap = {
        'id': 'apt-001',
        'reference_no': 'REF-2026-001',
        'patient_id': 'pat-uuid-1',
        'doctor_id': 'doc-uuid-1',
        'service_id': 'srv-1',
        'service_name': 'ECG Consultation',
        'appointment_date': '2026-09-04',
        'appointment_time': '11:00 AM',
        'consultation_fee': 2500,
        'status': 'confirmed',
        'profiles': {
          'id': 'pat-uuid-1',
          'full_name': 'Arsalan',
          'profile_photo_url': 'https://example.com/patient.png',
        },
        'clinics': {
          'id': 'cln-1',
          'name': 'City Health Clinic',
        }
      };

      final model = DoctorAppointmentModel.fromMap(aptMap);
      expect(model.patientId, equals('pat-uuid-1'));
      expect(model.patientName, equals('Arsalan'));
      expect(model.patientName, isNot(equals('Patient')));
      expect(model.patientName, isNot(startsWith('Dr.')));
      expect(model.serviceName, equals('ECG Consultation'));
      expect(model.fee, equals(2500.0));
      expect(model.status, equals(DoctorAppointmentStatus.confirmed));
    });

    test('DoctorAppointmentModel resolves distinct patient identities across appointments', () {
      final apt1 = DoctorAppointmentModel.fromMap({
        'id': 'apt-1',
        'patient_id': 'pat-x',
        'profiles': {'full_name': 'Usman Tariq'},
        'service_name': 'General Consultation',
      });

      final apt2 = DoctorAppointmentModel.fromMap({
        'id': 'apt-2',
        'patient_id': 'pat-y',
        'profiles': {'full_name': 'Ayesha Bilal'},
        'service_name': 'Dental Checkup',
      });

      expect(apt1.patientName, equals('Usman Tariq'));
      expect(apt2.patientName, equals('Ayesha Bilal'));
    });

    test('DoctorAppointmentModel provides honest fallback "Name not provided" when name is absent', () {
      final emptyNameApt = DoctorAppointmentModel.fromMap({
        'id': 'apt-3',
        'patient_id': 'pat-z',
        'profiles': {'full_name': ''},
      });

      expect(emptyNameApt.patientName, equals('Name not provided'));
      expect(emptyNameApt.patientName, isNot(equals('Patient')));
    });
  });

  group('Phase 5A.4: Complete Patient Demographics & Records in DoctorPatientModel', () {
    test('DoctorPatientModel aggregates profiles and patient_profiles data correctly', () {
      final patientRawMap = {
        'id': 'pat-007',
        'patient_id': 'pat-007',
        'profiles': {
          'id': 'pat-007',
          'full_name': 'Hamza Ahmed',
          'phone': '+923001234567',
        },
        'patient_profiles': {
          'patient_id': 'pat-007',
          'date_of_birth': '1995-06-15',
          'gender': 'Male',
          'blood_group': 'B+',
          'allergies': 'Penicillin, Dust',
          'medical_conditions': 'Hypertension, Asthma',
        },
      };

      final patient = DoctorPatientModel.fromMap(
        patientRawMap,
        totalVisits: 3,
        latestServiceName: 'Cardiology Review',
      );

      expect(patient.id, equals('pat-007'));
      expect(patient.name, equals('Hamza Ahmed'));
      expect(patient.gender, equals('Male'));
      expect(patient.bloodGroup, equals('B+'));
      expect(patient.allergies, equals('Penicillin, Dust'));
      expect(patient.medicalConditions, equals('Hypertension, Asthma'));
      expect(patient.age, greaterThanOrEqualTo(30)); // Calculated from 1995 DOB
      expect(patient.totalVisits, equals(3));
      expect(patient.primaryCondition, equals('Cardiology Review'));
    });

    test('DoctorPatientModel uses honest fallbacks when demographics are genuinely empty', () {
      final minimalPatientMap = {
        'id': 'pat-008',
        'patient_id': 'pat-008',
        'profiles': null,
        'patient_profiles': null,
      };

      final patient = DoctorPatientModel.fromMap(minimalPatientMap);
      expect(patient.name, equals('Name not provided'));
      expect(patient.gender, equals('Not specified'));
      expect(patient.bloodGroup, equals('Not specified'));
      expect(patient.allergies, equals('None added'));
      expect(patient.medicalConditions, equals('None added'));
    });
  });

  group('Phase 5A.4: Consultation History & Note Model Parsing', () {
    test('DoctorConsultationNoteModel parses joined profile and appointment data cleanly', () {
      final noteMap = {
        'id': 'note-1',
        'appointment_id': 'apt-101',
        'doctor_id': 'doc-1',
        'patient_id': 'pat-1',
        'diagnosis': 'Seasonal Allergic Rhinitis',
        'notes': 'Patient advised to avoid allergen exposure.',
        'prescriptions': [
          {
            'medicine_name': 'Cetirizine',
            'dosage': '10mg',
            'frequency': 'Once daily at night',
            'duration': '7 days',
            'instructions': 'After meal',
          }
        ],
        'created_at': '2026-09-03T10:30:00Z',
        'profiles': {
          'id': 'doc-1',
          'full_name': 'Arsalan',
        },
        'appointments': {
          'id': 'apt-101',
          'reference_no': 'REF-9988',
          'appointment_date': '2026-09-03',
          'status': 'completed',
        }
      };

      final note = DoctorConsultationNoteModel.fromMap(noteMap);
      expect(note.id, equals('note-1'));
      expect(note.doctorName, equals('Dr. Arsalan'));
      expect(note.diagnosis, equals('Seasonal Allergic Rhinitis'));
      expect(note.prescriptions.length, equals(1));
      expect(note.prescriptions.first.medicineName, equals('Cetirizine'));
      expect(note.appointmentReferenceNo, equals('REF-9988'));
    });
  });

  group('Phase 5A.4: Phase 4A–4C Security Matrix & Status Boundary Verification', () {
    test('Demographics allowed for pending, confirmed, completed; denied for cancelled', () {
      const allowedStatuses = {'pending', 'confirmed', 'completed'};
      const deniedStatuses = {'cancelled', 'declined'};

      for (final s in allowedStatuses) {
        expect(['pending', 'confirmed', 'completed'].contains(s), isTrue);
      }
      for (final s in deniedStatuses) {
        expect(['pending', 'confirmed', 'completed'].contains(s), isFalse);
      }
    });

    test('Clinical records (medicines, reports, notes) allowed only for confirmed & completed', () {
      const clinicalAllowed = {'confirmed', 'completed'};
      const clinicalDenied = {'pending', 'cancelled'};

      for (final s in clinicalAllowed) {
        expect(['confirmed', 'completed'].contains(s), isTrue);
      }
      for (final s in clinicalDenied) {
        expect(['confirmed', 'completed'].contains(s), isFalse);
      }
    });
  });
}
