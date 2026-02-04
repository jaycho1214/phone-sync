import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:desktop_client/app.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(child: PhoneSyncApp()),
    );

    // Verify that the app launches without errors.
    expect(find.text('PhoneSync'), findsNothing); // App title is in window, not widget tree
  });
}
