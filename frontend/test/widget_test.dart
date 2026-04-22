import 'package:flutter_test/flutter_test.dart';

import 'package:loss_weight/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const CutBroApp());
    await tester.pump();
  });
}
