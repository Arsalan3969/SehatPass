import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/features/sehat_ai/models/chat_message.dart';
import 'package:sehatpass/features/sehat_ai/models/sehat_ai_response.dart';
import 'package:sehatpass/features/sehat_ai/models/chat_conversation_model.dart';

/// Dart-equivalent of the Edge Function age calculation logic for verification
int? calculateAgeFromDob(String? dobString, {DateTime? now}) {
  if (dobString == null || dobString.trim().isEmpty) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(dobString.trim());
  if (match == null) return null;

  final birthYear = int.parse(match.group(1)!);
  final birthMonth = int.parse(match.group(2)!);
  final birthDay = int.parse(match.group(3)!);

  final today = now ?? DateTime.now();
  final currentYear = today.year;
  final currentMonth = today.month;
  final currentDay = today.day;

  int age = currentYear - birthYear;
  if (currentMonth < birthMonth || (currentMonth == birthMonth && currentDay < birthDay)) {
    age--;
  }

  return (age >= 0 && age <= 130) ? age : null;
}

/// Dart-equivalent of the Edge Function cleanHealthField logic for verification
String? cleanHealthField(String? val) {
  if (val == null || val.trim().isEmpty) return null;
  final trimmed = val.trim();
  final lower = trimmed.toLowerCase();
  if (lower == 'none added' ||
      lower == 'none' ||
      lower == 'not specified' ||
      lower == 'not set' ||
      lower == 'n/a' ||
      lower == 'nil' ||
      lower == 'null') {
    return null;
  }
  return trimmed;
}

/// Dart-equivalent of the Edge Function formatPromptWithContext logic for verification
String formatPatientPromptSnapshot({
  String? fullName,
  String? dob,
  int? age,
  String? gender,
  String? bloodGroup,
  String? allergies,
  String? medicalConditions,
}) {
  var prompt = '=== AUTHENTICATED PATIENT CONTEXT (CONFIDENTIAL VERIFIED USER RECORDS) ===\n\n';
  prompt += 'PATIENT PROFILE:\n';
  prompt += '- Full Name: ${fullName ?? "Not recorded"}\n';
  if (age != null) {
    prompt += '- Age: $age years (Date of Birth: ${dob ?? "Not recorded"})\n';
  } else if (dob != null) {
    prompt += '- Date of Birth: $dob (Age: Not calculated)\n';
  } else {
    prompt += '- Age / Date of Birth: Not recorded\n';
  }
  prompt += '- Gender: ${gender ?? "Not recorded"}\n';
  prompt += '- Blood Group: ${bloodGroup ?? "Not recorded"}\n';
  prompt += '- Known Allergies: ${allergies ?? "None recorded"}\n';
  prompt += '- Known Medical Conditions: ${medicalConditions ?? "None recorded"}\n\n';
  return prompt;
}

void main() {
  group('Sehat AI: Age Calculation & Value Cleaning Tests', () {
    final fixedNow = DateTime(2026, 9, 5);

    test('Calculates correct age when birthday has already occurred this year', () {
      // Born on April 15, 2000 -> As of Sept 5, 2026, age is 26
      expect(calculateAgeFromDob('2000-04-15', now: fixedNow), 26);
    });

    test('Calculates correct age when birthday has NOT occurred yet this year', () {
      // Born on December 20, 2000 -> As of Sept 5, 2026, age is 25
      expect(calculateAgeFromDob('2000-12-20', now: fixedNow), 25);
    });

    test('Calculates correct age on exact birthday', () {
      // Born on Sept 5, 2000 -> Today is Sept 5, 2026, age is exactly 26
      expect(calculateAgeFromDob('2000-09-05', now: fixedNow), 26);
    });

    test('Returns null for missing, null, or empty DOB', () {
      expect(calculateAgeFromDob(null), isNull);
      expect(calculateAgeFromDob(''), isNull);
      expect(calculateAgeFromDob('   '), isNull);
    });

    test('Returns null for invalid or malformed DOB string', () {
      expect(calculateAgeFromDob('not-a-date'), isNull);
      expect(calculateAgeFromDob('2000/05/10'), isNull);
    });

    test('Returns null for future birth date', () {
      // Born in 2030 -> age is negative, should return null
      expect(calculateAgeFromDob('2030-01-01', now: fixedNow), isNull);
    });

    test('cleanHealthField correctly filters placeholders and preserves valid values', () {
      expect(cleanHealthField(null), isNull);
      expect(cleanHealthField(''), isNull);
      expect(cleanHealthField('None added'), isNull);
      expect(cleanHealthField('none added'), isNull);
      expect(cleanHealthField('None'), isNull);
      expect(cleanHealthField('Not specified'), isNull);
      expect(cleanHealthField('not set'), isNull);
      expect(cleanHealthField('N/A'), isNull);
      expect(cleanHealthField('nil'), isNull);

      // Preserves legitimate values
      expect(cleanHealthField('Asthma'), 'Asthma');
      expect(cleanHealthField('Type 2 Diabetes'), 'Type 2 Diabetes');
      expect(cleanHealthField('Penicillin'), 'Penicillin');
      expect(cleanHealthField('B+'), 'B+');
      expect(cleanHealthField('Male'), 'Male');
    });
  });

  group('Sehat AI: Authenticated Patient Prompt Formatting Tests', () {
    test('Formats full patient profile including DOB, calculated age, and conditions', () {
      final dob = '1995-01-01';
      final age = calculateAgeFromDob(dob, now: DateTime(2026, 9, 5));
      final prompt = formatPatientPromptSnapshot(
        fullName: 'Arsalan',
        dob: dob,
        age: age,
        gender: cleanHealthField('Male'),
        bloodGroup: cleanHealthField('B+'),
        allergies: cleanHealthField('Penicillin'),
        medicalConditions: cleanHealthField('Asthma'),
      );

      expect(prompt, contains('=== AUTHENTICATED PATIENT CONTEXT'));
      expect(prompt, contains('- Full Name: Arsalan'));
      expect(prompt, contains('- Age: 31 years (Date of Birth: 1995-01-01)'));
      expect(prompt, contains('- Gender: Male'));
      expect(prompt, contains('- Blood Group: B+'));
      expect(prompt, contains('- Known Allergies: Penicillin'));
      expect(prompt, contains('- Known Medical Conditions: Asthma'));
    });

    test('Handles missing profile fields with safe default fallback strings', () {
      final prompt = formatPatientPromptSnapshot(
        fullName: null,
        dob: null,
        age: null,
        gender: null,
        bloodGroup: null,
        allergies: cleanHealthField('None added'),
        medicalConditions: cleanHealthField('None added'),
      );

      expect(prompt, contains('- Full Name: Not recorded'));
      expect(prompt, contains('- Age / Date of Birth: Not recorded'));
      expect(prompt, contains('- Gender: Not recorded'));
      expect(prompt, contains('- Blood Group: Not recorded'));
      expect(prompt, contains('- Known Allergies: None recorded'));
      expect(prompt, contains('- Known Medical Conditions: None recorded'));
    });
  });

  group('Sehat AI: Patient Context Assembly Models & Privacy Tests', () {
    test('ChatMessage correctly parses citations and model metadata', () {
      final map = {
        'id': 'msg-123',
        'conversation_id': 'conv-456',
        'sender': 'ai',
        'message': 'Your blood group is B+ and your CBC report from Sept 2 shows normal counts.',
        'created_at': '2026-09-05T10:00:00.000Z',
        'metadata': {
          'model': 'gemini-3.6-flash',
          'retrieval_count': 1,
          'citations': [
            {
              'title': 'Complete Blood Count (CBC) Guide',
              'source': 'MedlinePlus',
              'source_url': 'https://medlineplus.gov',
              'similarity': 0.89,
            }
          ]
        }
      };

      final msg = ChatMessage.fromMap(map);

      expect(msg.id, 'msg-123');
      expect(msg.conversationId, 'conv-456');
      expect(msg.isUser, false);
      expect(msg.text, contains('B+'));
      expect(msg.citations.length, 1);
      expect(msg.citations.first.title, 'Complete Blood Count (CBC) Guide');
    });

    test('ChatConversationModel parses conversation records correctly', () {
      final convMap = {
        'id': 'conv-001',
        'user_id': 'user-abc',
        'title': 'Blood Test Inquiry',
        'created_at': '2026-09-05T09:00:00.000Z',
        'updated_at': '2026-09-05T09:15:00.000Z',
      };

      final conv = ChatConversationModel.fromMap(convMap);

      expect(conv.id, 'conv-001');
      expect(conv.userId, 'user-abc');
      expect(conv.title, 'Blood Test Inquiry');
      expect(conv.updatedAt.isAfter(conv.createdAt), true);
    });

    test('SehatAiResponse safely handles empty citations and null metadata', () {
      final json = {
        'answer': 'Your active medicines are Metformin 500mg and Panadol.',
        'citations': [],
        'metadata': {
          'model': 'gemini-3.6-flash',
          'retrieval_count': 0,
        },
      };

      final response = SehatAiResponse.fromJson(json);

      expect(response.answer, contains('Metformin'));
      expect(response.citations, isEmpty);
      expect(response.metadata?['model'], 'gemini-3.6-flash');
    });
  });
}
