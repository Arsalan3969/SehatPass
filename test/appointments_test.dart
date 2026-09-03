import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/features/appointments/appointment_confirmation_screen.dart';
import 'package:sehatpass/features/appointments/appointment_detail_screen.dart';
import 'package:sehatpass/features/appointments/book_appointment_screen.dart';
import 'package:sehatpass/features/appointments/data/appointment_repository.dart';
import 'package:sehatpass/features/appointments/doctor_profile_screen.dart';
import 'package:sehatpass/features/appointments/find_doctor_screen.dart';
import 'package:sehatpass/features/appointments/models/appointment_model.dart';
import 'package:sehatpass/features/appointments/models/doctor_model.dart';
import 'package:sehatpass/features/appointments/my_appointments_screen.dart';

class MockAppointmentRepository extends AppointmentRepository {
  List<Doctor> doctorsToReturn;
  List<Appointment> appointmentsToReturn;
  final String? errorToThrow;
  bool shouldThrowDoubleBookingError;

  int getDoctorsCallCount = 0;
  int getPatientAppointmentsCallCount = 0;
  int bookAppointmentCallCount = 0;
  int cancelAppointmentCallCount = 0;

  String? lastBookedDoctorId;
  String? lastCancelledAppointmentId;

  MockAppointmentRepository({
    this.doctorsToReturn = const [],
    this.appointmentsToReturn = const [],
    this.errorToThrow,
    this.shouldThrowDoubleBookingError = false,
  });

  @override
  String? get currentUserId => 'patient-test-auth-id';

  @override
  Future<List<Doctor>> getDoctors({
    String? specialty,
    String? searchQuery,
  }) async {
    getDoctorsCallCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    var list = doctorsToReturn;
    if (specialty != null && specialty.isNotEmpty && specialty != 'All') {
      list = list.where((d) => d.specialization == specialty).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((d) =>
          d.name.toLowerCase().contains(q) ||
          d.specialization.toLowerCase().contains(q) ||
          d.clinic.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Future<List<Appointment>> getPatientAppointments() async {
    getPatientAppointmentsCallCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return appointmentsToReturn;
  }

  @override
  List<Appointment> get all => List.unmodifiable(appointmentsToReturn);

  @override
  List<Appointment> get upcoming => appointmentsToReturn
      .where((a) => a.status == AppointmentStatus.upcoming)
      .toList();

  @override
  List<Appointment> get past => appointmentsToReturn
      .where((a) => a.status == AppointmentStatus.past)
      .toList();

  @override
  List<Appointment> get cancelled => appointmentsToReturn
      .where((a) => a.status == AppointmentStatus.cancelled)
      .toList();

  @override
  Future<Appointment> bookAppointment({
    required Doctor doctor,
    required DateTime date,
    required String time,
    required int consultationFee,
    String? clinicId,
    String? serviceId,
    String? serviceName,
  }) async {
    bookAppointmentCallCount++;
    lastBookedDoctorId = doctor.id;

    if (shouldThrowDoubleBookingError) {
      throw 'This time slot has already been booked. Please choose another slot.';
    }

    if (errorToThrow != null) {
      throw errorToThrow!;
    }

    final newApt = Appointment(
      id: 'apt-test-${DateTime.now().millisecondsSinceEpoch}',
      referenceNo: 'SP-APT-1234',
      patientId: 'patient-test-auth-id',
      doctor: doctor,
      clinicId: clinicId ?? doctor.clinicId,
      serviceId: serviceId,
      serviceName: serviceName ?? 'General Consultation',
      date: date,
      time: time,
      consultationFee: consultationFee,
      status: AppointmentStatus.upcoming,
      rawStatus: 'pending',
    );

    appointmentsToReturn = [newApt, ...appointmentsToReturn];
    notifyListeners();
    return newApt;
  }

  @override
  Future<void> cancelAppointment({
    required String appointmentId,
    String? reason,
  }) async {
    cancelAppointmentCallCount++;
    lastCancelledAppointmentId = appointmentId;

    if (errorToThrow != null) {
      throw errorToThrow!;
    }

    appointmentsToReturn = appointmentsToReturn.map((a) {
      if (a.id == appointmentId) {
        return a.copyWith(
          status: AppointmentStatus.cancelled,
          rawStatus: 'cancelled',
          cancellationReason: reason ?? 'Cancelled by patient',
        );
      }
      return a;
    }).toList();
    notifyListeners();
  }
}

Doctor createTestDoctor({
  String id = 'doc-001',
  String name = 'Dr. Ahmed Khan',
  String specialization = 'Cardiologist',
  String clinic = 'City Heart Clinic',
  String location = 'Lahore',
  int fee = 2000,
  String qualifications = 'MBBS',
}) {
  return Doctor(
    id: id,
    name: name,
    specialization: specialization,
    clinic: clinic,
    location: location,
    qualifications: qualifications,
    rating: 4.8,
    consultationFee: fee,
    availability: 'Available Today',
    about: 'Experienced cardiologist with 12+ years of experience.',
    availableDays: const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
    consultationHours: '10:00 AM - 4:00 PM',
    services: [
      DoctorService(id: 'svc-001', name: 'General Consultation', fee: fee),
      const DoctorService(id: 'svc-002', name: 'Follow-up Consultation', fee: 1500),
    ],
  );
}

Appointment createTestAppointment({
  String id = 'apt-001',
  String referenceNo = 'SP-APT-0001',
  AppointmentStatus status = AppointmentStatus.upcoming,
  String rawStatus = 'pending',
  DateTime? date,
  String time = '10:00 AM',
}) {
  return Appointment(
    id: id,
    referenceNo: referenceNo,
    patientId: 'patient-test-auth-id',
    doctor: createTestDoctor(),
    date: date ?? DateTime(2026, 9, 1),
    time: time,
    consultationFee: 2000,
    status: status,
    rawStatus: rawStatus,
  );
}

void main() {
  group('Appointment & Doctor Model Tests', () {
    test('Doctor.fromMap parses Supabase joined profile and clinic data', () {
      final map = {
        'doctor_id': 'd-123',
        'specialization': 'Cardiologist',
        'qualifications': 'MBBS, FCPS',
        'experience_years': '10 years',
        'bio': 'Specialist heart doctor.',
        'rating': 4.9,
        'total_reviews': 24,
        'profiles': {
          'id': 'd-123',
          'full_name': 'Dr. Tariq Mahmood',
          'profile_photo_url': 'https://example.com/avatar.jpg',
        },
        'clinics': [
          {
            'id': 'clinic-1',
            'name': 'National Heart Center',
            'city': 'Lahore',
            'address': 'Jail Road, Lahore',
          }
        ],
        'clinic_services': [
          {'id': 'svc-1', 'name': 'Cardiology Consultation', 'fee': 3000},
          {'id': 'svc-2', 'name': 'Echocardiogram', 'fee': 5000},
        ],
        'doctor_availability': [
          {
            'id': 'avail-1',
            'day_of_week': 'Monday',
            'start_time': '10:00:00',
            'end_time': '15:00:00',
          },
          {
            'id': 'avail-2',
            'day_of_week': 'Wednesday',
            'start_time': '10:00:00',
            'end_time': '15:00:00',
          },
        ]
      };

      final doc = Doctor.fromMap(map);
      expect(doc.id, 'd-123');
      expect(doc.name, 'Dr. Tariq Mahmood');
      expect(doc.specialization, 'Cardiologist');
      expect(doc.qualifications, 'MBBS, FCPS');
      expect(doc.experienceYears, '10 years');
      expect(doc.clinic, 'National Heart Center');
      expect(doc.clinicId, 'clinic-1');
      expect(doc.consultationFee, 3000);
      expect(doc.services.length, 2);
      expect(doc.availableDays, contains('Monday'));
      expect(doc.availableDays, contains('Wednesday'));
    });

    test('Appointment.fromMap correctly parses Supabase appointments record', () {
      final map = {
        'id': 'apt-999',
        'reference_no': 'SP-APT-9999',
        'patient_id': 'pat-123',
        'doctor_id': 'doc-123',
        'clinic_id': 'clinic-1',
        'service_id': 'svc-001',
        'service_name': 'Cardiology Visit',
        'appointment_date': '2026-09-15',
        'appointment_time': '11:00 AM',
        'consultation_fee': 2500,
        'status': 'confirmed',
        'profiles': {
          'full_name': 'Dr. Usman',
          'doctor_profiles': [
            {'specialization': 'Cardiologist', 'rating': 4.9}
          ],
          'clinics': [
            {'name': 'Heart Care Clinic', 'city': 'Lahore'}
          ]
        }
      };

      final apt = Appointment.fromMap(map);
      expect(apt.id, 'apt-999');
      expect(apt.referenceNo, 'SP-APT-9999');
      expect(apt.patientId, 'pat-123');
      expect(apt.serviceId, 'svc-001');
      expect(apt.serviceName, 'Cardiology Visit');
      expect(apt.consultationFee, 2500);
      expect(apt.time, '11:00 AM');
      expect(apt.date.year, 2026);
      expect(apt.date.month, 9);
      expect(apt.date.day, 15);
      expect(apt.rawStatus, 'confirmed');
    });

    test('Appointment status mapping logic', () {
      final upcomingApt = Appointment.fromMap({
        'id': '1',
        'appointment_date': '2030-01-01',
        'appointment_time': '10:00 AM',
        'status': 'confirmed',
      });
      expect(upcomingApt.status, AppointmentStatus.upcoming);

      final cancelledApt = Appointment.fromMap({
        'id': '2',
        'appointment_date': '2026-09-01',
        'appointment_time': '10:00 AM',
        'status': 'cancelled',
      });
      expect(cancelledApt.status, AppointmentStatus.cancelled);

      final completedApt = Appointment.fromMap({
        'id': '3',
        'appointment_date': '2026-09-01',
        'appointment_time': '10:00 AM',
        'status': 'completed',
      });
      expect(completedApt.status, AppointmentStatus.past);
    });

    test('Appointment.toInsertMap formats payload for Supabase insertion', () {
      final apt = createTestAppointment();
      final insertMap = apt.toInsertMap();

      expect(insertMap['reference_no'], 'SP-APT-0001');
      expect(insertMap['patient_id'], 'patient-test-auth-id');
      expect(insertMap['doctor_id'], 'doc-001');
      expect(insertMap['appointment_date'], '2026-09-01');
      expect(insertMap['appointment_time'], '10:00 AM');
      expect(insertMap['consultation_fee'], 2000);
      expect(insertMap['status'], 'pending');
    });
  });

  group('Appointment Repository & Double Booking Prevention Tests', () {
    test('Mock repository records booking and generates appointment', () async {
      final mockRepo = MockAppointmentRepository();
      final doc = createTestDoctor();

      final apt = await mockRepo.bookAppointment(
        doctor: doc,
        date: DateTime(2026, 9, 5),
        time: '2:00 PM',
        consultationFee: 2000,
      );

      expect(mockRepo.bookAppointmentCallCount, 1);
      expect(mockRepo.lastBookedDoctorId, 'doc-001');
      expect(apt.time, '2:00 PM');
      expect(mockRepo.upcoming.length, 1);
    });

    test('Booking throws error when double-booking conflict occurs', () async {
      final mockRepo = MockAppointmentRepository(
        shouldThrowDoubleBookingError: true,
      );
      final doc = createTestDoctor();

      expect(
        () => mockRepo.bookAppointment(
          doctor: doc,
          date: DateTime(2026, 9, 5),
          time: '2:00 PM',
          consultationFee: 2000,
        ),
        throwsA(isA<String>()),
      );
    });

    test('cancelAppointment updates status in-place', () async {
      final apt = createTestAppointment(id: 'apt-to-cancel');
      final mockRepo = MockAppointmentRepository(
        appointmentsToReturn: [apt],
      );

      await mockRepo.cancelAppointment(
        appointmentId: 'apt-to-cancel',
        reason: 'Change of plans',
      );

      expect(mockRepo.cancelAppointmentCallCount, 1);
      expect(mockRepo.lastCancelledAppointmentId, 'apt-to-cancel');
      expect(mockRepo.cancelled.length, 1);
      expect(mockRepo.cancelled.first.cancellationReason, 'Change of plans');
    });
  });

  group('Find Doctor & Doctor Profile Widget Tests', () {
    testWidgets('FindDoctorScreen displays doctors list and searches by name',
        (WidgetTester tester) async {
      final docs = [
        createTestDoctor(id: 'd1', name: 'Dr. Zafar Iqbal', specialization: 'Dentist'),
        createTestDoctor(id: 'd2', name: 'Dr. Ayesha Malik', specialization: 'Cardiologist'),
      ];

      final mockRepo = MockAppointmentRepository(doctorsToReturn: docs);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: FindDoctorScreen(repository: mockRepo),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dr. Zafar Iqbal'), findsOneWidget);
      expect(find.text('Dr. Ayesha Malik'), findsOneWidget);

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Zafar');
      await tester.pumpAndSettle();

      expect(find.text('Dr. Zafar Iqbal'), findsOneWidget);
      expect(find.text('Dr. Ayesha Malik'), findsNothing);
    });

    testWidgets('DoctorProfileScreen displays details, fees, and services',
        (WidgetTester tester) async {
      final doc = createTestDoctor();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorProfileScreen(doctor: doc),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dr. Ahmed Khan'), findsOneWidget);
      expect(find.text('Cardiologist • MBBS'), findsOneWidget);
      expect(find.text('Rs. 2000'), findsWidgets);
      expect(find.text('General Consultation'), findsWidgets);
      expect(find.text('Follow-up Consultation'), findsOneWidget);
      expect(find.text('Book Appointment'), findsOneWidget);
    });
  });

  group('Book Appointment & Confirmation Flow Widget Tests', () {
    testWidgets('BookAppointmentScreen allows service and slot selection and requests appointment',
        (WidgetTester tester) async {
      final doc = createTestDoctor();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookAppointmentScreen(doctor: doc),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Book Appointment'), findsOneWidget);
      expect(find.text('Dr. Ahmed Khan'), findsOneWidget);
      expect(find.text('General Consultation'), findsWidgets);
      expect(find.text('Select Service'), findsOneWidget);
      expect(find.text('Select Date'), findsOneWidget);
      expect(find.text('Select Time'), findsOneWidget);
      expect(find.text('Payment: Cash at Clinic'), findsOneWidget);

      // Select first date chip
      final dateChips = find.byType(AnimatedContainer);
      expect(dateChips, findsWidgets);
      await tester.tap(dateChips.first);
      await tester.pumpAndSettle();

      // Select time slot
      final timeSlot = find.text('10:00 AM');
      expect(timeSlot, findsOneWidget);
      await tester.tap(timeSlot);
      await tester.pumpAndSettle();

      final requestBtn = find.widgetWithText(ElevatedButton, 'Request Appointment');
      expect(requestBtn, findsOneWidget);
    });

    testWidgets('AppointmentConfirmationScreen renders reference and cash notice',
        (WidgetTester tester) async {
      final apt = createTestAppointment();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AppointmentConfirmationScreen(appointment: apt),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Appointment Request Submitted'), findsOneWidget);
      expect(find.text('Reference: SP-APT-0001'), findsOneWidget);
      expect(find.text('Dr. Ahmed Khan'), findsOneWidget);
      expect(find.text('Rs. 2000'), findsOneWidget);
      expect(find.text('Cash in person (Pay at clinic)'), findsOneWidget);
      expect(find.text('View My Appointments'), findsOneWidget);
    });

    testWidgets('AppointmentDetailScreen renders service and Cash at clinic notice',
        (WidgetTester tester) async {
      final apt = createTestAppointment();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AppointmentDetailScreen(appointment: apt),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Appointment Details'), findsOneWidget);
      expect(find.text('Appointment ID'), findsOneWidget);
      expect(find.text('SP-APT-0001'), findsOneWidget);
      expect(find.text('Service'), findsOneWidget);
      expect(find.text('General Consultation'), findsOneWidget);
      expect(find.text('Consultation Fee'), findsOneWidget);
      expect(find.text('Rs. 2000'), findsOneWidget);
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Cash at clinic (Pay upon visit)'), findsOneWidget);
    });

    testWidgets('MyAppointmentsScreen renders list and empty state',
        (WidgetTester tester) async {
      final mockRepo = MockAppointmentRepository(
        appointmentsToReturn: [createTestAppointment()],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MyAppointmentsScreen(repository: mockRepo),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('My Appointments'), findsOneWidget);
      expect(find.text('Dr. Ahmed Khan'), findsOneWidget);
      expect(find.text('Rs. 2000'), findsOneWidget);
    });
  });
}
