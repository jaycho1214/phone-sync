import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android_provider/app.dart';

void main() {
  testWidgets('PhoneSyncApp shows setup complete message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: PhoneSyncApp()));

    expect(find.text('PhoneSync - Setup Complete'), findsOneWidget);
  });
}
