import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/doctor_model.dart';
import '../models/appointment_model.dart';

/// Repository responsible for appointment operations and doctor discovery backed by Supabase.
///
/// All mutations and queries for patient appointments are strictly scoped to the
/// authenticated user's ID (`Supabase.instance.client.auth.currentUser?.id`).
class AppointmentRepository extends ChangeNotifier {
  final SupabaseClient? _clientOverride;

  AppointmentRepository({SupabaseClient? client})
      : _clientOverride = client;

  static final AppointmentRepository instance = AppointmentRepository();

  SupabaseClient get _client {
    final override = _clientOverride;
    if (override != null) return override;
    return Supabase.instance.client;
  }

  /// Current authenticated user ID.
  String? get currentUserId {
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

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

  /// Formats date to 'YYYY-MM-DD' for SQL queries.
  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Fetches published doctors from Supabase with clinics, services, and availability.
  Future<List<Doctor>> getDoctors({
    String? specialty,
    String? searchQuery,
  }) async {
    try {
      var query = _client.from('doctor_profiles').select('''
        doctor_id,
        specialization,
        qualifications,
        experience_years,
        bio,
        rating,
        total_reviews,
        is_published,
        profiles!doctor_id (
          id,
          full_name,
          email,
          profile_photo_url
        ),
        clinics (
          id,
          name,
          address,
          city,
          phone,
          description,
          logo_url,
          is_active
        ),
        clinic_services (
          id,
          name,
          fee,
          is_active
        ),
        doctor_availability (
          id,
          day_of_week,
          start_time,
          end_time,
          is_available
        )
      ''').eq('is_published', true);

      if (specialty != null &&
          specialty.isNotEmpty &&
          specialty.toLowerCase() != 'all') {
        query = query.eq('specialization', specialty);
      }

      final response = await query;
      final List<Doctor> doctors = (response as List).map((item) {
        return Doctor.fromMap(Map<String, dynamic>.from(item as Map));
      }).toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        return doctors.where((d) {
          return d.name.toLowerCase().contains(q) ||
              d.specialization.toLowerCase().contains(q) ||
              d.clinic.toLowerCase().contains(q) ||
              d.location.toLowerCase().contains(q);
        }).toList();
      }

      return doctors;
    } catch (e) {
      debugPrint('AppointmentRepository: Error fetching doctors: $e');
      throw 'Unable to load doctors. Please try again.';
    }
  }

  /// Fetches appointments for the currently authenticated patient from Supabase.
  Future<List<Appointment>> getPatientAppointments() async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      _appointments.clear();
      notifyListeners();
      return [];
    }

    try {
      final response = await _client.from('appointments').select('''
        id,
        reference_no,
        patient_id,
        doctor_id,
        clinic_id,
        service_id,
        service_name,
        appointment_date,
        appointment_time,
        consultation_fee,
        platform_fee,
        total_amount,
        payment_status,
        payment_method,
        status,
        cancellation_reason,
        created_at,
        profiles!doctor_id (
          id,
          full_name,
          profile_photo_url,
          doctor_profiles (
            specialization,
            qualifications,
            experience_years,
            bio,
            rating,
            total_reviews
          ),
          clinics (
            id,
            name,
            address,
            city
          )
        )
      ''').eq('patient_id', userId).order('appointment_date', ascending: false).order('created_at', ascending: false);

      final List<Appointment> loaded = (response as List).map((item) {
        final itemMap = Map<String, dynamic>.from(item as Map);
        // Reshape nested doctor profiles
        final doctorProfileMap = itemMap['profiles'] is Map ? Map<String, dynamic>.from(itemMap['profiles'] as Map) : <String, dynamic>{};
        final docProf = doctorProfileMap['doctor_profiles'] is List && (doctorProfileMap['doctor_profiles'] as List).isNotEmpty
            ? (doctorProfileMap['doctor_profiles'] as List).first as Map
            : (doctorProfileMap['doctor_profiles'] is Map ? doctorProfileMap['doctor_profiles'] as Map : null);

        final clinicProf = doctorProfileMap['clinics'] is List && (doctorProfileMap['clinics'] as List).isNotEmpty
            ? (doctorProfileMap['clinics'] as List).first as Map
            : (doctorProfileMap['clinics'] is Map ? doctorProfileMap['clinics'] as Map : null);

        final doctorMap = {
          'id': itemMap['doctor_id'],
          'doctor_id': itemMap['doctor_id'],
          'name': doctorProfileMap['full_name'] ?? 'Doctor',
          'full_name': doctorProfileMap['full_name'] ?? 'Doctor',
          'photo_url': doctorProfileMap['profile_photo_url'],
          'specialization': docProf?['specialization'] ?? 'General Physician',
          'qualifications': docProf?['qualifications'] ?? 'MBBS',
          'experience_years': docProf?['experience_years'] ?? '1 year',
          'bio': docProf?['bio'] ?? '',
          'rating': docProf?['rating'] ?? 5.0,
          'total_reviews': docProf?['total_reviews'] ?? 0,
          'clinic': clinicProf?['name'] ?? 'SehatPass Partner Clinic',
          'location': clinicProf?['city'] ?? clinicProf?['address'] ?? 'Lahore',
          'clinic_id': clinicProf?['id'] ?? itemMap['clinic_id'],
          'consultation_fee': itemMap['consultation_fee'] ?? 1500,
        };

        itemMap['doctor'] = doctorMap;
        return Appointment.fromMap(itemMap);
      }).toList();

      _appointments.clear();
      _appointments.addAll(loaded);
      notifyListeners();
      return _appointments;
    } catch (e) {
      debugPrint('AppointmentRepository: Error fetching patient appointments: $e');
      throw 'Unable to load appointments. Please check your connection and try again.';
    }
  }

  /// Books a new appointment with double-booking prevention.
  ///
  /// Concurrency Strategy:
  /// 1. UX availability pre-check: Query active bookings (`pending` or `confirmed`) for the target doctor, date, and time.
  /// 2. Database-side concurrency protection: Postgres conditional unique index / constraint violation (`23505`) is caught and mapped to a friendly collision error.
  Future<Appointment> bookAppointment({
    required Doctor doctor,
    required DateTime date,
    required String time,
    required int consultationFee,
    int platformFee = 100,
    String? clinicId,
    String? serviceId,
    String? serviceName,
    String paymentMethod = 'card',
  }) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw 'Please sign in to book an appointment.';
    }

    final dateStr = _formatDate(date);

    // 1. UX Pre-check for conflicting active booking
    try {
      final conflictCheck = await _client
          .from('appointments')
          .select('id, status')
          .eq('doctor_id', doctor.id)
          .eq('appointment_date', dateStr)
          .eq('appointment_time', time)
          .inFilter('status', ['pending', 'confirmed']);

      if ((conflictCheck as List).isNotEmpty) {
        throw 'This time slot has already been booked. Please choose another slot.';
      }
    } on String {
      rethrow;
    } catch (e) {
      debugPrint('AppointmentRepository: Availability pre-check notice: $e');
      // If error was explicit string throw above, rethrow
      if (e is String) rethrow;
    }

    // 2. Insert into authoritative appointments table
    final refNo = 'SP-APT-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final payload = {
      'reference_no': refNo,
      'patient_id': userId,
      'doctor_id': doctor.id,
      if (clinicId != null || doctor.clinicId != null)
        'clinic_id': clinicId ?? doctor.clinicId,
      'service_id': ?serviceId,
      'service_name': serviceName ??
          (doctor.services.isNotEmpty
              ? doctor.services.first.name
              : 'General Consultation'),
      'appointment_date': dateStr,
      'appointment_time': time,
      'consultation_fee': consultationFee,
      'platform_fee': platformFee,
      'total_amount': consultationFee + platformFee,
      'payment_status': 'paid',
      'payment_method': paymentMethod,
      'status': 'pending',
    };

    try {
      final response = await _client
          .from('appointments')
          .insert(payload)
          .select()
          .single();

      final responseMap = Map<String, dynamic>.from(response as Map);
      responseMap['doctor'] = doctor;

      final newAppointment = Appointment.fromMap(responseMap);
      _appointments.insert(0, newAppointment);
      notifyListeners();
      return newAppointment;
    } on PostgrestException catch (e) {
      debugPrint('AppointmentRepository: PostgrestException on booking: ${e.code} - ${e.message}');
      if (e.code == '23505' ||
          e.message.toLowerCase().contains('unique') ||
          e.message.toLowerCase().contains('duplicate')) {
        throw 'This time slot was just booked by another patient. Please choose another slot.';
      }
      throw 'Unable to complete appointment booking. Please try again.';
    } catch (e) {
      debugPrint('AppointmentRepository: Booking error: $e');
      if (e is String) rethrow;
      throw 'Unable to book appointment. Please check your connection and try again.';
    }
  }

  /// Cancels an existing appointment. Scoped to the authenticated patient.
  Future<void> cancelAppointment({
    required String appointmentId,
    String? reason,
  }) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw 'Please sign in to manage appointments.';
    }

    try {
      await _client
          .from('appointments')
          .update({
            'status': 'cancelled',
            'cancellation_reason': reason ?? 'Cancelled by patient',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', appointmentId)
          .eq('patient_id', userId);

      final index = _appointments.indexWhere((a) => a.id == appointmentId);
      if (index != -1) {
        _appointments[index] = _appointments[index].copyWith(
          status: AppointmentStatus.cancelled,
          rawStatus: 'cancelled',
          cancellationReason: reason ?? 'Cancelled by patient',
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('AppointmentRepository: Cancellation error: $e');
      throw 'Unable to cancel appointment. Please try again.';
    }
  }

  /// Internal / local add helper for tests.
  void addAppointment(Appointment appointment) {
    _appointments.insert(0, appointment);
    notifyListeners();
  }

  /// Generate client-side fallback ID if required.
  String generateId() {
    return 'SP-APT-${(_appointments.length + 1).toString().padLeft(4, '0')}';
  }
}

/// Compatibility bridge for doctor listing queries.
class DoctorRepository {
  DoctorRepository._();

  static Future<List<Doctor>> getDoctors({
    String? specialty,
    String? searchQuery,
  }) =>
      AppointmentRepository.instance.getDoctors(
        specialty: specialty,
        searchQuery: searchQuery,
      );

  static List<Doctor> filterBySpecialty(List<Doctor> doctors, String specialty) {
    if (specialty == 'All') return doctors;
    return doctors.where((d) => d.specialization == specialty).toList();
  }

  static List<Doctor> search(List<Doctor> doctors, String query) {
    final q = query.toLowerCase();
    return doctors.where((d) =>
        d.name.toLowerCase().contains(q) ||
        d.specialization.toLowerCase().contains(q) ||
        d.clinic.toLowerCase().contains(q) ||
        d.location.toLowerCase().contains(q)).toList();
  }
}
