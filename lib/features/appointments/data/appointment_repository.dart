import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/doctor_model.dart';
import '../models/appointment_model.dart';

/// Repository responsible for appointment operations and doctor discovery backed by Supabase.
///
/// All mutations and queries for patient appointments are strictly scoped to the
/// authenticated user's ID (`Supabase.instance.client.auth.currentUser?.id`).
/// Payment is Cash at Clinic only (no online payments, platform fees, or payment processing).
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
        photo_url,
        profiles!doctor_id (
          id,
          full_name,
          email,
          avatar_url,
          profile_photo_url
        )
      ''').eq('is_published', true);

      if (specialty != null &&
          specialty.isNotEmpty &&
          specialty.toLowerCase() != 'all') {
        query = query.eq('specialization', specialty);
      }

      final response = await query;
      final rawList = response as List;
      if (rawList.isEmpty) {
        return [];
      }

      final doctorIds = rawList
          .map((item) => (item as Map)['doctor_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      // Fetch clinics, clinic_services, and doctor_availability in parallel
      final relatedResults = await Future.wait([
        _client.from('clinics').select('id, doctor_id, name, address, city, logo_url, is_active').inFilter('doctor_id', doctorIds).eq('is_active', true),
        _client.from('clinic_services').select().inFilter('doctor_id', doctorIds).eq('is_active', true),
        _client.from('doctor_availability').select().inFilter('doctor_id', doctorIds).eq('is_available', true),
      ]);

      final clinicsList = (relatedResults[0] as List).cast<Map<String, dynamic>>();
      final servicesList = (relatedResults[1] as List).cast<Map<String, dynamic>>();
      final availList = (relatedResults[2] as List).cast<Map<String, dynamic>>();

      final Map<String, List<Map<String, dynamic>>> clinicsByDoctor = {};
      for (final c in clinicsList) {
        final dId = c['doctor_id']?.toString() ?? '';
        clinicsByDoctor.putIfAbsent(dId, () => []).add(c);
      }

      final Map<String, List<Map<String, dynamic>>> servicesByDoctor = {};
      for (final s in servicesList) {
        final dId = s['doctor_id']?.toString() ?? '';
        servicesByDoctor.putIfAbsent(dId, () => []).add(s);
      }

      final Map<String, List<Map<String, dynamic>>> availByDoctor = {};
      for (final a in availList) {
        final dId = a['doctor_id']?.toString() ?? '';
        availByDoctor.putIfAbsent(dId, () => []).add(a);
      }

      final List<Doctor> doctors = rawList.map((item) {
        final itemMap = Map<String, dynamic>.from(item as Map);
        final dId = itemMap['doctor_id']?.toString() ?? '';
        itemMap['clinics'] = clinicsByDoctor[dId] ?? [];
        itemMap['clinic_services'] = servicesByDoctor[dId] ?? [];
        itemMap['doctor_availability'] = availByDoctor[dId] ?? [];
        return Doctor.fromMap(itemMap);
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

  /// Fetches published availability rows for a specific doctor and clinic from `public.doctor_availability`.
  Future<List<Map<String, dynamic>>> getDoctorAvailability({
    required String doctorId,
    String? clinicId,
  }) async {
    try {
      var query = _client
          .from('doctor_availability')
          .select()
          .eq('doctor_id', doctorId)
          .eq('is_available', true);

      if (clinicId != null && clinicId.isNotEmpty) {
        query = query.eq('clinic_id', clinicId);
      }

      final response = await query.order('day_of_week');
      final list = (response as List).cast<Map<String, dynamic>>();
      return list;
    } catch (e) {
      debugPrint('AppointmentRepository: Error fetching availability: $e');
      throw 'Unable to load doctor availability.';
    }
  }

  /// Returns list of already booked appointment times ('10:00 AM', etc.) for a doctor on a specific date.
  Future<List<String>> getBookedSlots({
    required String doctorId,
    required DateTime date,
  }) async {
    try {
      final dateStr = _formatDate(date);
      final response = await _client
          .from('appointments')
          .select('appointment_time')
          .eq('doctor_id', doctorId)
          .eq('appointment_date', dateStr)
          .inFilter('status', ['pending', 'confirmed']);

      final list = response as List;
      return list
          .map((item) => (item as Map)['appointment_time']?.toString() ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('AppointmentRepository: Error fetching booked slots: $e');
      return [];
    }
  }

  /// Fetches patient appointments from Supabase for the current authenticated user.
  Future<List<Appointment>> getPatientAppointments() => getAppointments();

  /// Fetches patient appointments from Supabase for the current authenticated user.
  Future<List<Appointment>> getAppointments({bool forceRefresh = false}) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      _appointments.clear();
      notifyListeners();
      return [];
    }

    if (_appointments.isNotEmpty && !forceRefresh) {
      return _appointments;
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
        status,
        cancellation_reason,
        created_at,
        profiles!doctor_id (
          id,
          full_name,
          avatar_url,
          profile_photo_url,
          doctor_profiles (
            specialization,
            qualifications,
            experience_years,
            bio,
            rating,
            total_reviews,
            photo_url
          ),
          clinics (
            id,
            name,
            address,
            city,
            logo_url
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
          'name': doctorProfileMap['full_name'] ?? '',
          'full_name': doctorProfileMap['full_name'] ?? '',
          'photo_url': doctorProfileMap['avatar_url'] ??
              doctorProfileMap['profile_photo_url'] ??
              docProf?['photo_url'],
          'clinic_logo_url': clinicProf?['logo_url'],
          'specialization': docProf?['specialization'] ?? '',
          'qualifications': docProf?['qualifications'] ?? '',
          'experience_years': docProf?['experience_years'] ?? '',
          'bio': docProf?['bio'] ?? '',
          'rating': docProf?['rating'] ?? 0.0,
          'total_reviews': docProf?['total_reviews'] ?? 0,
          'clinic': clinicProf?['name'] ?? '',
          'location': clinicProf?['city'] ?? clinicProf?['address'] ?? '',
          'clinic_id': clinicProf?['id'] ?? itemMap['clinic_id'],
          'consultation_fee': itemMap['consultation_fee'] ?? 0,
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

  /// Books a new appointment with authoritative database service-fee enforcement and double-booking prevention.
  ///
  /// Concurrency Strategy:
  /// 1. UX availability pre-check: Query active bookings (`pending` or `confirmed`) for the target doctor, date, and time.
  /// 2. Database-side concurrency protection: Postgres partial unique index `idx_appointments_no_double_booking`
  ///    enforces no double-booking at DB level.
  /// 3. Authoritative Service Fee: Database trigger `trg_enforce_appointment_service_fee` authoritatively sets
  ///    `consultation_fee` from `clinic_services.fee` at insert time.
  Future<Appointment> bookAppointment({
    required Doctor doctor,
    required DateTime date,
    required String time,
    required int consultationFee,
    String? clinicId,
    String? serviceId,
    String? serviceName,
  }) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw 'Please sign in to request an appointment.';
    }

    if (serviceId == null || serviceId.isEmpty) {
      throw 'Please select a valid service for this appointment.';
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
        throw 'This time slot has already been requested or booked. Please choose another slot.';
      }
    } on String {
      rethrow;
    } catch (e) {
      debugPrint('AppointmentRepository: Availability pre-check notice: $e');
      if (e is String) rethrow;
    }

    // 2. Insert into authoritative appointments table
    final refNo = 'SP-APT-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final payload = {
      'reference_no': refNo,
      'patient_id': userId,
      'doctor_id': doctor.id,
      'clinic_id': ?(clinicId ?? doctor.clinicId),
      'service_id': serviceId,
      'service_name': serviceName ??
          (doctor.services.isNotEmpty
              ? doctor.services.first.name
              : 'General Consultation'),
      'appointment_date': dateStr,
      'appointment_time': time,
      'consultation_fee': consultationFee,
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
