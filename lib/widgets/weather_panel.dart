import 'package:dcm/backend/models/weather_data.dart';
import 'package:flutter/material.dart';

class WeatherPanel extends StatelessWidget {
  final WeatherData? data;

  const WeatherPanel({super.key, this.data});

  static const _background = Color(0xFFF0F1F2);
  static const _surface = Color(0xFFE5E7E9);
  static const _ink = Color(0xFF202326);
  static const _muted = Color(0xFF687078);
  static const _sun = Color(0xFFF5A623);
  static const _rain = Color(0xFF2789E8);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final weather = data;
        if (weather == null) {
          return const ColoredBox(
            color: _background,
            child: Center(
              child: Text('暂无天气数据', style: TextStyle(color: _muted)),
            ),
          );
        }

        final compact = constraints.maxWidth < 360;
        final padding = compact ? 14.0 : 22.0;
        final city = _firstText(
          [weather.strCity, weather.strCountry, weather.strDesc],
          '天气',
        );
        final condition = _firstText([weather.strConditions], '天气状况');
        final narrative = weather.strText.trim();

        return ColoredBox(
          color: _background,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: _sun, size: 21),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _dateLabel(DateTime.now()),
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 18 : 24),
                Row(
                  children: [
                    Icon(
                      _weatherIcon(condition),
                      color: _weatherColor(condition),
                      size: compact ? 54 : 72,
                    ),
                    SizedBox(width: compact ? 8 : 15),
                    Text(
                      '${_number(weather.dbCurrent)}°C',
                      style: TextStyle(
                        color: _ink,
                        fontSize: compact ? 39 : 50,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        condition,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: _ink,
                          fontSize: compact ? 13 : 15,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                if (narrative.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    narrative,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
                SizedBox(height: compact ? 18 : 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _SummaryValue(
                        label: '最高',
                        value: '${_number(weather.dbHight)}°',
                      ),
                      _SummaryValue(
                        label: '最低',
                        value: '${_number(weather.dbLow)}°',
                      ),
                      _SummaryValue(
                        label: '体感',
                        value: '${_number(weather.dbFeels)}°',
                      ),
                    ],
                  ),
                ),
                if (narrative.isEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F0F4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.calendar_month_rounded,
                            size: 18, color: Color(0xFF397D9D)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '暂无逐小时或多日预报',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF315F73),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: compact ? 18 : 22),
                const Text(
                  '天气指标',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, metricConstraints) {
                    const spacing = 8.0;
                    final columns = metricConstraints.maxWidth < 360 ? 2 : 3;
                    final tileWidth =
                        (metricConstraints.maxWidth - spacing * (columns - 1)) /
                            columns;
                    final metrics = <_WeatherMetric>[
                      _WeatherMetric('湿度', '${_number(weather.dbHumidity)}%',
                          Icons.water_drop_rounded, _rain),
                      _WeatherMetric('风况', _fallback(weather.strWind),
                          Icons.air_rounded, const Color(0xFF4F8A78)),
                      _WeatherMetric(
                          '能见度',
                          _numberWithUnit(weather.dbVisibility, ' km'),
                          Icons.visibility_rounded,
                          const Color(0xFF587EA0)),
                      _WeatherMetric('露点', '${_number(weather.dbDewpoint)}°',
                          Icons.thermostat_rounded, const Color(0xFFB87848)),
                      _WeatherMetric('气压', _fallback(weather.strBarometer),
                          Icons.speed_rounded, const Color(0xFF827354)),
                      _WeatherMetric('紫外线', _fallback(weather.strURadiation),
                          Icons.wb_twilight_rounded, const Color(0xFFD08832)),
                    ];
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final metric in metrics)
                          SizedBox(
                            width: tileWidth,
                            height: 64,
                            child: _MetricTile(metric: metric),
                          ),
                      ],
                    );
                  },
                ),
                if (weather.dtPublish != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '更新于 ${_timeLabel(weather.dtPublish!)}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static String _firstText(List<String> values, String fallback) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return fallback;
  }

  static IconData _weatherIcon(String condition) {
    final value = condition.toLowerCase();
    if (value.contains('雷') || value.contains('thunder')) {
      return Icons.thunderstorm_rounded;
    }
    if (value.contains('雪') || value.contains('snow')) {
      return Icons.ac_unit_rounded;
    }
    if (value.contains('雨') || value.contains('rain')) {
      return Icons.cloudy_snowing;
    }
    if (value.contains('云') || value.contains('cloud') || value.contains('阴')) {
      return Icons.cloud_rounded;
    }
    return Icons.wb_sunny_rounded;
  }

  static Color _weatherColor(String condition) {
    final value = condition.toLowerCase();
    if (value.contains('雨') || value.contains('rain') || value.contains('雪')) {
      return _rain;
    }
    if (value.contains('云') || value.contains('cloud') || value.contains('阴')) {
      return const Color(0xFF6B9CAF);
    }
    return _sun;
  }

  static String _number(double value) {
    if (!value.isFinite) return '--';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  static String _fallback(String value) => value.trim().isEmpty ? '--' : value;

  static String _numberWithUnit(double value, String unit) =>
      value == 0 ? '--' : '${_number(value)}$unit';

  static String _dateLabel(DateTime date) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${date.month}月${date.day}日 ${weekdays[date.weekday - 1]}';
  }

  static String _timeLabel(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(color: WeatherPanel._muted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: WeatherPanel._ink,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherMetric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _WeatherMetric(this.label, this.value, this.icon, this.color);
}

class _MetricTile extends StatelessWidget {
  final _WeatherMetric metric;

  const _MetricTile({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(metric.icon, size: 17, color: metric.color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: WeatherPanel._muted, fontSize: 10),
                ),
                const SizedBox(height: 3),
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WeatherPanel._ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
