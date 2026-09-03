import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'data/appointment_repository.dart';
import 'models/doctor_model.dart';
import 'doctor_profile_screen.dart';

/// Find a Doctor search + filter + listing screen backed by Supabase.
class FindDoctorScreen extends StatefulWidget {
  final AppointmentRepository? repository;

  const FindDoctorScreen({super.key, this.repository});

  @override
  State<FindDoctorScreen> createState() => _FindDoctorScreenState();
}

class _FindDoctorScreenState extends State<FindDoctorScreen> {
  AppointmentRepository get _repo =>
      widget.repository ?? AppointmentRepository.instance;

  final _searchController = TextEditingController();
  String _selectedSpecialty = 'All';
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;
  List<Doctor> _doctors = [];

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final doctors = await _repo.getDoctors();
      if (mounted) {
        setState(() {
          _doctors = doctors;
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

  List<String> get _specialties {
    final Set<String> specs = {'All'};
    for (final doc in _doctors) {
      if (doc.specialization.isNotEmpty &&
          doc.specialization != 'Specialization not provided') {
        specs.add(doc.specialization);
      }
    }
    return specs.toList();
  }

  List<Doctor> get _filteredDoctors {
    var list = _selectedSpecialty == 'All'
        ? _doctors
        : _doctors
            .where((d) => d.specialization == _selectedSpecialty)
            .toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((d) =>
              d.name.toLowerCase().contains(q) ||
              d.specialization.toLowerCase().contains(q) ||
              d.clinic.toLowerCase().contains(q) ||
              d.location.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDoctors;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Find a Doctor'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Search & filter area ─────────────────────────────────────
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find the right doctor for your needs.',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: AppTextStyles.bodyLarge.copyWith(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search doctors or specialties...',
                        hintStyle: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textTertiary),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textTertiary,
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    size: 18, color: AppColors.textTertiary),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Specialty filter chips
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _specialties.length,
                      separatorBuilder: (_, i) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final spec = _specialties[i];
                        final selected = spec == _selectedSpecialty;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedSpecialty = spec),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                  ? AppColors.primary
                                  : AppColors.border,
                              ),
                            ),
                            child: Text(
                              spec,
                              style: AppTextStyles.caption.copyWith(
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.divider),

            // ── Doctor list / Loading / Error / Empty ────────────────────
            Expanded(
              child: _buildBody(filtered),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<Doctor> filtered) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.emergencySurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.emergency,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load doctors',
                style: AppTextStyles.headingSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadDoctors,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
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

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadDoctors,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Container(
            height: 400,
            alignment: Alignment.center,
            child: _buildEmptyState(),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDoctors,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: filtered.length,
        separatorBuilder: (_, i) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _DoctorCard(doctor: filtered[i]),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltering = _selectedSpecialty != 'All' || _searchQuery.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            isFiltering ? Icons.search_off_rounded : Icons.medical_services_outlined,
            size: 40,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isFiltering ? 'No doctors found' : 'No doctors available',
          style: AppTextStyles.headingSmall,
        ),
        const SizedBox(height: 6),
        Text(
          isFiltering
              ? 'Try adjusting your search or filter.'
              : 'There are currently no doctors available for booking. Please check back later.',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Doctor Card
// ─────────────────────────────────────────────────────────────────────────────

class _DoctorCard extends StatelessWidget {
  final Doctor doctor;
  const _DoctorCard({required this.doctor});

  Color get _availabilityColor =>
      doctor.availability.contains('Today')
          ? AppColors.primary
          : const Color(0xFF92400E);

  Color get _availabilityBg =>
      doctor.availability.contains('Today')
          ? AppColors.primarySurface
          : const Color(0xFFFFFBEB);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: doctor.photoUrl != null && doctor.photoUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          doctor.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.person_rounded,
                            size: 30,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.person_rounded,
                        size: 30,
                        color: AppColors.primary,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doctor.name,
                        style: AppTextStyles.labelLarge.copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(doctor.specialization,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        )),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: AppColors.textTertiary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '${doctor.clinic}, ${doctor.location}',
                            style: AppTextStyles.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              // Fee
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Consultation', style: AppTextStyles.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      'Rs. ${doctor.consultationFee.toStringAsFixed(0)}',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Availability badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _availabilityBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  doctor.availability,
                  style: AppTextStyles.caption.copyWith(
                    color: _availabilityColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // View Profile button
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DoctorProfileScreen(doctor: doctor)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  child: const Text('View Profile'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
