import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/features/sehat_ai/models/chat_message.dart';
import 'package:sehatpass/features/sehat_ai/models/citation_item.dart';
import 'package:sehatpass/features/sehat_ai/models/sehat_ai_response.dart';
import 'package:sehatpass/features/sehat_ai/data/sehat_ai_repository.dart';
import 'package:sehatpass/features/sehat_ai/widgets/ai_welcome_card.dart';

void main() {
  group('Sehat AI Models & Parsing Tests', () {
    test('CitationItem parses JSON correctly', () {
      final json = {
        'title': 'Metformin Overview',
        'source': 'MedlinePlus / NIH',
        'source_url': 'https://medlineplus.gov/druginfo/meds/a684058.html',
        'similarity': 0.8456,
      };

      final citation = CitationItem.fromJson(json);

      expect(citation.title, 'Metformin Overview');
      expect(citation.source, 'MedlinePlus / NIH');
      expect(citation.sourceUrl, 'https://medlineplus.gov/druginfo/meds/a684058.html');
      expect(citation.similarity, 0.8456);

      final outJson = citation.toJson();
      expect(outJson['title'], 'Metformin Overview');
      expect(outJson['similarity'], 0.8456);
    });

    test('SehatAiResponse parses full Edge Function response', () {
      final json = {
        'answer': 'Metformin is prescribed for type 2 diabetes management.',
        'citations': [
          {
            'title': 'Metformin Overview',
            'source': 'MedlinePlus / NIH',
            'source_url': 'https://medlineplus.gov/druginfo/meds/a684058.html',
            'similarity': 0.88,
          }
        ],
        'metadata': {
          'model': 'gemini-3.6-flash',
          'retrieval_count': 1,
        },
      };

      final response = SehatAiResponse.fromJson(json);

      expect(response.answer, 'Metformin is prescribed for type 2 diabetes management.');
      expect(response.citations.length, 1);
      expect(response.citations.first.title, 'Metformin Overview');
      expect(response.metadata?['model'], 'gemini-3.6-flash');
    });

    test('ChatMessage parses from Supabase database row', () {
      final row = {
        'sender': 'ai',
        'message': 'Always consult a doctor before changing dosages.',
        'created_at': '2026-09-01T12:00:00.000Z',
        'metadata': {
          'citations': [
            {
              'title': 'Medication Safety',
              'source': 'FDA',
              'source_url': 'https://fda.gov',
              'similarity': 0.91,
            }
          ]
        }
      };

      final msg = ChatMessage.fromMap(row);

      expect(msg.isUser, false);
      expect(msg.sender, MessageSender.ai);
      expect(msg.text, 'Always consult a doctor before changing dosages.');
      expect(msg.citations.length, 1);
      expect(msg.citations.first.source, 'FDA');
      expect(msg.timestamp.year, 2026);
    });

    test('SehatAiException formats messages and status codes', () {
      const ex = SehatAiException(
        'Sehat AI is temporarily unavailable. Please try again.',
        statusCode: 502,
        code: 'AI_PROVIDER_ERROR',
      );

      expect(ex.toString(), 'Sehat AI is temporarily unavailable. Please try again.');
      expect(ex.statusCode, 502);
      expect(ex.code, 'AI_PROVIDER_ERROR');
    });

    testWidgets('AiWelcomeCard displays actual patient name and fallback', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiWelcomeCard(patientName: 'Arsalan'),
          ),
        ),
      );

      expect(find.text('Hi Arsalan 👋'), findsOneWidget);
      expect(find.text('Hi Abdul 👋'), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiWelcomeCard(patientName: null),
          ),
        ),
      );

      expect(find.text('Hi there 👋'), findsOneWidget);
    });
  });
}
