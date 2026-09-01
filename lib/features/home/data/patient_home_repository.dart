import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/patient_home_data.dart';
import '../models/patient_medicine_model.dart';
import '../models/medical_report_model.dart';
import '../../medicines/data/medicine_repository.dart';
import '../../reports/data/medical_reports_repository.dart';

/// Repository responsible for loading patient-specific dashboard data from Supabase.
class PatientHomeRepository {
  final SupabaseClient? _clientOverride;
  final MedicineRepository _medicineRepository;
  final MedicalReportsRepository _reportsRepository;

  PatientHomeRepository({
    SupabaseClient? client,
    MedicineRepository? medicineRepository,
    MedicalReportsRepository? reportsRepository,
  })  : _clientOverride = client,
        _medicineRepository = medicineRepository ??
            (client != null
                ? MedicineRepository(client: client)
                : MedicineRepository.instance),
        _reportsRepository = reportsRepository ??
            (client != null
                ? MedicalReportsRepository(client: client)
                : MedicalReportsRepository.instance);

  static final PatientHomeRepository instance = PatientHomeRepository();

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

  /// Fetches the patient's display name from profiles table or email fallback.
  Future<String> getPatientName() async {
    final user = currentUser;
    final userId = user?.id;
    if (userId == null || userId.isEmpty) {
      return 'there';
    }

    String patientName = '';
    final email = user?.email ?? '';

    try {
      final profileData = await _client
          .from('profiles')
          .select('full_name, email')
          .eq('id', userId)
          .maybeSingle();

      if (profileData != null) {
        final fetchedName = profileData['full_name']?.toString().trim();
        if (fetchedName != null && fetchedName.isNotEmpty) {
          patientName = fetchedName;
        }
      }
    } catch (e) {
      debugPrint('PatientHomeRepository: Error fetching profile name: $e');
    }

    if (patientName.isEmpty) {
      if (email.isNotEmpty && email.contains('@')) {
        final username = email.split('@').first;
        patientName = username[0].toUpperCase() + username.substring(1);
      } else {
        patientName = 'there';
      }
    }

    return patientName;
  }

  /// Fetches complete patient dashboard data for the authenticated user.
  Future<PatientHomeData> getPatientHomeData() async {
    final user = currentUser;
    final userId = user?.id;

    if (userId == null || userId.isEmpty) {
      return const PatientHomeData(
        patientName: 'there',
        email: '',
        medicines: [],
        reports: [],
      );
    }

    try {
      // 1. Fetch Profile Name
      final patientName = await getPatientName();
      String email = user?.email ?? '';

      // 2. Fetch Active Medicines via shared MedicineRepository
      List<PatientMedicineModel> medicines = [];
      try {
        medicines = await _medicineRepository.getActiveMedicines();
      } catch (e) {
        debugPrint('PatientHomeRepository: Error fetching medicines: $e');
      }

      // 3. Fetch Recent Medical Reports via shared MedicalReportsRepository
      List<MedicalReportModel> reports = [];
      try {
        reports = await _reportsRepository.getRecentReports(limit: 10);
      } catch (e) {
        debugPrint('PatientHomeRepository: Error fetching reports: $e');
      }

      return PatientHomeData(
        patientName: patientName,
        email: email,
        medicines: medicines,
        reports: reports,
      );
    } catch (e) {
      debugPrint('PatientHomeRepository: Unexpected error: $e');
      throw 'Unable to load your health information. Please try again.';
    }
  }
}
