// TimeProductItem.dart
// This is a part of dc Catalogue System.
// Copyright (C) 2004 s2001 Ltd..
// All rights reserved.
//
// Author: John Lee, johnlee@s2001.com
//
// Date  : 03/03/2004

import 'product_data.dart';

/// Class to hold the data for content list item (Add for AH contentlist Item)
class TimeProductItem {
  DateTime? dtStart;
  DateTime? dtEnd;
  ProductData? pProduct;

  TimeProductItem();

  TimeProductItem.create({
    this.dtStart,
    this.dtEnd,
    this.pProduct,
  });

  /// Create a copy of this TimeProductItem
  TimeProductItem copy() {
    return TimeProductItem.create(
      dtStart: dtStart,
      dtEnd: dtEnd,
      pProduct: pProduct?.copy(),
    );
  }
}
