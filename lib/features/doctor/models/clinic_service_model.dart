class ClinicServiceModel {
  final String id;
  String name;
  double fee;

  ClinicServiceModel({
    required this.id,
    required this.name,
    required this.fee,
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
    String? name,
    double? fee,
  }) {
    return ClinicServiceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      fee: fee ?? this.fee,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'fee': fee,
    };
  }

  factory ClinicServiceModel.fromMap(Map<String, dynamic> map) {
    return ClinicServiceModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      fee: (map['fee'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
