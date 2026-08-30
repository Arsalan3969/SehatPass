class DoctorPatientModel {
  final String id;
  final String name;
  final int age;
  final String gender;
  final String phone;
  final String bloodGroup;
  final String lastVisit;
  final int totalVisits;
  final String primaryCondition;
  final String notes;
  final String allergies;
  final List<String> currentMedicines;
  final List<String> medicalHistory;
  final List<Map<String, String>> medicalReports;
  final String aiSummary;

  DoctorPatientModel({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.phone,
    required this.bloodGroup,
    required this.lastVisit,
    required this.totalVisits,
    required this.primaryCondition,
    required this.notes,
    this.allergies = 'None added',
    this.currentMedicines = const ['Vitamin C 500mg', 'Panadol 500mg'],
    this.medicalHistory = const [
      'Routine blood pressure monitoring',
      'Annual preventive cardiac checkup',
      'No major surgical history',
    ],
    this.medicalReports = const [
      {
        'title': 'Complete Blood Count (CBC)',
        'date': '15 Aug 2026',
        'facility': 'Chughtai Lab',
      },
      {
        'title': '12-Lead ECG Report',
        'date': '12 Jun 2026',
        'facility': 'City Heart Clinic',
      },
    ],
    this.aiSummary =
        'Patient has a history of routine blood testing. Current medicines include Vitamin C and Panadol. No recorded allergies.',
  });

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
          currentMedicines: ['Vitamin C 500mg', 'Panadol 500mg'],
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
          currentMedicines: ['Propranolol 10mg', 'Multivitamin'],
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
          currentMedicines: ['Metformin 500mg', 'Atorvastatin 10mg'],
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
          currentMedicines: ['Omega-3 Fish Oil', 'Vitamin D3'],
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
          currentMedicines: ['Cetirizine 10mg'],
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
        ),
      ];

  static DoctorPatientModel getPatientByName(String name) {
    return dummyPatients.firstWhere(
      (p) => p.name.toLowerCase() == name.toLowerCase(),
      orElse: () => DoctorPatientModel(
        id: 'p-gen',
        name: name,
        age: 30,
        gender: 'Male',
        phone: '+92 300 0000000',
        bloodGroup: 'O+',
        lastVisit: '15 Aug 2026',
        totalVisits: 1,
        primaryCondition: 'General Medical Care',
        notes: 'Patient profile created for clinical consultation.',
      ),
    );
  }
}
