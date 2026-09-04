import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/features/doctor/appointments/doctor_appointments_screen.dart';
import 'package:sehatpass/features/doctor/dashboard/doctor_dashboard_screen.dart';
import 'package:sehatpass/features/doctor/data/doctor_repository.dart';
import 'package:sehatpass/features/doctor/models/doctor_appointment_model.dart';
import 'package:sehatpass/features/doctor/models/doctor_onboarding_data.dart';
import 'package:sehatpass/features/doctor/models/doctor_patient_model.dart';
import 'package:sehatpass/features/doctor/models/doctor_profile_model.dart';
import 'package:sehatpass/features/doctor/patients/doctor_patient_detail_screen.dart';

class MockDoctorStatsRepository extends DoctorRepository {
  List<DoctorAppointmentModel> appointments;
  List<DoctorPatientModel> patients;

  MockDoctorStatsRepository({
    this.appointments = const [],
    this.patients = const [],
  });

  @override
  String? get currentUserId => 'doc-test-123';

  @override
  Future<List<DoctorAppointmentModel>> getDoctorAppointments({
    String? status,
  }) async {
    if (status != null && status.isNotEmpty) {
      return appointments
          .where((a) => a.rawStatus.toLowerCase() == status.toLowerCase())
          .toList();
    }
    return appointments;
  }

  @override
  Future<DoctorAppointmentModel> acceptAppointment(String appointmentId) async {
    final idx = appointments.indexWhere((a) => a.id == appointmentId);
    if (idx != -1) {
      final updated = appointments[idx].copyWith(
        status: DoctorAppointmentStatus.confirmed,
        rawStatus: 'confirmed',
      );
      appointments[idx] = updated;
      return updated;
    }
    throw 'Appointment not found';
  }

  @override
  Future<List<DoctorPatientModel>> getDoctorPatients() async {
    return patients;
  }

  @override
  Future<DoctorPatientModel?> getDoctorPatientDetail(String patientId) async {
    try {
      return patients.firstWhere((p) => p.id == patientId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DoctorOnboardingData> loadExistingOnboardingData() async {
    return DoctorOnboardingData(
      profile: DoctorProfileModel(
        doctorId: 'doc-test-123',
        fullName: 'Dr. Arsalan Khan',
        specialization: 'Cardiologist',
        isPublished: true,
      ),
    );
  }
}

void main() {
  group('Doctor Appointment Schedule & Visit Statistics Logic Tests', () {
    testWidgets('1. Accepting a future appointment (7 Sep) removes it from Pending and does NOT add to Today\'s Schedule',
        (WidgetTester tester) async {
      // Setup test scenario:
      // Today is 4 Sep 2026.
      // Patient appointment requested for 7 Sep 2026 at 12:15 PM (status: pending).
      final futureApt = DoctorAppointmentModel(
        id: 'apt-sep7',
        patientName: 'Arsalan',
        serviceName: 'ECG Consultation',
        appointmentDate: DateTime(2026, 9, 7),
        date: '7 Sep 2026',
        time: '12:15 PM',
        fee: 2500,
        status: DoctorAppointmentStatus.pending,
        rawStatus: 'pending',
      );

      final repo = MockDoctorStatsRepository(
        appointments: [futureApt],
      );

      final onboardingData = DoctorOnboardingData(
        profile: DoctorProfileModel(
          doctorId: 'doc-test-123',
          fullName: 'Dr. Test Doctor',
          isPublished: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorDashboardScreen(
            data: onboardingData,
            appointments: [futureApt],
            repository: repo,
            onAcceptAppointment: (apt) async {
              await repo.acceptAppointment(apt.id);
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Before Accept:
      // Pending Requests: 1 New, displays Arsalan
      expect(find.text('Pending Requests'), findsWidgets);
      expect(find.text('1 New'), findsOneWidget);
      expect(find.text('Arsalan'), findsOneWidget);
      expect(find.text('7 Sep 2026 • 12:15 PM'), findsOneWidget);

      // Today's Schedule: empty (No confirmed appointments for today)
      expect(find.text('No confirmed appointments for today.'), findsOneWidget);
      expect(find.text("Today's Appointments"), findsOneWidget);
      expect(find.text('0'), findsWidgets); // 0 today appointments

      // Ensure Accept button is visible and tap it
      final acceptBtn = find.widgetWithText(ElevatedButton, 'Accept');
      expect(acceptBtn, findsOneWidget);
      await tester.ensureVisible(acceptBtn);
      await tester.pumpAndSettle();
      await tester.tap(acceptBtn);
      await tester.pumpAndSettle();

      // After Accept:
      // 1. Pending Requests section is now GONE (no pending requests)
      expect(find.text('1 New'), findsNothing);

      // 2. Today's Schedule MUST NOT contain the 7 Sep appointment
      expect(find.text('No confirmed appointments for today.'), findsOneWidget);

      // 3. Today's Appointments metric remains 0
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('2. Future confirmed appointment appears under Upcoming tab with date/time intact',
        (WidgetTester tester) async {
      final futureConfirmedApt = DoctorAppointmentModel(
        id: 'apt-sep7',
        patientName: 'Arsalan',
        serviceName: 'ECG Consultation',
        appointmentDate: DateTime(2026, 9, 7),
        date: '7 Sep 2026',
        time: '12:15 PM',
        fee: 2500,
        status: DoctorAppointmentStatus.confirmed,
        rawStatus: 'confirmed',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorAppointmentsScreen(
            appointments: [futureConfirmedApt],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Upcoming filter tab
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();

      // Verify future confirmed appointment is listed with full details
      expect(find.text('Arsalan'), findsOneWidget);
      expect(find.text('ECG Consultation'), findsOneWidget);
      expect(find.text('7 Sep 2026 • 12:15 PM'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
    });

    testWidgets('3. Doctor Patient Details displays Total Visits = 2 and Last Visit = 3 Sep 2026 (completed only)',
        (WidgetTester tester) async {
      // Patient with:
      // 2 completed (1 Sep 2026, 3 Sep 2026)
      // 1 future confirmed (7 Sep 2026)
      // 1 pending (10 Sep 2026)
      final patient = DoctorPatientModel(
        id: 'pat-arsalan',
        name: 'Arsalan',
        age: 28,
        gender: 'Male',
        phone: '+92 300 1234567',
        bloodGroup: 'B+',
        lastVisit: '3 Sep 2026', // Most recent completed visit
        lastAppointmentDate: DateTime(2026, 9, 3),
        totalVisits: 2, // Only completed visits counted
        primaryCondition: 'ECG Consultation',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorPatientDetailScreen(
            patient: patient,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Arsalan'), findsOneWidget);
      expect(find.text('Total Visits'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // NOT 4
      expect(find.text('Last Visit'), findsOneWidget);
      expect(find.text('3 Sep 2026'), findsOneWidget); // NOT 7 Sep 2026
    });

    testWidgets('4. Patient with only future confirmed appointment displays Total Visits = 0 and "No visits yet"',
        (WidgetTester tester) async {
      final newPatient = DoctorPatientModel(
        id: 'pat-new',
        name: 'Zahid Khan',
        age: 35,
        gender: 'Male',
        phone: '+92 321 9876543',
        bloodGroup: 'O+',
        lastVisit: 'No visits yet',
        lastAppointmentDate: null,
        totalVisits: 0,
        primaryCondition: 'General Consultation',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorPatientDetailScreen(
            patient: newPatient,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Zahid Khan'), findsOneWidget);
      expect(find.text('Total Visits'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Last Visit'), findsOneWidget);
      expect(find.text('No visits yet'), findsOneWidget);
    });
  });
}
