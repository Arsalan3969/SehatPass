class DoctorPatientModel {
  final String id;
  final String name;
  final String? photoUrl;
  final int age;
  final String gender;
  final String phone;
  final String bloodGroup;
  final String lastVisit;
  final DateTime? lastAppointmentDate;
  final int totalVisits;
  final String primaryCondition;
  final String notes;
  final String allergies;
  final String medicalConditions;
  final DateTime? dateOfBirth;
  final List<String> currentMedicines;
  final List<String> medicalHistory;
  final List<Map<String, String>> medicalReports;
  final String aiSummary;

  String get patientId => id;
  int get appointmentCount => totalVisits;

  DoctorPatientModel({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.age,
    required this.gender,
    required this.phone,
    required this.bloodGroup,
    required this.lastVisit,
    this.lastAppointmentDate,
    required this.totalVisits,
    required this.primaryCondition,
    this.notes = '',
    this.allergies = 'None added',
    this.medicalConditions = 'None added',
    this.dateOfBirth,
    this.currentMedicines = const [],
    this.medicalHistory = const [],
    this.medicalReports = const [],
    this.aiSummary = '',
  });

  /// Calculates age in complete years from date of birth.
  static int calculateAge(DateTime? dob, {int fallbackAge = 30}) {
    if (dob == null) return fallbackAge;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age >= 0 ? age : 0;
  }

  /// Formats date to user-friendly string (e.g. '15 Aug 2026')
  static String formatDate(DateTime? date) {
    if (date == null) return 'No visits yet';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Robust constructor from Supabase database joined map or repository aggregated data.
  factory DoctorPatientModel.fromMap(
    Map<String, dynamic> map, {
    int? totalVisits,
    DateTime? lastAppointmentDate,
    String? latestServiceName,
  }) {
    final patientId = map['id']?.toString() ??
        map['patient_id']?.toString() ??
        map['user_id']?.toString() ??
        '';

    // 1. Resolve profiles data (full_name, profile_photo_url, phone)
    final profileMap = map['profiles'] is Map
        ? Map<String, dynamic>.from(map['profiles'] as Map)
        : (map['profile'] is Map
            ? Map<String, dynamic>.from(map['profile'] as Map)
            : null);

    final rawFullName = profileMap?['full_name']?.toString().trim() ??
        map['full_name']?.toString().trim() ??
        map['name']?.toString().trim() ??
        map['patient_name']?.toString().trim() ??
        '';

    final fullName =
        rawFullName.isNotEmpty ? rawFullName : 'Name not provided';

    final photoUrl = profileMap?['avatar_url']?.toString() ??
        profileMap?['profile_photo_url']?.toString() ??
        map['avatar_url']?.toString() ??
        map['profile_photo_url']?.toString() ??
        map['photo_url']?.toString();

    final phoneStr = profileMap?['phone']?.toString() ??
        map['phone']?.toString() ??
        map['patient_phone']?.toString() ??
        'Not provided';

    // 2. Resolve patient_profiles data (date_of_birth, gender, blood_group, allergies, medical_conditions)
    final patientProfileMap = map['patient_profiles'] is Map
        ? Map<String, dynamic>.from(map['patient_profiles'] as Map)
        : (map['patient_profiles'] is List && (map['patient_profiles'] as List).isNotEmpty
            ? Map<String, dynamic>.from((map['patient_profiles'] as List).first as Map)
            : null);

    final rawDob = patientProfileMap?['date_of_birth']?.toString() ??
        map['date_of_birth']?.toString();
    final parsedDob = rawDob != null ? DateTime.tryParse(rawDob) : null;

    final ageVal = (map['age'] as num?)?.toInt() ??
        calculateAge(parsedDob, fallbackAge: 0);

    final genderStr = patientProfileMap?['gender']?.toString() ??
        map['gender']?.toString() ??
        'Not specified';

    final bloodGroupStr = patientProfileMap?['blood_group']?.toString() ??
        map['blood_group']?.toString() ??
        'Not specified';

    final allergiesStr = patientProfileMap?['allergies']?.toString() ??
        map['allergies']?.toString() ??
        'None added';

    final conditionsStr = patientProfileMap?['medical_conditions']?.toString() ??
        map['medical_conditions']?.toString() ??
        'None added';

    // 3. Resolve visit metrics (strictly completed visits when provided)
    final visitCount = totalVisits ??
        (map['total_visits'] as num?)?.toInt() ??
        (map['appointment_count'] as num?)?.toInt() ??
        1;

    DateTime? resolvedLastDate = lastAppointmentDate;
    if (resolvedLastDate == null && map['last_appointment_date'] != null) {
      resolvedLastDate = DateTime.tryParse(map['last_appointment_date'].toString());
    }

    final lastVisitStr = map['last_visit']?.toString() ??
        (resolvedLastDate != null
            ? formatDate(resolvedLastDate)
            : (visitCount == 0 ? 'No visits yet' : 'Recent'));

    final primaryConditionStr = latestServiceName ??
        map['primary_condition']?.toString() ??
        (conditionsStr != 'None added' ? conditionsStr : 'General Medical Care');

    return DoctorPatientModel(
      id: patientId,
      name: fullName,
      photoUrl: photoUrl,
      age: ageVal,
      gender: genderStr,
      phone: phoneStr,
      bloodGroup: bloodGroupStr,
      lastVisit: lastVisitStr,
      lastAppointmentDate: resolvedLastDate,
      totalVisits: visitCount,
      primaryCondition: primaryConditionStr,
      notes: map['notes']?.toString() ?? '',
      allergies: allergiesStr,
      medicalConditions: conditionsStr,
      dateOfBirth: parsedDob,
      currentMedicines: const [],
      medicalHistory: const [],
      medicalReports: const [],
      aiSummary: '',
    );
  }

  DoctorPatientModel copyWith({
    String? id,
    String? name,
    String? photoUrl,
    int? age,
    String? gender,
    String? phone,
    String? bloodGroup,
    String? lastVisit,
    DateTime? lastAppointmentDate,
    int? totalVisits,
    String? primaryCondition,
    String? notes,
    String? allergies,
    String? medicalConditions,
    DateTime? dateOfBirth,
    List<String>? currentMedicines,
    List<String>? medicalHistory,
    List<Map<String, String>>? medicalReports,
    String? aiSummary,
  }) {
    return DoctorPatientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      lastVisit: lastVisit ?? this.lastVisit,
      lastAppointmentDate: lastAppointmentDate ?? this.lastAppointmentDate,
      totalVisits: totalVisits ?? this.totalVisits,
      primaryCondition: primaryCondition ?? this.primaryCondition,
      notes: notes ?? this.notes,
      allergies: allergies ?? this.allergies,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      currentMedicines: currentMedicines ?? this.currentMedicines,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      medicalReports: medicalReports ?? this.medicalReports,
      aiSummary: aiSummary ?? this.aiSummary,
    );
  }

  static List<DoctorPatientModel> get dummyPatients => [
        DoctorPatientModel(
          id: 'p-1',
          name: 'Ali Khan',
          age: 28,
          gender: 'Male',
          phone: '+92 301 5551234',
          bloodGroup: 'O+',
          lastVisit: '15 Aug 2026',
          totalVisits: 4,
          primaryCondition: 'General Wellness & Routine Checkup',
          notes:
              'Blood pressure normal. Vitals stable. Advised regular exercise and continuing prescribed vitamins.',
          allergies: 'None added',
          medicalConditions: 'None added',
          currentMedicines: const ['Vitamin C 500mg', 'Panadol 500mg'],
          aiSummary:
              'Patient has a history of routine blood testing. Current medicines include Vitamin C and Panadol. No recorded allergies.',
        ),
        DoctorPatientModel(
          id: 'p-2',
          name: 'Fatima Ahmed',
          age: 30,
          gender: 'Female',
          phone: '+92 321 4445678',
          bloodGroup: 'B+',
          lastVisit: '27 Aug 2026',
          totalVisits: 2,
          primaryCondition: 'Palpitations & Follow-up',
          notes:
              'ECG normal sinus rhythm. Advised lifestyle modifications and follow-up if symptoms persist.',
          allergies: 'Penicillin (mild rash)',
          medicalConditions: 'Mild Palpitations',
          currentMedicines: const ['Propranolol 10mg', 'Multivitamin'],
          aiSummary:
              'Follow-up patient with resolved mild palpitations. History of penicillin allergy noted.',
        ),
        DoctorPatientModel(
          id: 'p-3',
          name: 'Usman Ali',
          age: 45,
          gender: 'Male',
          phone: '+92 333 7778899',
          bloodGroup: 'A+',
          lastVisit: '25 Aug 2026',
          totalVisits: 6,
          primaryCondition: 'Type 2 Diabetes & CAD Evaluation',
          notes:
              'Regular cardiac follow-up. Lipid profile monitored every 6 months.',
          allergies: 'None added',
          medicalConditions: 'Type 2 Diabetes',
          currentMedicines: const ['Metformin 500mg', 'Atorvastatin 10mg'],
          aiSummary:
              'Patient managing Type 2 Diabetes with routine lipid and cardiovascular monitoring. Good treatment adherence.',
        ),
        DoctorPatientModel(
          id: 'p-4',
          name: 'Hassan Raza',
          age: 38,
          gender: 'Male',
          phone: '+92 345 1112233',
          bloodGroup: 'O+',
          lastVisit: '28 Aug 2026',
          totalVisits: 3,
          primaryCondition: 'General Consultation',
          notes: 'Consultation completed. Routine labs reviewed and satisfactory.',
          allergies: 'None added',
          medicalConditions: 'None added',
          currentMedicines: const ['Omega-3 Fish Oil', 'Vitamin D3'],
          aiSummary:
              'Completed annual physical consultation. All vital parameters within normal ranges.',
        ),
        DoctorPatientModel(
          id: 'p-5',
          name: 'Ayesha Malik',
          age: 34,
          gender: 'Female',
          phone: '+92 312 3334455',
          bloodGroup: 'AB+',
          lastVisit: '26 Aug 2026',
          totalVisits: 1,
          primaryCondition: 'Follow-up Consultation',
          notes: 'Appointment was cancelled by clinic due to schedule conflict.',
          allergies: 'Sulfa drugs',
          medicalConditions: 'Allergic Rhinitis',
          currentMedicines: const ['Cetirizine 10mg'],
          aiSummary:
              'Recent follow-up request cancelled. Recorded allergy to sulfa medications.',
        ),
        DoctorPatientModel(
          id: 'p-6',
          name: 'Zainab Bibi',
          age: 52,
          gender: 'Female',
          phone: '+92 345 8889900',
          bloodGroup: 'AB+',
          lastVisit: '20 Aug 2026',
          totalVisits: 3,
          primaryCondition: 'Mild Angina Screening',
          notes: 'Advised stress test and adherence to prescribed medications.',
          medicalConditions: 'Mild Angina',
        ),
      ];

  static DoctorPatientModel getPatientByName(String name) {
    return dummyPatients.firstWhere(
      (p) => p.name.toLowerCase() == name.toLowerCase(),
      orElse: () => DoctorPatientModel(
        id: 'p-gen',
        name: name,
        age: 30,
        gender: 'Not specified',
        phone: 'Not provided',
        bloodGroup: 'Not specified',
        lastVisit: 'Recent',
        totalVisits: 1,
        primaryCondition: 'General Medical Care',
        notes: 'Patient profile created for clinical consultation.',
      ),
    );
  }
}
