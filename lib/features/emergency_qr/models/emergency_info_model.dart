import 'package:flutter/foundation.dart';

/// Model representing patient emergency information and privacy/sharing settings.
/// Backed by `public.emergency_settings`, `public.profiles`, `public.patient_profiles`,
/// and `public.patient_medicines` in Supabase.
class EmergencyInfoData {
  final String identifier;
  final String fullName;
  final String bloodGroup;
  final String allergies;
  final String medicalConditions;
  final String importantMedicines;
  final String emergencyContactName;
  final String emergencyContactRelationship;
  final String emergencyContactPhone;

  // Toggle flags for emergency QR sharing
  final bool shareName;
  final bool shareBloodGroup;
  final bool shareAllergies;
  final bool shareMedicalConditions;
  final bool shareImportantMedicines;
  final bool shareEmergencyContact;

  final bool isActive;
  final DateTime? updatedAt;

  const EmergencyInfoData({
    this.identifier = '',
    this.fullName = '',
    this.bloodGroup = '',
    this.allergies = '',
    this.medicalConditions = '',
    this.importantMedicines = '',
    this.emergencyContactName = '',
    this.emergencyContactRelationship = '',
    this.emergencyContactPhone = '',
    this.shareName = true,
    this.shareBloodGroup = true,
    this.shareAllergies = true,
    this.shareMedicalConditions = true,
    this.shareImportantMedicines = true,
    this.shareEmergencyContact = true,
    this.isActive = true,
    this.updatedAt,
  });

  /// Factory constructor to parse map representations from Supabase or RPC.
  factory EmergencyInfoData.fromMap(
    Map<String, dynamic> map, {
    String fullName = '',
    String bloodGroup = '',
    String allergies = '',
    String medicalConditions = '',
    String importantMedicines = '',
  }) {
    return EmergencyInfoData(
      identifier: (map['emergency_token'] ?? map['identifier'] ?? '').toString(),
      fullName: (map['full_name'] ?? fullName).toString(),
      bloodGroup: (map['blood_group'] ?? bloodGroup).toString(),
      allergies: (map['allergies'] ?? allergies).toString(),
      medicalConditions: (map['medical_conditions'] ?? medicalConditions).toString(),
      importantMedicines: (map['important_medicines'] ?? importantMedicines).toString(),
      emergencyContactName: (map['contact_name'] ?? map['emergency_contact_name'] ?? '').toString(),
      emergencyContactRelationship: (map['contact_relationship'] ?? map['emergency_contact_relationship'] ?? '').toString(),
      emergencyContactPhone: (map['contact_phone'] ?? map['emergency_contact_phone'] ?? '').toString(),
      shareName: map['share_name'] is bool ? map['share_name'] as bool : true,
      shareBloodGroup: map['share_blood_group'] is bool ? map['share_blood_group'] as bool : true,
      shareAllergies: map['share_allergies'] is bool ? map['share_allergies'] as bool : true,
      shareMedicalConditions: map['share_medical_conditions'] is bool ? map['share_medical_conditions'] as bool : true,
      shareImportantMedicines: map['share_important_medicines'] is bool ? map['share_important_medicines'] as bool : true,
      shareEmergencyContact: map['share_emergency_contact'] is bool ? map['share_emergency_contact'] as bool : true,
      isActive: map['is_active'] is bool ? map['is_active'] as bool : true,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  /// Converts sharing flags and contact information to Supabase `emergency_settings` map.
  Map<String, dynamic> toEmergencySettingsMap({String? patientId}) {
    final map = <String, dynamic>{
      'contact_name': emergencyContactName,
      'contact_relationship': emergencyContactRelationship,
      'contact_phone': emergencyContactPhone,
      'share_name': shareName,
      'share_blood_group': shareBloodGroup,
      'share_allergies': shareAllergies,
      'share_medical_conditions': shareMedicalConditions,
      'share_important_medicines': shareImportantMedicines,
      'share_emergency_contact': shareEmergencyContact,
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (patientId != null && patientId.isNotEmpty) {
      map['patient_id'] = patientId;
    }
    if (identifier.isNotEmpty) {
      map['emergency_token'] = identifier;
    }
    return map;
  }

  /// Checks whether any sharing toggle is active.
  bool get hasAnySharedInfo =>
      shareName ||
      shareBloodGroup ||
      shareAllergies ||
      shareMedicalConditions ||
      shareImportantMedicines ||
      shareEmergencyContact;

  /// Checks whether an emergency contact has been configured.
  bool get hasEmergencyContact =>
      emergencyContactName.trim().isNotEmpty &&
      emergencyContactPhone.trim().isNotEmpty;

  /// Checks whether the primary emergency health info is filled in.
  bool get isComplete =>
      bloodGroup.trim().isNotEmpty &&
      bloodGroup != 'None added' &&
      hasEmergencyContact;

  /// Returns a clean formatted contact summary.
  String get formattedEmergencyContact {
    if (!hasEmergencyContact) return 'No emergency contact added';
    if (emergencyContactRelationship.trim().isNotEmpty) {
      return '$emergencyContactName ($emergencyContactRelationship) • $emergencyContactPhone';
    }
    return '$emergencyContactName • $emergencyContactPhone';
  }

  EmergencyInfoData copyWith({
    String? identifier,
    String? fullName,
    String? bloodGroup,
    String? allergies,
    String? medicalConditions,
    String? importantMedicines,
    String? emergencyContactName,
    String? emergencyContactRelationship,
    String? emergencyContactPhone,
    bool? shareName,
    bool? shareBloodGroup,
    bool? shareAllergies,
    bool? shareMedicalConditions,
    bool? shareImportantMedicines,
    bool? shareEmergencyContact,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return EmergencyInfoData(
      identifier: identifier ?? this.identifier,
      fullName: fullName ?? this.fullName,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      importantMedicines: importantMedicines ?? this.importantMedicines,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactRelationship:
          emergencyContactRelationship ?? this.emergencyContactRelationship,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      shareName: shareName ?? this.shareName,
      shareBloodGroup: shareBloodGroup ?? this.shareBloodGroup,
      shareAllergies: shareAllergies ?? this.shareAllergies,
      shareMedicalConditions:
          shareMedicalConditions ?? this.shareMedicalConditions,
      shareImportantMedicines:
          shareImportantMedicines ?? this.shareImportantMedicines,
      shareEmergencyContact:
          shareEmergencyContact ?? this.shareEmergencyContact,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Backward compatibility provider for any legacy listeners during migration.
class EmergencyInfoRepository extends ChangeNotifier {
  EmergencyInfoRepository._();
  static final EmergencyInfoRepository instance = EmergencyInfoRepository._();

  EmergencyInfoData _data = const EmergencyInfoData();

  EmergencyInfoData get data => _data;

  void update(EmergencyInfoData newData) {
    _data = newData;
    notifyListeners();
  }
}
