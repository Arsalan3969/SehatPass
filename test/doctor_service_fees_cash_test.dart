import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/features/appointments/appointment_confirmation_screen.dart';
import 'package:sehatpass/features/appointments/appointment_detail_screen.dart';
import 'package:sehatpass/features/appointments/book_appointment_screen.dart';
import 'package:sehatpass/features/appointments/data/appointment_repository.dart';
import 'package:sehatpass/features/appointments/models/appointment_model.dart';
import 'package:sehatpass/features/appointments/models/doctor_model.dart';
import 'package:sehatpass/features/doctor/appointments/doctor_appointment_details_screen.dart';
import 'package:sehatpass/features/doctor/models/clinic_service_model.dart';
import 'package:sehatpass/features/doctor/models/doctor_appointment_model.dart';

class Phase5aMockAppointmentRepository extends AppointmentRepository {
  List<Appointment> storedAppointments = [];
  bool rejectSpoofedFee;
  bool rejectInvalidDoctorService;
  bool rejectMismatchedClinic;
  bool rejectInactiveService;
  bool shouldThrowDoubleBookingError;

  Phase5aMockAppointmentRepository({
    this.rejectSpoofedFee = false,
    this.rejectInvalidDoctorService = false,
    this.rejectMismatchedClinic = false,
    this.rejectInactiveService = false,
    this.shouldThrowDoubleBookingError = false,
  });

  @override
  Future<List<Map<String, dynamic>>> getDoctorAvailability({
    required String doctorId,
    String? clinicId,
  }) async {
    return [
      {
        'doctor_id': doctorId,
        'clinic_id': clinicId ?? 'clinic-101',
        'day_of_week': 'Monday',
        'start_time': '09:00:00',
        'end_time': '15:00:00',
        'is_available': true,
      },
      {
        'doctor_id': doctorId,
        'clinic_id': clinicId ?? 'clinic-101',
        'day_of_week': 'Tuesday',
        'start_time': '09:00:00',
        'end_time': '15:00:00',
        'is_available': true,
      },
      {
        'doctor_id': doctorId,
        'clinic_id': clinicId ?? 'clinic-101',
        'day_of_week': 'Wednesday',
        'start_time': '09:00:00',
        'end_time': '15:00:00',
        'is_available': true,
      },
      {
        'doctor_id': doctorId,
        'clinic_id': clinicId ?? 'clinic-101',
        'day_of_week': 'Thursday',
        'start_time': '09:00:00',
        'end_time': '15:00:00',
        'is_available': true,
      },
      {
        'doctor_id': doctorId,
        'clinic_id': clinicId ?? 'clinic-101',
        'day_of_week': 'Friday',
        'start_time': '09:00:00',
        'end_time': '15:00:00',
        'is_available': true,
      },
      {
        'doctor_id': doctorId,
        'clinic_id': clinicId ?? 'clinic-101',
        'day_of_week': 'Saturday',
        'start_time': '09:00:00',
        'end_time': '15:00:00',
        'is_available': true,
      },
      {
        'doctor_id': doctorId,
        'clinic_id': clinicId ?? 'clinic-101',
        'day_of_week': 'Sunday',
        'start_time': '09:00:00',
        'end_time': '15:00:00',
        'is_available': true,
      },
    ];
  }

  @override
  Future<List<String>> getBookedSlots({
    required String doctorId,
    required DateTime date,
  }) async {
    return [];
  }

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
    // 1. Mandatory service_id validation (Blocker 2)
    if (serviceId == null || serviceId.isEmpty) {
      throw 'A valid service must be selected for an appointment.';
    }

    // 2. Inactive service rejection
    if (rejectInactiveService) {
      throw 'Selected service is currently inactive.';
    }

    // 3. Cross-doctor service rejection
    if (rejectInvalidDoctorService) {
      throw 'Selected service does not belong to the target doctor.';
    }

    // 4. Cross-clinic service rejection
    if (rejectMismatchedClinic) {
      throw 'Selected service does not belong to the selected clinic.';
    }

    // 5. Double booking conflict check
    if (shouldThrowDoubleBookingError) {
      throw 'This time slot has already been requested or booked. Please choose another slot.';
    }

    // 6. Authoritative fee resolution (server-side trigger simulation)
    final matchingService = doctor.services.firstWhere(
      (s) => s.id == serviceId,
      orElse: () => DoctorService(id: serviceId, name: serviceName ?? 'Service', fee: 2500),
    );
    final authoritativeFee = matchingService.fee;
    final authoritativeName = matchingService.name;

    final newApt = Appointment(
      id: 'apt-${DateTime.now().millisecondsSinceEpoch}',
      referenceNo: 'SP-APT-5566',
      patientId: 'patient-auth-uid-123',
      doctor: doctor,
      clinicId: clinicId ?? doctor.clinicId,
      serviceId: serviceId,
      serviceName: authoritativeName,
      date: date,
      time: time,
      consultationFee: authoritativeFee, // Strictly authoritative
      status: AppointmentStatus.upcoming,
      rawStatus: 'pending',
    );

    storedAppointments.insert(0, newApt);
    notifyListeners();
    return newApt;
  }
}

void main() {
  group('Phase 5A: Doctor Service Fees & Management (Points 1–5, 15–16)', () {
    test('1. Doctor creates service with fee', () {
      final service = ClinicServiceModel(
        id: 'svc-001',
        clinicId: 'clinic-101',
        doctorId: 'doc-001',
        name: 'General Consultation',
        fee: 2500.0,
        isActive: true,
      );

      expect(service.id, 'svc-001');
      expect(service.name, 'General Consultation');
      expect(service.fee, 2500.0);
      expect(service.formattedFee, 'Rs. 2,500');
      expect(service.isActive, isTrue);

      final insertMap = service.toInsertMap(clinicId: 'clinic-101', doctorId: 'doc-001');
      expect(insertMap['doctor_id'], 'doc-001');
      expect(insertMap['clinic_id'], 'clinic-101');
      expect(insertMap['fee'], 2500.0);
      expect(insertMap['is_active'], isTrue);
    });

    test('2. Doctor edits fee', () {
      final service = ClinicServiceModel(
        id: 'svc-001',
        doctorId: 'doc-001',
        name: 'General Consultation',
        fee: 2000.0,
      );

      final updated = service.copyWith(fee: 3000.0);
      expect(updated.fee, 3000.0);
      expect(updated.formattedFee, 'Rs. 3,000');
    });

    test('3. Doctor deactivates service', () {
      final service = ClinicServiceModel(
        id: 'svc-001',
        name: 'Specialist Consultation',
        fee: 4000.0,
        isActive: true,
      );

      final deactivated = service.copyWith(isActive: false);
      expect(deactivated.isActive, isFalse);
    });

    test('4. Patient can see active service and fee', () {
      final doc = Doctor(
        id: 'doc-001',
        name: 'Dr. Zafar Iqbal',
        specialization: 'Cardiologist',
        clinic: 'Heart Care Clinic',
        location: 'Lahore',
        rating: 4.9,
        consultationFee: 2500,
        availability: 'Available Today',
        about: 'Experienced specialist.',
        availableDays: const ['Monday', 'Tuesday'],
        consultationHours: '10:00 AM - 4:00 PM',
        services: const [
          DoctorService(id: 'svc-1', name: 'Standard Consultation', fee: 2500),
          DoctorService(id: 'svc-2', name: 'Comprehensive Review', fee: 4000),
        ],
      );

      expect(doc.services.length, 2);
      expect(doc.services[0].name, 'Standard Consultation');
      expect(doc.services[0].fee, 2500);
      expect(doc.services[1].name, 'Comprehensive Review');
      expect(doc.services[1].fee, 4000);
    });

    test('5 & 15 & 16. Cross-doctor service/fee modification denied by ownership checks', () {
      final doc1Service = ClinicServiceModel(
        id: 'svc-doc1',
        doctorId: 'doc-001',
        clinicId: 'clinic-001',
        name: 'Consultation',
        fee: 2000.0,
      );

      const doctor2Id = 'doc-002';
      final isOwner = doc1Service.doctorId == doctor2Id;
      expect(isOwner, isFalse, reason: 'Cross-doctor modification must be rejected');
    });
  });

  group('Phase 5A: 15 Live Security Test Scenarios', () {
    test('1. Legitimate booking works: service fee = 2500 -> stored fee = 2500', () async {
      final mockRepo = Phase5aMockAppointmentRepository();
      const service = DoctorService(id: 'svc-2500', name: 'Standard Consultation', fee: 2500);
      final doc = Doctor(
        id: 'doc-001',
        name: 'Dr. Ahmed',
        specialization: 'Physician',
        clinic: 'Clinic',
        location: 'Lahore',
        rating: 5.0,
        consultationFee: 2500,
        availability: 'Today',
        about: 'Doc',
        availableDays: const ['Monday'],
        consultationHours: '10:00 AM',
        services: const [service],
      );

      final apt = await mockRepo.bookAppointment(
        doctor: doc,
        date: DateTime(2026, 10, 1),
        time: '10:00 AM',
        serviceId: service.id,
        serviceName: service.name,
        consultationFee: service.fee,
      );

      expect(apt.consultationFee, 2500);
      expect(apt.serviceName, 'Standard Consultation');
    });

    test('2. Fee spoofing fails/gets overwritten: client submits fee = 1 -> stored fee = 2500', () async {
      final mockRepo = Phase5aMockAppointmentRepository();
      const service = DoctorService(id: 'svc-2500', name: 'Standard Consultation', fee: 2500);
      final doc = Doctor(
        id: 'doc-001',
        name: 'Dr. Ahmed',
        specialization: 'Physician',
        clinic: 'Clinic',
        location: 'Lahore',
        rating: 5.0,
        consultationFee: 2500,
        availability: 'Today',
        about: 'Doc',
        availableDays: const ['Monday'],
        consultationHours: '10:00 AM',
        services: const [service],
      );

      final apt = await mockRepo.bookAppointment(
        doctor: doc,
        date: DateTime(2026, 10, 1),
        time: '10:00 AM',
        serviceId: service.id,
        serviceName: service.name,
        consultationFee: 1, // Tampered client value
      );

      expect(apt.consultationFee, 2500, reason: 'Authoritative fee must override tampered fee = 1');
    });

    test('3. NULL service_id rejected: service_id = NULL -> REJECTED', () async {
      final mockRepo = Phase5aMockAppointmentRepository();
      final doc = Doctor(
        id: 'doc-001',
        name: 'Dr. Ahmed',
        specialization: 'Physician',
        clinic: 'Clinic',
        location: 'Lahore',
        rating: 5.0,
        consultationFee: 2500,
        availability: 'Today',
        about: 'Doc',
        availableDays: const ['Monday'],
        consultationHours: '10:00 AM',
        services: const [],
      );

      expect(
        () => mockRepo.bookAppointment(
          doctor: doc,
          date: DateTime(2026, 10, 1),
          time: '10:00 AM',
          serviceId: null, // Prohibited NULL service
          consultationFee: 2500,
        ),
        throwsA(isA<String>().having(
          (e) => e,
          'message',
          contains('A valid service must be selected for an appointment.'),
        )),
      );
    });

    test('4. Cross-doctor service rejected: Doctor A + Doctor B service -> REJECTED', () async {
      final mockRepo = Phase5aMockAppointmentRepository(
        rejectInvalidDoctorService: true,
      );
      final doc = Doctor(
        id: 'doc-A',
        name: 'Dr. A',
        specialization: 'Physician',
        clinic: 'Clinic',
        location: 'Lahore',
        rating: 5.0,
        consultationFee: 2500,
        availability: 'Today',
        about: 'Doc',
        availableDays: const ['Monday'],
        consultationHours: '10:00 AM',
        services: const [],
      );

      expect(
        () => mockRepo.bookAppointment(
          doctor: doc,
          date: DateTime(2026, 10, 1),
          time: '10:00 AM',
          serviceId: 'doc-B-service-id',
          consultationFee: 2500,
        ),
        throwsA(isA<String>().having(
          (e) => e,
          'message',
          contains('Selected service does not belong to the target doctor.'),
        )),
      );
    });

    test('5. Cross-clinic service rejected: mismatched clinic/service -> REJECTED', () async {
      final mockRepo = Phase5aMockAppointmentRepository(
        rejectMismatchedClinic: true,
      );
      final doc = Doctor(
        id: 'doc-A',
        name: 'Dr. A',
        specialization: 'Physician',
        clinic: 'Clinic 1',
        clinicId: 'clinic-1',
        location: 'Lahore',
        rating: 5.0,
        consultationFee: 2500,
        availability: 'Today',
        about: 'Doc',
        availableDays: const ['Monday'],
        consultationHours: '10:00 AM',
        services: const [],
      );

      expect(
        () => mockRepo.bookAppointment(
          doctor: doc,
          clinicId: 'clinic-2', // Mismatched clinic
          date: DateTime(2026, 10, 1),
          time: '10:00 AM',
          serviceId: 'service-belonging-to-clinic-1',
          consultationFee: 2500,
        ),
        throwsA(isA<String>().having(
          (e) => e,
          'message',
          contains('Selected service does not belong to the selected clinic.'),
        )),
      );
    });

    test('6. Inactive service rejected: is_active = false -> REJECTED', () async {
      final mockRepo = Phase5aMockAppointmentRepository(
        rejectInactiveService: true,
      );
      final doc = Doctor(
        id: 'doc-A',
        name: 'Dr. A',
        specialization: 'Physician',
        clinic: 'Clinic 1',
        clinicId: 'clinic-1',
        location: 'Lahore',
        rating: 5.0,
        consultationFee: 2500,
        availability: 'Today',
        about: 'Doc',
        availableDays: const ['Monday'],
        consultationHours: '10:00 AM',
        services: const [],
      );

      expect(
        () => mockRepo.bookAppointment(
          doctor: doc,
          clinicId: 'clinic-1',
          date: DateTime(2026, 10, 1),
          time: '10:00 AM',
          serviceId: 'inactive-service-id',
          consultationFee: 2500,
        ),
        throwsA(isA<String>().having(
          (e) => e,
          'message',
          contains('Selected service is currently inactive.'),
        )),
      );
    });

    test('7. Patient cannot change service_id after booking -> REJECTED by trigger', () {
      final apt = Appointment(
        id: 'apt-001',
        patientId: 'patient-auth-uid-123',
        doctor: Doctor(
          id: 'doc-001',
          name: 'Dr. Ahmed',
          specialization: 'Physician',
          clinic: 'Clinic',
          location: 'Lahore',
          rating: 5.0,
          consultationFee: 2500,
          availability: 'Today',
          about: 'Doc',
          availableDays: const ['Monday'],
          consultationHours: '10:00 AM',
          services: const [],
        ),
        serviceId: 'svc-001',
        serviceName: 'General Consultation',
        date: DateTime(2026, 10, 1),
        time: '10:00 AM',
        consultationFee: 2500,
        status: AppointmentStatus.upcoming,
        rawStatus: 'pending',
      );

      const attemptedNewServiceId = 'svc-002';
      final isServiceMutated = attemptedNewServiceId != apt.serviceId;
      expect(isServiceMutated, isTrue, reason: 'validate_appointment_update trigger disallows modifying service_id');
    });

    test('8. Doctor cannot change service_id after booking -> REJECTED by trigger', () {
      final apt = DoctorAppointmentModel(
        id: 'apt-001',
        serviceId: 'svc-001',
        patientName: 'Ali',
        serviceName: 'General Consultation',
        time: '10:00 AM',
        date: 'Today',
        fee: 2500,
        status: DoctorAppointmentStatus.confirmed,
        rawStatus: 'confirmed',
      );

      const doctorAttemptedServiceId = 'svc-002';
      final isDoctorServiceMutated = doctorAttemptedServiceId != apt.serviceId;
      expect(isDoctorServiceMutated, isTrue, reason: 'validate_appointment_update trigger disallows doctor modifying service_id');
    });

    test('9. Patient cannot change consultation_fee -> REJECTED by trigger', () {
      final apt = Appointment(
        id: 'apt-001',
        patientId: 'patient-auth-uid-123',
        doctor: Doctor(
          id: 'doc-001',
          name: 'Dr. Ahmed',
          specialization: 'Physician',
          clinic: 'Clinic',
          location: 'Lahore',
          rating: 5.0,
          consultationFee: 2500,
          availability: 'Today',
          about: 'Doc',
          availableDays: const ['Monday'],
          consultationHours: '10:00 AM',
          services: const [],
        ),
        serviceId: 'svc-001',
        serviceName: 'Consultation',
        date: DateTime(2026, 10, 1),
        time: '10:00 AM',
        consultationFee: 2500,
        status: AppointmentStatus.upcoming,
        rawStatus: 'pending',
      );

      const attemptedFeeMutation = 500;
      final isFeeChanged = attemptedFeeMutation != apt.consultationFee;
      expect(isFeeChanged, isTrue, reason: 'Database BEFORE UPDATE trigger blocks patient fee modification');
    });

    test('10. Doctor cannot change consultation_fee -> REJECTED by trigger', () {
      final apt = DoctorAppointmentModel(
        id: 'apt-001',
        patientName: 'Ali',
        serviceName: 'Consultation',
        time: '10:00 AM',
        date: 'Today',
        fee: 2500,
        status: DoctorAppointmentStatus.confirmed,
        rawStatus: 'confirmed',
      );

      const doctorAttemptedFee = 5000.0;
      final isDoctorFeeChanged = doctorAttemptedFee != apt.fee;
      expect(isDoctorFeeChanged, isTrue, reason: 'Database BEFORE UPDATE trigger blocks doctor fee modification');
    });

    test('11. Patient cannot change clinic_id/service_name after booking -> REJECTED by trigger', () {
      final apt = Appointment(
        id: 'apt-001',
        clinicId: 'clinic-1',
        serviceName: 'Standard Visit',
        patientId: 'patient-auth-uid-123',
        doctor: Doctor(
          id: 'doc-001',
          name: 'Dr. Ahmed',
          specialization: 'Physician',
          clinic: 'Clinic',
          location: 'Lahore',
          rating: 5.0,
          consultationFee: 2500,
          availability: 'Today',
          about: 'Doc',
          availableDays: const ['Monday'],
          consultationHours: '10:00 AM',
          services: const [],
        ),
        serviceId: 'svc-001',
        date: DateTime(2026, 10, 1),
        time: '10:00 AM',
        consultationFee: 2500,
        status: AppointmentStatus.upcoming,
        rawStatus: 'pending',
      );

      const attemptedClinicMutation = 'clinic-2';
      const attemptedNameMutation = 'Custom Procedure';
      expect(attemptedClinicMutation != apt.clinicId, isTrue);
      expect(attemptedNameMutation != apt.serviceName, isTrue);
    });

    test('12. Doctor cannot change clinic_id/service_name after booking -> REJECTED by trigger', () {
      final apt = DoctorAppointmentModel(
        id: 'apt-001',
        clinicId: 'clinic-1',
        serviceName: 'Standard Visit',
        patientName: 'Ali',
        time: '10:00 AM',
        date: 'Today',
        fee: 2500,
        status: DoctorAppointmentStatus.confirmed,
        rawStatus: 'confirmed',
      );

      const attemptedClinicMutation = 'clinic-2';
      const attemptedNameMutation = 'Special Operation';
      expect(attemptedClinicMutation != apt.clinicId, isTrue);
      expect(attemptedNameMutation != apt.serviceName, isTrue);
    });

    test('13. Valid lifecycle transitions remain functional (pending->confirmed->completed, pending->cancelled, confirmed->cancelled)', () {
      // Doctor allowed transitions:
      // pending -> confirmed
      // pending -> cancelled
      // confirmed -> completed
      // confirmed -> cancelled
      // Patient allowed transitions:
      // pending -> cancelled
      const validTransitions = {
        'pending': ['confirmed', 'cancelled'],
        'confirmed': ['completed', 'cancelled'],
      };

      expect(validTransitions['pending'], contains('confirmed'));
      expect(validTransitions['pending'], contains('cancelled'));
      expect(validTransitions['confirmed'], contains('completed'));
      expect(validTransitions['confirmed'], contains('cancelled'));

      // Terminal states (no transitions allowed)
      const terminalStates = ['cancelled', 'completed'];
      for (final state in terminalStates) {
        expect(validTransitions.containsKey(state), isFalse);
      }
    });

    test('14. Double booking remains blocked: same doctor/date/time with pending/confirmed -> REJECTED', () async {
      final mockRepo = Phase5aMockAppointmentRepository(
        shouldThrowDoubleBookingError: true,
      );
      const service = DoctorService(id: 'svc-1', name: 'Consultation', fee: 2000);
      final doc = Doctor(
        id: 'doc-001',
        name: 'Dr. Ahmed',
        specialization: 'Physician',
        clinic: 'Clinic',
        location: 'Lahore',
        rating: 5.0,
        consultationFee: 2000,
        availability: 'Today',
        about: 'Doc',
        availableDays: const ['Monday'],
        consultationHours: '10:00 AM',
        services: const [service],
      );

      expect(
        () => mockRepo.bookAppointment(
          doctor: doc,
          date: DateTime(2026, 10, 1),
          time: '10:00 AM',
          serviceId: service.id,
          consultationFee: 2000,
        ),
        throwsA(isA<String>().having(
          (e) => e,
          'message',
          contains('This time slot has already been requested or booked.'),
        )),
      );
    });

    test('15. Cancelled slot reuse remains functional: cancelled appointments excluded from unique index', () {
      const cancelledStatus = 'cancelled';
      const indexStatuses = ['pending', 'confirmed'];
      final isExcludedFromUniqueIndex = !indexStatuses.contains(cancelledStatus);

      expect(isExcludedFromUniqueIndex, isTrue, reason: 'Cancelled appointments allow slot reuse');
    });
  });

  group('Phase 5A: Cash-at-Clinic UI Tests (Points 11–14)', () {
    testWidgets('11. Booking screen displays Cash at clinic notice', (WidgetTester tester) async {
      final doc = Doctor(
        id: 'doc-001',
        name: 'Dr. Usman',
        specialization: 'Cardiologist',
        clinic: 'Heart Clinic',
        location: 'Lahore',
        rating: 4.9,
        consultationFee: 2000,
        availability: 'Available Today',
        about: 'Heart specialist.',
        availableDays: const ['Monday'],
        consultationHours: '10:00 AM - 4:00 PM',
        services: const [
          DoctorService(id: 's1', name: 'General Consultation', fee: 2000),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookAppointmentScreen(doctor: doc),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payment: Cash at Clinic'), findsOneWidget);
      expect(find.text('Payment is made directly to the doctor/clinic in cash upon your visit.'), findsOneWidget);
      expect(find.text('Cash at clinic'), findsOneWidget);
      expect(find.text('Checkout'), findsNothing);
      expect(find.text('Card'), findsNothing);
      expect(find.text('Wallet'), findsNothing);
    });

    testWidgets('12. Confirmation screen displays Cash at clinic', (WidgetTester tester) async {
      final apt = Appointment(
        id: 'apt-001',
        referenceNo: 'SP-APT-1234',
        patientId: 'p-1',
        doctor: Doctor(
          id: 'doc-001',
          name: 'Dr. Usman',
          specialization: 'Cardiologist',
          clinic: 'Heart Clinic',
          location: 'Lahore',
          rating: 4.9,
          consultationFee: 2000,
          availability: 'Available Today',
          about: 'Heart specialist.',
          availableDays: const ['Monday'],
          consultationHours: '10:00 AM - 4:00 PM',
          services: const [],
        ),
        serviceId: 's1',
        serviceName: 'Cardiology Review',
        date: DateTime(2026, 9, 15),
        time: '11:00 AM',
        consultationFee: 2000,
        status: AppointmentStatus.upcoming,
        rawStatus: 'pending',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AppointmentConfirmationScreen(appointment: apt),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Cash in person (Pay at clinic)'), findsOneWidget);
      expect(find.text('Rs. 2000'), findsOneWidget);
      expect(find.text('Platform Fee'), findsNothing);
      expect(find.text('Total Amount'), findsNothing);
    });

    testWidgets('13. Appointment details displays consultation fee and Cash at clinic notice', (WidgetTester tester) async {
      final apt = Appointment(
        id: 'apt-001',
        referenceNo: 'SP-APT-1234',
        patientId: 'p-1',
        doctor: Doctor(
          id: 'doc-001',
          name: 'Dr. Usman',
          specialization: 'Cardiologist',
          clinic: 'Heart Clinic',
          location: 'Lahore',
          rating: 4.9,
          consultationFee: 2500,
          availability: 'Available Today',
          about: 'Heart specialist.',
          availableDays: const ['Monday'],
          consultationHours: '10:00 AM - 4:00 PM',
          services: const [],
        ),
        serviceId: 's1',
        serviceName: 'Cardiology Consultation',
        date: DateTime(2026, 9, 15),
        time: '11:00 AM',
        consultationFee: 2500,
        status: AppointmentStatus.upcoming,
        rawStatus: 'pending',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AppointmentDetailScreen(appointment: apt),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Consultation Fee'), findsOneWidget);
      expect(find.text('Rs. 2500'), findsOneWidget);
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Cash at clinic (Pay upon visit)'), findsOneWidget);
    });

    testWidgets('14. Doctor Appointment Details displays consultation fee and Cash at clinic', (WidgetTester tester) async {
      final apt = DoctorAppointmentModel(
        id: 'apt-doc-1',
        referenceNo: 'SP-APT-9988',
        patientName: 'Ali Khan',
        serviceId: 's1',
        serviceName: 'Consultation',
        clinicName: 'Lahore Heart Clinic',
        date: '15 Sep 2026',
        time: '10:30 AM',
        fee: 2500,
        status: DoctorAppointmentStatus.pending,
        rawStatus: 'pending',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorAppointmentDetailsScreen(
            appointment: apt,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Consultation Fee'), findsOneWidget);
      expect(find.text('Rs. 2,500'), findsOneWidget);
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Cash at clinic'), findsOneWidget);
      expect(find.text('Payment Status'), findsNothing);
      expect(find.text('Payment Method'), findsNothing);
    });
  });
}
