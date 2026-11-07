import 'package:dcm/backend/models/clock_data.dart';
import 'package:dcm/widgets/clock_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;

void main() {
  testWidgets('renders configured digital time, date, and weekday',
      (tester) async {
    final clock = ClockData()
      ..bShowDate = true
      ..bShowTime = true
      ..bShowWeek = true
      ..nDate = 5
      ..nTime = 1
      ..nWeek = 2
      ..strDateSep = '-';
    final today = intl.DateFormat('yyyy-MM-dd').format(DateTime.now());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(child: ClockPanel(data: clock)),
        ),
      ),
    );

    expect(find.byKey(const Key('clock-time')), findsOneWidget);
    expect(find.byKey(const Key('clock-date')), findsOneWidget);
    expect(find.text(today), findsOneWidget);
    expect(find.byKey(const Key('clock-week')), findsOneWidget);
    expect(find.textContaining('星期'), findsOneWidget);
  });

  testWidgets('renders an analog face for analog clock settings',
      (tester) async {
    final clock = ClockData()
      ..nClockType = 1
      ..bShowSecondHand = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(child: ClockPanel(data: clock)),
        ),
      ),
    );

    expect(find.byKey(const Key('analog-clock')), findsOneWidget);
  });
}
