import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formfit_ai/main.dart';

void main() {
  testWidgets('onboarding, auth, tabs, and exercise flow', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FormFitApp()));
    await tester.pumpAndSettle();

    expect(find.text('Train with AI spotting'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('See your progress'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('FormFit AI'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);

    await tester.tap(find.text('Continue as Guest'));
    await tester.pumpAndSettle();
    expect(find.text('Push-Ups'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('End session'), findsOneWidget);
    expect(find.text('Camera preview'), findsOneWidget);

    await tester.tap(find.text('End session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Session complete'), findsOneWidget);

    await tester.tap(find.text('Save & Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Push-Ups'), findsWidgets);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsWidgets);

    await tester.tap(find.text('Leaderboard'));
    await tester.pumpAndSettle();
    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('Jordan Lee'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Guest Athlete'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  });
}
