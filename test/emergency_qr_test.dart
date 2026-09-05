import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/features/emergency_qr/data/emergency_repository.dart';
import 'package:sehatpass/features/emergency_qr/emergency_info_preview_screen.dart';
import 'package:sehatpass/features/emergency_qr/emergency_qr_screen.dart';
import 'package:sehatpass/features/emergency_qr/manage_emergency_info_screen.dart';
import 'package:sehatpass/features/emergency_qr/models/emergency_info_model.dart';

class MockEmergencyRepository extends EmergencyRepository {
  EmergencyInfoData dataToReturn;
  final String? errorToThrow;
  int getEmergencyInfoCallCount = 0;
  int saveEmergencySettingsCallCount = 0;
  int regenerateEmergencyTokenCallCount = 0;
  int getPublicEmergencyInfoCallCount = 0;

  EmergencyInfoData? lastSavedData;
  String? lastPublicTokenRequested;

  MockEmergencyRepository({
    EmergencyInfoData? initialData,
    this.errorToThrow,
  }) : dataToReturn = initialData ??
            const EmergencyInfoData(
              identifier: 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
              fullName: 'Abdul Wahab',
              bloodGroup: 'O+',
              allergies: 'Penicillin',
              medicalConditions: 'Asthma',
              importantMedicines: 'Ventolin (100mcg)',
              emergencyContactName: 'Muhammad Arsalan',
              emergencyContactRelationship: 'Friend',
              emergencyContactPhone: '+92 300 1234567',
              shareName: true,
              shareBloodGroup: true,
              shareAllergies: true,
              shareMedicalConditions: true,
              shareImportantMedicines: true,
              shareEmergencyContact: true,
            );

  @override
  Future<EmergencyInfoData> getEmergencyInfo() async {
    getEmergencyInfoCallCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return dataToReturn;
  }

  @override
  Future<EmergencyInfoData> saveEmergencySettings(EmergencyInfoData data) async {
    saveEmergencySettingsCallCount++;
    lastSavedData = data;
    dataToReturn = data;
    return data;
  }

  @override
  Future<String> regenerateEmergencyToken() async {
    regenerateEmergencyTokenCallCount++;
    const newToken = 'f9e8d7c6-b5a4-4321-9876-fedcba098765';
    dataToReturn = dataToReturn.copyWith(identifier: newToken);
    return newToken;
  }

  @override
  Future<Map<String, dynamic>?> getPublicEmergencyInfo(String token) async {
    getPublicEmergencyInfoCallCount++;
    lastPublicTokenRequested = token;
    if (token == dataToReturn.identifier) {
      return {
        'full_name': dataToReturn.shareName ? dataToReturn.fullName : null,
        'blood_group':
            dataToReturn.shareBloodGroup ? dataToReturn.bloodGroup : null,
        'allergies':
            dataToReturn.shareAllergies ? dataToReturn.allergies : null,
        'medical_conditions': dataToReturn.shareMedicalConditions
            ? dataToReturn.medicalConditions
            : null,
        'important_medicines': dataToReturn.shareImportantMedicines
            ? [
                {'name': 'Ventolin', 'dosage': '100mcg'}
              ]
            : null,
        'emergency_contact': dataToReturn.shareEmergencyContact
            ? {
                'name': dataToReturn.emergencyContactName,
                'relationship': dataToReturn.emergencyContactRelationship,
                'phone': dataToReturn.emergencyContactPhone,
              }
            : null,
      };
    }
    return {'error': 'Invalid or revoked emergency QR code.'};
  }
}

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: child,
  );
}

void main() {
  group('EmergencyInfoData Model Unit Tests', () {
    test('Default model has all share flags enabled by default', () {
      const model = EmergencyInfoData();
      expect(model.shareName, isTrue);
      expect(model.shareBloodGroup, isTrue);
      expect(model.shareAllergies, isTrue);
      expect(model.shareMedicalConditions, isTrue);
      expect(model.shareImportantMedicines, isTrue);
      expect(model.shareEmergencyContact, isTrue);
      expect(model.hasAnySharedInfo, isTrue);
      expect(model.isComplete, isFalse);
    });

    test('isComplete returns true when blood group and contact are valid', () {
      const completeModel = EmergencyInfoData(
        bloodGroup: 'A+',
        emergencyContactName: 'Fatima',
        emergencyContactPhone: '+92 300 9999999',
      );
      expect(completeModel.isComplete, isTrue);
      expect(completeModel.hasEmergencyContact, isTrue);
    });

    test('isComplete returns false when blood group or contact phone is missing', () {
      const incomplete1 = EmergencyInfoData(
        bloodGroup: '',
        emergencyContactName: 'Fatima',
        emergencyContactPhone: '+92 300 9999999',
      );
      expect(incomplete1.isComplete, isFalse);

      const incomplete2 = EmergencyInfoData(
        bloodGroup: 'B+',
        emergencyContactName: '',
        emergencyContactPhone: '',
      );
      expect(incomplete2.isComplete, isFalse);
    });

    test('Serialization to/from Supabase map preserves all fields', () {
      final now = DateTime.now();
      final map = {
        'emergency_token': '11112222-3333-4444-5555-666677778888',
        'contact_name': 'Ali Khan',
        'contact_relationship': 'Brother',
        'contact_phone': '+92 321 1234567',
        'share_name': true,
        'share_blood_group': false,
        'share_allergies': true,
        'share_medical_conditions': false,
        'share_important_medicines': true,
        'share_emergency_contact': false,
        'updated_at': now.toIso8601String(),
      };

      final parsed = EmergencyInfoData.fromMap(
        map,
        fullName: 'Zubair Ahmed',
        bloodGroup: 'AB+',
        allergies: 'Pollen',
        medicalConditions: 'Hypertension',
        importantMedicines: 'Lisinopril 10mg',
      );

      expect(parsed.identifier, '11112222-3333-4444-5555-666677778888');
      expect(parsed.fullName, 'Zubair Ahmed');
      expect(parsed.bloodGroup, 'AB+');
      expect(parsed.allergies, 'Pollen');
      expect(parsed.medicalConditions, 'Hypertension');
      expect(parsed.importantMedicines, 'Lisinopril 10mg');
      expect(parsed.emergencyContactName, 'Ali Khan');
      expect(parsed.emergencyContactRelationship, 'Brother');
      expect(parsed.emergencyContactPhone, '+92 321 1234567');
      expect(parsed.shareBloodGroup, isFalse);
      expect(parsed.shareMedicalConditions, isFalse);
      expect(parsed.shareEmergencyContact, isFalse);

      final outMap = parsed.toEmergencySettingsMap(patientId: 'patient-uuid-123');
      expect(outMap['patient_id'], 'patient-uuid-123');
      expect(outMap['emergency_token'], '11112222-3333-4444-5555-666677778888');
      expect(outMap['contact_name'], 'Ali Khan');
      expect(outMap['share_blood_group'], isFalse);
    });

    test('generateSecureUuidV4 produces valid RFC 4122 v4 UUID format', () {
      final uuid = EmergencyRepository.generateSecureUuidV4();
      expect(uuid.length, 36);
      expect(uuid[14], '4'); // version 4
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(uuid), isTrue);
    });
  });

  group('EmergencyRepository URL Building Tests', () {
    test('buildEmergencyAccessUrl uses EMERGENCY_WEB_URL when configured', () async {
      await dotenv.load(mergeWith: {
        'SUPABASE_URL': 'https://vnavceiizdjekbmtzpsn.supabase.co',
        'EMERGENCY_WEB_URL': 'https://sehat-pass.vercel.app',
      });

      final repo = EmergencyRepository.instance;
      final url = repo.buildEmergencyAccessUrl('a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d');
      expect(url, 'https://sehat-pass.vercel.app/?token=a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d');
      expect(url.contains('supabase.co/functions/v1/emergency-access'), isFalse);
    });

    test('buildEmergencyAccessUrl handles trailing slash in EMERGENCY_WEB_URL cleanly', () async {
      await dotenv.load(mergeWith: {
        'EMERGENCY_WEB_URL': 'https://sehat-pass.vercel.app/',
      });

      final repo = EmergencyRepository.instance;
      final url = repo.buildEmergencyAccessUrl('test-uuid-1234');
      expect(url, 'https://sehat-pass.vercel.app/?token=test-uuid-1234');
    });

    test('buildEmergencyAccessUrl falls back to Supabase Edge Function when EMERGENCY_WEB_URL is absent', () async {
      await dotenv.load(mergeWith: {
        'SUPABASE_URL': 'https://vnavceiizdjekbmtzpsn.supabase.co',
        'EMERGENCY_WEB_URL': '',
      });

      final repo = EmergencyRepository.instance;
      final url = repo.buildEmergencyAccessUrl('a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d');
      expect(url, 'https://vnavceiizdjekbmtzpsn.supabase.co/functions/v1/emergency-access?token=a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d');
    });

    test('buildEmergencyAccessUrl returns empty string for empty token', () {
      final repo = EmergencyRepository.instance;
      expect(repo.buildEmergencyAccessUrl(''), '');
      expect(repo.buildEmergencyAccessUrl('   '), '');
    });
  });

  group('EmergencyQrScreen Widget Tests', () {
    testWidgets('Renders patient name, Token ID, and QRImageView with non-sensitive token',
        (tester) async {
      final mockRepo = MockEmergencyRepository();

      await tester.pumpWidget(createTestApp(
        EmergencyQrScreen(repository: mockRepo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Emergency QR'), findsWidgets);
      expect(find.text('Abdul Wahab'), findsOneWidget);
      expect(
        find.textContaining('Token: a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'),
        findsOneWidget,
      );

      // Verify QR widget is rendered
      final qrFinder = find.byType(QrImageView);
      expect(qrFinder, findsOneWidget);

      // Verify the token chip displays the secure non-sensitive identifier
      final tokenChipFinder = find.textContaining('Token: a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d');
      expect(tokenChipFinder, findsOneWidget);
    });

    testWidgets('Renders Incomplete Information advisory banner when medical info is missing',
        (tester) async {
      final mockRepo = MockEmergencyRepository(
        initialData: const EmergencyInfoData(
          identifier: 'token-incomplete-1',
          fullName: 'Test Patient',
          bloodGroup: '',
          emergencyContactName: '',
          emergencyContactPhone: '',
        ),
      );

      await tester.pumpWidget(createTestApp(
        EmergencyQrScreen(repository: mockRepo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Emergency information is incomplete'), findsOneWidget);
      expect(find.text('Complete Information →'), findsOneWidget);
    });

    testWidgets('Tapping Reset Emergency QR opens dialog and regenerates token upon confirmation',
        (tester) async {
      final mockRepo = MockEmergencyRepository();

      await tester.pumpWidget(createTestApp(
        EmergencyQrScreen(repository: mockRepo),
      ));
      await tester.pumpAndSettle();

      // Find and tap the reset action
      final refreshIconFinder = find.byTooltip('Regenerate QR Token');
      expect(refreshIconFinder, findsOneWidget);
      await tester.tap(refreshIconFinder);
      await tester.pumpAndSettle();

      expect(find.text('Reset Emergency QR'), findsOneWidget);
      expect(
        find.text('Regenerating your QR token will immediately invalidate any existing printed or shared QR codes. Do you want to proceed?'),
        findsOneWidget,
      );

      // Confirm reset
      await tester.tap(find.text('Reset QR'));
      await tester.pumpAndSettle();

      expect(mockRepo.regenerateEmergencyTokenCallCount, 1);
      expect(
        find.textContaining('Token: f9e8d7c6-b5a4-4321-9876-fedcba098765'),
        findsOneWidget,
      );
    });

    testWidgets('Displays error state with retry button when loading fails',
        (tester) async {
      final mockRepo = MockEmergencyRepository(
        errorToThrow: 'Network connectivity lost.',
      );

      await tester.pumpWidget(createTestApp(
        EmergencyQrScreen(repository: mockRepo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Unable to Load Emergency Data'), findsOneWidget);
      expect(find.text('Network connectivity lost.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });
  });

  group('ManageEmergencyInfoScreen Widget Tests', () {
    testWidgets('Renders all 6 sharing switches and allows toggling',
        (tester) async {
      final mockRepo = MockEmergencyRepository();

      await tester.pumpWidget(createTestApp(
        ManageEmergencyInfoScreen(
          repository: mockRepo,
          initialData: mockRepo.dataToReturn,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Medical Information'), findsOneWidget);
      expect(find.text('Emergency Contact'), findsOneWidget);

      // 6 Switches for the 6 sharing toggles
      expect(find.byType(Switch), findsNWidgets(6));
    });

    testWidgets('Editing emergency contact and saving calls saveEmergencySettings with updated values',
        (tester) async {
      final mockRepo = MockEmergencyRepository();

      await tester.pumpWidget(createTestApp(
        ManageEmergencyInfoScreen(
          repository: mockRepo,
          initialData: mockRepo.dataToReturn,
        ),
      ));
      await tester.pumpAndSettle();

      // Scroll to Edit Contact and tap
      final editContactFinder = find.text('Edit Contact');
      await tester.ensureVisible(editContactFinder);
      await tester.pumpAndSettle();
      await tester.tap(editContactFinder);
      await tester.pumpAndSettle();

      expect(find.text('Contact Full Name'), findsOneWidget);

      // Fill in new phone and relationship
      await tester.enterText(find.widgetWithText(TextFormField, 'Phone Number'), '+92 333 7654321');
      await tester.pump();

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Scroll to Save Changes and save
      final saveFinder = find.text('Save Changes');
      await tester.ensureVisible(saveFinder);
      await tester.pumpAndSettle();
      await tester.tap(saveFinder);
      await tester.pumpAndSettle();

      expect(mockRepo.saveEmergencySettingsCallCount, 1);
      expect(mockRepo.lastSavedData?.emergencyContactPhone, '+92 333 7654321');
    });
  });

  group('EmergencyInfoPreviewScreen Widget Tests', () {
    testWidgets('Renders only enabled fields and respects privacy settings',
        (tester) async {
      final mockRepo = MockEmergencyRepository();

      await tester.pumpWidget(createTestApp(
        EmergencyInfoPreviewScreen(
          repository: mockRepo,
          initialData: mockRepo.dataToReturn,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Public View'), findsOneWidget);
      expect(find.text('Abdul Wahab'), findsOneWidget);
      expect(find.text('O+'), findsOneWidget);
      expect(find.text('Penicillin'), findsOneWidget);
      expect(find.text('Asthma'), findsOneWidget);
      expect(find.text('Ventolin (100mcg)'), findsOneWidget);
      expect(find.text('Muhammad Arsalan'), findsOneWidget);
      expect(find.text('Contact Emergency Contact'), findsOneWidget);
    });

    testWidgets('Displays No Information Shared empty card when all sharing flags are disabled',
        (tester) async {
      final mockRepo = MockEmergencyRepository(
        initialData: const EmergencyInfoData(
          identifier: 'token-hidden',
          fullName: 'Hidden Patient',
          bloodGroup: 'AB+',
          shareName: false,
          shareBloodGroup: false,
          shareAllergies: false,
          shareMedicalConditions: false,
          shareImportantMedicines: false,
          shareEmergencyContact: false,
        ),
      );

      await tester.pumpWidget(createTestApp(
        EmergencyInfoPreviewScreen(
          repository: mockRepo,
          initialData: mockRepo.dataToReturn,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No Information Shared'), findsOneWidget);
      expect(
        find.text('The patient has turned off all emergency sharing toggles.'),
        findsOneWidget,
      );
    });
  });
}
