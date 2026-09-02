import '../../../core/constants/dummy_data.dart';

/// Model representing a patient medical report from `public.medical_reports`.
class MedicalReportModel {
  final String id;
  final String patientId;
  final String title;
  final String labFacility;
  final DateTime? reportDate;
  final String category;
  final String? storageFilePath;
  final String? fileName;
  final int? fileSizeBytes;
  final String? mimeType;
  final String? summary;
  final String? extractedText;
  final DateTime? createdAt;

  const MedicalReportModel({
    required this.id,
    required this.patientId,
    required this.title,
    required this.labFacility,
    this.reportDate,
    required this.category,
    this.storageFilePath,
    this.fileName,
    this.fileSizeBytes,
    this.mimeType,
    this.summary,
    this.extractedText,
    this.createdAt,
  });

  MedicalReportModel copyWith({
    String? id,
    String? patientId,
    String? title,
    String? labFacility,
    DateTime? reportDate,
    String? category,
    String? storageFilePath,
    String? fileName,
    int? fileSizeBytes,
    String? mimeType,
    String? summary,
    String? extractedText,
    DateTime? createdAt,
  }) {
    return MedicalReportModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      title: title ?? this.title,
      labFacility: labFacility ?? this.labFacility,
      reportDate: reportDate ?? this.reportDate,
      category: category ?? this.category,
      storageFilePath: storageFilePath ?? this.storageFilePath,
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      mimeType: mimeType ?? this.mimeType,
      summary: summary ?? this.summary,
      extractedText: extractedText ?? this.extractedText,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory MedicalReportModel.fromMap(Map<String, dynamic> map) {
    return MedicalReportModel(
      id: map['id']?.toString() ?? '',
      patientId: map['patient_id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Medical Report',
      labFacility: map['lab_facility']?.toString() ?? 'Laboratory',
      reportDate: map['report_date'] != null
          ? DateTime.tryParse(map['report_date'].toString())
          : null,
      category: map['category']?.toString() ?? 'other',
      storageFilePath: map['storage_file_path']?.toString(),
      fileName: map['file_name']?.toString(),
      fileSizeBytes: map['file_size_bytes'] is int
          ? map['file_size_bytes'] as int
          : int.tryParse(map['file_size_bytes']?.toString() ?? ''),
      mimeType: map['mime_type']?.toString(),
      summary: map['summary']?.toString(),
      extractedText: map['extracted_text']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'title': title,
      'lab_facility': labFacility,
      if (reportDate != null)
        'report_date':
            "${reportDate!.year.toString().padLeft(4, '0')}-${reportDate!.month.toString().padLeft(2, '0')}-${reportDate!.day.toString().padLeft(2, '0')}",
      'category': category,
      'storage_file_path': storageFilePath,
      'file_name': fileName,
      'file_size_bytes': fileSizeBytes,
      'mime_type': mimeType,
      'summary': summary,
      'extracted_text': extractedText,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Formatted date string for UI display (e.g. '25 Aug 2026' or '25 August 2026').
  String get formattedDate {
    if (reportDate == null) return 'Recent';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${reportDate!.day.toString().padLeft(2, '0')} ${months[reportDate!.month - 1]} ${reportDate!.year}';
  }

  String get formattedDateLong {
    if (reportDate == null) return 'Recent';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${reportDate!.day.toString().padLeft(2, '0')} ${months[reportDate!.month - 1]} ${reportDate!.year}';
  }

  /// Category badge label for display (e.g. 'Blood Test', 'Scan', 'Other').
  String get categoryLabel {
    switch (category.toLowerCase()) {
      case 'bloodtest':
      case 'blood test':
      case 'blood_test':
        return 'Blood Test';
      case 'scan':
      case 'scans':
      case 'xray':
      case 'x-ray':
      case 'mri':
      case 'ct':
        return 'Scan';
      case 'other':
      default:
        return 'Other';
    }
  }

  /// Formatted human-readable file size (e.g. '1.2 MB', '450 KB').
  String? get formattedFileSize {
    if (fileSizeBytes == null || fileSizeBytes! <= 0) return null;
    if (fileSizeBytes! < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes! < 1024 * 1024) {
      return '${(fileSizeBytes! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Interoperability with [DummyReport] / [ReportItem].
  DummyReport toDummyReport() {
    return DummyReport(
      title: title,
      date: formattedDate,
      type: categoryLabel,
    );
  }

  ReportCategory get reportCategory {
    switch (category.toLowerCase()) {
      case 'bloodtest':
      case 'blood test':
      case 'blood_test':
        return ReportCategory.bloodTest;
      case 'scan':
      case 'scans':
      case 'xray':
      case 'x-ray':
      case 'mri':
      case 'ct':
        return ReportCategory.scan;
      default:
        return ReportCategory.other;
    }
  }

  ReportItem toReportItem() {
    return ReportItem(
      name: title,
      lab: labFacility,
      date: formattedDate,
      category: reportCategory,
    );
  }
}
