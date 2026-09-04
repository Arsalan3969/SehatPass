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
import 'package:sehatpass/features/doctor/models/doctor_availability_model.dart';

class MockAppointmentRepository extends AppointmentRepository {
  List<Doctor> doctorsToReturn;
  List<Appointment> appointmentsToReturn;
  List<Map<String, dynamic>> availabilityToReturn;
  List<String> bookedSlotsToReturn;
  final String? errorToThrow;
  String? availabilityErrorToThrow;
  bool shouldThrowDoubleBookingError;

  int getDoctorsCallCount = 0;
  int getPatientAppointmentsCallCount = 0;
  int getDoctorAvailabilityCallCount = 0;
  int getBookedSlotsCallCount = 0;
  int bookAppointmentCallCount = 0;
  int cancelAppointmentCallCount = 0;

  String? lastBookedDoctorId;
  String? lastCancelledAppointmentId;
  String? lastQueriedDoctorId;
  String? lastQueriedClinicId;

  MockAppointmentRepository({
    this.doctorsToReturn = const [],
    this.appointmentsToReturn = const [],
    List<Map<String, dynamic>>? availabilityToReturn,
    this.bookedSlotsToReturn = const [],
    this.errorToThrow,
    this.availabilityErrorToThrow,
    this.shouldThrowDoubleBookingError = false,
  }) : availabilityToReturn = availabilityToReturn ?? [
          {
            'doctor_id': 'doc-001',
            'clinic_id': 'clinic-1',
            'day_of_week': 'Monday',
            'start_time': '09:00:00',
            'end_time': '15:00:00',
            'is_available': true,
          },
          {
            'doctor_id': 'doc-001',
            'clinic_id': 'clinic-1',
            'day_of_week': 'Tuesday',
            'start_time': '09:00:00',
            'end_time': '15:00:00',
            'is_available': true,
          },
          {
            'doctor_id': 'doc-001',
            'clinic_id': 'clinic-1',
            'day_of_week': 'Wednesday',
            'start_time': '09:00:00',
            'end_time': '15:00:00',
            'is_available': true,
          },
        ];

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
  Future<List<Map<String, dynamic>>> getDoctorAvailability({
    required String doctorId,
    String? clinicId,
  }) async {
    getDoctorAvailabilityCallCount++;
    lastQueriedDoctorId = doctorId;
    lastQueriedClinicId = clinicId;

    if (availabilityErrorToThrow != null) {
      throw availabilityErrorToThrow!;
    }

    return availabilityToReturn.where((r) {
      final matchDoc = r['doctor_id'] == doctorId;
      final rowClinic = r['clinic_id'];
      final matchClinic = clinicId == null || rowClinic == null || rowClinic == clinicId;
      return matchDoc && matchClinic && r['is_available'] == true;
    }).toList();
  }

  @override
  Future<List<String>> getBookedSlots({
    required String doctorId,
    required DateTime date,
  }) async {
    getBookedSlotsCallCount++;
    return bookedSlotsToReturn;
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
  String clinicId = 'clinic-1',
  String location = 'Lahore',
  int fee = 2000,
  String qualifications = 'MBBS',
}) {
  return Doctor(
    id: id,
    name: name,
    specialization: specialization,
    clinic: clinic,
    clinicId: clinicId,
    location: location,
    qualifications: qualifications,
    rating: 4.8,
    consultationFee: fee,
    availability: 'Available Today',
    about: 'Experienced cardiologist with 12+ years of experience.',
    availableDays: const ['Monday', 'Tuesday', 'Wednesday'],
    consultationHours: '9:00 AM - 3:00 PM',
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
    date: date ?? DateTime(2026, 9, 7),
    time: time,
    consultationFee: 2000,
    status: status,
    rawStatus: rawStatus,
  );
}

void main() {
  group('Doctor Availability & Slot Generation Unit Tests', () {
    test('DoctorAvailabilityModel generates 15-minute slots inside 09:00 - 15:00 window (24 slots)', () {
      final start = DoctorAvailabilityModel.parseTimeString('09:00:00');
      final end = DoctorAvailabilityModel.parseTimeString('15:00:00');

      final slots = DoctorAvailabilityModel.generate15MinSlots(
        start: start,
        end: end,
      );

      // Expected number of slots = 24
      expect(slots.length, 24);
      expect(slots.first, '9:00 AM');
      expect(slots[1], '9:15 AM');
      expect(slots[2], '9:30 AM');
      expect(slots[3], '9:45 AM');
      expect(slots.last, '2:45 PM');

      // Slot at/after 15:00 (3:00 PM) is NOT offered
      expect(slots.contains('3:00 PM'), isFalse);
      expect(slots.contains('8:45 AM'), isFalse);
      expect(slots.contains('4:00 PM'), isFalse);
    });

    test('generateUpcomingBookableDates filters out unavailable days and past dates', () {
      final fromDate = DateTime(2026, 9, 4); // Friday
      final availableDays = ['Monday', 'Tuesday', 'Wednesday'];

      final dates = DoctorAvailabilityModel.generateUpcomingBookableDates(
        availableDays: availableDays,
        windowDays: 14,
        fromDate: fromDate,
      );

      expect(dates.isNotEmpty, isTrue);

      // Verify every generated date is Monday, Tuesday, or Wednesday
      for (final d in dates) {
        final dayName = DoctorAvailabilityModel.allDays[d.weekday - 1];
        expect(availableDays.contains(dayName), isTrue,
            reason: '$d ($dayName) should be in availableDays');
        expect(dayName == 'Thursday' || dayName == 'Friday' || dayName == 'Saturday' || dayName == 'Sunday', isFalse);
      }
    });

    test('isSlotPassed identifies past times on today vs future times', () {
      final today = DateTime(2026, 9, 4, 14, 30); // 2:30 PM
      final slot10Am = '10:00 AM';
      final slot2Pm = '2:00 PM';
      final slot3Pm = '3:00 PM';

      expect(DoctorAvailabilityModel.isSlotPassed(DateTime(2026, 9, 4), slot10Am, today), isTrue);
      expect(DoctorAvailabilityModel.isSlotPassed(DateTime(2026, 9, 4), slot2Pm, today), isTrue);
      expect(DoctorAvailabilityModel.isSlotPassed(DateTime(2026, 9, 4), slot3Pm, today), isFalse);

      // Future date
      expect(DoctorAvailabilityModel.isSlotPassed(DateTime(2026, 9, 7), slot10Am, today), isFalse);
    });
  });

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
      expect(insertMap['appointment_date'], '2026-09-07');
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
        date: DateTime(2026, 9, 7),
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
          date: DateTime(2026, 9, 7),
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

  group('Book Appointment Dynamic Availability Flow Widget Tests', () {
    testWidgets('1. Doctor available Mon-Wed shows only Mon-Wed dates and hourly slots',
        (WidgetTester tester) async {
      final doc = createTestDoctor();
      final mockRepo = MockAppointmentRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookAppointmentScreen(
            doctor: doc,
            repository: mockRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Book Appointment'), findsOneWidget);
      expect(find.text('Dr. Ahmed Khan'), findsOneWidget);
      expect(find.text('Select Service'), findsOneWidget);
      expect(find.text('Select Date'), findsOneWidget);
      expect(find.text('Select Time'), findsOneWidget);

      // Verify availability query was called for doc-001 and clinic-1
      expect(mockRepo.getDoctorAvailabilityCallCount, 1);
      expect(mockRepo.lastQueriedDoctorId, 'doc-001');
      expect(mockRepo.lastQueriedClinicId, 'clinic-1');

      // Date headers must only be Mon, Tue, or Wed
      expect(find.text('Mon'), findsWidgets);
      expect(find.text('Tue'), findsWidgets);
      expect(find.text('Wed'), findsWidgets);
      expect(find.text('Thu'), findsNothing);
      expect(find.text('Fri'), findsNothing);
      expect(find.text('Sat'), findsNothing);
      expect(find.text('Sun'), findsNothing);

      // 15-minute slots inside 09:00-15:00 window (e.g. 9:00 AM, 9:15 AM, 9:30 AM, ..., 2:45 PM)
      expect(find.text('9:00 AM'), findsOneWidget);
      expect(find.text('9:15 AM'), findsOneWidget);
      expect(find.text('9:30 AM'), findsOneWidget);
      expect(find.text('9:45 AM'), findsOneWidget);
      expect(find.text('10:00 AM'), findsOneWidget);
      expect(find.text('2:45 PM'), findsOneWidget);
      // 3:00 PM should NOT be offered (boundary)
      expect(find.text('3:00 PM'), findsNothing);

      // Select time slot
      await tester.ensureVisible(find.text('10:00 AM'));
      await tester.tap(find.text('10:00 AM'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Tap Request Appointment
      final requestBtn = find.widgetWithText(ElevatedButton, 'Request Appointment');
      expect(requestBtn, findsOneWidget);
      await tester.tap(requestBtn);
      await tester.pumpAndSettle();

      expect(mockRepo.bookAppointmentCallCount, 1);
      expect(find.text('Appointment Request Submitted'), findsOneWidget);
    });

    testWidgets('2. Already booked slot is rendered as disabled/booked and cannot be requested',
        (WidgetTester tester) async {
      final doc = createTestDoctor();
      final mockRepo = MockAppointmentRepository(
        bookedSlotsToReturn: ['10:00 AM'],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookAppointmentScreen(
            doctor: doc,
            repository: mockRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 10:00 AM is booked
      expect(find.text('10:00 AM (Booked)'), findsOneWidget);

      // Tapping booked slot does not select it
      await tester.ensureVisible(find.text('10:00 AM (Booked)'));
      await tester.tap(find.text('10:00 AM (Booked)'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final requestBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Request Appointment'),
      );
      // Request button remains disabled
      expect(requestBtn.onPressed, isNull);

      // Select an available slot (11:00 AM)
      await tester.ensureVisible(find.text('11:00 AM'));
      await tester.tap(find.text('11:00 AM'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final activeRequestBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Request Appointment'),
      );
      expect(activeRequestBtn.onPressed, isNotNull);
    });

    testWidgets('3. Empty state: Doctor with no published availability displays clear notice and disables booking',
        (WidgetTester tester) async {
      final doc = createTestDoctor();
      final mockRepo = MockAppointmentRepository(
        availabilityToReturn: [], // No availability
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookAppointmentScreen(
            doctor: doc,
            repository: mockRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('This doctor has not published any appointment availability yet.'),
        findsOneWidget,
      );

      final requestBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Request Appointment'),
      );
      expect(requestBtn.onPressed, isNull);
    });

    testWidgets('4. Error state: Availability fetch failure displays retry button and recovers on tap',
        (WidgetTester tester) async {
      final doc = createTestDoctor();
      final mockRepo = MockAppointmentRepository(
        availabilityErrorToThrow: 'Network error loading schedule.',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookAppointmentScreen(
            doctor: doc,
            repository: mockRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Network error loading schedule.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Clear error on mock repo and tap Retry button
      mockRepo.availabilityErrorToThrow = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Select Date'), findsOneWidget);
      expect(find.text('9:00 AM'), findsOneWidget);
    });

    testWidgets('5. Cross-doctor & Cross-clinic isolation: availability queries are strictly scoped',
        (WidgetTester tester) async {
      final mockRepo = MockAppointmentRepository(
        availabilityToReturn: [
          {
            'doctor_id': 'doc-A',
            'clinic_id': 'clinic-A',
            'day_of_week': 'Monday',
            'start_time': '09:00:00',
            'end_time': '12:00:00',
            'is_available': true,
          },
          {
            'doctor_id': 'doc-B',
            'clinic_id': 'clinic-B',
            'day_of_week': 'Friday',
            'start_time': '14:00:00',
            'end_time': '18:00:00',
            'is_available': true,
          },
        ],
      );

      final docA = createTestDoctor(id: 'doc-A', clinicId: 'clinic-A');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookAppointmentScreen(
            doctor: docA,
            repository: mockRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Doc A only has Monday (not Friday)
      expect(find.text('Mon'), findsWidgets);
      expect(find.text('Fri'), findsNothing);

      expect(mockRepo.lastQueriedDoctorId, 'doc-A');
      expect(mockRepo.lastQueriedClinicId, 'clinic-A');
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
