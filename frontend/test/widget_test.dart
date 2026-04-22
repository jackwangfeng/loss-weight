import 'package:flutter_test/flutter_test.dart';

import 'package:loss_weight/main.dart';
import 'package:loss_weight/providers/locale_provider.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(CutBroApp(localeProvider: LocaleProvider()));
    await tester.pump();
  });
}
