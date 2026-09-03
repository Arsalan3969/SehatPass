import 'package:flutter/material.dart';

class DoctorAvailabilityModel {
  final String? clinicId;
  final String? doctorId;
  List<String> selectedDays;
  TimeOfDay startTime;
  TimeOfDay endTime;

  DoctorAvailabilityModel({
    this.clinicId,
    this.doctorId,
    List<String>? selectedDays,
    this.startTime = const TimeOfDay(hour: 10, minute: 0),
    this.endTime = const TimeOfDay(hour: 16, minute: 0),
  }) : selectedDays = selectedDays ??
            [
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
            ];

  static const List<String> allDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String get formattedHours {
    return '${formatTime(startTime)} - ${formatTime(endTime)}';
  }

  String get formattedDays {
    if (selectedDays.isEmpty) return 'No days selected';
    if (selectedDays.length == 7) return 'Everyday (Mon - Sun)';

    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    if (selectedDays.length == 5 &&
        weekdays.every((d) => selectedDays.contains(d))) {
      return 'Monday - Friday';
    }

    const weekends = ['Saturday', 'Sunday'];
    if (selectedDays.length == 2 &&
        weekends.every((d) => selectedDays.contains(d))) {
      return 'Weekends (Sat - Sun)';
    }

    if (selectedDays.length <= 3) {
      return selectedDays.join(', ');
    }

    return '${selectedDays.first} - ${selectedDays.last} (${selectedDays.length} days)';
  }

  DoctorAvailabilityModel copyWith({
    String? clinicId,
    String? doctorId,
    List<String>? selectedDays,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) {
    return DoctorAvailabilityModel(
      clinicId: clinicId ?? this.clinicId,
      doctorId: doctorId ?? this.doctorId,
      selectedDays: selectedDays != null
          ? List<String>.from(selectedDays)
          : List<String>.from(this.selectedDays),
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (clinicId != null) 'clinic_id': clinicId,
      if (doctorId != null) 'doctor_id': doctorId,
      'selected_days': selectedDays,
      'start_time': '${startTime.hour}:${startTime.minute}',
      'end_time': '${endTime.hour}:${endTime.minute}',
    };
  }

  List<Map<String, dynamic>> toInsertRows({
    required String doctorId,
    String? clinicId,
  }) {
    final startStr =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
    final endStr =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

    return selectedDays.map((day) {
      return <String, dynamic>{
        'doctor_id': doctorId,
        if (clinicId != null && clinicId.isNotEmpty) 'clinic_id': clinicId,
        'day_of_week': day,
        'start_time': startStr,
        'end_time': endStr,
        'is_available': true,
      };
    }).toList();
  }

  factory DoctorAvailabilityModel.fromDbRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return DoctorAvailabilityModel();
    }

    final days = <String>[];
    TimeOfDay parsedStart = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay parsedEnd = const TimeOfDay(hour: 16, minute: 0);
    String? clinicId;
    String? doctorId;

    for (final row in rows) {
      if (row['is_available'] == true) {
        final day = row['day_of_week']?.toString();
        if (day != null && day.isNotEmpty) {
          days.add(day);
        }
      }
      clinicId ??= row['clinic_id']?.toString();
      doctorId ??= row['doctor_id']?.toString();

      final sTime = row['start_time']?.toString();
      if (sTime != null && sTime.contains(':')) {
        final parts = sTime.split(':');
        final h = int.tryParse(parts[0]) ?? 10;
        final m = int.tryParse(parts[1]) ?? 0;
        parsedStart = TimeOfDay(hour: h, minute: m);
      }

      final eTime = row['end_time']?.toString();
      if (eTime != null && eTime.contains(':')) {
        final parts = eTime.split(':');
        final h = int.tryParse(parts[0]) ?? 16;
        final m = int.tryParse(parts[1]) ?? 0;
        parsedEnd = TimeOfDay(hour: h, minute: m);
      }
    }

    return DoctorAvailabilityModel(
      clinicId: clinicId,
      doctorId: doctorId,
      selectedDays: days.isNotEmpty ? days : null,
      startTime: parsedStart,
      endTime: parsedEnd,
    );
  }
}

