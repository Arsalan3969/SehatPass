import 'package:flutter/foundation.dart';

/// Model representing patient emergency information and privacy/sharing settings.
/// In future iterations, [identifier] will be replaced by a secure backend-signed token/URL.
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

  const EmergencyInfoData({
    this.identifier = 'SEHATPASS-EMERGENCY-USER-001',
    this.fullName = 'Abdul Wahab',
    this.bloodGroup = 'O+',
    this.allergies = 'None added',
    this.medicalConditions = 'None added',
    this.importantMedicines = 'None added',
    this.emergencyContactName = 'Muhammad Arsalan',
    this.emergencyContactRelationship = 'Friend',
    this.emergencyContactPhone = '+92 XXX XXXXXXX',
    this.shareName = true,
    this.shareBloodGroup = true,
    this.shareAllergies = true,
    this.shareMedicalConditions = true,
    this.shareImportantMedicines = true,
    this.shareEmergencyContact = true,
  });

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
    );
  }
}

/// Simple in-memory repository with a ChangeNotifier to keep emergency
/// settings synchronized across screens locally.
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
