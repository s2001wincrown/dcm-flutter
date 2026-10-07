import 'dart:async';
import 'dart:math' as math;

import 'package:dcm/backend/models/clock_data.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

class ClockPanel extends StatefulWidget {
  final ClockData data;

  const ClockPanel({super.key, required this.data});

  @override
  State<ClockPanel> createState() => _ClockPanelState();
}

class _ClockPanelState extends State<ClockPanel> {
  late DateTime _now;
  Timer? _timer;

  ClockData get _data => widget.data;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(_updateTime);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ClockPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _updateTime();
    }
  }

  void _updateTime() {
    _now = DateTime.now().add(Duration(minutes: _data.nOffsetMins));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background =
        Color(0xFF000000 | (_data.crTextBKColor & 0x00FFFFFF));
    final foreground =
        Color(0xFF000000 | (_data.crTextFGColor & 0x00FFFFFF));

    return ColoredBox(
      color: background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fontSize = math.min(
            _data.nTextFontSize.toDouble(),
            constraints.maxHeight / 3,
          );
          final textStyle = TextStyle(
            color: foreground,
            fontFamily: _data.strTextFontName.isEmpty
                ? null
                : _data.strTextFontName,
            fontSize: fontSize,
            fontWeight:
                _data.bFontBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: _data.bFontItalic ? FontStyle.italic : FontStyle.normal,
            decoration: _data.bFontUnderline
                ? TextDecoration.underline
                : TextDecoration.none,
          );
          final analog = _data.nClockType == 1;
          final title = _data.strTimeZoneTitle.trim();

          return Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle.copyWith(fontSize: fontSize * 0.65),
                  ),
                Expanded(
                  child: Center(
                    child: analog
                        ? LayoutBuilder(
                            builder: (context, clockConstraints) {
                              final side = math.min(
                                clockConstraints.maxWidth,
                                clockConstraints.maxHeight,
                              );
                              return CustomPaint(
                                key: const Key('analog-clock'),
                                size: Size.square(side),
                                painter: _AnalogClockPainter(
                                  time: _now,
                                  color: foreground,
                                  showSeconds: _data.bShowSecondHand,
                                ),
                              );
                            },
                          )
                        : _data.bShowTime
                            ? FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _formatTime(_now, _data),
                                  key: const Key('clock-time'),
                                  style: textStyle,
                                ),
                              )
                            : const SizedBox.shrink(),
                  ),
                ),
                if (_data.bShowDate)
                  Text(
                    _formatDate(_now, _data),
                    key: const Key('clock-date'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle.copyWith(fontSize: fontSize * 0.55),
                  ),
                if (_data.bShowWeek)
                  Text(
                    _formatWeek(_now, _data.nWeek),
                    key: const Key('clock-week'),
                    style: textStyle.copyWith(fontSize: fontSize * 0.45),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _formatDate(DateTime date, ClockData data) {
  final separator = data.strDateSep;
  final year = intl.DateFormat('yyyy').format(date);
  final shortYear = intl.DateFormat('yy').format(date);
  final month = intl.DateFormat('MM').format(date);
  final day = intl.DateFormat('dd').format(date);
  final shortDay = intl.DateFormat('d').format(date);
  final shortMonthName = intl.DateFormat('MMM').format(date);
  final monthName = intl.DateFormat('MMMM').format(date);

  switch (data.nDate) {
    case 0:
      return '$day$separator$month$separator$shortYear';
    case 1:
      return '$day$separator$month$separator$year';
    case 2:
      return '$month$separator$day$separator$shortYear';
    case 3:
      return '$month$separator$day$separator$year';
    case 4:
      return '$shortYear$separator$month$separator$day';
    case 5:
      return '$year$separator$month$separator$day';
    case 6:
      return '$day$separator$shortMonthName$separator$shortYear';
    case 7:
      return '$day$separator$shortMonthName$separator$year';
    case 8:
      return '$shortMonthName$separator$day$separator$shortYear';
    case 9:
      return '$shortMonthName$separator$day$separator$year';
    case 10:
      return '$day$separator$monthName$separator$shortYear';
    case 11:
      return '$day$separator$monthName$separator$year';
    case 12:
      return '$monthName$separator$day$separator$shortYear';
    case 13:
      return '$monthName$separator$day$separator$year';
    case 14:
      return '$year年$month月$shortDay日';
    default:
      return '$year$separator$month$separator$day';
  }
}

String _formatTime(DateTime time, ClockData data) {
  final separator =
      data.strTimeSep.isEmpty ? ':' : data.strTimeSep;
  final hour24 = time.hour.toString().padLeft(2, '0');
  final hour12 = (time.hour % 12 == 0 ? 12 : time.hour % 12)
      .toString()
      .padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  final second = time.second.toString().padLeft(2, '0');
  final period = time.hour < 12 ? 'AM' : 'PM';

  switch (data.nTime) {
    case 1:
      return '$hour24$separator$minute$separator$second';
    case 2:
      return '$hour12$separator$minute $period';
    case 3:
      return '$hour12$separator$minute$separator$second $period';
    case 4:
      return '$period $hour12$separator$minute';
    case 5:
      return '$period $hour12$separator$minute$separator$second';
    case 6:
      return '${time.hour}时${minute}分${second}秒';
    case 7:
      return '$period $hour12时${minute}分';
    default:
      return '$hour24$separator$minute';
  }
}

String _formatWeek(DateTime date, int format) {
  const shortNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const fullNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const chineseNames = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  final index = date.weekday - 1;

  switch (format) {
    case 1:
      return fullNames[index];
    case 2:
      return chineseNames[index];
    default:
      return shortNames[index];
  }
}

class _AnalogClockPainter extends CustomPainter {
  final DateTime time;
  final Color color;
  final bool showSeconds;

  const _AnalogClockPainter({
    required this.time,
    required this.color,
    required this.showSeconds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final facePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, radius * 0.035);
    canvas.drawCircle(center, radius * 0.94, facePaint);

    final tickPaint = Paint()
      ..color = color
      ..strokeWidth = math.max(1, radius * 0.025)
      ..strokeCap = StrokeCap.round;
    for (var tick = 0; tick < 60; tick++) {
      final angle = tick * math.pi / 30;
      final major = tick % 5 == 0;
      final outer = radius * 0.88;
      final inner = radius * (major ? 0.76 : 0.83);
      canvas.drawLine(
        Offset(
          center.dx + math.sin(angle) * inner,
          center.dy - math.cos(angle) * inner,
        ),
        Offset(
          center.dx + math.sin(angle) * outer,
          center.dy - math.cos(angle) * outer,
        ),
        tickPaint..strokeWidth = math.max(1, radius * (major ? 0.035 : 0.018)),
      );
    }

    _drawHand(
      canvas,
      center,
      radius * 0.52,
      (time.hour % 12 + time.minute / 60) * math.pi / 6,
      math.max(2, radius * 0.055),
    );
    _drawHand(
      canvas,
      center,
      radius * 0.73,
      (time.minute + time.second / 60) * math.pi / 30,
      math.max(1.5, radius * 0.035),
    );
    if (showSeconds) {
      _drawHand(
        canvas,
        center,
        radius * 0.78,
        time.second * math.pi / 30,
        math.max(1, radius * 0.012),
      );
    }
    canvas.drawCircle(center, math.max(2, radius * 0.045), Paint()..color = color);
  }

  void _drawHand(
    Canvas canvas,
    Offset center,
    double length,
    double angle,
    double strokeWidth,
  ) {
    canvas.drawLine(
      center,
      Offset(
        center.dx + math.sin(angle) * length,
        center.dy - math.cos(angle) * length,
      ),
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _AnalogClockPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.color != color ||
        oldDelegate.showSeconds != showSeconds;
  }
}
