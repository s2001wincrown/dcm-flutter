import 'dart:convert';

import 'package:dcm/backend/models/file_info_data.dart';
import 'package:dcm/backend/models/message_data.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/zone_data.dart';
import 'package:dcm/backend/models/zoneext_data.dart';
import 'package:dcm/backend/xml_settings/contentlist_impl.dart';
import 'package:intl/intl.dart';

class ContentListFileImpl {
  final ContentListImpl _contentList = ContentListImpl(0);

  String id = '';
  String contentList = '';
  String organizationId = '';
  String desc = '';
  int uiID = -1;
  String userCode = '';
  String groupCode = '';
  DateTime? modified;
  DateTime? created;

  List<ProductData> get lstProduct => _contentList.lstProduct;
  List<String> get arrContentList => _contentList.arrContentList;
  DateTime get lastModified => _contentList.dtLastModified;

  void clear() {
    id = '';
    contentList = '';
    organizationId = '';
    desc = '';
    uiID = -1;
    userCode = '';
    groupCode = '';
    modified = null;
    created = null;
    _contentList.lstProduct.clear();
    _contentList.arrContentList.clear();
  }

  bool initialize(String fileName) {
    clear();
    contentList = fileName;
    return true;
  }

  bool saveContentList(MessageData messageData) {
    return _contentList.saveContentList(messageData);
  }

  MessageData? loadContentList(String contentListName) {
    return _contentList.loadContentList(contentListName);
  }

  bool loadContentListFile(String contentListName) {
    _contentList.loadContentListFile(contentListName);
    return _contentList.lstProduct.isNotEmpty;
  }

  bool loadContentListByDateRange(DateTime? start, DateTime? end,
      {String? contentList}) {
    _contentList.loadContentListByDateRange(start, end,
        strContentList: contentList);
    return _contentList.lstProduct.isNotEmpty;
  }

  bool loadContentListGeneral({String contentList = ''}) {
    _contentList.loadContentListGeneral(strContentList: contentList);
    return _contentList.lstProduct.isNotEmpty;
  }

  Future<bool> isExistedContentList(MessageData messageData) {
    return _contentList.isExistedContentList(messageData);
  }

  bool isValidForPlay() {
    return _contentList.isValidForPlay();
  }

  bool isOutdated(ProductData productData) {
    return _contentList.isOutdated(productData);
  }

  bool isTimeForPlay(ProductData productData) {
    return _contentList.isTimeForPlay(productData);
  }

  ProductData? getProductData({int nProduct = 0}) {
    return _contentList.getProductData(nProduct: nProduct);
  }

  List<FileInfoData> getFileInfo(List<FileInfoData> fileInfo,
      {String? contentList}) {
    return _contentList.getFileInfo(
      fileInfo,
      strContentList: contentList ?? '',
    );
  }

  double getDuration() {
    return _contentList.getDuration();
  }

  ProductData newProduct(String title, {String? layout}) {
    final product = ProductData();
    product.uiID = _contentList.lstProduct.length + 1;
    product.strProductName = title;
    product.strProductDesc = layout ?? '';
    _contentList.lstProduct.add(product);
    return product;
  }

  ProductData insertProduct(String title, int afterIndex, {String? layout}) {
    final product = ProductData();
    product.strProductName = title;
    product.strProductDesc = layout ?? '';

    int insertPos = _contentList.lstProduct.indexWhere(
      (item) => item.uiID == afterIndex,
    );
    if (insertPos < 0) {
      _contentList.lstProduct.add(product);
    } else {
      _contentList.lstProduct.insert(insertPos + 1, product);
    }

    _reindexProducts();
    return product;
  }

  bool deleteItem(int index) {
    final before = _contentList.lstProduct.length;
    _contentList.lstProduct.removeWhere((item) => item.uiID == index);
    final removed = _contentList.lstProduct.length < before;
    if (removed) {
      _reindexProducts();
    }
    return removed;
  }

  bool deleteItemByProduct(ProductData product) {
    final removed = _contentList.lstProduct.remove(product);
    if (removed) {
      _reindexProducts();
    }
    return removed;
  }

  ProductData? getFirstProduct() {
    return _contentList.lstProduct.isNotEmpty
        ? _contentList.lstProduct.first
        : null;
  }

  ProductData? getNextProduct(ProductData product) {
    final index = _contentList.lstProduct.indexOf(product);
    if (index >= 0 && index < _contentList.lstProduct.length - 1) {
      return _contentList.lstProduct[index + 1];
    }
    return null;
  }

  ProductData? getProductByIndex(int index) {
    return _contentList.lstProduct
                .firstWhere(
                  (item) => item.uiID == index,
                  orElse: () => ProductData(),
                )
                .uiID ==
            index
        ? _contentList.lstProduct.firstWhere((item) => item.uiID == index)
        : null;
  }

  int getProductIndex(ProductData product) {
    return product.uiID;
  }

  bool setProductIndex(ProductData product, int index) {
    if (_contentList.lstProduct.contains(product)) {
      product.uiID = index;
      _reindexProducts();
      return true;
    }
    return false;
  }

  String getProductLayout(ProductData product) {
    return product.strProductDesc;
  }

  bool setProductLayout(ProductData product, String layout) {
    if (_contentList.lstProduct.contains(product)) {
      product.strProductDesc = layout;
      return true;
    }
    return false;
  }

  bool setProductName(ProductData product, String title) {
    if (_contentList.lstProduct.contains(product)) {
      product.strProductName = title;
      return true;
    }
    return false;
  }

  String getProductName(ProductData product) {
    return product.strProductName;
  }

  String getProductTimeRange(ProductData product) {
    return product.strImgFile;
  }

  bool setProductTimeRange(ProductData product, String timeRange) {
    if (_contentList.lstProduct.contains(product)) {
      product.strImgFile = timeRange;
      return true;
    }
    return false;
  }

  int getProductItemType(ProductData product) {
    return product.nLanguage;
  }

  bool setProductItemType(ProductData product, int itemType) {
    if (_contentList.lstProduct.contains(product)) {
      product.nLanguage = itemType;
      return true;
    }
    return false;
  }

  ZoneData? getZone(ProductData product, int zoneId) {
    return product.lstZone
                .firstWhere(
                  (zone) => zone.nZoneID == zoneId,
                  orElse: () => ZoneData(),
                )
                .nZoneID ==
            zoneId
        ? product.lstZone.firstWhere((zone) => zone.nZoneID == zoneId)
        : null;
  }

  int getZoneNumber(ProductData product) {
    if (product.lstZone.isEmpty) {
      return 0;
    }
    int maxZone = 0;
    for (var zone in product.lstZone) {
      if (zone.nZoneID + 1 > maxZone) {
        maxZone = zone.nZoneID + 1;
      }
    }
    return maxZone;
  }

  ZoneData? getZoneData(String content) {
    for (final product in _contentList.lstProduct) {
      for (final zone in product.lstZone) {
        if (zone.strZoneFile.toLowerCase().contains(content.toLowerCase())) {
          return zone;
        }
      }
    }
    return null;
  }

  bool addZone(ProductData product, ZoneData zone) {
    final existing = getZone(product, zone.nZoneID);
    if (existing != null) {
      final index = product.lstZone.indexOf(existing);
      product.lstZone[index] = zone;
    } else {
      product.lstZone.add(zone);
    }
    return true;
  }

  bool isVideoCombine() {
    for (final product in _contentList.lstProduct) {
      if (product.lstZone.isNotEmpty) {
        final firstZone = product.lstZone.first;
        if (firstZone is ZoneExtData && firstZone.uiChannelID == 0x7fffffff) {
          return true;
        }
      }
    }
    return false;
  }

  void setVideoCombine(bool combine) {
    for (final product in _contentList.lstProduct) {
      if (product.lstZone.isNotEmpty) {
        final firstZone = product.lstZone.first;
        if (firstZone is ZoneExtData) {
          firstZone.uiChannelID = combine ? 0x7fffffff : 0;
        }
      }
    }
  }

  void setCreatedDate(DateTime dt) {
    created = dt;
  }

  void setModifiedDate(DateTime dt) {
    modified = dt;
  }

  DateTime? getCreateDate() {
    return created;
  }

  DateTime? getModifiedDate() {
    return modified;
  }

  String getContentListJson() {
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final payload = {
      'createdBy': userCode,
      'dateAdded': created != null ? formatter.format(created!) : '',
      'lastModifiedBy': groupCode,
      'dateLastModified': modified != null ? formatter.format(modified!) : '',
      'contentListItems': _contentList.lstProduct.map(_productToJson).toList(),
      'organization': {'id': organizationId},
      'id': id,
      'contentName': contentList,
      'description': desc,
    };
    return jsonEncode(payload);
  }

  Map<String, dynamic> _productToJson(ProductData product) {
    return {
      'contentListZones': product.lstZone.map(_zoneDataToJson).toList(),
      'id': product.id,
      'layout': product.strProductDesc,
      'nIndex': product.uiID > 0 ? product.uiID - 1 : 0,
    };
  }

  Map<String, dynamic> _zoneDataToJson(ZoneData zone) {
    final startTime = zone is ZoneExtData ? zone.dtStartTime : null;
    final endTime = zone is ZoneExtData ? zone.dtEndTime : null;
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');

    return {
      'id': zone.uiID,
      'contentObjectId': zone.strZoneFile,
      'dtStartTime': startTime != null ? formatter.format(startTime) : '',
      'dtEndTime': endTime != null ? formatter.format(endTime) : '',
      'nZoneIndex': zone.nZoneID,
      'lFrequency': zone.lFrequency,
      'dSpeed': zone.dSpeed,
      'nZoneDelay': zone.nZoneDelay,
      'crZoneBGColor': zone.crZoneBGColor,
      'nZoneOrientation': zone.nZoneOrientation,
      'nZonePort': zone.nZonePort,
      'nZoneMotion': zone.nZoneMotion,
      'nWebZoom': zone.nWebZoom,
      'strZoneOffineFile': zone.strZoneOfflineFile,
      'dAspect': zone.dAspect,
      'bChkZone': zone.bChkZone,
      'bZoneSelectBgPic': zone.bZoneSelectBgPic,
      'bAlpha': zone.bAlpha,
      'bZoneMute': zone.bZoneMute,
      'dVolume': zone.dVolume,
      'bZoneRatio': zone.bZoneRatio,
      'strZoneFile': zone.strZoneFile,
      'nZoneType': zone.nZoneType,
      'dZoneDuration': zone.nZoneDuration,
      'strWebCharset': zone.strWebCharset,
      'nZoom': zone.nZoom,
      'nZoneDirection': zone.nZoneDirection,
      'nZoneEffectType': zone.nZoneEffectType,
      'nZoneTVStandard': zone.nZoneTVStandard,
      'nZoneTVSource': zone.nZoneTVSource,
      'bDDERefresh': zone.bDDERefresh,
      'nZoneTVInputType': zone.nZoneTVInputType,
      'nAudioSource': zone.nAudioSource,
      'strZoneTVSource': zone.strZoneTVSource,
      'nZoneTVInput': zone.nZoneTVInput,
      'nZoneTVTuningSpace': zone.nZoneTVTuningSpace,
      'bZoneChkMpeg2': zone.bZoneChkMpeg2,
      'nAudioStandard': zone.nAudioStandard,
      'strAudioSource': zone.strAudioSource,
      'strZoneBGFile': zone.strZoneBGFile,
    };
  }

  void _reindexProducts() {
    for (int i = 0; i < _contentList.lstProduct.length; i++) {
      final product = _contentList.lstProduct[i];
      product.uiID = i + 1;
      for (final zone in product.lstZone) {
        zone.nProductIndex = product.uiID;
      }
    }
  }
}
