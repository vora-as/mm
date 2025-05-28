import 'package:meta/meta.dart';
import 'dart:convert';

List<OnlineOrder> onlineOrderFromMap(String str) =>
    List<OnlineOrder>.from(json.decode(str).map((x) => OnlineOrder.fromMap(x)));

String onlineOrderToMap(List<OnlineOrder> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toMap())));

class OnlineOrder {
  String orderId;
  List<OnlineOrderItemList> onlineOrderItemList;
  CustomerDetail? customerDetail;
  int restaurantId;
  String restaurantName;
  String externalOrderId;
  String orderFrom;
  DateTime orderDateTime;
  int enableDelivery;
  double netAmount;
  double grossAmount;
  String paymentMode;
  String orderType;
  double cgst;
  double sgst;
  double? cgstPercent;
  double? sgstPercent;
  int orderPackaging;
  double orderPackagingCgst;
  double orderPackagingSgst;
  final double discount;
  final String orderInstructions;
  double deliveryCharge;
  String status;
  String? billNo; // To store the bill number
  String? kotID;

  OnlineOrder({
    required this.orderId,
    required this.onlineOrderItemList,
    this.customerDetail,
    required this.restaurantId,
    required this.restaurantName,
    required this.externalOrderId,
    required this.orderFrom,
    required this.orderDateTime,
    required this.enableDelivery,
    required this.netAmount,
    required this.grossAmount,
    required this.paymentMode,
    required this.orderType,
    required this.discount,
    required this.orderInstructions,
    required this.cgst,
    required this.sgst,
    this.cgstPercent,
    this.sgstPercent,
    required this.orderPackaging,
    required this.orderPackagingCgst,
    required this.orderPackagingSgst,
    required this.deliveryCharge,
    required this.status,
    this.billNo, // ✅ NEW FIELD
    this.kotID,
  });

  factory OnlineOrder.fromMap(Map<String, dynamic> json) => OnlineOrder(
    orderId: (json["orderId"] ?? json["online_order_id"])?.toString() ?? "N/A",
    onlineOrderItemList: (json["onlineOrderItemList"] is List)
        ? List<OnlineOrderItemList>.from(json["onlineOrderItemList"].map((x) => OnlineOrderItemList.fromMap(x)))
        : [],
    customerDetail: (json["customerDetail"] != null && json["customerDetail"] is Map)
        ? CustomerDetail.fromMap(json["customerDetail"])
        : null,  // Ensure it's null-safe and if data is missing, it's set to null
    restaurantId: json["restaurantId"] ?? json["restaurant_id"] ?? 0,
    restaurantName: json["restaurantName"] ?? json["restaurant_name"] ?? "Unknown",
    externalOrderId: json["externalOrderId"] ?? json["external_order_id"] ?? "Unknown",
    orderFrom: json["orderFrom"] ?? json["order_from"] ?? "Unknown",
    orderDateTime: DateTime.tryParse(json["orderDateTime"] ?? json["order_date_time"] ?? "") ?? DateTime.now(),
    enableDelivery: json["enableDelivery"] ?? json["enable_delivery"] ?? 0,
    netAmount: (json["netAmount"] ?? json["net_amount"] ?? 0.0).toDouble(),
    grossAmount: (json["grossAmount"] ?? json["gross_amount"] ?? 0.0).toDouble(),
    paymentMode: json["paymentMode"] ?? json["payment_mode"] ?? "Unknown",
    orderType: json["orderType"] ?? json["order_type"] ?? "Unknown",
    orderInstructions: json["orderInstructions"] ?? json["order_instructions"] ?? "",
    cgst: (json["cgst"] ?? 0.0).toDouble(),
    sgst: (json["sgst"] ?? 0.0).toDouble(),
    cgstPercent: (json["cgstPercent"] ?? json["cgst_percent"] ?? 0.0).toDouble(),
    sgstPercent: (json["sgstPercent"] ?? json["sgst_percent"] ?? 0.0).toDouble(),
    orderPackaging: json["orderPackaging"] ?? json["order_packaging"] ?? 0,
    orderPackagingCgst: (json["orderPackagingCgst"] ?? json["order_packaging_cgst"] ?? 0.0).toDouble(),
    orderPackagingSgst: (json["orderPackagingSgst"] ?? json["order_packaging_sgst"] ?? 0.0).toDouble(),
    discount: (json["discount"] ?? 0.0).toDouble(),
    deliveryCharge: (json["deliveryCharge"] ?? json["delivery_charge"] ?? 0.0).toDouble(),
    status: json["status"] ?? "inactive",
    kotID: json["kotID"] ?? json["kotID"] ?? "",
    billNo: json["billno"] ?? json["billNo"] ?? "",
  );

  get vatPercent => null;

  get vat => null;

  Map<String, dynamic> toMap() => {
    "orderId": orderId,
    "onlineOrderItemList": List<dynamic>.from(onlineOrderItemList.map((x) => x.toMap())),
    "customerDetail": customerDetail?.toMap(),
    "restaurantId": restaurantId,
    "restaurantName": restaurantName,
    "externalOrderId": externalOrderId,
    "orderFrom": orderFrom,
    "orderDateTime": orderDateTime.toIso8601String(),
    "enableDelivery": enableDelivery,
    "netAmount": netAmount,
    "grossAmount": grossAmount,
    "paymentMode": paymentMode,
    "orderType": orderType,
    "orderInstructions": orderInstructions,
    "cgst": cgst,
    "sgst": sgst,
    "cgstPercent": cgstPercent,
    "sgstPercent": sgstPercent,
    "orderPackaging": orderPackaging,
    "orderPackagingCgst": orderPackagingCgst,
    "orderPackagingSgst": orderPackagingSgst,
    "discount": discount,
    "deliveryCharge": deliveryCharge,
    "status": status,
    "kotID": kotID,
    "billNo": billNo,
  };
}

class OnlineOrderItemList {
  String weraItemId;
  List<dynamic> onlineOrderItemVariantList;
  List<OnlineOrderItemAddonList> onlineOrderItemAddonList;
  int itemId;
  String itemName;
  double itemUnitPrice;
  double subtotal;
  double discount;
  int itemQuantity;
  double cgst;
  double sgst;
  double cgstPercent;
  double sgstPercent;
  int packaging;
  double packagingCgst;
  double packagingSgst;
  double packagingCgstPercent;
  double packagingSgstPercent;

  OnlineOrderItemList({
    required this.weraItemId,
    required this.onlineOrderItemVariantList,
    required this.onlineOrderItemAddonList,
    required this.itemId,
    required this.itemName,
    required this.itemUnitPrice,
    required this.subtotal,
    required this.discount,
    required this.itemQuantity,
    required this.cgst,
    required this.sgst,
    required this.cgstPercent,
    required this.sgstPercent,
    required this.packaging,
    required this.packagingCgst,
    required this.packagingSgst,
    required this.packagingCgstPercent,
    required this.packagingSgstPercent,
  });

  factory OnlineOrderItemList.fromMap(Map<String, dynamic> json) => OnlineOrderItemList(
    weraItemId: json["weraItemId"]?.toString() ?? json["wera_item_id"]?.toString() ?? "",
    onlineOrderItemVariantList: json["onlineOrderItemVariantList"] ?? [],
    onlineOrderItemAddonList: json["onlineOrderItemAddonList"] != null
        ? List<OnlineOrderItemAddonList>.from(
        json["onlineOrderItemAddonList"].map((x) => OnlineOrderItemAddonList.fromMap(x)))
        : [],
    itemId: json["itemId"] ?? json["item_id"] ?? 0,
    itemName: json["itemName"] ?? json["item_name"] ?? "Unknown Item",
    itemUnitPrice: (json["itemUnitPrice"] ?? json["item_unit_price"] ?? 0.0).toDouble(),
    subtotal: (json["subtotal"] ?? 0.0).toDouble(),
    discount: (json["discount"] ?? json["item_discount"] ?? 0.0).toDouble(),
    itemQuantity: json["itemQuantity"] ?? json["item_quantity"] ?? 1,
    cgst: (json["cgst"] ?? json["item_cgst"] ?? 0.0).toDouble(),
    sgst: (json["sgst"] ?? json["item_sgst"] ?? 0.0).toDouble(),
    cgstPercent: (json["cgstPercent"] ?? json["item_cgst_percent"] ?? 0.0).toDouble(),
    sgstPercent: (json["sgstPercent"] ?? json["item_sgst_percent"] ?? 0.0).toDouble(),
    packaging: json["packaging"] ?? 0,
    packagingCgst: (json["packagingCgst"] ?? json["packaging_cgst"] ?? 0.0).toDouble(),
    packagingSgst: (json["packagingSgst"] ?? json["packaging_sgst"] ?? 0.0).toDouble(),
    packagingCgstPercent: (json["packagingCgstPercent"] ?? json["packaging_cgst_percent"] ?? 0.0).toDouble(),
    packagingSgstPercent: (json["packagingSgstPercent"] ?? json["packaging_sgst_percent"] ?? 0.0).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    "weraItemId": weraItemId,
    "onlineOrderItemVariantList": List<dynamic>.from(onlineOrderItemVariantList.map((x) => x)),
    "onlineOrderItemAddonList": List<dynamic>.from(onlineOrderItemAddonList.map((x) => x.toMap())),
    "itemId": itemId,
    "itemName": itemName,
    "itemUnitPrice": itemUnitPrice,
    "subtotal": subtotal,
    "discount": discount,
    "itemQuantity": itemQuantity,
    "cgst": cgst,
    "sgst": sgst,
    "cgstPercent": cgstPercent,
    "sgstPercent": sgstPercent,
    "packaging": packaging,
    "packagingCgst": packagingCgst,
    "packagingSgst": packagingSgst,
    "packagingCgstPercent": packagingCgstPercent,
    "packagingSgstPercent": packagingSgstPercent,
  };
}

class OnlineOrderItemAddonList {
  String addonId;
  String weraAddonId;
  String addonName;
  double addonPrice;
  double cgst;
  double sgst;
  double cgstPercent;
  double sgstPercent;
  double discountedPrice;

  OnlineOrderItemAddonList({
    required this.addonId,
    required this.weraAddonId,
    required this.addonName,
    required this.addonPrice,
    required this.cgst,
    required this.sgst,
    required this.cgstPercent,
    required this.sgstPercent,
    required this.discountedPrice,
  });

  factory OnlineOrderItemAddonList.fromMap(Map<String, dynamic> json) =>
      OnlineOrderItemAddonList(
        addonId: json["addonId"] ?? "",
        weraAddonId: json["weraAddonId"] ?? "",
        addonName: json["addonName"] ?? "",
        addonPrice: (json["addonPrice"] ?? 0.0).toDouble(),
        cgst: (json["cgst"] ?? 0.0).toDouble(),
        sgst: (json["sgst"] ?? 0.0).toDouble(),
        discountedPrice: (json["discountedPrice"] ?? 0.0).toDouble(),
        cgstPercent: (json["cgstPercent"] ?? 0.0).toDouble(),
        sgstPercent: (json["sgstPercent"] ?? 0.0).toDouble(),
      );

  Map<String, dynamic> toMap() => {
    "addonId": addonId,
    "weraAddonId": weraAddonId,
    "addonName": addonName,
    "addonPrice": addonPrice,
    "cgst": cgst,
    "sgst": sgst,
    "discountedPrice": discountedPrice,
    "cgstPercent": cgstPercent,
    "sgstPercent": sgstPercent,
  };
}

class CustomerDetail {
  int id;
  String custname;
  String? orderInstructions;
  String deliveryArea;
  String phoneNumber;

  CustomerDetail({
    required this.id,
    required this.custname,
    this.orderInstructions,
    required this.deliveryArea,
    required this.phoneNumber,
  });

  factory CustomerDetail.fromMap(Map<String, dynamic> json) => CustomerDetail(
    id: json["id"] ?? 0,
    custname: json["custname"] ?? "Unknown",
    orderInstructions: json["orderInstructions"],
    deliveryArea: json["deliveryArea"] ?? "",
    phoneNumber: json["phoneNumber"] ?? "N/A",
  );

  Map<String, dynamic> toMap() => {
    "id": id,
    "custname": custname,
    "orderInstructions": orderInstructions,
    "deliveryArea": deliveryArea,
    "phoneNumber": phoneNumber,
  };
}
