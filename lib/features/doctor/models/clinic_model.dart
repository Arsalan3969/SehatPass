class ClinicModel {
  final String? id;
  final String? doctorId;
  String name;
  String address;
  String city;
  String phone;
  String description;
  String? logoUrl;
  bool isActive;

  ClinicModel({
    this.id,
    this.doctorId,
    this.name = '',
    this.address = '',
    this.city = 'Lahore',
    this.phone = '',
    this.description = '',
    this.logoUrl,
    this.isActive = true,
  });

  ClinicModel copyWith({
    String? id,
    String? doctorId,
    String? name,
    String? address,
    String? city,
    String? phone,
    String? description,
    String? logoUrl,
    bool? isActive,
  }) {
    return ClinicModel(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (doctorId != null) 'doctor_id': doctorId,
      'name': name,
      'address': address,
      'city': city,
      'phone': phone,
      'description': description,
      'logo_url': logoUrl,
      'is_active': isActive,
    };
  }

  factory ClinicModel.fromMap(Map<String, dynamic> map) {
    return ClinicModel(
      id: map['id']?.toString(),
      doctorId: map['doctor_id']?.toString(),
      name: map['name']?.toString().trim() ?? '',
      address: map['address']?.toString().trim() ?? '',
      city: map['city']?.toString().trim() ?? 'Lahore',
      phone: map['phone']?.toString().trim() ?? '',
      description: map['description']?.toString().trim() ?? '',
      logoUrl: map['logo_url']?.toString(),
      isActive: map['is_active'] ?? true,
    );
  }
}

