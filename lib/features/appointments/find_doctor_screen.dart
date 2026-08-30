import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'models/doctor_model.dart';
import 'doctor_profile_screen.dart';

/// Find a Doctor search + filter + listing screen.
class FindDoctorScreen extends StatefulWidget {
  const FindDoctorScreen({super.key});

  @override
  State<FindDoctorScreen> createState() => _FindDoctorScreenState();
}

class _FindDoctorScreenState extends State<FindDoctorScreen> {
  final _searchController = TextEditingController();
  String _selectedSpecialty = 'All';
  String _searchQuery = '';

  static const List<String> _specialties = [
    'All',
    'General Physician',
    'Cardiologist',
    'Dermatologist',
    'Dentist',
  ];

  static const List<Doctor> _allDoctors = [
    Doctor(
      id: 'doc-001',
      name: 'Dr. Ahmed Khan',
      specialization: 'Cardiologist',
      clinic: 'City Heart Clinic',
      location: 'Lahore',
      rating: 4.8,
      consultationFee: 2000,
      availability: 'Available Today',
      about:
          'Experienced cardiologist providing general and specialized cardiac consultation. Over 12 years of clinical experience managing heart conditions and preventive cardiology.',
      availableDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      consultationHours: '10:00 AM - 4:00 PM',
      services: [
        DoctorService(name: 'General Consultation', fee: 2000),
        DoctorService(name: 'Follow-up Consultation', fee: 1500),
        DoctorService(name: 'ECG Review', fee: 1000),
      ],
    ),
    Doctor(
      id: 'doc-002',
      name: 'Dr. Sarah Ali',
      specialization: 'Dermatologist',
      clinic: 'Skin Care Clinic',
      location: 'Lahore',
      rating: 4.7,
      consultationFee: 1500,
      availability: 'Available Tomorrow',
      about:
          'Specialist in skin, hair, and nail conditions with extensive experience in cosmetic and medical dermatology.',
      availableDays: ['Monday', 'Wednesday', 'Thursday', 'Saturday'],
      consultationHours: '11:00 AM - 5:00 PM',
      services: [
        DoctorService(name: 'Skin Consultation', fee: 1500),
        DoctorService(name: 'Follow-up Visit', fee: 1000),
        DoctorService(name: 'Skin Biopsy', fee: 3000),
      ],
    ),
    Doctor(
      id: 'doc-003',
      name: 'Dr. Bilal Hassan',
      specialization: 'General Physician',
      clinic: 'Medicos Clinic',
      location: 'Lahore',
      rating: 4.6,
      consultationFee: 1000,
      availability: 'Available Today',
      about:
          'General practitioner with 8+ years of experience in primary healthcare, chronic disease management, and preventive medicine.',
      availableDays: [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
      ],
      consultationHours: '9:00 AM - 7:00 PM',
      services: [
        DoctorService(name: 'General Consultation', fee: 1000),
        DoctorService(name: 'Follow-up Consultation', fee: 800),
      ],
    ),
    Doctor(
      id: 'doc-004',
      name: 'Dr. Fatima Noor',
      specialization: 'Dentist',
      clinic: 'Bright Smile Dental',
      location: 'Lahore',
      rating: 4.9,
      consultationFee: 1200,
      availability: 'Available Today',
      about:
          'Experienced dentist specializing in cosmetic and restorative dentistry. Passionate about helping patients achieve healthy and beautiful smiles.',
      availableDays: ['Tuesday', 'Wednesday', 'Friday', 'Saturday'],
      consultationHours: '10:00 AM - 3:00 PM',
      services: [
        DoctorService(name: 'Dental Check-up', fee: 1200),
        DoctorService(name: 'Teeth Cleaning', fee: 2000),
        DoctorService(name: 'Tooth Extraction', fee: 2500),
      ],
    ),
    Doctor(
      id: 'doc-005',
      name: 'Dr. Usman Raza',
      specialization: 'Cardiologist',
      clinic: 'Punjab Heart Institute',
      location: 'Lahore',
      rating: 4.5,
      consultationFee: 2500,
      availability: 'Available Tomorrow',
      about:
          'Senior cardiologist with 18+ years of experience in interventional cardiology and heart failure management.',
      availableDays: ['Monday', 'Wednesday', 'Friday'],
      consultationHours: '2:00 PM - 6:00 PM',
      services: [
        DoctorService(name: 'Cardiac Consultation', fee: 2500),
        DoctorService(name: 'Echocardiography Review', fee: 2000),
        DoctorService(name: 'Follow-up', fee: 1500),
      ],
    ),
  ];

  List<Doctor> get _filteredDoctors {
    var list = _selectedSpecialty == 'All'
        ? _allDoctors
        : _allDoctors
            .where((d) => d.specialization == _selectedSpecialty)
            .toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((d) =>
              d.name.toLowerCase().contains(q) ||
              d.specialization.toLowerCase().contains(q) ||
              d.clinic.toLowerCase().contains(q))
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
            // ── Search & filter area (not scrollable) ────────────────────
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

            // ── Doctor list ──────────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, i) => const SizedBox(height: 12),
                      itemBuilder: (context, i) =>
                          _DoctorCard(doctor: filtered[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          Text('No doctors found', style: AppTextStyles.headingSmall),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search or filter.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
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
      doctor.availability.contains('Today') ? AppColors.primary : const Color(0xFF92400E);

  Color get _availabilityBg =>
      doctor.availability.contains('Today') ? AppColors.primarySurface : const Color(0xFFFFFBEB);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x07000000), blurRadius: 12, offset: Offset(0, 4)),
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
                child: const Icon(Icons.person_rounded,
                    size: 30, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doctor.name, style: AppTextStyles.labelLarge.copyWith(fontSize: 15)),
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
                        Text(
                          '${doctor.clinic}, ${doctor.location}',
                          style: AppTextStyles.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Rating
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 3),
                  Text(
                    doctor.rating.toStringAsFixed(1),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
