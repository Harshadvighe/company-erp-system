import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/main.dart';

void main() {
  testWidgets('Saark ERP App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SaarkErpApp()));
    expect(find.byType(SaarkErpApp), findsOneWidget);
  });
}
