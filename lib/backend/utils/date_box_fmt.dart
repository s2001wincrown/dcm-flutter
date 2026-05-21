// DATEBOXFMT.dart
// This is a part of dc Catalogue System.
// Copyright (C) 2004 s2001 Ltd..
// All rights reserved.
//
// Author: John Lee, johnlee@s2001.com
//
// Date  : 03/03/2004

/// Date box format utility class
class DATEBOXFMT {
  /// Date box format types
  static const int formatD = 0;
  static const int formatDD = 1;

  /// Format day with given format type
  static String formatDay(int day, int formatType) {
    switch (formatType) {
      case formatD:
        return day.toString();
      case formatDD:
        return day.toString().padLeft(2, '0');
      default:
        return day.toString();
    }
  }

  /// Format month with given format type
  static String formatMonth(int month, int formatType) {
    switch (formatType) {
      case formatD:
        return month.toString();
      case formatDD:
        return month.toString().padLeft(2, '0');
      default:
        return month.toString();
    }
  }

  /// Format year with given format type
  static String formatYear(int year, bool fullYear) {
    if (fullYear) {
      return year.toString();
    } else {
      return (year % 100).toString().padLeft(2, '0');
    }
  }

  /// Format hour with given format type
  static String formatHour(int hour, bool is24Hour) {
    if (is24Hour) {
      return hour.toString().padLeft(2, '0');
    } else {
      if (hour == 0) return '12';
      if (hour > 12) return (hour - 12).toString();
      return hour.toString();
    }
  }

  /// Get AM/PM indicator
  static String getAmPm(int hour) {
    return hour >= 12 ? 'pm' : 'am';
  }

  /// Format minute
  static String formatMinute(int minute) {
    return minute.toString().padLeft(2, '0');
  }

  /// Format second
  static String formatSecond(int second) {
    return second.toString().padLeft(2, '0');
  }

  /// Format date with pattern
  static String formatDate(DateTime date, String pattern,
      {String separator = '-'}) {
    final parts = <String>[];
    final tokens = pattern.split(' ');

    for (final token in tokens) {
      switch (token.toUpperCase()) {
        case 'DD':
          parts.add(date.day.toString().padLeft(2, '0'));
          break;
        case 'D':
          parts.add(date.day.toString());
          break;
        case 'MM':
          parts.add(date.month.toString().padLeft(2, '0'));
          break;
        case 'MMM':
          parts.add(_getMonthAbbr(date.month));
          break;
        case 'MMMM':
          parts.add(_getMonthFull(date.month));
          break;
        case 'YY':
          parts.add((date.year % 100).toString().padLeft(2, '0'));
          break;
        case 'YYYY':
          parts.add(date.year.toString());
          break;
        default:
          parts.add(token);
      }
    }

    return parts.join(separator);
  }

  /// Format time with pattern
  static String formatTime(DateTime date, String pattern,
      {bool useAmPm = false}) {
    String result = pattern;

    int hour = date.hour;
    final isPm = hour >= 12;

    if (useAmPm) {
      if (hour == 0)
        hour = 12;
      else if (hour > 12) hour -= 12;
    }

    result = result.replaceAll('HH', hour.toString().padLeft(2, '0'));
    result = result.replaceAll('MM', date.minute.toString().padLeft(2, '0'));
    result = result.replaceAll('SS', date.second.toString().padLeft(2, '0'));

    if (useAmPm) {
      result = result.replaceAll('am/pm', isPm ? 'pm' : 'am');
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
}
