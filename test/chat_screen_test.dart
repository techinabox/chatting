import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ephemeral_chat/screens/chat_screen.dart';
import 'package:ephemeral_chat/providers/chat_providers.dart';
import 'dart:async';

void main() {
  testWidgets('ChatScreen shows messages, input field and image button', (WidgetTester tester) async {
    final messagesController = StreamController<List<Map<String, dynamic>>>();
    final roomController = StreamController<Map<String, dynamic>?>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messagesStreamProvider('test_room').overrideWith((ref) => messagesController.stream),
          roomStreamProvider('test_room').overrideWith((ref) => roomController.stream),
        ],
        child: const MaterialApp(
          home: ChatScreen(roomId: 'test_room'),
        ),
      ),
    );

    // Initial state: loading
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    // Emit room data to keep the screen alive
    roomController.add({'id': 'test_room', 'status': 'active'});
    
    // Emit some messages
    messagesController.add([
      {'id': '1', 'content': 'Hello world', 'type': 'text'},
      {'id': '2', 'content': 'Image incoming', 'type': 'text'}
    ]);
    
    await tester.pumpAndSettle();

    // Verify UI elements
    expect(find.text('Hello world'), findsOneWidget);
    expect(find.text('Image incoming'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.image), findsOneWidget); // Assuming an image icon is used for the image button
    expect(find.byIcon(Icons.send), findsOneWidget); // Assuming a send icon is used for the send button
  });

  testWidgets('ChatScreen pops when room is destroyed (Realtime kick-out)', (WidgetTester tester) async {
    final messagesController = StreamController<List<Map<String, dynamic>>>();
    final roomController = StreamController<Map<String, dynamic>?>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messagesStreamProvider('test_room').overrideWith((ref) => messagesController.stream),
          roomStreamProvider('test_room').overrideWith((ref) => roomController.stream),
        ],
        child: MaterialApp(
          routes: {
            '/': (context) => const Scaffold(body: Text('Home Screen')),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/chat') {
              return MaterialPageRoute(
                builder: (context) => const ChatScreen(roomId: 'test_room'),
              );
            }
            return null;
          },
          initialRoute: '/',
        ),
      ),
    );

    // Navigate to chat
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/chat');
    
    // Emit empty messages list to avoid indefinite CircularProgressIndicator animation
    messagesController.add([]);
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);

    // Emit room data - active
    roomController.add({'id': 'test_room', 'status': 'active'});
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);

    // Emit room destroyed (kick-out)
    roomController.add(null);
    await tester.pumpAndSettle();

    // Should pop back to Home Screen
    expect(find.byType(ChatScreen), findsNothing);
    expect(find.text('Home Screen'), findsOneWidget);
  });
}
