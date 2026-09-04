import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/doctor_profile_model.dart';
import '../models/clinic_model.dart';
import '../models/clinic_service_model.dart';
import '../models/doctor_availability_model.dart';
import '../models/doctor_onboarding_data.dart';
import '../models/doctor_appointment_model.dart';
import '../models/doctor_patient_model.dart';
import '../models/doctor_consultation_note_model.dart';
import '../../home/models/patient_medicine_model.dart';
import '../../home/models/medical_report_model.dart';

/// Repository responsible for Doctor profile, clinic, services, and availability
/// persistence backed by Supabase with Row Level Security (RLS).
class DoctorRepository {
  final SupabaseClient? _clientOverride;

  DoctorRepository({SupabaseClient? client}) : _clientOverride = client;

  static final DoctorRepository instance = DoctorRepository();

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

  /// Current authenticated user.
  User? get currentUser {
    try {
      return _client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Fetches the doctor profile from `public.profiles` and `public.doctor_profiles`.
  Future<DoctorProfileModel?> getDoctorProfile({String? doctorId}) async {
    final uid = doctorId ?? currentUserId;
    if (uid == null || uid.isEmpty) return null;

    try {
      final results = await Future.wait([
        _client.from('profiles').select().eq('id', uid).maybeSingle(),
        _client.from('doctor_profiles').select().eq('doctor_id', uid).maybeSingle(),
      ]);

      final profileRow = results[0];
      final docProfileRow = results[1];

      if (profileRow == null && docProfileRow == null) {
        return null;
      }

      final fullName = profileRow?['full_name']?.toString().trim() ?? '';
      final photoUrl = profileRow?['profile_photo_url']?.toString();

      if (docProfileRow != null) {
        return DoctorProfileModel.fromMap(
          docProfileRow,
          fullName: fullName.isNotEmpty ? fullName : null,
          profilePhotoUrl: photoUrl,
        );
      }

      return DoctorProfileModel(
        doctorId: uid,
        fullName: fullName,
        photoUrl: photoUrl,
      );
    } catch (e) {
      debugPrint('DoctorRepository: Error fetching doctor profile: $e');
      throw _getFriendlyErrorMessage(e, 'Unable to load doctor profile.');
    }
  }

  /// Checks whether the doctor has completed onboarding and published their profile in `public.doctor_profiles`.
  /// Returns `true` if a record exists with `is_published == true`.
  /// Returns `false` if no record exists or `is_published == false`.
  /// Throws a friendly error string if database query fails.
  Future<bool> isDoctorProfilePublished({String? doctorId}) async {
    final uid = doctorId ?? currentUserId;
    if (uid == null || uid.isEmpty) return false;

    try {
      final response = await _client
          .from('doctor_profiles')
          .select('is_published')
          .eq('doctor_id', uid)
          .maybeSingle();

      if (response == null) return false;
      return response['is_published'] == true;
    } catch (e) {
      debugPrint('DoctorRepository: Error checking doctor published status: $e');
      throw _getFriendlyErrorMessage(e, 'Unable to verify doctor profile status.');
    }
  }

  /// Saves doctor profile to `public.profiles` and `public.doctor_profiles`.
  Future<DoctorProfileModel> saveDoctorProfile({
    required String doctorId,
    required DoctorProfileModel profile,
  }) async {
    try {
      // 1. Update public.profiles (full_name only, preserve role & id)
      if (profile.fullName.trim().isNotEmpty) {
        await _client.from('profiles').update({
          'full_name': profile.fullName.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', doctorId);
      }

      // 2. Upsert public.doctor_profiles
      final doctorPayload = <String, dynamic>{
        'doctor_id': doctorId,
        'specialization': profile.specialization.trim(),
        'qualifications': profile.qualifications.trim(),
        'experience_years': profile.experienceYears.trim(),
        'bio': profile.bio.trim(),
        'is_published': profile.isPublished,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('doctor_profiles')
          .upsert(doctorPayload, onConflict: 'doctor_id')
          .select()
          .single();

      return DoctorProfileModel.fromMap(
        response,
        fullName: profile.fullName,
        profilePhotoUrl: profile.photoUrl,
      );
    } catch (e) {
      debugPrint('DoctorRepository: Error saving doctor profile: $e');
      throw _getFriendlyErrorMessage(e, 'Unable to save doctor profile.');
    }
  }

  /// Fetches the primary clinic for the given doctor.
  Future<ClinicModel?> getDoctorClinic({String? doctorId}) async {
    final uid = doctorId ?? currentUserId;
    if (uid == null || uid.isEmpty) return null;

    try {
      final response = await _client
          .from('clinics')
          .select()
          .eq('doctor_id', uid)
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return ClinicModel.fromMap(response);
    } catch (e) {
      debugPrint('DoctorRepository: Error fetching clinic: $e');
      throw _getFriendlyErrorMessage(e, 'Unable to load clinic details.');
    }
  }

  /// Saves or updates the doctor's primary clinic in `public.clinics`.
  /// Ensures idempotency so repeat calls update the primary clinic without creating duplicates.
  Future<ClinicModel> saveDoctorClinic({
    required String doctorId,
    required ClinicModel clinic,
  }) async {
    try {
      String? targetClinicId = clinic.id;

      // If no valid UUID clinic id is present in model, look up existing clinic row
      final isValidUuid = targetClinicId != null &&
          RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
              .hasMatch(targetClinicId);

      if (!isValidUuid) {
        final existing = await _client
            .from('clinics')
            .select('id')
            .eq('doctor_id', doctorId)
            .order('created_at', ascending: true)
            .limit(1)
            .maybeSingle();

        if (existing != null) {
          targetClinicId = existing['id']?.toString();
        }
      }

      final payload = <String, dynamic>{
        'doctor_id': doctorId,
        'name': clinic.name.trim(),
        'address': clinic.address.trim(),
        'city': clinic.city.trim(),
        'phone': clinic.phone.trim(),
        'description': clinic.description.trim(),
        if (clinic.logoUrl != null) 'logo_url': clinic.logoUrl,
        'is_active': clinic.isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

      Map<String, dynamic> response;
      if (targetClinicId != null && targetClinicId.isNotEmpty) {
        response = await _client
            .from('clinics')
            .update(payload)
            .eq('id', targetClinicId)
            .eq('doctor_id', doctorId)
            .select()
            .single();
      } else {
        response = await _client.from('clinics').insert(payload).select().single();
      }

      return ClinicModel.fromMap(response);
    } catch (e) {
      debugPrint('DoctorRepository: Error saving clinic: $e');
      throw _getFriendlyErrorMessage(e, 'Unable to save clinic details.');
    }
  }

  /// Fetches services for a clinic owned by the doctor.
  Future<List<ClinicServiceModel>> getClinicServices({
    required String clinicId,
    required String doctorId,
  }) async {
    try {
      final response = await _client
          .from('clinic_services')
          .select()
          .eq('clinic_id', clinicId)
          .eq('doctor_id', doctorId)
          .eq('is_active', true)
          .order('created_at', ascending: true);

      final list = (response as List).cast<Map<String, dynamic>>();
      return list.map((m) => ClinicServiceModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('DoctorRepository: Error fetching clinic services: $e');
      throw _getFriendlyErrorMessage(e, 'Unable to load clinic services.');
    }
  }

  /// Reconciles and saves clinic services in `public.clinic_services`.
  /// Deletes existing services for the specified clinic and inserts the active list.
  Future<List<ClinicServiceModel>> saveClinicServices({
    required String clinicId,
    required String doctorId,
    required List<ClinicServiceModel> services,
  }) async {
    if (services.isEmpty) {
      throw 'Please provide at least one clinic service.';
    }

    try {
      // 1. Clear previous services for idempotency
      await _client
          .from('clinic_services')
          .delete()
          .eq('clinic_id', clinicId)
          .eq('doctor_id', doctorId);

      // 2. Insert new active services
      final rowsToInsert = services.map((s) {
        return {
          'clinic_id': clinicId,
          'doctor_id': doctorId,
          'name': s.name.trim(),
          'fee': s.fee,
          'is_active': true,
        };
      }).toList();

      final response = await _client
          .from('clinic_services')
          .insert(rowsToInsert)
          .select();

      final insertedList = (response as List).cast<Map<String, dynamic>>();
      return insertedList.map((m) => ClinicServiceModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('DoctorRepository: Error saving clinic services: $e');
      throw _getFriendlyErrorMessage(e, 'Unable to save clinic services.');
    }
  }

  /// Fetches doctor availability rows for the authenticated doctor.
  Future<DoctorAvailabilityModel> getDoctorAvailability({
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

      final response = await query;
      final rows = (response as List).cast<Map<String, dynamic>>();
      return DoctorAvailabilityModel.fromDbRows(rows);
    } catch (e) {
      debugPrint('DoctorRepository: Error fetching availability: $e');
      throw _getFriendlyErrorMessage(e, 'Unable to load doctor availability.');
    }
  }

  /// Reconciles and saves doctor availability in `public.doctor_availability`.
  /// Deletes existing availability rows for this doctor and inserts one row per selected day.
  Future<DoctorAvailabilityModel> saveDoctorAvailability({
    required String doctorId,
    String? clinicId,
    required DoctorAvailabilityModel availability,
  }) async {
    if (availability.selectedDays.isEmpty) {
      throw 'Please select at least one available day.';
    }

    try {
      // 1. Clear previous availability rows for this doctor
      await _client
          .from('doctor_availability')
          .delete()
          .eq('doctor_id', doctorId);

      // 2. Insert one row per day
      final rowsToInsert = availability.toInsertRows(
        doctorId: doctorId,
        clinicId: clinicId,
      );

      final response = await _client
          .from('doctor_availability')
          .insert(rowsToInsert)
          .select();

      final insertedRows = (response as List).cast<Map<String, dynamic>>();
      return DoctorAvailabilityModel.fromDbRows(insertedRows);
    } catch (e) {
      debugPrint('DoctorRepository: Error saving availability: $e');
      throw _getFriendlyErrorMessage(e, 'Unable to save doctor availability.');
    }
  }

  /// Full atomic publish pipeline for Doctor onboarding.
  ///
  /// Steps:
  /// 1. Saves profile (profiles.full_name + doctor_profiles with is_published = false)
  /// 2. Saves clinic (public.clinics) and captures generated clinic UUID
  /// 3. Saves services (public.clinic_services) linked to clinic and doctor
  /// 4. Saves availability (public.doctor_availability) linked to clinic and doctor
  /// 5. Marks doctor_profiles.is_published = true only AFTER all preceding steps succeed.
  ///
  /// If any step fails, is_published is NOT set, avoiding partial or broken listings.
  Future<DoctorOnboardingData> publishDoctorProfile({
    required DoctorOnboardingData data,
  }) async {
    final doctorId = currentUserId;
    if (doctorId == null || doctorId.isEmpty) {
      throw 'Doctor session expired. Please log in again to publish your clinic.';
    }

    try {
      // 1. Save doctor profile (draft status)
      final savedProfile = await saveDoctorProfile(
        doctorId: doctorId,
        profile: data.profile.copyWith(isPublished: false),
      );

      // 2. Save clinic and capture authoritative UUID
      final savedClinic = await saveDoctorClinic(
        doctorId: doctorId,
        clinic: data.clinic,
      );

      final clinicId = savedClinic.id;
      if (clinicId == null || clinicId.isEmpty) {
        throw 'Failed to generate clinic identifier. Please try again.';
      }

      // 3. Save services linked to clinic
      final savedServices = await saveClinicServices(
        clinicId: clinicId,
        doctorId: doctorId,
        services: data.services,
      );

      // 4. Save availability linked to clinic
      final savedAvail = await saveDoctorAvailability(
        doctorId: doctorId,
        clinicId: clinicId,
        availability: data.availability,
      );

      // 5. Authoritatively mark published
      await _client
          .from('doctor_profiles')
          .update({
            'is_published': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('doctor_id', doctorId);

      return DoctorOnboardingData(
        profile: savedProfile.copyWith(isPublished: true),
        clinic: savedClinic,
        services: savedServices,
        availability: savedAvail,
        isPublished: true,
      );
    } catch (e) {
      debugPrint('DoctorRepository: Error during publishDoctorProfile: $e');
      if (e is String) rethrow;
      throw _getFriendlyErrorMessage(e, 'Failed to publish clinic. Please check your connection and retry.');
    }
  }

  /// Loads existing draft or published onboarding data for the authenticated doctor,
  /// allowing smooth resumption if onboarding was previously interrupted.
  Future<DoctorOnboardingData> loadExistingOnboardingData() async {
    final doctorId = currentUserId;
    if (doctorId == null || doctorId.isEmpty) {
      return DoctorOnboardingData();
    }

    try {
      final profile = await getDoctorProfile(doctorId: doctorId);
      if (profile == null) {
        return DoctorOnboardingData();
      }

      final clinic = await getDoctorClinic(doctorId: doctorId);
      List<ClinicServiceModel>? services;
      DoctorAvailabilityModel? availability;

      if (clinic?.id != null) {
        final results = await Future.wait([
          getClinicServices(clinicId: clinic!.id!, doctorId: doctorId),
          getDoctorAvailability(doctorId: doctorId, clinicId: clinic.id),
        ]);
        services = results[0] as List<ClinicServiceModel>;
        availability = results[1] as DoctorAvailabilityModel;
      } else {
        availability = await getDoctorAvailability(doctorId: doctorId);
      }

      return DoctorOnboardingData.fromPersistedState(
        profile: profile,
        clinic: clinic,
        services: services,
        availability: availability,
      );
    } catch (e) {
      debugPrint('DoctorRepository: Error resuming onboarding state: $e');
      return DoctorOnboardingData();
    }
  }

  /// Fetches appointments assigned to the authenticated doctor from `public.appointments`.
  /// Scoped strictly to `doctor_id = currentUserId` via RLS and query parameters.
  Future<List<DoctorAppointmentModel>> getDoctorAppointments({
    String? status,
  }) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      return [];
    }

    try {
      var query = _client.from('appointments').select('''
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
        updated_at,
        profiles!patient_id (
          id,
          full_name,
          profile_photo_url
        ),
        clinics (
          id,
          name,
          address,
          city
        )
      ''').eq('doctor_id', uid);

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status.toLowerCase());
      }

      final response = await query
          .order('appointment_date', ascending: false)
          .order('created_at', ascending: false);

      final list = (response as List).cast<Map<String, dynamic>>();
      return list.map((m) => DoctorAppointmentModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('DoctorRepository: Error fetching doctor appointments: $e');
      throw _getFriendlyErrorMessage(
          e, 'Unable to load appointments. Please check your connection.');
    }
  }

  /// Fetches a single appointment by ID, ensuring it belongs to the authenticated doctor.
  Future<DoctorAppointmentModel?> getDoctorAppointmentById(
      String appointmentId) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) return null;

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
        updated_at,
        profiles!patient_id (
          id,
          full_name,
          profile_photo_url
        ),
        clinics (
          id,
          name,
          address,
          city
        )
      ''').eq('id', appointmentId).eq('doctor_id', uid).maybeSingle();

      if (response == null) return null;
      return DoctorAppointmentModel.fromMap(response);
    } catch (e) {
      debugPrint('DoctorRepository: Error fetching appointment by id: $e');
      throw _getFriendlyErrorMessage(e, 'Unable to load appointment details.');
    }
  }

  /// Updates an appointment status strictly for the authenticated doctor.
  /// Validated by the database trigger `trg_validate_appointment_update` and RLS.
  Future<DoctorAppointmentModel> updateAppointmentStatus({
    required String appointmentId,
    required DoctorAppointmentStatus status,
    String? cancellationReason,
  }) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      throw 'Doctor session expired. Please sign in again.';
    }

    final statusStr = status == DoctorAppointmentStatus.confirmed
        ? 'confirmed'
        : (status == DoctorAppointmentStatus.completed
            ? 'completed'
            : (status == DoctorAppointmentStatus.cancelled
                ? 'cancelled'
                : 'pending'));

    final payload = <String, dynamic>{
      'status': statusStr,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (cancellationReason != null) {
      payload['cancellation_reason'] = cancellationReason;
    }

    try {
      final response = await _client
          .from('appointments')
          .update(payload)
          .eq('id', appointmentId)
          .eq('doctor_id', uid)
          .select('''
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
            updated_at,
            profiles!patient_id (
              id,
              full_name,
              profile_photo_url
            ),
            clinics (
              id,
              name,
              address,
              city
            )
          ''')
          .single();

      return DoctorAppointmentModel.fromMap(response);
    } catch (e) {
      debugPrint('DoctorRepository: Error updating appointment status: $e');
      throw _getFriendlyErrorMessage(
          e, 'Unable to update appointment status. Please try again.');
    }
  }

  /// Convenience method for doctor accepting a pending appointment.
  Future<DoctorAppointmentModel> acceptAppointment(String appointmentId) {
    return updateAppointmentStatus(
      appointmentId: appointmentId,
      status: DoctorAppointmentStatus.confirmed,
    );
  }

  /// Convenience method for doctor declining a pending appointment.
  Future<DoctorAppointmentModel> declineAppointment(
    String appointmentId, {
    String? reason,
  }) {
    return updateAppointmentStatus(
      appointmentId: appointmentId,
      status: DoctorAppointmentStatus.cancelled,
      cancellationReason: reason ?? 'Declined by doctor',
    );
  }

  /// Fetches the roster of distinct patients who have authorized appointments
  /// (pending, confirmed, or completed) with the authenticated doctor.
  /// Deduplicates patient records and joins demographic data through RLS.
  Future<List<DoctorPatientModel>> getDoctorPatients() async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) {
      return [];
    }

    try {
      // 1. Fetch authorized appointments for this doctor
      final aptResponse = await _client
          .from('appointments')
          .select('id, patient_id, appointment_date, service_name, status, created_at')
          .eq('doctor_id', uid)
          .inFilter('status', ['pending', 'confirmed', 'completed'])
          .order('appointment_date', ascending: false)
          .order('created_at', ascending: false);

      final aptList = (aptResponse as List).cast<Map<String, dynamic>>();
      if (aptList.isEmpty) {
        return [];
      }

      // Group appointments by patient_id
      final Map<String, List<Map<String, dynamic>>> appointmentsByPatient = {};
      for (final apt in aptList) {
        final pId = apt['patient_id']?.toString() ?? '';
        if (pId.isNotEmpty) {
          appointmentsByPatient.putIfAbsent(pId, () => []).add(apt);
        }
      }

      final uniquePatientIds = appointmentsByPatient.keys.toList();
      if (uniquePatientIds.isEmpty) {
        return [];
      }

      // 2. Fetch profiles and patient_profiles in parallel for these patients
      final results = await Future.wait([
        _client
            .from('profiles')
            .select('id, full_name, profile_photo_url')
            .inFilter('id', uniquePatientIds),
        _client
            .from('patient_profiles')
            .select('patient_id, date_of_birth, gender, blood_group, allergies, medical_conditions')
            .inFilter('patient_id', uniquePatientIds),
      ]);

      final profilesList = (results[0] as List).cast<Map<String, dynamic>>();
      final patientProfilesList = (results[1] as List).cast<Map<String, dynamic>>();

      final Map<String, Map<String, dynamic>> profilesMap = {
        for (final p in profilesList) p['id']?.toString() ?? '': p
      };

      final Map<String, Map<String, dynamic>> patientProfilesMap = {
        for (final pp in patientProfilesList) pp['patient_id']?.toString() ?? '': pp
      };

      // 3. Assemble DoctorPatientModel objects
      final List<DoctorPatientModel> patients = [];
      for (final pId in uniquePatientIds) {
        final pApts = appointmentsByPatient[pId] ?? [];
        final completedApts = pApts
            .where((a) =>
                a['status']?.toString().trim().toLowerCase() == 'completed')
            .toList();

        final latestCompletedApt =
            completedApts.isNotEmpty ? completedApts.first : null;
        DateTime? lastCompletedDate;
        if (latestCompletedApt != null &&
            latestCompletedApt['appointment_date'] != null) {
          lastCompletedDate = DateTime.tryParse(
              latestCompletedApt['appointment_date'].toString());
        }

        final latestAptOverall = pApts.isNotEmpty ? pApts.first : null;

        final combinedMap = <String, dynamic>{
          'id': pId,
          'patient_id': pId,
          if (profilesMap.containsKey(pId)) 'profiles': profilesMap[pId],
          if (patientProfilesMap.containsKey(pId))
            'patient_profiles': patientProfilesMap[pId],
        };

        patients.add(DoctorPatientModel.fromMap(
          combinedMap,
          totalVisits: completedApts.length,
          lastAppointmentDate: lastCompletedDate,
          latestServiceName: latestCompletedApt?['service_name']?.toString() ??
              latestAptOverall?['service_name']?.toString(),
        ));
      }

      // Sort by latest completed visit date descending
      patients.sort((a, b) {
        final aDate = a.lastAppointmentDate;
        final bDate = b.lastAppointmentDate;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      return patients;
    } catch (e) {
      debugPrint('DoctorRepository: Error fetching doctor patients: $e');
      throw _getFriendlyErrorMessage(e, 'Unable to load patients roster.');
    }
  }

  /// Fetches demographic and appointment summary for a specific patient.
  /// Strictly verifies that an authorized appointment exists between the doctor and this patient.
  Future<DoctorPatientModel?> getDoctorPatientDetail(String patientId) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty || patientId.isEmpty) {
      return null;
    }

    try {
      // 1. Verify doctor-patient authorization through appointments
      final aptResponse = await _client
          .from('appointments')
          .select('id, appointment_date, service_name, status, created_at')
          .eq('doctor_id', uid)
          .eq('patient_id', patientId)
          .inFilter('status', ['pending', 'confirmed', 'completed'])
          .order('appointment_date', ascending: false)
          .order('created_at', ascending: false);

      final aptList = (aptResponse as List).cast<Map<String, dynamic>>();
      if (aptList.isEmpty) {
        // Unauthorized or no valid appointment exists
        return null;
      }

      // 2. Fetch profile and patient_profile
      final results = await Future.wait([
        _client
            .from('profiles')
            .select('id, full_name, profile_photo_url')
            .eq('id', patientId)
            .maybeSingle(),
        _client
            .from('patient_profiles')
            .select('patient_id, date_of_birth, gender, blood_group, allergies, medical_conditions')
            .eq('patient_id', patientId)
            .maybeSingle(),
      ]);

      final profileRow = results[0];
      final patientProfileRow = results[1];

      final completedApts = aptList
          .where((a) =>
              a['status']?.toString().trim().toLowerCase() == 'completed')
          .toList();

      final latestCompletedApt =
          completedApts.isNotEmpty ? completedApts.first : null;
      DateTime? lastCompletedDate;
      if (latestCompletedApt != null &&
          latestCompletedApt['appointment_date'] != null) {
        lastCompletedDate = DateTime.tryParse(
            latestCompletedApt['appointment_date'].toString());
      }

      final latestAptOverall = aptList.first;

      final combinedMap = <String, dynamic>{
        'id': patientId,
        'patient_id': patientId,
      };
      if (profileRow != null) {
        combinedMap['profiles'] = profileRow;
      }
      if (patientProfileRow != null) {
        combinedMap['patient_profiles'] = patientProfileRow;
      }

      return DoctorPatientModel.fromMap(
        combinedMap,
        totalVisits: completedApts.length,
        lastAppointmentDate: lastCompletedDate,
        latestServiceName: latestCompletedApt?['service_name']?.toString() ??
            latestAptOverall['service_name']?.toString(),
      );
    } catch (e) {
      debugPrint('DoctorRepository: Error fetching patient detail: $e');
      throw _getFriendlyErrorMessage(e, 'Unable to load patient details.');
    }
  }

  /// Fetches active medications for an assigned patient under a confirmed or completed appointment.
  ///
  /// Scoped to authenticated doctor (`auth.uid()`) and verified against `public.appointments`
  /// before querying `public.patient_medicines`. PostgREST RLS serves as the final security boundary.
  Future<List<PatientMedicineModel>> getDoctorPatientMedicines(String patientId) async {
    final docId = currentUserId;
    if (docId == null || docId.isEmpty) {
      throw 'Authentication required. Please log in as a doctor.';
    }
    if (patientId.isEmpty) {
      return [];
    }

    try {
      // 1. Authorization check: confirmed or completed appointment required
      final aptAuth = await _client
          .from('appointments')
          .select('id')
          .eq('doctor_id', docId)
          .eq('patient_id', patientId)
          .inFilter('status', ['confirmed', 'completed'])
          .limit(1);

      if ((aptAuth as List).isEmpty) {
        // Not authorized for clinical medical data if appointment is only pending/cancelled or missing
        return [];
      }

      // 2. Query active patient medicines
      final response = await _client
          .from('patient_medicines')
          .select()
          .eq('patient_id', patientId)
          .eq('is_active', true)
          .order('created_at', ascending: true);

      return (response as List)
          .map((item) => PatientMedicineModel.fromMap(
              Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('DoctorRepository: Error fetching patient medicines: $e');
      throw _getFriendlyErrorMessage(e, 'Unable to load patient medications.');
    }
  }

  /// Fetches diagnostic reports for an assigned patient under a confirmed or completed appointment.
  ///
  /// Scoped to authenticated doctor (`auth.uid()`) and verified against `public.appointments`
  /// before querying `public.medical_reports`.
  Future<List<MedicalReportModel>> getDoctorPatientReports(String patientId) async {
    final docId = currentUserId;
    if (docId == null || docId.isEmpty) {
      throw 'Authentication required. Please log in as a doctor.';
    }
    if (patientId.isEmpty) {
      return [];
    }

    try {
      // 1. Authorization check: confirmed or completed appointment required
      final aptAuth = await _client
          .from('appointments')
          .select('id')
          .eq('doctor_id', docId)
          .eq('patient_id', patientId)
          .inFilter('status', ['confirmed', 'completed'])
          .limit(1);

      if ((aptAuth as List).isEmpty) {
        return [];
      }

      // 2. Query medical reports metadata
      final response = await _client
          .from('medical_reports')
          .select()
          .eq('patient_id', patientId)
          .order('report_date', ascending: false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => MedicalReportModel.fromMap(
              Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('DoctorRepository: Error fetching patient reports: $e');
      throw _getFriendlyErrorMessage(e, 'Unable to load medical reports.');
    }
  }

  /// Generates a temporary authenticated signed URL to securely view/download a private report file.
  ///
  /// Enforces private bucket access through Supabase Storage RLS. Never constructs or falls back
  /// to unauthenticated public URLs.
  Future<String?> getDoctorReportSignedUrl(
    String storageFilePath, {
    int expiresInSeconds = 3600,
  }) async {
    final docId = currentUserId;
    if (docId == null || docId.isEmpty || storageFilePath.isEmpty) {
      return null;
    }

    // Guard: Prevent arbitrary external URLs or path traversal
    if (storageFilePath.startsWith('http://') ||
        storageFilePath.startsWith('https://') ||
        storageFilePath.contains('..')) {
      debugPrint('DoctorRepository: Invalid storage file path rejected: $storageFilePath');
      return null;
    }

    try {
      final signedUrl = await _client.storage
          .from('medical-reports')
          .createSignedUrl(storageFilePath, expiresInSeconds);
      return signedUrl;
    } catch (e) {
      debugPrint('DoctorRepository: Error generating signed URL for report: $e');
      return null;
    }
  }

  /// Fetches the clinical consultation note for a specific appointment.
  Future<DoctorConsultationNoteModel?> getConsultationNoteForAppointment(
    String appointmentId,
  ) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty || appointmentId.isEmpty) {
      return null;
    }

    try {
      final response = await _client
          .from('doctor_consultation_notes')
          .select()
          .eq('appointment_id', appointmentId)
          .maybeSingle();

      if (response == null) return null;
      return DoctorConsultationNoteModel.fromMap(
          Map<String, dynamic>.from(response as Map));
    } catch (e) {
      debugPrint('DoctorRepository: Error fetching appointment consultation note: $e');
      throw _getFriendlyErrorMessage(
          e, 'Unable to load consultation note.');
    }
  }

  /// Fetches historical consultation notes authored for a patient across all authorized visits.
  Future<List<DoctorConsultationNoteModel>> getPatientConsultationHistory(
    String patientId,
  ) async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty || patientId.isEmpty) {
      return [];
    }

    try {
      final response = await _client
          .from('doctor_consultation_notes')
          .select('''
            id,
            appointment_id,
            doctor_id,
            patient_id,
            diagnosis,
            notes,
            prescriptions,
            created_at,
            profiles!doctor_id (
              id,
              full_name
            ),
            appointments!appointment_id (
              id,
              reference_no,
              appointment_date,
              status
            )
          ''')
          .eq('patient_id', patientId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => DoctorConsultationNoteModel.fromMap(
              Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('DoctorRepository: Error fetching patient consultation history: $e');
      throw _getFriendlyErrorMessage(
          e, 'Unable to load consultation history.');
    }
  }

  /// Saves or updates a consultation note and optionally marks the appointment as completed.
  ///
  /// Enforces tri-party validation and RLS constraints through authenticated Supabase client.
  Future<DoctorConsultationNoteModel> saveConsultationNote({
    required DoctorConsultationNoteModel note,
    bool completeAppointment = false,
  }) async {
    final docId = currentUserId;
    if (docId == null || docId.isEmpty) {
      throw 'Authentication required. Please log in as a doctor.';
    }

    if (note.appointmentId.isEmpty) {
      throw 'Appointment ID is required to save a consultation note.';
    }

    try {
      // 1. Authoritatively fetch and validate appointment
      final aptRow = await _client
          .from('appointments')
          .select('id, doctor_id, patient_id, status')
          .eq('id', note.appointmentId)
          .maybeSingle();

      if (aptRow == null) {
        throw 'Appointment not found. Please refresh and retry.';
      }

      final aptDocId = aptRow['doctor_id']?.toString();
      if (aptDocId != docId) {
        throw 'Access denied. You can only author consultation notes for your assigned appointments.';
      }

      final aptStatus = aptRow['status']?.toString().toLowerCase() ?? '';
      if (aptStatus != 'confirmed' && aptStatus != 'completed') {
        throw 'Consultation notes can only be authored for confirmed or completed appointments (current status: $aptStatus).';
      }

      final resolvedPatientId = (aptRow['patient_id']?.toString().isNotEmpty ?? false)
          ? aptRow['patient_id'].toString()
          : note.patientId;

      // 2. Check if a consultation note already exists for this appointment
      final existingResponse = await _client
          .from('doctor_consultation_notes')
          .select('id, appointment_id, doctor_id, patient_id')
          .eq('appointment_id', note.appointmentId)
          .maybeSingle();

      Map<String, dynamic> response;
      if (existingResponse != null) {
        // UPDATE existing record cleanly without modifying immutable columns (id, doctor_id, patient_id, appointment_id)
        final updatePayload = <String, dynamic>{
          'diagnosis': note.diagnosis?.trim(),
          'notes': note.notes?.trim(),
          'prescriptions': note.prescriptions.map((p) => p.toMap()).toList(),
        };

        response = await _client
            .from('doctor_consultation_notes')
            .update(updatePayload)
            .eq('appointment_id', note.appointmentId)
            .select()
            .single();
      } else {
        // INSERT new record
        final insertPayload = <String, dynamic>{
          'appointment_id': note.appointmentId,
          'doctor_id': docId,
          'patient_id': resolvedPatientId,
          'diagnosis': note.diagnosis?.trim(),
          'notes': note.notes?.trim(),
          'prescriptions': note.prescriptions.map((p) => p.toMap()).toList(),
        };

        response = await _client
            .from('doctor_consultation_notes')
            .insert(insertPayload)
            .select()
            .single();
      }

      // 3. If completeAppointment is requested and appointment is confirmed, mark as completed
      if (completeAppointment && aptStatus != 'completed') {
        await updateAppointmentStatus(
          appointmentId: note.appointmentId,
          status: DoctorAppointmentStatus.completed,
        );
      }

      return DoctorConsultationNoteModel.fromMap(
          Map<String, dynamic>.from(response));
    } catch (e) {
      if (e is String) rethrow;
      throw _getFriendlyErrorMessage(
          e, 'Unable to save consultation record. Please verify appointment status.');
    }
  }

  /// Translates Postgrest and network exceptions into safe, user-friendly messages.
  static String _getFriendlyErrorMessage(dynamic error, String fallback) {
    if (error is PostgrestException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('permission denied') ||
          msg.contains('row-level security') ||
          error.code == '42501') {
        return 'Access denied. You do not have permission to perform this action.';
      }
      if (error.code == '23505' || msg.contains('unique') || msg.contains('duplicate')) {
        return 'A record with this information already exists.';
      }
      if (error.code == '23503' || msg.contains('foreign key')) {
        return 'Invalid reference. Please ensure associated clinic or doctor profile exists.';
      }
      if (error.message.isNotEmpty && !msg.contains('syntax error') && !msg.contains('internal')) {
        return error.message;
      }
    }

    final str = error.toString().toLowerCase();
    if (str.contains('socketexception') ||
        str.contains('failed host lookup') ||
        str.contains('clientexception') ||
        str.contains('network')) {
      return 'Network connection error. Please check your internet and try again.';
    }

    return fallback;
  }
}
