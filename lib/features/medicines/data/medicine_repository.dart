import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../home/models/patient_medicine_model.dart';
import '../models/medicine_item.dart';

/// Repository responsible for patient medicine operations backed by Supabase.
///
/// All database operations are authoritative and internally scoped to the
/// authenticated user's ID (`Supabase.instance.client.auth.currentUser.id`).
class MedicineRepository {
  final SupabaseClient? _clientOverride;

  MedicineRepository({SupabaseClient? client}) : _clientOverride = client;

  static final MedicineRepository instance = MedicineRepository();

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

  /// Formats date to 'YYYY-MM-DD' for dose_date comparison.
  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Fetches all active medicines for the currently authenticated patient.
  Future<List<PatientMedicineModel>> getActiveMedicines() async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      return [];
    }

    try {
      final response = await _client
          .from('patient_medicines')
          .select()
          .eq('patient_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: true);

      return (response as List)
          .map((item) => PatientMedicineModel.fromMap(
              Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('MedicineRepository: Error fetching active medicines: $e');
      throw 'Unable to load your medicines. Please try again.';
    }
  }

  /// Fetches all medicines (active & inactive) for the currently authenticated patient.
  Future<List<PatientMedicineModel>> getAllMedicines() async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      return [];
    }

    try {
      final response = await _client
          .from('patient_medicines')
          .select()
          .eq('patient_id', userId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((item) => PatientMedicineModel.fromMap(
              Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('MedicineRepository: Error fetching all medicines: $e');
      throw 'Unable to load your medicines. Please try again.';
    }
  }

  /// Fetches dose logs for a specific date (defaults to today) for the authenticated patient.
  Future<List<Map<String, dynamic>>> getTodayDoseLogs({DateTime? date}) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      return [];
    }

    final dateStr = _formatDate(date ?? DateTime.now());

    try {
      final response = await _client
          .from('medicine_dose_logs')
          .select()
          .eq('dose_date', dateStr);

      return (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (e) {
      debugPrint('MedicineRepository: Error fetching dose logs: $e');
      return [];
    }
  }

  /// Fetches active medicines and resolves today's dose tracking status for each.
  Future<List<MedicineItem>> getTodayMedicineSchedule({DateTime? date}) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      return [];
    }

    try {
      final medicines = await getActiveMedicines();
      final doseLogs = await getTodayDoseLogs(date: date);

      // Create a map of medicine_id -> dose log
      final Map<String, Map<String, dynamic>> doseLogMap = {};
      for (final log in doseLogs) {
        final medId = log['medicine_id']?.toString();
        if (medId != null && medId.isNotEmpty) {
          doseLogMap[medId] = log;
        }
      }

      return medicines.map((med) {
        final log = doseLogMap[med.id];
        MedicineStatus status = MedicineStatus.upcoming;
        String? doseLogId;

        if (log != null) {
          status = MedicineStatusProps.fromString(log['status']?.toString());
          doseLogId = log['id']?.toString();
        }

        return med.toMedicineItem(status: status, doseLogId: doseLogId);
      }).toList();
    } catch (e) {
      debugPrint('MedicineRepository: Error getting today schedule: $e');
      if (e is String) rethrow;
      throw 'Unable to load your medicines schedule. Please try again.';
    }
  }

  /// Adds a new medicine for the currently authenticated patient.
  Future<PatientMedicineModel> addMedicine({
    required String name,
    required String dosage,
    required String instruction,
    required String scheduledTime,
    DateTime? startDate,
  }) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw 'Authentication required to add medications.';
    }

    final trimmedName = name.trim();
    final trimmedDosage = dosage.trim();
    if (trimmedName.isEmpty || trimmedDosage.isEmpty) {
      throw 'Medicine name and dosage are required.';
    }

    try {
      final insertData = <String, dynamic>{
        'patient_id': userId,
        'name': trimmedName,
        'dosage': trimmedDosage,
        'instruction': instruction.trim(),
        'scheduled_time': scheduledTime.trim(),
        'is_active': true,
      };

      if (startDate != null) {
        insertData['start_date'] = _formatDate(startDate);
      }

      final response = await _client
          .from('patient_medicines')
          .insert(insertData)
          .select()
          .single();

      return PatientMedicineModel.fromMap(
          Map<String, dynamic>.from(response as Map));
    } catch (e) {
      debugPrint('MedicineRepository: Error adding medicine: $e');
      throw 'Unable to save medication. Please try again.';
    }
  }

  /// Updates an existing medication for the currently authenticated patient.
  Future<PatientMedicineModel> updateMedicine({
    required String medicineId,
    required String name,
    required String dosage,
    required String instruction,
    required String scheduledTime,
    DateTime? startDate,
    bool isActive = true,
  }) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw 'Authentication required to update medications.';
    }

    final trimmedName = name.trim();
    final trimmedDosage = dosage.trim();
    if (trimmedName.isEmpty || trimmedDosage.isEmpty) {
      throw 'Medicine name and dosage are required.';
    }

    try {
      final updateData = <String, dynamic>{
        'name': trimmedName,
        'dosage': trimmedDosage,
        'instruction': instruction.trim(),
        'scheduled_time': scheduledTime.trim(),
        'is_active': isActive,
      };

      if (startDate != null) {
        updateData['start_date'] = _formatDate(startDate);
      }

      final response = await _client
          .from('patient_medicines')
          .update(updateData)
          .eq('id', medicineId)
          .eq('patient_id', userId)
          .select()
          .single();

      return PatientMedicineModel.fromMap(
          Map<String, dynamic>.from(response as Map));
    } catch (e) {
      debugPrint('MedicineRepository: Error updating medicine: $e');
      throw 'Unable to update medication. Please try again.';
    }
  }

  /// Deactivates a medication (`is_active = false`) for the authenticated patient.
  Future<void> deactivateMedicine(String medicineId) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw 'Authentication required to deactivate medications.';
    }

    try {
      await _client
          .from('patient_medicines')
          .update({'is_active': false})
          .eq('id', medicineId)
          .eq('patient_id', userId);
    } catch (e) {
      debugPrint('MedicineRepository: Error deactivating medicine: $e');
      throw 'Unable to remove medication. Please try again.';
    }
  }

  /// Permanently deletes a medication record if required.
  Future<void> deleteMedicine(String medicineId) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw 'Authentication required to delete medications.';
    }

    try {
      await _client
          .from('patient_medicines')
          .delete()
          .eq('id', medicineId)
          .eq('patient_id', userId);
    } catch (e) {
      debugPrint('MedicineRepository: Error deleting medicine: $e');
      throw 'Unable to delete medication. Please try again.';
    }
  }

  /// Marks a medicine dose as 'taken' for today for the authenticated patient.
  Future<void> markDoseTaken({
    required String medicineId,
    DateTime? date,
  }) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw 'Authentication required to record doses.';
    }

    final dateStr = _formatDate(date ?? DateTime.now());
    final nowIso = DateTime.now().toIso8601String();

    try {
      final existingLog = await _client
          .from('medicine_dose_logs')
          .select('id')
          .eq('medicine_id', medicineId)
          .eq('dose_date', dateStr)
          .maybeSingle();

      if (existingLog != null) {
        await _client
            .from('medicine_dose_logs')
            .update({
              'status': 'taken',
              'logged_at': nowIso,
            })
            .eq('id', existingLog['id']);
      } else {
        await _client.from('medicine_dose_logs').insert({
          'medicine_id': medicineId,
          'dose_date': dateStr,
          'status': 'taken',
          'logged_at': nowIso,
        });
      }
    } catch (e) {
      debugPrint('MedicineRepository: Error marking dose taken: $e');
      throw 'Unable to update dose status. Please try again.';
    }
  }
}
