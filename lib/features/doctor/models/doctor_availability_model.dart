import 'package:flutter/material.dart';

class DoctorAvailabilityModel {
  List<String> selectedDays;
  TimeOfDay startTime;
  TimeOfDay endTime;

  DoctorAvailabilityModel({
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
    List<String>? selectedDays,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) {
    return DoctorAvailabilityModel(
      selectedDays: selectedDays != null
          ? List<String>.from(selectedDays)
          : List<String>.from(this.selectedDays),
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'selected_days': selectedDays,
      'start_time': '${startTime.hour}:${startTime.minute}',
      'end_time': '${endTime.hour}:${endTime.minute}',
    };
  }
}
