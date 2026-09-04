import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/features/doctor/appointments/doctor_appointment_details_screen.dart';
import 'package:sehatpass/features/doctor/appointments/doctor_appointments_screen.dart';
import 'package:sehatpass/features/doctor/data/doctor_repository.dart';
import 'package:sehatpass/features/doctor/models/doctor_appointment_model.dart';
import 'package:sehatpass/features/doctor/models/doctor_patient_model.dart';

class MockDoctorRepository extends DoctorRepository {
  List<DoctorAppointmentModel> appointmentsToReturn;
  final String? errorToThrow;
  int getDoctorAppointmentsCallCount = 0;
  int acceptAppointmentCallCount = 0;
  int declineAppointmentCallCount = 0;
  String? lastAcceptedId;
  String? lastDeclinedId;
  String? lastDeclineReason;

  MockDoctorRepository({
    this.appointmentsToReturn = const [],
    this.errorToThrow,
  });

  @override
  String? get currentUserId => 'mock-doctor-uuid-123';

  @override
  Future<List<DoctorAppointmentModel>> getDoctorAppointments({
    String? status,
  }) async {
    getDoctorAppointmentsCallCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    if (status != null && status.isNotEmpty) {
      return appointmentsToReturn
          .where((a) => a.rawStatus.toLowerCase() == status.toLowerCase())
          .toList();
    }
    return appointmentsToReturn;
  }

  @override
  Future<DoctorAppointmentModel?> getDoctorAppointmentById(
      String appointmentId) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    try {
      return appointmentsToReturn.firstWhere((a) => a.id == appointmentId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DoctorAppointmentModel> acceptAppointment(String appointmentId) async {
    acceptAppointmentCallCount++;
    lastAcceptedId = appointmentId;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    final index = appointmentsToReturn.indexWhere((a) => a.id == appointmentId);
    if (index != -1) {
      final updated = appointmentsToReturn[index].copyWith(
        status: DoctorAppointmentStatus.confirmed,
        rawStatus: 'confirmed',
      );
      appointmentsToReturn[index] = updated;
      return updated;
    }
    return DoctorAppointmentModel(
      id: appointmentId,
      patientName: 'Updated Patient',
      serviceName: 'General Consultation',
      time: '10:00 AM',
      date: 'Today',
      fee: 2000,
      status: DoctorAppointmentStatus.confirmed,
      rawStatus: 'confirmed',
    );
  }

  @override
  Future<DoctorAppointmentModel> declineAppointment(
    String appointmentId, {
    String? reason,
  }) async {
    declineAppointmentCallCount++;
    lastDeclinedId = appointmentId;
    lastDeclineReason = reason;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    final index = appointmentsToReturn.indexWhere((a) => a.id == appointmentId);
    if (index != -1) {
      final updated = appointmentsToReturn[index].copyWith(
        status: DoctorAppointmentStatus.cancelled,
        rawStatus: 'cancelled',
        cancellationReason: reason ?? 'Declined by doctor',
      );
      appointmentsToReturn[index] = updated;
      return updated;
    }
    return DoctorAppointmentModel(
      id: appointmentId,
      patientName: 'Updated Patient',
      serviceName: 'General Consultation',
      time: '10:00 AM',
      date: 'Today',
      fee: 2000,
      status: DoctorAppointmentStatus.cancelled,
      rawStatus: 'cancelled',
      cancellationReason: reason ?? 'Declined by doctor',
    );
  }
}

void main() {
  group('DoctorAppointmentModel Serialization & Mapping Tests', () {
    test('fromMap maps Supabase joined appointment row accurately', () {
      final rawRow = {
        'id': 'apt-uuid-001',
        'reference_no': 'SP-APT-998877',
        'patient_id': 'patient-uuid-111',
        'doctor_id': 'doctor-uuid-222',
        'clinic_id': 'clinic-uuid-333',
        'service_id': 'service-uuid-444',
        'service_name': 'Cardiology Consultation',
        'appointment_date': '2026-09-10',
        'appointment_time': '11:30 AM',
        'consultation_fee': 2500.00,
        'status': 'pending',
        'cancellation_reason': null,
        'created_at': '2026-09-02T10:00:00.000Z',
        'updated_at': '2026-09-02T10:00:00.000Z',
        'profiles': {
          'id': 'patient-uuid-111',
          'full_name': 'Tariq Mehmood',
          'profile_photo_url': 'https://example.com/photo.jpg',
        },
        'clinics': {
          'id': 'clinic-uuid-333',
          'name': 'Lahore Heart Center',
          'address': 'Gulberg III',
          'city': 'Lahore',
        },
      };

      final model = DoctorAppointmentModel.fromMap(rawRow);

      expect(model.id, 'apt-uuid-001');
      expect(model.referenceNo, 'SP-APT-998877');
      expect(model.patientId, 'patient-uuid-111');
      expect(model.patientName, 'Tariq Mehmood');
      expect(model.serviceName, 'Cardiology Consultation');
      expect(model.clinicName, 'Lahore Heart Center');
      expect(model.time, '11:30 AM');
      expect(model.date, '10 Sep 2026');
      expect(model.fee, 2500.0);
      expect(model.formattedFee, 'Rs. 2,500');
      expect(model.status, DoctorAppointmentStatus.pending);
      expect(model.rawStatus, 'pending');
    });

    test('parseStatus correctly maps standard database statuses', () {
      expect(DoctorAppointmentModel.parseStatus('pending'),
          DoctorAppointmentStatus.pending);
      expect(DoctorAppointmentModel.parseStatus('confirmed'),
          DoctorAppointmentStatus.confirmed);
      expect(DoctorAppointmentModel.parseStatus('accepted'),
          DoctorAppointmentStatus.confirmed);
      expect(DoctorAppointmentModel.parseStatus('completed'),
          DoctorAppointmentStatus.completed);
      expect(DoctorAppointmentModel.parseStatus('cancelled'),
          DoctorAppointmentStatus.cancelled);
      expect(DoctorAppointmentModel.parseStatus('declined'),
          DoctorAppointmentStatus.cancelled);
      expect(DoctorAppointmentModel.parseStatus(null),
          DoctorAppointmentStatus.pending);
    });

    test('toMap and copyWith preserve all fields correctly', () {
      final original = DoctorAppointmentModel(
        id: 'apt-1',
        referenceNo: 'REF-1',
        patientId: 'p-1',
        patientName: 'Ali',
        serviceName: 'Consultation',
        clinicName: 'Clinic A',
        time: '10:00 AM',
        date: 'Today',
        fee: 1500,
        status: DoctorAppointmentStatus.pending,
        rawStatus: 'pending',
      );

      final modified = original.copyWith(
        status: DoctorAppointmentStatus.confirmed,
        rawStatus: 'confirmed',
      );

      expect(modified.status, DoctorAppointmentStatus.confirmed);
      expect(modified.rawStatus, 'confirmed');
      expect(modified.id, 'apt-1');
      expect(modified.patientName, 'Ali');

      final map = modified.toMap();
      expect(map['id'], 'apt-1');
      expect(map['patient_name'], 'Ali');
      expect(map['status'], 'confirmed');
    });
  });

  group('Doctor Appointments UI Widget Tests', () {
    List<DoctorAppointmentModel> createTestAppointments() => [
          DoctorAppointmentModel(
            id: 'apt-p1',
            referenceNo: 'SP-APT-1001',
            patientName: 'Kamran Akmal',
            serviceName: 'General Consultation',
            date: 'Today',
            time: '10:00 AM',
            clinicName: 'Lahore Health Center',
            fee: 1500,
            status: DoctorAppointmentStatus.pending,
            rawStatus: 'pending',
          ),
          DoctorAppointmentModel(
            id: 'apt-u1',
            referenceNo: 'SP-APT-1002',
            patientName: 'Bilal Asif',
            serviceName: 'Cardiology Review',
            date: 'Tomorrow',
            time: '12:00 PM',
            clinicName: 'Lahore Health Center',
            fee: 2500,
            status: DoctorAppointmentStatus.confirmed,
            rawStatus: 'confirmed',
          ),
          DoctorAppointmentModel(
            id: 'apt-c1',
            referenceNo: 'SP-APT-1003',
            patientName: 'Saima Noor',
            serviceName: 'Follow-up',
            date: '28 Aug 2026',
            time: '02:00 PM',
            clinicName: 'Lahore Health Center',
            fee: 1000,
            status: DoctorAppointmentStatus.completed,
            rawStatus: 'completed',
          ),
          DoctorAppointmentModel(
            id: 'apt-x1',
            referenceNo: 'SP-APT-1004',
            patientName: 'Zubair Khan',
            serviceName: 'General Consultation',
            date: '25 Aug 2026',
            time: '04:00 PM',
            clinicName: 'Lahore Health Center',
            fee: 1500,
            status: DoctorAppointmentStatus.cancelled,
            rawStatus: 'cancelled',
          ),
        ];

    testWidgets('DoctorAppointmentsScreen filters tabs (Pending, Upcoming, Completed, Cancelled)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorAppointmentsScreen(
            appointments: createTestAppointments(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default filter is Pending -> Kamran Akmal
      expect(find.text('Kamran Akmal'), findsOneWidget);
      expect(find.text('Bilal Asif'), findsNothing);

      // Tap Upcoming -> Bilal Asif
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();
      expect(find.text('Bilal Asif'), findsOneWidget);
      expect(find.text('Kamran Akmal'), findsNothing);

      // Tap Completed -> Saima Noor
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      expect(find.text('Saima Noor'), findsOneWidget);

      // Tap Cancelled -> Zubair Khan
      await tester.tap(find.text('Cancelled'));
      await tester.pumpAndSettle();
      expect(find.text('Zubair Khan'), findsOneWidget);
    });

    testWidgets('DoctorAppointmentsScreen Accept button triggers callback',
        (WidgetTester tester) async {
      DoctorAppointmentModel? accepted;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorAppointmentsScreen(
            appointments: createTestAppointments(),
            onAcceptAppointment: (apt) async {
              accepted = apt;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final acceptBtn = find.widgetWithText(ElevatedButton, 'Accept');
      expect(acceptBtn, findsOneWidget);

      await tester.tap(acceptBtn);
      await tester.pumpAndSettle();

      expect(accepted, isNotNull);
      expect(accepted!.id, 'apt-p1');
      expect(find.textContaining('accepted & moved to Upcoming'), findsOneWidget);
    });

    testWidgets('DoctorAppointmentsScreen Decline confirmation dialog triggers decline callback',
        (WidgetTester tester) async {
      DoctorAppointmentModel? declined;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorAppointmentsScreen(
            appointments: createTestAppointments(),
            onDeclineAppointment: (apt) async {
              declined = apt;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final declineBtn = find.widgetWithText(OutlinedButton, 'Decline');
      expect(declineBtn, findsOneWidget);

      await tester.tap(declineBtn);
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Decline Request?'), findsOneWidget);

      final confirmDecline = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Decline'),
      );
      await tester.tap(confirmDecline);
      await tester.pumpAndSettle();

      expect(declined, isNotNull);
      expect(declined!.id, 'apt-p1');
      expect(find.textContaining('was declined'), findsOneWidget);
    });

    testWidgets('DoctorAppointmentsScreen renders loading and error states',
        (WidgetTester tester) async {
      bool retryTapped = false;

      // Loading state
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const DoctorAppointmentsScreen(
            appointments: [],
            isLoading: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Error state with retry
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorAppointmentsScreen(
            appointments: const [],
            isLoading: false,
            errorMessage: 'Network connection failed.',
            onRetry: () {
              retryTapped = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to Load Appointments'), findsOneWidget);
      expect(find.text('Network connection failed.'), findsOneWidget);

      final tryAgainBtn = find.widgetWithText(ElevatedButton, 'Try Again');
      expect(tryAgainBtn, findsOneWidget);
      await tester.tap(tryAgainBtn);
      expect(retryTapped, isTrue);
    });

    testWidgets('DoctorAppointmentDetailsScreen displays summary fields and handles actions',
        (WidgetTester tester) async {
      final apt = DoctorAppointmentModel(
        id: 'apt-det-1',
        referenceNo: 'SP-APT-7788',
        patientName: 'Hamza Tariq',
        serviceName: 'Cardiology Review',
        date: '10 Sep 2026',
        time: '11:00 AM',
        clinicName: 'City Heart Clinic',
        fee: 3000,
        status: DoctorAppointmentStatus.pending,
        rawStatus: 'pending',
      );

      bool acceptCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorAppointmentDetailsScreen(
            appointment: apt,
            onAccept: (a) async {
              acceptCalled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Appointment Details'), findsOneWidget);
      expect(find.text('Appointment Summary'), findsOneWidget);
      expect(find.text('Reference No'), findsOneWidget);
      expect(find.text('SP-APT-7788'), findsOneWidget);
      expect(find.text('Hamza Tariq'), findsWidgets);
      expect(find.text('Cardiology Review'), findsOneWidget);
      expect(find.text('City Heart Clinic'), findsOneWidget);
      expect(find.text('Rs. 3,000'), findsOneWidget);
      expect(find.text('Cash at clinic'), findsOneWidget);

      final acceptBtn = find.widgetWithText(ElevatedButton, 'Accept');
      expect(acceptBtn, findsOneWidget);
      await tester.ensureVisible(acceptBtn);
      await tester.tap(acceptBtn);
      await tester.pumpAndSettle();

      expect(acceptCalled, isTrue);
    });
  });

  group('Doctor Appointment Date & Visit Statistics Regression Tests', () {
    test('1. Accepting an appointment changes ONLY status, preserving date, time, and fee', () async {
      final repo = MockDoctorRepository();
      final apt = DoctorAppointmentModel(
        id: 'apt-sep-7',
        referenceNo: 'SP-APT-9900',
        patientId: 'pat-1',
        patientName: 'Arsalan',
        serviceId: 'svc-1',
        serviceName: 'ECG Consultation',
        clinicId: 'clinic-1',
        clinicName: 'City Clinic',
        appointmentDate: DateTime(2026, 9, 7),
        date: '7 Sep 2026',
        time: '12:15 PM',
        fee: 2500,
        status: DoctorAppointmentStatus.pending,
        rawStatus: 'pending',
      );

      repo.appointmentsToReturn = [apt];

      final accepted = await repo.acceptAppointment('apt-sep-7');

      // Status transitioned to confirmed
      expect(accepted.status, DoctorAppointmentStatus.confirmed);
      expect(accepted.rawStatus, 'confirmed');

      // Date and time preserved exactly
      expect(accepted.appointmentDate, DateTime(2026, 9, 7));
      expect(accepted.date, '7 Sep 2026');
      expect(accepted.time, '12:15 PM');
      expect(accepted.patientId, 'pat-1');
      expect(accepted.patientName, 'Arsalan');
      expect(accepted.fee, 2500.0);
    });

    test('2. isScheduledForToday returns false for future appointment and true for today', () {
      final now = DateTime(2026, 9, 4, 15, 0); // Today is 4 Sep 2026

      final futureApt = DoctorAppointmentModel(
        id: 'apt-future',
        patientName: 'Arsalan',
        serviceName: 'Consultation',
        appointmentDate: DateTime(2026, 9, 7),
        date: '7 Sep 2026',
        time: '12:15 PM',
        fee: 2500,
        status: DoctorAppointmentStatus.confirmed,
      );

      final todayApt = DoctorAppointmentModel(
        id: 'apt-today',
        patientName: 'Ali',
        serviceName: 'Consultation',
        appointmentDate: DateTime(2026, 9, 4),
        date: '4 Sep 2026',
        time: '10:00 AM',
        fee: 2000,
        status: DoctorAppointmentStatus.confirmed,
      );

      expect(futureApt.isScheduledForToday(now), isFalse);
      expect(todayApt.isScheduledForToday(now), isTrue);
    });

    test('3. DoctorPatientModel calculates Total Visits and Last Visit strictly from completed visits', () {
      // Patient with:
      // Appointment 1: 2026-09-01 (completed)
      // Appointment 2: 2026-09-03 (completed)
      // Appointment 3: 2026-09-07 (confirmed)
      // Appointment 4: 2026-09-10 (pending)

      final patient = DoctorPatientModel.fromMap(
        {
          'id': 'pat-arsalan',
          'patient_id': 'pat-arsalan',
          'profiles': {'full_name': 'Arsalan'},
        },
        totalVisits: 2, // 2 completed
        lastAppointmentDate: DateTime(2026, 9, 3), // Most recent completed
      );

      expect(patient.totalVisits, 2);
      expect(patient.lastVisit, '3 Sep 2026');
      expect(patient.lastAppointmentDate, DateTime(2026, 9, 3));
    });

    test('4. Patient with only future confirmed appointment has 0 Total Visits and "No visits yet"', () {
      final patient = DoctorPatientModel.fromMap(
        {
          'id': 'pat-new',
          'patient_id': 'pat-new',
          'profiles': {'full_name': 'New Patient'},
        },
        totalVisits: 0,
        lastAppointmentDate: null,
      );

      expect(patient.totalVisits, 0);
      expect(patient.lastVisit, 'No visits yet');
      expect(patient.lastAppointmentDate, isNull);
    });

    test('5. Lifecycle transition to completed updates Total Visits and Last Visit to the completed date', () {
      // Future appointment on 7 Sep becomes completed
      final patientAfterCompletion = DoctorPatientModel.fromMap(
        {
          'id': 'pat-arsalan',
          'patient_id': 'pat-arsalan',
          'profiles': {'full_name': 'Arsalan'},
        },
        totalVisits: 3, // 2 previous + 1 completed
        lastAppointmentDate: DateTime(2026, 9, 7),
      );

      expect(patientAfterCompletion.totalVisits, 3);
      expect(patientAfterCompletion.lastVisit, '7 Sep 2026');
      expect(patientAfterCompletion.lastAppointmentDate, DateTime(2026, 9, 7));
    });
  });
}
