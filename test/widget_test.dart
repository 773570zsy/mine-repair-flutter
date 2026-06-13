import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mine_repair_flutter/app.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MineRepairApp()));
    // Use pump with duration instead of pumpAndSettle to avoid
    // infinite animation/redirect issues with go_router login redirect
    await tester.pump(const Duration(seconds: 1));

    // App should render (login page or redirect to login)
    expect(find.byType(MineRepairApp), findsOneWidget);
  });
}
