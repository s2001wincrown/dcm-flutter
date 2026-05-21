// ProductNameData.dart
// This is a part of dc Catalogue System.
// Copyright (C) 2004 s2001 Ltd..
// All rights reserved.
//
// Author: John Lee, johnlee@s2001.com
//
// Date  : 03/03/2004

/// Class to hold the data for Product Name
class ProductNameData {
  // Attributes
  String strLangISO = '';
  String strProductName = '';

  ProductNameData();

  ProductNameData.create({
    required this.strLangISO,
    required this.strProductName,
  });

  /// Create a copy of this ProductNameData
  ProductNameData copy() {
    return ProductNameData.create(
      strLangISO: strLangISO,
      strProductName: strProductName,
    );
  }
}
