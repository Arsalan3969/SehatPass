class DoctorProfileModel {
  final String? doctorId;
  String fullName;
  String specialization;
  String qualifications;
  String experienceYears;
  String bio;
  String? photoUrl;
  bool isPublished;
  double rating;
  int totalReviews;

  DoctorProfileModel({
    this.doctorId,
    this.fullName = '',
    this.specialization = '',
    this.qualifications = '',
    this.experienceYears = '',
    this.bio = '',
    this.photoUrl,
    this.isPublished = false,
    this.rating = 5.0,
    this.totalReviews = 0,
  });

  DoctorProfileModel copyWith({
    String? doctorId,
    String? fullName,
    String? specialization,
    String? qualifications,
    String? experienceYears,
    String? bio,
    String? photoUrl,
    bool? isPublished,
    double? rating,
    int? totalReviews,
  }) {
    return DoctorProfileModel(
      doctorId: doctorId ?? this.doctorId,
      fullName: fullName ?? this.fullName,
      specialization: specialization ?? this.specialization,
      qualifications: qualifications ?? this.qualifications,
      experienceYears: experienceYears ?? this.experienceYears,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      isPublished: isPublished ?? this.isPublished,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (doctorId != null) 'doctor_id': doctorId,
      'full_name': fullName,
      'specialization': specialization,
      'qualifications': qualifications,
      'experience_years': experienceYears,
      'bio': bio,
      'photo_url': photoUrl,
      'is_published': isPublished,
      'rating': rating,
      'total_reviews': totalReviews,
    };
  }

  factory DoctorProfileModel.fromMap(
    Map<String, dynamic> doctorMap, {
    String? fullName,
    String? profilePhotoUrl,
  }) {
    final resolvedName = fullName?.trim() ?? doctorMap['full_name']?.toString().trim() ?? '';
    return DoctorProfileModel(
      doctorId: doctorMap['doctor_id']?.toString(),
      fullName: resolvedName,
      specialization: doctorMap['specialization']?.toString().trim() ?? '',
      qualifications: doctorMap['qualifications']?.toString().trim() ?? '',
      experienceYears: doctorMap['experience_years']?.toString().trim() ?? '',
      bio: doctorMap['bio']?.toString().trim() ?? '',
      photoUrl: profilePhotoUrl ?? doctorMap['photo_url'] ?? doctorMap['profile_photo_url'],
      isPublished: doctorMap['is_published'] == true,
      rating: (doctorMap['rating'] as num?)?.toDouble() ?? 5.0,
      totalReviews: (doctorMap['total_reviews'] as num?)?.toInt() ?? 0,
    );
  }
}

