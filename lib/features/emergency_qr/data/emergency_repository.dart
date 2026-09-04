import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/emergency_info_model.dart';

/// Repository responsible for patient Emergency Information and Emergency QR settings.
///
/// Backed authoritatively by Supabase tables:
/// - `public.emergency_settings` (Contact, QR token, `is_active` toggle & privacy toggles)
/// - `public.profiles` (Patient full name)
/// - `public.patient_profiles` (Blood group, allergies, chronic conditions)
/// - `public.patient_medicines` (Active medications list)
///
/// Scoped strictly to the currently authenticated user (`_client.auth.currentUser.id`).
class EmergencyRepository {
  final SupabaseClient? _clientOverride;

  EmergencyRepository({SupabaseClient? client}) : _clientOverride = client;

  static final EmergencyRepository instance = EmergencyRepository();

  SupabaseClient get _client {
    final override = _clientOverride;
    if (override != null) return override;
    return Supabase.instance.client;
  }

  /// Resolves the authenticated user ID.
  String? get currentUserId {
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// Generates a cryptographically secure RFC 4122 compliant version 4 UUID.
  static String generateSecureUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 10
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Constructs the full secure HTTPS public web profile URL for emergency responders.
  String buildEmergencyAccessUrl(String token) {
    if (token.trim().isEmpty) return '';

    // 1. Check for dedicated deployed emergency web app domain (e.g. Vercel/Netlify/custom domain)
    String? webUrl;
    try {
      webUrl = dotenv.isInitialized ? dotenv.env['EMERGENCY_WEB_URL'] : null;
    } catch (_) {
      webUrl = null;
    }

    if (webUrl != null && webUrl.trim().isNotEmpty) {
      final cleanWeb = webUrl.trim().endsWith('/')
          ? webUrl.trim().substring(0, webUrl.trim().length - 1)
          : webUrl.trim();
      return '$cleanWeb/?token=${token.trim()}';
    }

    // 2. Default fallback to Supabase Edge Function
    String? baseUrl;
    try {
      baseUrl = dotenv.isInitialized ? dotenv.env['SUPABASE_URL'] : null;
    } catch (_) {
      baseUrl = null;
    }
    baseUrl ??= 'https://vnavceiizdjekbmtzpsn.supabase.co';
    final cleanBase =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$cleanBase/functions/v1/emergency-access?token=${token.trim()}';
  }

  /// Fetches complete aggregated emergency information for the current patient.
  Future<EmergencyInfoData> getEmergencyInfo() async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      return const EmergencyInfoData();
    }

    try {
      // 1. Fetch Profile Name
      String fullName = '';
      try {
        final profile = await _client
            .from('profiles')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();
        if (profile != null && profile['full_name'] != null) {
          fullName = profile['full_name'].toString();
        }
      } catch (e) {
        debugPrint('EmergencyRepository: Error fetching profile: $e');
      }

      // 2. Fetch Medical Profile (Blood group, allergies, conditions)
      String bloodGroup = '';
      String allergies = '';
      String medicalConditions = '';
      try {
        final patientProfile = await _client
            .from('patient_profiles')
            .select('blood_group, allergies, medical_conditions')
            .eq('patient_id', userId)
            .maybeSingle();
        if (patientProfile != null) {
          bloodGroup = (patientProfile['blood_group'] ?? '').toString();
          allergies = (patientProfile['allergies'] ?? '').toString();
          medicalConditions =
              (patientProfile['medical_conditions'] ?? '').toString();
        }
      } catch (e) {
        debugPrint('EmergencyRepository: Error fetching patient profile: $e');
      }

      // 3. Fetch Active Medications
      String importantMedicines = '';
      try {
        final medicines = await _client
            .from('patient_medicines')
            .select('name, dosage')
            .eq('patient_id', userId)
            .eq('is_active', true)
            .order('created_at', ascending: true);

        final medList = (medicines as List)
            .map((m) {
              final name = (m['name'] ?? '').toString();
              final dosage = (m['dosage'] ?? '').toString();
              if (dosage.isNotEmpty) return '$name ($dosage)';
              return name;
            })
            .where((m) => m.trim().isNotEmpty)
            .toList();

        if (medList.isNotEmpty) {
          importantMedicines = medList.join(', ');
        }
      } catch (e) {
        debugPrint('EmergencyRepository: Error fetching active medicines: $e');
      }

      // 4. Fetch Emergency Settings
      Map<String, dynamic>? emergencySettings;
      try {
        final res = await _client
            .from('emergency_settings')
            .select()
            .eq('patient_id', userId)
            .maybeSingle();

        if (res != null) {
          emergencySettings = Map<String, dynamic>.from(res as Map);
        }
      } catch (e) {
        debugPrint('EmergencyRepository: Error fetching emergency_settings: $e');
      }

      // 5. If emergency_settings does not exist, initialize with safe defaults
      if (emergencySettings == null) {
        final initialToken = generateSecureUuidV4();
        final initialMap = {
          'patient_id': userId,
          'emergency_token': initialToken,
          'contact_name': '',
          'contact_relationship': '',
          'contact_phone': '',
          'share_name': true,
          'share_blood_group': true,
          'share_allergies': true,
          'share_medical_conditions': true,
          'share_important_medicines': true,
          'share_emergency_contact': true,
          'is_active': true,
          'updated_at': DateTime.now().toIso8601String(),
        };

        try {
          final inserted = await _client
              .from('emergency_settings')
              .upsert(initialMap, onConflict: 'patient_id')
              .select()
              .single();
          emergencySettings = Map<String, dynamic>.from(inserted as Map);
        } catch (e) {
          debugPrint('EmergencyRepository: Error initializing emergency_settings: $e');
          emergencySettings = initialMap;
        }
      }

      final infoData = EmergencyInfoData.fromMap(
        emergencySettings,
        fullName: fullName,
        bloodGroup: bloodGroup,
        allergies: allergies,
        medicalConditions: medicalConditions,
        importantMedicines: importantMedicines,
      );

      // Keep in-memory repository updated
      EmergencyInfoRepository.instance.update(infoData);

      return infoData;
    } catch (e) {
      debugPrint('EmergencyRepository: Exception in getEmergencyInfo: $e');
      throw 'Unable to load emergency information. Please try again.';
    }
  }

  /// Saves emergency settings and sharing toggles authoritatively for current user.
  Future<EmergencyInfoData> saveEmergencySettings(EmergencyInfoData data) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw 'User is not authenticated.';
    }

    try {
      final token = data.identifier.isNotEmpty
          ? data.identifier
          : generateSecureUuidV4();

      final payload = <String, dynamic>{
        'patient_id': userId,
        'emergency_token': token,
        'contact_name': data.emergencyContactName,
        'contact_relationship': data.emergencyContactRelationship,
        'contact_phone': data.emergencyContactPhone,
        'share_name': data.shareName,
        'share_blood_group': data.shareBloodGroup,
        'share_allergies': data.shareAllergies,
        'share_medical_conditions': data.shareMedicalConditions,
        'share_important_medicines': data.shareImportantMedicines,
        'share_emergency_contact': data.shareEmergencyContact,
        'is_active': data.isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('emergency_settings')
          .upsert(payload, onConflict: 'patient_id')
          .select()
          .single();

      final updated = data.copyWith(
        identifier: (response['emergency_token'] ?? token).toString(),
        isActive: response['is_active'] is bool ? response['is_active'] as bool : true,
        updatedAt: response['updated_at'] != null
            ? DateTime.tryParse(response['updated_at'].toString())
            : DateTime.now(),
      );

      EmergencyInfoRepository.instance.update(updated);

      return updated;
    } catch (e) {
      debugPrint('EmergencyRepository: Error saving emergency settings: $e');
      throw 'Failed to save emergency information. Please try again.';
    }
  }

  /// Toggles emergency access active status (`is_active` in emergency_settings)
  Future<bool> setEmergencyAccessActive(bool isActive) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw 'User is not authenticated.';
    }

    try {
      await _client
          .from('emergency_settings')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('patient_id', userId);

      final current = EmergencyInfoRepository.instance.data;
      EmergencyInfoRepository.instance.update(
        current.copyWith(isActive: isActive),
      );

      return isActive;
    } catch (e) {
      debugPrint('EmergencyRepository: Error updating emergency active status: $e');
      throw 'Unable to update emergency access status.';
    }
  }

  /// Regenerates the patient's Emergency QR token, invalidating all previous QR codes.
  Future<String> regenerateEmergencyToken() async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw 'User is not authenticated.';
    }

    try {
      final newToken = generateSecureUuidV4();
      final response = await _client
          .from('emergency_settings')
          .update({
            'emergency_token': newToken,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('patient_id', userId)
          .select('emergency_token')
          .single();

      final tokenResult = (response['emergency_token'] ?? newToken).toString();

      final current = EmergencyInfoRepository.instance.data;
      EmergencyInfoRepository.instance.update(
        current.copyWith(identifier: tokenResult),
      );

      return tokenResult;
    } catch (e) {
      debugPrint('EmergencyRepository: Error regenerating emergency token: $e');
      throw 'Unable to regenerate emergency QR. Please try again.';
    }
  }

  /// Calls the secure PostgreSQL RPC `get_public_emergency_info` to safely fetch
  /// what an authorized responder/scanner sees for the given QR token.
  Future<Map<String, dynamic>?> getPublicEmergencyInfo(String token) async {
    if (token.trim().isEmpty) return null;

    try {
      final response = await _client.rpc(
        'get_public_emergency_info',
        params: {'p_token': token.trim()},
      );

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return null;
    } catch (e) {
      debugPrint('EmergencyRepository: Error calling get_public_emergency_info RPC: $e');
      return null;
    }
  }
}
