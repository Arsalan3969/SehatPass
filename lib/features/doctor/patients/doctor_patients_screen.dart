import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/doctor_repository.dart';
import '../models/doctor_patient_model.dart';
import 'doctor_patient_detail_screen.dart';

class DoctorPatientsScreen extends StatefulWidget {
  final DoctorRepository? repository;
  final List<DoctorPatientModel>? initialPatients;

  const DoctorPatientsScreen({
    super.key,
    this.repository,
    this.initialPatients,
  });

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  late final DoctorRepository _repository;
  List<DoctorPatientModel> _allPatients = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DoctorRepository.instance;

    if (widget.initialPatients != null) {
      _allPatients = List.from(widget.initialPatients!);
    } else if (_repository.currentUserId != null) {
      _fetchPatients();
    } else {
      _fetchPatients();
    }
  }

  Future<void> _fetchPatients() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repository.getDoctorPatients();
      if (mounted) {
        setState(() {
          _allPatients = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<DoctorPatientModel> get _filteredPatients {
    if (_searchQuery.isEmpty) return _allPatients;
    final query = _searchQuery.toLowerCase();
    return _allPatients.where((p) {
      return p.name.toLowerCase().contains(query) ||
          p.primaryCondition.toLowerCase().contains(query) ||
          p.medicalConditions.toLowerCase().contains(query) ||
          p.phone.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredPatients;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Patients',
          style: AppTextStyles.headingMedium,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search patients by name or condition...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceSecondary,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),

            // Patient List Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${list.length} Patients Total',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Sorted by recent visit',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),

            // Content Area (Loading / Error / Empty / List)
            Expanded(
              child: _buildBody(list),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<DoctorPatientModel> list) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.emergencySurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: AppColors.emergency,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchPatients,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceSecondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_search_rounded,
                size: 40,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No patients found' : 'No matches found',
              style: AppTextStyles.headingSmall,
            ),
            const SizedBox(height: 4),
            Text(
              _searchQuery.isEmpty
                  ? 'Patients with confirmed or past appointments will appear here.'
                  : 'No patients match "$_searchQuery".',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPatients,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        itemCount: list.length,
        separatorBuilder: (_, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final patient = list[index];
          return _buildPatientCard(patient);
        },
      ),
    );
  }

  Widget _buildPatientCard(DoctorPatientModel patient) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DoctorPatientDetailScreen(
                patient: patient,
                patientId: patient.id,
                repository: _repository,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    patient.name.isNotEmpty ? patient.name[0].toUpperCase() : 'P',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${patient.primaryCondition} • Blood ${patient.bloodGroup}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Last visit: ${patient.lastVisit} (${patient.totalVisits} ${patient.totalVisits == 1 ? 'visit' : 'visits'})',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
