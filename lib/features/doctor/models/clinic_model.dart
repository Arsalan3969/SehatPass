class ClinicModel {
  String name;
  String address;
  String city;
  String phone;
  String description;
  String? logoUrl;

  ClinicModel({
    this.name = 'City Heart Clinic',
    this.address = 'Main Boulevard, Lahore',
    this.city = 'Lahore',
    this.phone = '+92 42 35789000',
    this.description =
        'A modern clinic providing cardiology consultation and follow-up care.',
    this.logoUrl,
  });

  ClinicModel copyWith({
    String? name,
    String? address,
    String? city,
    String? phone,
    String? description,
    String? logoUrl,
  }) {
    return ClinicModel(
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'phone': phone,
      'description': description,
      'logo_url': logoUrl,
    };
  }
}
