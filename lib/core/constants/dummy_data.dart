// Dummy data models for SehatPass

class DummyMedicine {
  final String name;
  final String dose;
  final String time;
  final String mealNote;

  const DummyMedicine({
    required this.name,
    required this.dose,
    required this.time,
    required this.mealNote,
  });
}

// Lightweight report model used on the Home screen
class DummyReport {
  final String title;
  final String date;
  final String type;

  const DummyReport({
    required this.title,
    required this.date,
    required this.type,
  });
}

/// Report category used for filter chips on the Reports screen.
enum ReportCategory { all, bloodTest, scan, other }

extension ReportCategoryLabel on ReportCategory {
  String get label {
    switch (this) {
      case ReportCategory.all:
        return 'All';
      case ReportCategory.bloodTest:
        return 'Blood Tests';
      case ReportCategory.scan:
        return 'Scans';
      case ReportCategory.other:
        return 'Other';
    }
  }
}

/// Full report model used on the Reports screen.
class ReportItem {
  final String name;
  final String lab;
  final String date;
  final ReportCategory category;

  const ReportItem({
    required this.name,
    required this.lab,
    required this.date,
    required this.category,
  });
}

class DummyData {
  DummyData._();

  static const String patientName = 'Abdul';

  static const DummyMedicine nextMedicine = DummyMedicine(
    name: 'Panadol',
    dose: '1 Tablet',
    time: '8:00 PM',
    mealNote: 'After Dinner',
  );

  static const DummyReport latestReport = DummyReport(
    title: 'Blood Test',
    date: '25 August 2026',
    type: 'Laboratory',
  );

  static const List<DummyMedicine> todaySchedule = [
    DummyMedicine(
      name: 'Panadol',
      dose: '1 Tablet',
      time: '8:00 PM',
      mealNote: 'After Dinner',
    ),
    DummyMedicine(
      name: 'Vitamin C',
      dose: '1 Capsule',
      time: '9:00 AM',
      mealNote: 'After Breakfast',
    ),
  ];

  static const List<DummyReport> recentReports = [
    DummyReport(
      title: 'Blood Test',
      date: '25 Aug 2026',
      type: 'Laboratory',
    ),
    DummyReport(
      title: 'CBC Report',
      date: '12 Aug 2026',
      type: 'Laboratory',
    ),
  ];

  // ── Reports screen data ───────────────────────────────────────────────────

  static const List<ReportItem> allReports = [
    ReportItem(
      name: 'Blood Test',
      lab: 'City Laboratory',
      date: '25 Aug 2026',
      category: ReportCategory.bloodTest,
    ),
    ReportItem(
      name: 'CBC Report',
      lab: 'Chughtai Lab',
      date: '12 Aug 2026',
      category: ReportCategory.bloodTest,
    ),
    ReportItem(
      name: 'Chest X-Ray',
      lab: 'General Hospital',
      date: '05 Aug 2026',
      category: ReportCategory.scan,
    ),
    ReportItem(
      name: 'Liver Function Test',
      lab: 'City Laboratory',
      date: '28 Jul 2026',
      category: ReportCategory.bloodTest,
    ),
  ];
}
