import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../home/models/medical_report_model.dart';

/// Repository responsible for loading, creating, and managing patient medical reports in Supabase.
///
/// All queries and mutations are strictly scoped to the authenticated user's ID
/// (`Supabase.instance.client.auth.currentUser.id`).
class MedicalReportsRepository {
  final SupabaseClient? _clientOverride;

  MedicalReportsRepository({SupabaseClient? client})
      : _clientOverride = client;

  static final MedicalReportsRepository instance = MedicalReportsRepository();

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

  /// Formats date to 'YYYY-MM-DD' for SQL date column.
  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Normalizes display categories to database allowed check constraint values ('bloodTest', 'scan', 'other').
  String _normalizeCategory(String cat) {
    final lower = cat.trim().toLowerCase();
    if (lower.contains('blood') || lower.contains('lab') || lower.contains('cbc')) {
      return 'bloodTest';
    } else if (lower.contains('scan') || lower.contains('radio') || lower.contains('xray') || lower.contains('mri') || lower.contains('ct')) {
      return 'scan';
    }
    return 'other';
  }

  /// Fetches all medical reports for the authenticated patient with optional category & search filtering.
  Future<List<MedicalReportModel>> getPatientReports({
    String? category,
    String? searchQuery,
  }) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      return [];
    }

    try {
      var query = _client
          .from('medical_reports')
          .select()
          .eq('patient_id', userId);

      if (category != null &&
          category.isNotEmpty &&
          category.toLowerCase() != 'all') {
        query = query.eq('category', category);
      }

      final response = await query
          .order('report_date', ascending: false)
          .order('created_at', ascending: false);

      List<MedicalReportModel> reports = (response as List)
          .map((item) => MedicalReportModel.fromMap(
              Map<String, dynamic>.from(item as Map)))
          .toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final queryClean = searchQuery.trim().toLowerCase();
        reports = reports.where((r) {
          final titleMatch = r.title.toLowerCase().contains(queryClean);
          final labMatch = r.labFacility.toLowerCase().contains(queryClean);
          final summaryMatch =
              r.summary?.toLowerCase().contains(queryClean) ?? false;
          return titleMatch || labMatch || summaryMatch;
        }).toList();
      }

      return reports;
    } catch (e) {
      debugPrint('MedicalReportsRepository: Error fetching reports: $e');
      throw 'Unable to load your medical reports. Please try again.';
    }
  }

  /// Fetches recent medical reports (for Dashboard / Home screen).
  Future<List<MedicalReportModel>> getRecentReports({int limit = 10}) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      return [];
    }

    try {
      final response = await _client
          .from('medical_reports')
          .select()
          .eq('patient_id', userId)
          .order('report_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) => MedicalReportModel.fromMap(
              Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('MedicalReportsRepository: Error fetching recent reports: $e');
      throw 'Unable to load your medical reports. Please try again.';
    }
  }

  /// Creates a new medical report record in `public.medical_reports`.
  Future<MedicalReportModel> createReport({
    required String title,
    required String labFacility,
    required DateTime reportDate,
    required String category,
    String? storageFilePath,
    String? fileName,
    int? fileSizeBytes,
    String? mimeType,
    String? summary,
  }) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw 'Authentication required to create a medical report.';
    }

    final trimmedTitle = title.trim();
    final trimmedLab = labFacility.trim();
    if (trimmedTitle.isEmpty || trimmedLab.isEmpty) {
      throw 'Report title and laboratory name are required.';
    }

    try {
      final insertData = <String, dynamic>{
        'patient_id': userId,
        'title': trimmedTitle,
        'lab_facility': trimmedLab,
        'report_date': _formatDate(reportDate),
        'category': _normalizeCategory(category),
      };
      if (storageFilePath != null) {
        insertData['storage_file_path'] = storageFilePath;
      }
      if (fileName != null) {
        insertData['file_name'] = fileName;
      }
      if (fileSizeBytes != null) {
        insertData['file_size_bytes'] = fileSizeBytes;
      }
      if (mimeType != null) {
        insertData['mime_type'] = mimeType;
      }
      if (summary != null && summary.trim().isNotEmpty) {
        insertData['summary'] = summary.trim();
      }

      final response = await _client
          .from('medical_reports')
          .insert(insertData)
          .select()
          .single();

      return MedicalReportModel.fromMap(
          Map<String, dynamic>.from(response as Map));
    } catch (e) {
      debugPrint('MedicalReportsRepository: Error creating report: $e');
      throw 'Unable to save medical report. Please try again.';
    }
  }

  /// Uploads a report file to Supabase Storage and creates the database record.
  Future<MedicalReportModel> uploadAndCreateReport({
    required String title,
    required String labFacility,
    required DateTime reportDate,
    required String category,
    String? summary,
    required String fileName,
    required List<int> fileBytes,
    String? mimeType,
  }) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw 'Authentication required to upload a medical report.';
    }

    String? storagePath;
    try {
      // 1. Upload to Supabase Storage bucket `medical-reports`
      final sanitizedFileName =
          fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      storagePath =
          '$userId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedFileName';

      await _client.storage.from('medical-reports').uploadBinary(
            storagePath,
            Uint8List.fromList(fileBytes),
            fileOptions: FileOptions(
              contentType: mimeType ?? 'application/pdf',
              upsert: true,
            ),
          );
    } catch (e) {
      debugPrint(
          'MedicalReportsRepository: Error uploading file to storage: $e');
      throw 'Unable to upload file to storage. Please try again.';
    }

    // 2. Insert record in `public.medical_reports`
    return createReport(
      title: title,
      labFacility: labFacility,
      reportDate: reportDate,
      category: category,
      storageFilePath: storagePath,
      fileName: fileName,
      fileSizeBytes: fileBytes.length,
      mimeType: mimeType,
      summary: summary,
    );
  }

  /// Generates a temporary authenticated signed URL to securely view/download a private report file.
  Future<String?> getReportSignedUrl(
    String storageFilePath, {
    int expiresInSeconds = 3600,
  }) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty || storageFilePath.isEmpty) {
      return null;
    }

    try {
      final signedUrl = await _client.storage
          .from('medical-reports')
          .createSignedUrl(storageFilePath, expiresInSeconds);
      return signedUrl;
    } catch (e) {
      debugPrint('MedicalReportsRepository: Error generating signed URL: $e');
      return null;
    }
  }

  /// Deletes a medical report record and its associated storage file.
  Future<void> deleteReport({
    required String reportId,
    String? storageFilePath,
  }) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw 'Authentication required to delete a medical report.';
    }

    try {
      // Delete database record
      await _client
          .from('medical_reports')
          .delete()
          .eq('id', reportId)
          .eq('patient_id', userId);

      // Clean up storage file if present
      if (storageFilePath != null && storageFilePath.isNotEmpty) {
        try {
          await _client.storage
              .from('medical-reports')
              .remove([storageFilePath]);
        } catch (storageError) {
          debugPrint(
              'MedicalReportsRepository: Storage cleanup warning: $storageError');
        }
      }
    } catch (e) {
      debugPrint('MedicalReportsRepository: Error deleting report: $e');
      throw 'Unable to delete medical report. Please try again.';
    }
  }
}
