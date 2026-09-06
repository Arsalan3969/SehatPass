import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/features/sehat_ai/models/chat_message.dart';
import 'package:sehatpass/features/sehat_ai/models/citation_item.dart';
import 'package:sehatpass/features/sehat_ai/models/sehat_ai_response.dart';
import 'package:sehatpass/features/sehat_ai/data/sehat_ai_repository.dart';
import 'package:sehatpass/features/sehat_ai/sehat_ai_screen.dart';
import 'package:sehatpass/features/sehat_ai/widgets/ai_welcome_card.dart';

class MockSehatAiRepository extends SehatAiRepository {
  String mockPatientName = 'Arsalan';
  String? lastSentMessage;
  List<ChatMessage>? lastSessionHistory;
  bool shouldThrow = false;

  @override
  Future<String> getPatientName() async => mockPatientName;

  @override
  Future<SehatAiResponse> sendMessage(
    String message, {
    List<ChatMessage>? sessionHistory,
  }) async {
    if (shouldThrow) {
      throw const SehatAiException(
        'AI service error',
        statusCode: 500,
        code: 'INTERNAL_ERROR',
      );
    }
    lastSentMessage = message;
    lastSessionHistory = sessionHistory != null ? List.from(sessionHistory) : null;

    return SehatAiResponse(
      answer: 'Response to: $message',
      citations: [
        const CitationItem(
          title: 'Health Guide',
          source: 'Verified Medline',
          sourceUrl: 'https://medlineplus.gov',
          similarity: 0.95,
        ),
      ],
    );
  }
}

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

    test('ChatMessage parses from data map correctly', () {
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

  group('Sehat AI Fresh Session & Chat Tests (No History / Stateless Session)', () {
    late MockSehatAiRepository mockRepo;

    setUp(() {
      mockRepo = MockSehatAiRepository();
    });

    testWidgets('Opening Sehat AI starts fresh in landing mode with Welcome Card & Quick Actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SehatAiScreen(repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Verified: Welcome Card appears with patient name
      expect(find.text('Hi Arsalan 👋'), findsOneWidget);
      expect(find.byType(AiWelcomeCard), findsOneWidget);

      // Verified: Quick action prompts exist
      expect(find.text('My Health Summary'), findsOneWidget);
      expect(find.text('Explain My Report'), findsOneWidget);
      expect(find.text('Medicine Information'), findsOneWidget);

      // Verified: Input field is ready
      expect(find.text('Ask anything about your health...'), findsOneWidget);
    });

    testWidgets('Chat History UI is completely absent (no history icon, no drawer)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SehatAiScreen(repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Verified: No history icon / tooltip exists
      expect(find.byTooltip('Chat History'), findsNothing);
      expect(find.byIcon(Icons.history_rounded), findsNothing);
      expect(find.text('Chat History'), findsNothing);
    });

    testWidgets('Sending a message renders active conversation bubbles and hides welcome card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SehatAiScreen(repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Send a user question
      await tester.enterText(find.byType(TextField), 'What is my blood group?');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // Welcome card hidden, message bubbles displayed
      expect(find.byType(AiWelcomeCard), findsNothing);
      expect(find.text('What is my blood group?'), findsOneWidget);
      expect(find.text('Response to: What is my blood group?'), findsOneWidget);
      expect(find.text('Verified Medline'), findsOneWidget);
    });

    testWidgets('Tapping a Quick Action sends the prompt immediately', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SehatAiScreen(repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure widget is visible in SingleChildScrollView before tapping
      await tester.ensureVisible(find.text('My Health Summary'));
      await tester.pumpAndSettle();

      // Tap "My Health Summary" card
      await tester.tap(find.text('My Health Summary'));
      await tester.pumpAndSettle();

      expect(mockRepo.lastSentMessage, 'My Health Summary');
      expect(find.text('My Health Summary'), findsOneWidget);
      expect(find.text('Response to: My Health Summary'), findsOneWidget);
    });

    testWidgets('Current session maintains multi-turn conversation and passes session history', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SehatAiScreen(repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Turn 1
      await tester.enterText(find.byType(TextField), 'What medications am I taking?');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(mockRepo.lastSentMessage, 'What medications am I taking?');
      expect(mockRepo.lastSessionHistory, isEmpty);

      // Turn 2
      await tester.enterText(find.byType(TextField), 'Are there any side effects?');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(mockRepo.lastSentMessage, 'Are there any side effects?');
      // Previous messages were passed in sessionHistory
      expect(mockRepo.lastSessionHistory, isNotNull);
      expect(mockRepo.lastSessionHistory!.length, 2);
      expect(mockRepo.lastSessionHistory![0].text, 'What medications am I taking?');
      expect(mockRepo.lastSessionHistory![1].text, 'Response to: What medications am I taking?');

      // Both exchanges are visible in the current session
      expect(find.text('What medications am I taking?'), findsOneWidget);
      expect(find.text('Are there any side effects?'), findsOneWidget);
    });

    testWidgets('New Chat button resets the current session to clean landing mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SehatAiScreen(repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Send a message
      await tester.enterText(find.byType(TextField), 'Explain my CBC report');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Explain my CBC report'), findsOneWidget);
      expect(find.byType(AiWelcomeCard), findsNothing);

      // Tap New Chat button in AppBar
      await tester.tap(find.byTooltip('New Chat'));
      await tester.pumpAndSettle();

      // Resets cleanly to fresh landing mode
      expect(find.byType(AiWelcomeCard), findsOneWidget);
      expect(find.text('Hi Arsalan 👋'), findsOneWidget);
      expect(find.text('Explain my CBC report'), findsNothing);
    });

    testWidgets('Error during sendMessage surfaces user-friendly error snackbar', (tester) async {
      mockRepo.shouldThrow = true;

      await tester.pumpWidget(
        MaterialApp(
          home: SehatAiScreen(repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Test error query');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('AI service error'), findsOneWidget);
    });
  });
}
