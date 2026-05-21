// DATEFORMAT.dart
// This is a part of dc Catalogue System.
// Copyright (C) 2004 s2001 Ltd..
// All rights reserved.
//
// Author: John Lee, johnlee@s2001.com
//
// Date  : 03/03/2004

/// Date format utility class
class DATEFORMAT {
  /// Format date with given pattern
  static String format(DateTime date, String pattern) {
    String result = pattern;

    // Year
    result = result.replaceAll('YYYY', date.year.toString());
    result =
        result.replaceAll('YY', (date.year % 100).toString().padLeft(2, '0'));

    // Month
    result = result.replaceAll('MM', date.month.toString().padLeft(2, '0'));
    result = result.replaceAll('MMM', _getMonthAbbr(date.month));
    result = result.replaceAll('MMMM', _getMonthFull(date.month));

    // Day
    result = result.replaceAll('DD', date.day.toString().padLeft(2, '0'));

    // Hour
    result = result.replaceAll('HH', date.hour.toString().padLeft(2, '0'));

    // Minute
    result = result.replaceAll('MM', date.minute.toString().padLeft(2, '0'));

    // Second
    result = result.replaceAll('SS', date.second.toString().padLeft(2, '0'));

    // AM/PM
    if (result.contains('am/pm')) {
      final hour = date.hour;
      final amPm = hour >= 12 ? 'pm' : 'am';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      result = result.replaceAll('am/pm', amPm);
      result = result.replaceAll('HH', hour12.toString().padLeft(2, '0'));
    }

    return result;
  }

  /// Get month abbreviation
  static String _getMonthAbbr(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return month >= 1 && month <= 12 ? months[month] : '';
  }

  /// Get full month name
  static String _getMonthFull(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return month >= 1 && month <= 12 ? months[month] : '';
  }

  /// Get week day name
  static String getWeekDay(int dayOfWeek) {
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return dayOfWeek >= 1 && dayOfWeek <= 7 ? days[dayOfWeek] : '';
  }

  /// Get week day abbreviation
  static String getWeekDayAbbr(int dayOfWeek) {
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return dayOfWeek >= 1 && dayOfWeek <= 7 ? days[dayOfWeek] : '';
  }

  /// Parse date from string
  static DateTime? parse(String dateStr, String pattern) {
    try {
      // Simple implementation - would need more robust parsing for production
      final parts = dateStr.split(RegExp(r'[-/\s:]'));
      final patternParts = pattern.split(RegExp(r'[-/\s:]'));

      int year = DateTime.now().year;
      int month = 1;
      int day = 1;
      int hour = 0;
      int minute = 0;
      int second = 0;

      for (int i = 0; i < parts.length && i < patternParts.length; i++) {
        final p = patternParts[i].toUpperCase();
        final v = parts[i];

        if (p.contains('Y')) {
          year = int.parse(v);
        } else if (p.contains('M') && !p.contains('MM')) {
          month = int.parse(v);
        } else if (p.contains('D')) {
          day = int.parse(v);
        } else if (p.contains('H')) {
          hour = int.parse(v);
        } else if (p == 'MM') {
          minute = int.parse(v);
        } else if (p == 'SS') {
          second = int.parse(v);
        }
      }

      return DateTime(year, month, day, hour, minute, second);
    } catch (e) {
      return null;
    }
  }
}
