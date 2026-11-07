import 'package:dcm/backend/models/weather_data.dart';
import 'package:dcm/widgets/weather_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows current weather and details without layout overflow',
      (tester) async {
    final weather = WeatherData()
      ..strCity = '广州市'
      ..strConditions = '晴转多云'
      ..strWind = '东南风 2级'
      ..strBarometer = '1012 hPa'
      ..strURadiation = '中等'
      ..dbCurrent = 35
      ..dbHight = 36
      ..dbLow = 26
      ..dbFeels = 37
      ..dbHumidity = 31
      ..dbVisibility = 10
      ..dbDewpoint = 22;

    for (final size in [const Size(430, 540), const Size(320, 400)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(child: WeatherPanel(data: weather)),
          ),
        ),
      );

      expect(find.text('广州市'), findsOneWidget);
      expect(find.text('35°C'), findsOneWidget);
      expect(find.text('晴转多云'), findsOneWidget);
      expect(find.text('天气指标'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('shows an empty state when weather data is unavailable',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(child: WeatherPanel(data: null)),
        ),
      ),
    );

    expect(find.text('暂无天气数据'), findsOneWidget);
  });
}
