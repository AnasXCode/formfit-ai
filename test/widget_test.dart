import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formfit_ai/main.dart';

void main() {
  testWidgets('onboarding leads to auth buttons', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FormFitApp()));
    await tester.pumpAndSettle();

    expect(find.text('Train with AI spotting'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('FormFit AI'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
  });
}
