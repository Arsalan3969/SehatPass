import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../home/models/medical_report_model.dart';
import '../data/medical_reports_repository.dart';

/// Modal bottom sheet for viewing full report details, accessing files, and deleting reports.
class ReportDetailsBottomSheet extends StatefulWidget {
  final MedicalReportModel report;
  final MedicalReportsRepository repository;
  final Future<void> Function() onDeleted;

  const ReportDetailsBottomSheet({
    super.key,
    required this.report,
    required this.repository,
    required this.onDeleted,
  });

  static Future<void> show(
    BuildContext context, {
    required MedicalReportModel report,
    required MedicalReportsRepository repository,
    required Future<void> Function() onDeleted,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReportDetailsBottomSheet(
        report: report,
        repository: repository,
        onDeleted: onDeleted,
      ),
    );
  }

  @override
  State<ReportDetailsBottomSheet> createState() =>
      _ReportDetailsBottomSheetState();
}

class _ReportDetailsBottomSheetState extends State<ReportDetailsBottomSheet> {
  bool _isDeleting = false;
  bool _isLoadingUrl = false;
  String? _signedUrl;
  String? _errorMessage;

  Future<void> _handleViewFile() async {
    final storagePath = widget.report.storageFilePath;
    if (storagePath == null || storagePath.isEmpty) return;

    setState(() {
      _isLoadingUrl = true;
      _errorMessage = null;
    });

    try {
      final url = await widget.repository.getReportSignedUrl(storagePath);
      if (mounted) {
        setState(() {
          _signedUrl = url;
          _isLoadingUrl = false;
        });

        if (url != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Secure access link generated.',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUrl = false;
          _errorMessage = 'Unable to access report file. Please try again.';
        });
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: Text('Delete Medical Report', style: AppTextStyles.headingSmall),
        content: Text(
          'Are you sure you want to delete "${widget.report.title}"? This action cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergency,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isDeleting = true;
        _errorMessage = null;
      });

      try {
        await widget.repository.deleteReport(
          reportId: widget.report.id,
          storageFilePath: widget.report.storageFilePath,
        );
        if (mounted) {
          Navigator.pop(context);
          await widget.onDeleted();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isDeleting = false;
            _errorMessage =
                e is String ? e : 'Failed to delete report. Please try again.';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
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

              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(report.title, style: AppTextStyles.headingSmall),
                        const SizedBox(height: 3),
                        Text(
                          report.labFacility,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
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
              const SizedBox(height: 18),

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

              // Metadata grid
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Report Date',
                      value: report.formattedDateLong,
                    ),
                    const Divider(height: 18),
                    _DetailRow(
                      icon: Icons.category_outlined,
                      label: 'Category',
                      value: report.categoryLabel,
                    ),
                    if (report.fileName != null &&
                        report.fileName!.isNotEmpty) ...[
                      const Divider(height: 18),
                      _DetailRow(
                        icon: Icons.attach_file_rounded,
                        label: 'Attached File',
                        value: report.fileName!,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Summary notes if present
              if (report.summary != null && report.summary!.isNotEmpty) ...[
                Text('Doctor / Lab Notes', style: AppTextStyles.labelLarge),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primarySurface),
                  ),
                  child: Text(
                    report.summary!,
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // File Access Button (if storage file exists)
              if (report.storageFilePath != null &&
                  report.storageFilePath!.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _isLoadingUrl ? null : _handleViewFile,
                    icon: _isLoadingUrl
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.file_open_outlined, size: 18),
                    label: Text(
                      _signedUrl != null ? 'File Link Ready' : 'Access Report Document',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Delete Report Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _isDeleting ? null : _handleDelete,
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(AppColors.emergency),
                          ),
                        )
                      : const Icon(Icons.delete_outline_rounded,
                          color: AppColors.emergency, size: 18),
                  label: Text(
                    'Delete Report',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.emergency,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.emergencyBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
