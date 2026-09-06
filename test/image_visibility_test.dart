import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/features/appointments/models/doctor_model.dart';
import 'package:sehatpass/features/doctor/models/doctor_appointment_model.dart';
import 'package:sehatpass/features/doctor/models/doctor_patient_model.dart';
import 'package:sehatpass/services/image_upload_service.dart';
import 'package:sehatpass/shared/widgets/app_user_avatar.dart';

void main() {
  setUp(() {
    ImageUploadService.clearCache();
  });

  group('Image Visibility & Authorization Model Tests', () {
    test('Doctor.fromMap extracts photo_url and clinicLogoUrl accurately', () {
      final map = {
        'doctor_id': 'doc-123',
        'specialization': 'Cardiologist',
        'qualifications': 'MBBS, FCPS',
        'photo_url': 'doc-123/avatar_111.jpg',
        'profiles': {
          'full_name': 'Dr. Sarah Ahmed',
          'avatar_url': 'doc-123/avatar_111.jpg',
        },
        'clinics': [
          {
            'id': 'clinic-999',
            'name': 'Heart Care Clinic',
            'city': 'Lahore',
            'logo_url': 'doc-123/clinic_logo_222.jpg',
          }
        ],
      };

      final doctor = Doctor.fromMap(map);

      expect(doctor.id, 'doc-123');
      expect(doctor.name, 'Dr. Sarah Ahmed');
      expect(doctor.specialization, 'Cardiologist');
      expect(doctor.photoUrl, 'doc-123/avatar_111.jpg');
      expect(doctor.clinic, 'Heart Care Clinic');
      expect(doctor.clinicLogoUrl, 'doc-123/clinic_logo_222.jpg');
    });

    test('DoctorAppointmentModel.fromMap parses patientAvatarUrl from joined profile', () {
      final map = {
        'id': 'apt-101',
        'patient_id': 'pat-456',
        'service_name': 'Checkup',
        'consultation_fee': 2000,
        'status': 'confirmed',
        'profiles': {
          'full_name': 'Ali Khan',
          'avatar_url': 'pat-456/patient_avatar_333.jpg',
        },
        'clinics': {
          'name': 'Sehat Clinic',
        }
      };

      final apt = DoctorAppointmentModel.fromMap(map);

      expect(apt.id, 'apt-101');
      expect(apt.patientId, 'pat-456');
      expect(apt.patientName, 'Ali Khan');
      expect(apt.patientAvatarUrl, 'pat-456/patient_avatar_333.jpg');
      expect(apt.status, DoctorAppointmentStatus.confirmed);
    });

    test('DoctorPatientModel.fromMap parses photoUrl from avatar_url', () {
      final map = {
        'id': 'pat-789',
        'profiles': {
          'full_name': 'Fatima Noor',
          'avatar_url': 'pat-789/avatar_444.jpg',
        },
        'patient_profiles': {
          'date_of_birth': '1995-05-12',
          'gender': 'Female',
          'blood_group': 'B+',
        },
      };

      final patient = DoctorPatientModel.fromMap(map);

      expect(patient.id, 'pat-789');
      expect(patient.name, 'Fatima Noor');
      expect(patient.photoUrl, 'pat-789/avatar_444.jpg');
      expect(patient.bloodGroup, 'B+');
      expect(patient.gender, 'Female');
    });

    test('ImageUploadService getCachedUrl handles absolute and cached paths', () {
      expect(ImageUploadService.getCachedUrl(null), isNull);
      expect(ImageUploadService.getCachedUrl(''), isNull);

      // Direct HTTP URL
      expect(
        ImageUploadService.getCachedUrl('https://example.com/photo.jpg'),
        'https://example.com/photo.jpg',
      );
    });
  });

  group('AppUserAvatar Widget Tests', () {
    testWidgets('Renders patient initial when no avatar URL is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppUserAvatar(
              imageUrlOrPath: null,
              name: 'Usman Tariq',
              size: 50,
            ),
          ),
        ),
      );

      expect(find.text('U'), findsOneWidget);
    });

    testWidgets('Renders doctor initial stripped of Dr. prefix', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppUserAvatar(
              imageUrlOrPath: null,
              name: 'Dr. Ayesha Malik',
              size: 50,
            ),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('Renders fallback icon when name is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppUserAvatar(
              imageUrlOrPath: null,
              name: '',
              size: 50,
              fallbackIcon: Icons.local_hospital_rounded,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.local_hospital_rounded), findsOneWidget);
    });
  });
}
