import 'dart:math';

import 'package:dcm/backend/constants.dart';
import 'package:intl/intl.dart';

String getProgressString(Duration duration) {
  if (duration.inSeconds ~/ 3600 == 0) {
    return '${(duration.inSeconds % 3600 ~/ 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  } else {
    return '${duration.inSeconds ~/ 3600}:${(duration.inSeconds % 3600 ~/ 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}

String getCurrentTimeString() {
  final now = DateTime.now();
  return now.microsecondsSinceEpoch.toString();
}

double bounded(double l, double val, double r) {
  return max(min(val, r), l);
}

DateTime stringToTime(DateTime dtTime, String strTime, String strSep) {
  int nHour = 0;
  int nMin = 0;
  int nSec = 0;
  if (strSep.isEmpty) {
    nHour = int.tryParse(strTime.substring(0, 2)) ?? 0;
    nMin = int.tryParse(strTime.substring(2, 4)) ?? 0;
    nSec = int.tryParse(strTime.substring(4, 6)) ?? 0;
  } else {
    var components = strTime.split(strSep);
    nHour =
        components.isNotEmpty ? (int.tryParse(components[0].trim()) ?? 0) : 0;
    nMin =
        components.length > 1 ? (int.tryParse(components[1].trim()) ?? 0) : 0;
    nSec =
        components.length > 2 ? (int.tryParse(components[2].trim()) ?? 0) : 0;
  }

  if (nHour == 24 && nMin == 0 && nSec == 0) {
    nHour = 23;
    nMin = 59;
    nSec = 59;
  }

  return dtTime.copyWith(hour: nHour, minute: nMin, second: nSec);
}

DateTime? fromDateTimeFormat(String strTime, [int nFormat = 0]) {
  int d = 0, m = 0, y = 0, h = -1, mm = -1, s = -1;

  int noFields = 0;
  if (nFormat == 0) {
    var components = strTime.split(' ');
    var dateComponents =
        components.isNotEmpty ? components[0].split('/') : null;
    var timeComponents =
        components.length > 1 ? components[1].split(':') : null;
    noFields = (dateComponents != null ? dateComponents.length : 0) +
        (timeComponents != null ? timeComponents.length : 0);
  } else if (nFormat == 1) {
    if (strTime.isNotEmpty) {
      noFields++;
      y = int.tryParse(strTime.substring(0, 4)) ?? 0;
    }
    if (strTime.length > 4) {
      noFields++;
      m = int.tryParse(strTime.substring(4, 6)) ?? 0;
    }
    if (strTime.length > 6) {
      noFields++;
      d = int.tryParse(strTime.substring(6, 8)) ?? 0;
    }
    if (strTime.length > 8) {
      noFields++;
      h = int.tryParse(strTime.substring(8, 10)) ?? 0;
    }
    if (strTime.length > 10) {
      noFields++;
      mm = int.tryParse(strTime.substring(10, 12)) ?? 0;
    }
    if (strTime.length > 12) {
      noFields++;
      d = int.tryParse(strTime.substring(12, 14)) ?? 0;
    }
  }

  if (noFields != 6) {
    return null;
  }

  if (h == 24 && mm == 0 && s == 0) {
    h = 23;
    mm = 59;
    s = 59;
  }

  return DateTime(y, m, d, h, mm, s);
}

double getDuration(String strStart, String strEnd) {
  if (strStart == '00:00:00' && strEnd == '00:00:00') {
    return 0.00;
  }
  DateTime dtCurr = DateTime.now();

  DateTime dtStart = dtCurr;
  stringToTime(dtStart, strStart, ':');
  DateTime dtEnd = dtCurr;
  stringToTime(dtEnd, strEnd, ':');
  Duration dts = dtEnd.difference(dtStart);

  return dts.inSeconds.toDouble();
}

bool comparePlayDateTime(DateTime dtDateTime1, DateTime dtDateTime2) {
  Duration dtsTest = dtDateTime1.difference(dtDateTime2);
  double dbTest = (dtsTest.inMilliseconds / 1000.0).abs();

  return (dbTest < cPLAYINGINTERVAL * 2);
}

///      ICU Name                   Skeleton
///      --------                   --------
///      DAY                          d
///      ABBR_WEEKDAY                 E
///      WEEKDAY                      EEEE
///      ABBR_STANDALONE_MONTH        LLL
///      STANDALONE_MONTH             LLLL
///      NUM_MONTH                    M
///      NUM_MONTH_DAY                Md
///      NUM_MONTH_WEEKDAY_DAY        MEd
///      ABBR_MONTH                   MMM
///      ABBR_MONTH_DAY               MMMd
///      ABBR_MONTH_WEEKDAY_DAY       MMMEd
///      MONTH                        MMMM
///      MONTH_DAY                    MMMMd
///      MONTH_WEEKDAY_DAY            MMMMEEEEd
///      ABBR_QUARTER                 QQQ
///      QUARTER                      QQQQ
///      YEAR                         y
///      YEAR_NUM_MONTH               yM
///      YEAR_NUM_MONTH_DAY           yMd
///      YEAR_NUM_MONTH_WEEKDAY_DAY   yMEd
///      YEAR_ABBR_MONTH              yMMM
///      YEAR_ABBR_MONTH_DAY          yMMMd
///      YEAR_ABBR_MONTH_WEEKDAY_DAY  yMMMEd
///      YEAR_MONTH                   yMMMM
///      YEAR_MONTH_DAY               yMMMMd
///      YEAR_MONTH_WEEKDAY_DAY       yMMMMEEEEd
///      YEAR_ABBR_QUARTER            yQQQ
///      YEAR_QUARTER                 yQQQQ
///      HOUR24                       H
///      HOUR24_MINUTE                Hm
///      HOUR24_MINUTE_SECOND         Hms
///      HOUR                         j
///      HOUR_MINUTE                  jm
///      HOUR_MINUTE_SECOND           jms
///      HOUR_MINUTE_GENERIC_TZ       jmv   (not yet implemented)
///      HOUR_MINUTE_TZ               jmz   (not yet implemented)
///      HOUR_GENERIC_TZ              jv    (not yet implemented)
///      HOUR_TZ                      jz    (not yet implemented)
///      MINUTE                       m
///      MINUTE_SECOND                ms
///      SECOND                       s
DateTime? concatDateTime(String? dateString, String? time) {
  if (dateString == null || dateString.isEmpty) {
    dateString = DateFormat("yyyy-MM-dd").format(DateTime.now());
  }

  if (time == null || time.isEmpty) {
    time = "00:00:00";
  } else if (time.split(':').length == 1) {
    time += ':00:00';
  } else if (time.split(':').length == 2) {
    time += ':00';
  }

  return DateFormat("yyyy-MM-dd HH:mm:ss").tryParse("$dateString $time");
}

DateTime mergeTimeFrom(DateTime date, String time) {
  return stringToTime(date, time, ':');
}

DateTime combineDateTime(DateTime date, [DateTime? time]) {
  time ??= DateTime.now();
  return date.copyWith(
      hour: time.hour,
      minute: time.minute,
      second: time.second,
      millisecond: 0,
      microsecond: 0);
}

Duration differenceTime(DateTime? dt1, DateTime? dt2) {
  if (dt1 == null || dt2 == null) {
    return Duration.zero;
  }

  return dt2.difference(dt1);
}

bool equalsTime(DateTime? dt1, DateTime? dt2) {
  if (dt1 == null && dt2 == null) {
    return true;
  }

  if (dt1 == null || dt2 == null) {
    return false;
  }

  return dt2.compareTo(dt1) == 0;
}

DateTime? addDuration(DateTime? dt1, Duration dts) {
  if (dt1 == null) {
    return null;
  }

  return dt1.add(dts);
}

DateTime fromOleDateTime([double? oleDate]) {
  final epoch = DateTime(1899, 12, 30);
  if (oleDate != null && oleDate > 0) {
    return epoch.add(
      Duration(microseconds: (oleDate * 86400 * 1000000).round()),
    );
  }

  return epoch;
}

double toOleDateTime(DateTime dateTime) {
  final epoch = DateTime(1899, 12, 30);

  return dateTime.difference(epoch).inMicroseconds / (86400 * 1000000);
}
