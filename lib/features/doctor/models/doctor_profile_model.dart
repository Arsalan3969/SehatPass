class DoctorProfileModel {
  String fullName;
  String specialization;
  String qualifications;
  String experienceYears;
  String bio;
  String? photoUrl;

  DoctorProfileModel({
    this.fullName = 'Dr. Ahmed Khan',
    this.specialization = 'Cardiologist',
    this.qualifications = 'MBBS, FCPS',
    this.experienceYears = '8 years',
    this.bio = 'Cardiologist providing general and specialized cardiac consultation.',
    this.photoUrl,
  });

  DoctorProfileModel copyWith({
    String? fullName,
    String? specialization,
    String? qualifications,
    String? experienceYears,
    String? bio,
    String? photoUrl,
  }) {
    return DoctorProfileModel(
      fullName: fullName ?? this.fullName,
      specialization: specialization ?? this.specialization,
      qualifications: qualifications ?? this.qualifications,
      experienceYears: experienceYears ?? this.experienceYears,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'full_name': fullName,
      'specialization': specialization,
      'qualifications': qualifications,
      'experience_years': experienceYears,
      'bio': bio,
      'photo_url': photoUrl,
    };
  }
}
