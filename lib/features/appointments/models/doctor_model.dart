/// Doctor service model.
class DoctorService {
  final String? id;
  final String name;
  final int fee;

  const DoctorService({
    this.id,
    required this.name,
    required this.fee,
  });

  factory DoctorService.fromMap(Map<String, dynamic> map) {
    return DoctorService(
      id: map['id']?.toString(),
      name: map['name']?.toString() ?? 'General Consultation',
      fee: (map['fee'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'fee': fee,
    };
  }
}

/// Doctor data model for the appointment feature backed by Supabase.
class Doctor {
  final String id;
  final String name;
  final String specialization;
  final String clinic;
  final String? clinicId;
  final String location;
  final double rating;
  final int totalReviews;
  final int consultationFee;
  final String availability; // e.g. "Available Today", "Available Tomorrow"
  final String about;
  final List<String> availableDays;
  final String consultationHours;
  final List<DoctorService> services;
  final String? photoUrl;
  final String qualifications;
  final String experienceYears;

  const Doctor({
    required this.id,
    required this.name,
    required this.specialization,
    required this.clinic,
    this.clinicId,
    required this.location,
    this.rating = 0.0,
    this.totalReviews = 0,
    required this.consultationFee,
    required this.availability,
    required this.about,
    required this.availableDays,
    required this.consultationHours,
    required this.services,
    this.photoUrl,
    this.qualifications = '',
    this.experienceYears = '',
  });

  factory Doctor.fromMap(Map<String, dynamic> map) {
    // 1. Profile / Doctor Name
    final profile = map['profiles'] is Map ? map['profiles'] as Map : null;
    final rawName = profile?['full_name']?.toString().trim() ??
        map['full_name']?.toString().trim() ??
        map['name']?.toString().trim() ??
        '';

    final String doctorName;
    if (rawName.isEmpty) {
      doctorName = 'Doctor';
    } else if (rawName.toLowerCase().startsWith('dr.') ||
        rawName.toLowerCase().startsWith('dr ')) {
      doctorName = rawName;
    } else {
      doctorName = 'Dr. $rawName';
    }

    final photo = profile?['profile_photo_url']?.toString() ??
        map['profile_photo_url']?.toString() ??
        map['photo_url']?.toString();

    // 2. Doctor Profile fields
    final doctorId = map['doctor_id']?.toString() ??
        map['id']?.toString() ??
        profile?['id']?.toString() ??
        '';
    final rawSpec = map['specialization']?.toString().trim();
    final specialization = (rawSpec != null && rawSpec.isNotEmpty)
        ? rawSpec
        : 'Specialization not provided';

    final qualifications = map['qualifications']?.toString().trim() ?? '';
    final experienceYears = map['experience_years']?.toString().trim() ?? '';
    final rawBio = map['bio']?.toString().trim() ?? map['about']?.toString().trim();
    final about = (rawBio != null && rawBio.isNotEmpty)
        ? rawBio
        : 'No biography provided yet.';
    final rating = (map['rating'] as num?)?.toDouble() ?? 0.0;
    final totalReviews = (map['total_reviews'] as num?)?.toInt() ?? 0;

    // 3. Clinic fields
    String clinicName = 'Clinic not specified';
    String? clinicId;
    String location = 'Location not provided';

    if (map['clinics'] != null) {
      if (map['clinics'] is List && (map['clinics'] as List).isNotEmpty) {
        final c = (map['clinics'] as List).first as Map;
        clinicId = c['id']?.toString();
        final cName = c['name']?.toString().trim();
        if (cName != null && cName.isNotEmpty) {
          clinicName = cName;
        }
        final city = c['city']?.toString().trim();
        final addr = c['address']?.toString().trim();
        if (city != null && city.isNotEmpty && addr != null && addr.isNotEmpty) {
          location = '$addr, $city';
        } else if (city != null && city.isNotEmpty) {
          location = city;
        } else if (addr != null && addr.isNotEmpty) {
          location = addr;
        }
      } else if (map['clinics'] is Map) {
        final c = map['clinics'] as Map;
        clinicId = c['id']?.toString();
        final cName = c['name']?.toString().trim();
        if (cName != null && cName.isNotEmpty) {
          clinicName = cName;
        }
        final city = c['city']?.toString().trim();
        final addr = c['address']?.toString().trim();
        if (city != null && city.isNotEmpty && addr != null && addr.isNotEmpty) {
          location = '$addr, $city';
        } else if (city != null && city.isNotEmpty) {
          location = city;
        } else if (addr != null && addr.isNotEmpty) {
          location = addr;
        }
      }
    } else {
      final directClinic = map['clinic']?.toString().trim() ?? map['clinic_name']?.toString().trim();
      if (directClinic != null && directClinic.isNotEmpty) {
        clinicName = directClinic;
      }
      final directLoc = map['location']?.toString().trim() ?? map['city']?.toString().trim();
      if (directLoc != null && directLoc.isNotEmpty) {
        location = directLoc;
      }
      clinicId = map['clinic_id']?.toString();
    }

    // 4. Services
    final List<DoctorService> parsedServices = [];
    if (map['clinic_services'] is List) {
      for (final s in map['clinic_services'] as List) {
        if (s is Map) {
          parsedServices.add(DoctorService.fromMap(Map<String, dynamic>.from(s)));
        }
      }
    } else if (map['services'] is List) {
      for (final s in map['services'] as List) {
        if (s is DoctorService) {
          parsedServices.add(s);
        } else if (s is Map) {
          parsedServices.add(DoctorService.fromMap(Map<String, dynamic>.from(s)));
        }
      }
    }

    // Determine consultation fee from services or direct field
    int baseFee = 0;
    if (parsedServices.isNotEmpty) {
      baseFee = parsedServices.first.fee;
    } else {
      final explicitFee = (map['consultation_fee'] as num?)?.toInt() ??
          (map['consultationFee'] as num?)?.toInt() ??
          (map['fee'] as num?)?.toInt();
      if (explicitFee != null && explicitFee > 0) {
        baseFee = explicitFee;
        parsedServices.add(DoctorService(
          name: 'General Consultation',
          fee: baseFee,
        ));
      }
    }

    // 5. Availability Schedule
    final List<String> parsedDays = [];
    String consultationHours = 'Consultation hours not specified';
    if (map['doctor_availability'] is List && (map['doctor_availability'] as List).isNotEmpty) {
      final availList = map['doctor_availability'] as List;
      for (final a in availList) {
        if (a is Map) {
          final day = a['day_of_week']?.toString();
          if (day != null && !parsedDays.contains(day)) {
            parsedDays.add(day);
          }
          final start = a['start_time']?.toString();
          final end = a['end_time']?.toString();
          if (start != null && end != null) {
            consultationHours = _formatTimeRange(start, end);
          }
        }
      }
    } else if (map['available_days'] is List) {
      parsedDays.addAll((map['available_days'] as List).map((e) => e.toString()));
    } else if (map['availableDays'] is List) {
      parsedDays.addAll((map['availableDays'] as List).map((e) => e.toString()));
    }

    if (parsedDays.isNotEmpty && consultationHours == 'Consultation hours not specified') {
      consultationHours = '10:00 AM - 4:00 PM';
    }

    // Availability badge label
    final availability = _computeAvailability(parsedDays);

    return Doctor(
      id: doctorId,
      name: doctorName,
      specialization: specialization,
      clinic: clinicName,
      clinicId: clinicId,
      location: location,
      rating: rating,
      totalReviews: totalReviews,
      consultationFee: baseFee,
      availability: availability,
      about: about,
      availableDays: parsedDays,
      consultationHours: consultationHours,
      services: parsedServices,
      photoUrl: photo,
      qualifications: qualifications,
      experienceYears: experienceYears,
    );
  }

  static String _formatTimeRange(String start, String end) {
    String formatSingle(String t) {
      try {
        final parts = t.split(':');
        if (parts.length >= 2) {
          int hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          final period = hour >= 12 ? 'PM' : 'AM';
          if (hour > 12) hour -= 12;
          if (hour == 0) hour = 12;
          final minuteStr = minute.toString().padLeft(2, '0');
          return '$hour:$minuteStr $period';
        }
      } catch (_) {}
      return t;
    }

    return '${formatSingle(start)} - ${formatSingle(end)}';
  }

  static String _computeAvailability(List<String> days) {
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final today = DateTime.now();
    final todayDayName = dayNames[today.weekday - 1];
    final tomorrowDayName = dayNames[today.weekday % 7];

    if (days.contains(todayDayName)) {
      return 'Available Today';
    } else if (days.contains(tomorrowDayName)) {
      return 'Available Tomorrow';
    } else if (days.isNotEmpty) {
      return 'Available ${days.first}';
    }
    return 'Available on Request';
  }
}
