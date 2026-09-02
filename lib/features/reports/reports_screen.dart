import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/dummy_data.dart';
import '../../shared/widgets/app_card.dart';
import '../home/models/medical_report_model.dart';
import 'data/medical_reports_repository.dart';
import 'widgets/report_card.dart';
import 'widgets/report_filter_chips.dart';
import 'widgets/upload_report_bottom_sheet.dart';
import 'widgets/report_details_bottom_sheet.dart';

class ReportsScreen extends StatefulWidget {
  final MedicalReportsRepository? repository;

  const ReportsScreen({super.key, this.repository});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  MedicalReportsRepository get _repo =>
      widget.repository ?? MedicalReportsRepository.instance;

  ReportCategory _selectedFilter = ReportCategory.all;
  final TextEditingController _searchController = TextEditingController();

  List<MedicalReportModel> _allReports = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadReports();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reports = await _repo.getPatientReports();
      if (!mounted) return;
      setState(() {
        _allReports = reports;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is String
            ? e
            : 'Unable to load your medical reports. Please try again.';
        _isLoading = false;
      });
    }
  }

  List<MedicalReportModel> get _filteredReports {
    final query = _searchController.text.trim().toLowerCase();

    return _allReports.where((r) {
      final matchesFilter = _selectedFilter == ReportCategory.all ||
          r.reportCategory == _selectedFilter;

      if (!matchesFilter) return false;

      if (query.isEmpty) return true;

      final matchesTitle = r.title.toLowerCase().contains(query);
      final matchesLab = r.labFacility.toLowerCase().contains(query);
      final matchesSummary =
          r.summary?.toLowerCase().contains(query) ?? false;
      final matchesFileName =
          r.fileName?.toLowerCase().contains(query) ?? false;

      return matchesTitle || matchesLab || matchesSummary || matchesFileName;
    }).toList();
  }

  void _openUploadReport() {
    UploadReportBottomSheet.show(
      context,
      onUpload: ({
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
      }) async {
        if (fileBytes != null && fileName != null && fileName.isNotEmpty) {
          await _repo.uploadAndCreateReport(
            title: title,
            labFacility: labFacility,
            reportDate: reportDate,
            category: category,
            summary: summary,
            extractedText: extractedText,
            fileName: fileName,
            fileBytes: fileBytes,
            mimeType: mimeType ?? 'application/pdf',
          );
        } else {
          await _repo.createReport(
            title: title,
            labFacility: labFacility,
            reportDate: reportDate,
            category: category,
            summary: summary,
            extractedText: extractedText,
            fileName: fileName,
            fileSizeBytes: fileSizeBytes,
            mimeType: mimeType,
          );
        }
        await _loadReports();
        if (mounted) {
          _showSnackBar('$title uploaded successfully.');
        }
      },
    );
  }

  void _openReportDetails(MedicalReportModel report) {
    ReportDetailsBottomSheet.show(
      context,
      report: report,
      repository: _repo,
      onDeleted: () async {
        await _loadReports();
        if (mounted) {
          _showSnackBar('${report.title} deleted.');
        }
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reports = _filteredReports;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Reports', style: AppTextStyles.headingLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Keep track of your medical reports in one place.',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 18),

                  // ── Search bar ───────────────────────────────────────
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x06000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: AppTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Search reports',
                        hintStyle: AppTextStyles.bodyMedium,
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textTertiary,
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    size: 18, color: AppColors.textSecondary),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Filter chips ──────────────────────────────────────────────
            ReportFilterChips(
              selected: _selectedFilter,
              onSelected: (cat) => setState(() => _selectedFilter = cat),
            ),

            const SizedBox(height: 16),

            // ── Report count label ────────────────────────────────────────
            if (!_isLoading && _errorMessage == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '${reports.length} ${reports.length == 1 ? 'report' : 'reports'} found',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // ── Report list / States ───────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadReports,
                color: AppColors.primary,
                child: _buildContent(reports),
              ),
            ),
          ],
        ),
      ),

      // ── FAB ───────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openUploadReport,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.upload_file_outlined, size: 20),
        label: Text(
          'Upload Report',
          style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildContent(List<MedicalReportModel> reports) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Loading your reports...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.emergencySurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.emergencyBorder),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.emergency,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Unable to load your medical reports',
                style: AppTextStyles.headingSmall.copyWith(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage ??
                    'Please check your connection and try again.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _loadReports,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(fontWeight: FontWeight.w600),
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
            ],
          ),
        ),
      );
    }

    if (reports.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        child: SizedBox(
          height: 380,
          child: Center(
            child: _EmptyState(
              filter: _selectedFilter,
              onUpload: _openUploadReport,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: reports.length,
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final report = reports[index];
        return ReportCard(
          report: report,
          onTap: () => _openReportDetails(report),
        );
      },
    );
  }
}

/// Shown when no reports match the selected filter or no reports exist.
class _EmptyState extends StatelessWidget {
  final ReportCategory filter;
  final VoidCallback? onUpload;

  const _EmptyState({
    required this.filter,
    this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final title = filter == ReportCategory.all
        ? 'No medical reports yet'
        : 'No ${filter.label.toLowerCase()} found';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.folder_open_outlined,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.headingSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Upload lab tests or diagnostic reports to keep them organized.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (onUpload != null) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text(
                'Upload Report',
                style: TextStyle(fontWeight: FontWeight.w600),
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
          ],
        ],
      ),
    );
  }
}
