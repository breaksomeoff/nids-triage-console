import 'package:flutter_test/flutter_test.dart';

import 'package:nids_triage_console/main.dart';

void main() {
  testWidgets('home screen shows the analyst name and the alert queue', (
    tester,
  ) async {
    await tester.pumpWidget(const NidsTriageConsoleApp());

    expect(find.text('NIDS Triage Console'), findsOneWidget);
    expect(find.text('Alessio Inglese'), findsOneWidget);
    expect(find.text('Critical'), findsOneWidget);
    expect(find.text('DDoS (SYN flood)'), findsOneWidget);
  });
}
