class ClinicServiceModel {
  final String id;
  final String? clinicId;
  final String? doctorId;
  String name;
  double fee;
  bool isActive;

  ClinicServiceModel({
    required this.id,
    this.clinicId,
    this.doctorId,
    required this.name,
    required this.fee,
    this.isActive = true,
  });

  String get formattedFee {
    // Format fee with commas, e.g., Rs. 2,000
    final feeInt = fee.toInt();
    final formatted = feeInt.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return 'Rs. $formatted';
  }

  ClinicServiceModel copyWith({
    String? id,
    String? clinicId,
    String? doctorId,
    String? name,
    double? fee,
    bool? isActive,
  }) {
    return ClinicServiceModel(
      id: id ?? this.id,
      clinicId: clinicId ?? this.clinicId,
      doctorId: doctorId ?? this.doctorId,
      name: name ?? this.name,
      fee: fee ?? this.fee,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (clinicId != null) 'clinic_id': clinicId,
      if (doctorId != null) 'doctor_id': doctorId,
      'name': name,
      'fee': fee,
      'is_active': isActive,
    };
  }

  Map<String, dynamic> toInsertMap({
    required String clinicId,
    required String doctorId,
  }) {
    final map = <String, dynamic>{
      'clinic_id': clinicId,
      'doctor_id': doctorId,
      'name': name,
      'fee': fee,
      'is_active': isActive,
    };
    // Include id if it's a valid UUID
    final isUuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id);
    if (isUuid) {
      map['id'] = id;
    }
    return map;
  }

  factory ClinicServiceModel.fromMap(Map<String, dynamic> map) {
    return ClinicServiceModel(
      id: map['id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString(),
      doctorId: map['doctor_id']?.toString(),
      name: map['name'] ?? '',
      fee: (map['fee'] as num?)?.toDouble() ?? 0.0,
      isActive: map['is_active'] ?? true,
    );
  }
}

