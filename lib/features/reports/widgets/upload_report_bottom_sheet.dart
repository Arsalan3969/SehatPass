import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

typedef UploadReportCallback = Future<void> Function({
  required String title,
  required String labFacility,
  required DateTime reportDate,
  required String category,
  String? summary,
  String? extractedText,
  String? fileName,
  List<int>? fileBytes,
  int? fileSizeBytes,
  String? mimeType,
});

/// Modal bottom sheet for creating and uploading a real medical report PDF.
class UploadReportBottomSheet extends StatefulWidget {
  final UploadReportCallback onUpload;

  const UploadReportBottomSheet({
    super.key,
    required this.onUpload,
  });

  static Future<void> show(
    BuildContext context, {
    required UploadReportCallback onUpload,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UploadReportBottomSheet(onUpload: onUpload),
    );
  }

  @override
  State<UploadReportBottomSheet> createState() =>
      _UploadReportBottomSheetState();
}

class _UploadReportBottomSheetState extends State<UploadReportBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _labController;
  late final TextEditingController _dateController;
  late final TextEditingController _summaryController;

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'bloodTest';
  bool _isUploading = false;
  String? _errorMessage;

  // Real native file picker data
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  int? _selectedFileSize;

  static const List<({String label, String value})> _categoryOptions = [
    (label: 'Blood Test', value: 'bloodTest'),
    (label: 'Scan / X-Ray', value: 'scan'),
    (label: 'Other', value: 'other'),
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _labController = TextEditingController();
    _dateController =
        TextEditingController(text: _formatDisplayDate(_selectedDate));
    _summaryController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _labController.dispose();
    _dateController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  String _formatDisplayDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDisplayDate(picked);
      });
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFileName = file.name;
          _selectedFileBytes = file.bytes;
          _selectedFileSize = file.size;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to open file picker. Please try again.';
      });
    }
  }

  void _clearSelectedFile() {
    setState(() {
      _selectedFileName = null;
      _selectedFileBytes = null;
      _selectedFileSize = null;
    });
  }

  String? _extractTextFromPdfBytes(Uint8List bytes) {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final String text = extractor.extractText();
      document.dispose();
      final trimmed = text.trim();
      return trimmed.isNotEmpty ? trimmed : null;
    } catch (e) {
      debugPrint('UploadReportBottomSheet: Text extraction note: $e');
      return null;
    }
  }

  Future<void> _handleSubmit() async {
    if (_isUploading) return;
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isUploading = true;
        _errorMessage = null;
      });

      try {
        String? extractedText;
        if (_selectedFileBytes != null) {
          extractedText = _extractTextFromPdfBytes(_selectedFileBytes!);
        }

        await widget.onUpload(
          title: _titleController.text.trim(),
          labFacility: _labController.text.trim(),
          reportDate: _selectedDate,
          category: _selectedCategory,
          summary: _summaryController.text.trim().isNotEmpty
              ? _summaryController.text.trim()
              : null,
          extractedText: extractedText,
          fileName: _selectedFileName,
          fileBytes: _selectedFileBytes,
          fileSizeBytes: _selectedFileSize,
          mimeType: _selectedFileName != null ? 'application/pdf' : null,
        );

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isUploading = false;
            _errorMessage =
                e is String ? e : 'Unable to upload report. Please try again.';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Upload Medical Report',
                      style: AppTextStyles.headingMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.emergencySurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.emergencyBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.emergency, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.emergency,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Report Title
                Text(
                  'Report Title',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g. Complete Blood Count (CBC)',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter report title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Laboratory / Diagnostic Center
                Text(
                  'Laboratory / Diagnostic Facility',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _labController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g. Chughtai Lab, Aga Khan Hospital',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter laboratory facility';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Category Selector
                Text(
                  'Report Category',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: _categoryOptions.map((cat) {
                    final isSelected = _selectedCategory == cat.value;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedCategory = cat.value),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primarySurface
                                  : AppColors.surfaceSecondary,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                cat.label,
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Report Date
                Text(
                  'Report Date',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: InputDecoration(
                    hintText: 'Select report date',
                    prefixIcon: const Icon(Icons.calendar_today_outlined,
                        color: AppColors.primary, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.edit_calendar_rounded,
                          size: 18, color: AppColors.textSecondary),
                      onPressed: _pickDate,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 14),

                // PDF Attachment Card (Native File Picker)
                Text(
                  'Attach PDF Document',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),

                if (_selectedFileName != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7D9C0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Color(0xFFDC2626),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedFileName!,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedFileSize != null
                                    ? _formatFileSize(_selectedFileSize!)
                                    : 'PDF Document',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: AppColors.textSecondary),
                          onPressed: _clearSelectedFile,
                          tooltip: 'Remove file',
                        ),
                        TextButton(
                          onPressed: _pickPdfFile,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  InkWell(
                    onTap: _pickPdfFile,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.upload_file_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select PDF Report from Device',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Tap to browse device storage (.pdf)',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Summary / Doctor Notes
                Text(
                  'Summary / Doctor Notes (Optional)',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _summaryController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText:
                        'e.g. All parameters within normal reference range.',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save & Upload Report',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
