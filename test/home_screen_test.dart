import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ephemeral_chat/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen has Create and Join flows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    // Verify "Create Room" button exists
    expect(find.text('Create Room'), findsOneWidget);

    // Verify "Join Room" button exists
    expect(find.text('Join Room'), findsOneWidget);

    // Tap "Join Room" to reveal the invite code input
    await tester.tap(find.text('Join Room'));
    await tester.pumpAndSettle();

    // Verify there's an input field for the invite code
    expect(find.byType(TextField), findsOneWidget);

    // Try to enter a short invite code and submit
    await tester.enterText(find.byType(TextField), 'shortcode');

    // Find submit or join button in the form
    final joinSubmitButton = find.text('Join');
    expect(joinSubmitButton, findsOneWidget);
    await tester.tap(joinSubmitButton);
    await tester.pumpAndSettle();

    // Should see validation error
    expect(
      find.text('Invite code must be at least 20 characters'),
      findsOneWidget,
    );

    // Enter invalid non-alphanumeric code (20+ chars)
    await tester.enterText(
      find.byType(TextField),
      'thisisatwentycharactercode123!',
    );
    await tester.tap(joinSubmitButton);
    await tester.pumpAndSettle();

    // Should see alphanumeric validation error
    expect(find.text('Invite code must be alphanumeric'), findsOneWidget);

    // Enter valid invite code
    await tester.enterText(
      find.byType(TextField),
      'thisisatwentycharactercode123',
    );
    await tester.tap(joinSubmitButton);
    await tester.pumpAndSettle();

    // Validation errors should be gone
    expect(
      find.text('Invite code must be at least 20 characters'),
      findsNothing,
    );
    expect(find.text('Invite code must be alphanumeric'), findsNothing);
  });
}
