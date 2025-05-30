class TotalSalesReport {
  final String occupiedTables;
  final String onlineSales;
  final String billDiscount;
  final String endDate;
  final String counterTotal;
  final String netSales;
  final String totalSales;
  final String roundOffTotal;
  final String onlineOrders;
  final String homeDeliveryChargeTotal;
  final String totalKotEntries;
  final String homeDeliveryTotal;
  final String billTimes;
  final String cashSales;
  final String cardSales;
  final String upiSales;
  final String othersSales;
  final String billTax;
  final String dineTotal;
  final String takeAwayTotal;
  final String onlineTotal;
  final String homeDeliverySales;
  final String counterSales;
  final String occupiedTableCount;
  final String startDate;

  // Counter sales fields as per your new JSON structure
  final String dineInSales;
  final String takeAwaySales;

  TotalSalesReport({
    required this.occupiedTables,
    required this.onlineSales,
    required this.billDiscount,
    required this.endDate,
    required this.counterTotal,
    required this.netSales,
    required this.totalSales,
    required this.roundOffTotal,
    required this.onlineOrders,
    required this.homeDeliveryChargeTotal,
    required this.totalKotEntries,
    required this.homeDeliveryTotal,
    required this.billTimes,
    required this.cashSales,
    required this.cardSales,
    required this.upiSales,
    required this.othersSales,
    required this.billTax,
    required this.dineTotal,
    required this.takeAwayTotal,
    required this.onlineTotal,
    required this.homeDeliverySales,
    required this.counterSales,
    required this.occupiedTableCount,
    required this.startDate,
    // new fields
    required this.dineInSales,
    required this.takeAwaySales,
  });

  factory TotalSalesReport.fromJson(Map<String, dynamic> json) {
    return TotalSalesReport(
      occupiedTables: json['occupiedTables']?.toString() ?? "",
      onlineSales: json['onlineSales']?.toString() ?? "",
      billDiscount: json['billDiscount']?.toString() ?? "",
      endDate: json['endDate']?.toString() ?? "",
      counterTotal: json['counterTotal']?.toString() ?? "",
      netSales: json['netTotal']?.toString() ?? json['netSales']?.toString() ?? "",
      totalSales: json['grandTotal']?.toString() ?? json['totalSales']?.toString() ?? "",
      roundOffTotal: json['roundOffTotal']?.toString() ?? "",
      onlineOrders: json['onlineOrders']?.toString() ?? "",
      homeDeliveryChargeTotal: json['homeDeliveryChargeTotal']?.toString() ?? "",
      totalKotEntries: json['totalKotEntries']?.toString() ?? "",
      homeDeliveryTotal: json['homeDeliveryTotal']?.toString() ?? "",
      billTimes: json['billTimes']?.toString() ?? "",
      cashSales: json['cashSales']?.toString() ?? "",
      cardSales: json['cardSales']?.toString() ?? "",
      upiSales: json['upiSales']?.toString() ?? "",
      othersSales: json['othersSales']?.toString() ?? "",
      billTax: json['billTax']?.toString() ?? "",
      dineTotal: json['dineInSales']?.toString() ?? json['dineTotal']?.toString() ?? "",
      takeAwayTotal: json['takeAwaySales']?.toString() ?? json['takeAwayTotal']?.toString() ?? "",
      onlineTotal: json['onlineSales']?.toString() ?? "",
      homeDeliverySales: json['homeDeliverySales']?.toString() ?? "",
      counterSales: json['counterSales']?.toString() ?? "",
      occupiedTableCount: json['occupiedTableCount']?.toString() ?? "",
      startDate: json['startDate']?.toString() ?? "",
      dineInSales: json['dineInSales']?.toString() ?? "",
      takeAwaySales: json['takeAwaySales']?.toString() ?? "",
    );
  }

  /// Helper to support Dashboard's field mapping
  String getField(String key, {String fallback = "0.00"}) {
    switch (key) {
      case "occupiedTables":
        return occupiedTables.isNotEmpty ? occupiedTables : fallback;
      case "occupiedTableCount":
        return occupiedTableCount.isNotEmpty
            ? occupiedTableCount
            : (occupiedTables.isNotEmpty ? occupiedTables : fallback);
      case "onlineSales":
        return onlineSales.isNotEmpty ? onlineSales : fallback;
      case "billDiscount":
        return billDiscount.isNotEmpty ? billDiscount : fallback;
      case "endDate":
        return endDate.isNotEmpty ? endDate : fallback;
      case "counterTotal":
      case "counterSales":
        return counterTotal.isNotEmpty
            ? counterTotal
            : (counterSales.isNotEmpty ? counterSales : fallback);
      case "netSales":
      case "netTotal":
        return netSales.isNotEmpty ? netSales : fallback;
      case "totalSales":
      case "grandTotal":
        return totalSales.isNotEmpty ? totalSales : fallback;
      case "roundOffTotal":
        return roundOffTotal.isNotEmpty ? roundOffTotal : fallback;
      case "onlineOrders":
        return onlineOrders.isNotEmpty ? onlineOrders : fallback;
      case "homeDeliveryChargeTotal":
        return homeDeliveryChargeTotal.isNotEmpty ? homeDeliveryChargeTotal : fallback;
      case "totalKotEntries":
        return totalKotEntries.isNotEmpty ? totalKotEntries : fallback;
      case "homeDeliveryTotal":
        return homeDeliveryTotal.isNotEmpty ? homeDeliveryTotal : fallback;
      case "homeDeliverySales":
        return homeDeliverySales.isNotEmpty ? homeDeliverySales : fallback;
      case "billTimes":
        return billTimes.isNotEmpty ? billTimes : fallback;
      case "cashSales":
        return cashSales.isNotEmpty ? cashSales : fallback;
      case "cardSales":
        return cardSales.isNotEmpty ? cardSales : fallback;
      case "upiSales":
        return upiSales.isNotEmpty ? upiSales : fallback;
      case "othersSales":
        return othersSales.isNotEmpty ? othersSales : fallback;
      case "billTax":
        return billTax.isNotEmpty ? billTax : fallback;
      case "dineTotal":
      case "dineInSales":
        return dineTotal.isNotEmpty ? dineTotal : (dineInSales.isNotEmpty ? dineInSales : fallback);
      case "takeAwayTotal":
      case "takeAwaySales":
        return takeAwayTotal.isNotEmpty ? takeAwayTotal : (takeAwaySales.isNotEmpty ? takeAwaySales : fallback);
      case "startDate":
        return startDate.isNotEmpty ? startDate : fallback;
      default:
        return fallback;
    }
  }
}

class TimeslotSales {
  final String timeslot;
  final double dineInSales;
  final double takeAwaySales;
  final double deliverySales;
  final double onlineSales;
  final double counterSales;

  TimeslotSales({
    required this.timeslot,
    required this.dineInSales,
    required this.takeAwaySales,
    required this.deliverySales,
    required this.onlineSales,
    required this.counterSales,
  });

  factory TimeslotSales.fromJson(Map<String, dynamic> json) {
    return TimeslotSales(
      timeslot: json['timeslot']?.toString() ?? "",
      dineInSales: (json['dineInSales'] is num)
          ? (json['dineInSales'] as num).toDouble()
          : double.tryParse(json['dineInSales']?.toString() ?? "0") ?? 0,
      takeAwaySales: (json['takeAwaySales'] is num)
          ? (json['takeAwaySales'] as num).toDouble()
          : double.tryParse(json['takeAwaySales']?.toString() ?? "0") ?? 0,
      deliverySales: (json['deliverySales'] is num)
          ? (json['deliverySales'] as num).toDouble()
          : double.tryParse(json['deliverySales']?.toString() ?? "0") ?? 0,
      onlineSales: (json['onlineSales'] is num)
          ? (json['onlineSales'] as num).toDouble()
          : double.tryParse(json['onlineSales']?.toString() ?? "0") ?? 0,
      // Fix here: use 'counter' as key if that's what API sends
      counterSales: (json['counterSales'] is num)
          ? (json['counterSales'] as num).toDouble()
          : (json['counter'] is num)
          ? (json['counter'] as num).toDouble()
          : double.tryParse(json['counterSales']?.toString() ?? json['counter']?.toString() ?? "0") ?? 0,
    );
  }
}

class ItemwiseReport {
  final String productCode;
  final String productName;
  final String totalQntSold;
  final String totalSaleAmount;

  ItemwiseReport({
    required this.productCode,
    required this.productName,
    required this.totalQntSold,
    required this.totalSaleAmount,
  });

  factory ItemwiseReport.fromJson(Map<String, dynamic> json) {
    return ItemwiseReport(
      productCode: json['productCode']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      totalQntSold: json['totalQntSold']?.toString() ?? '0',
      totalSaleAmount: json['totalSaleAmount']?.toString() ?? '0.00',
    );
  }
}

class BillwiseReport {
  final String billNo;
  final String customerName;
  final String billDate;
  final String subtotal;
  final String settlementModeName;
  final String billDiscount;
  final String? billTax;
  final String? remark;
  final String deliveryCharges;
  final String netTotal;
  final String grandAmount;
  final String discountPercent;
  final String packagingCharge;
  final String roundOff;

  BillwiseReport({
    required this.billNo,
    required this.customerName,
    required this.billDate,
    required this.subtotal,
    required this.settlementModeName,
    required this.billDiscount,
    this.billTax,
    this.remark,
    required this.deliveryCharges,
    required this.netTotal,
    required this.grandAmount,
    required this.discountPercent,
    required this.packagingCharge,
    required this.roundOff,
  });

  factory BillwiseReport.fromJson(Map<String, dynamic> json) {
    return BillwiseReport(
      billNo: json['billNo'] ?? '',
      customerName: json['customerName'] ?? '',
      billDate: json['billDate'] ?? '',
      subtotal: json['subtotal'] ?? '',
      settlementModeName: json['settlementModeName'] ?? '',
      billDiscount: json['billDiscount'] ?? '',
      billTax: json['billTax']?.toString(),
      remark: json['remark']?.toString(),
      deliveryCharges: json['deliveryCharges'] ?? '',
      netTotal: json['netTotal'] ?? '',
      grandAmount: json['grandAmount'] ?? '',
      discountPercent: json['discountPercent'] ?? '',
      packagingCharge: json['packagingCharge'] ?? '',
      roundOff: json['roundOff'] ?? '',
    );
  }
}

class TaxwiseReport {
  final String billNo;
  final String billDate;
  final String taxName;
  final String taxPercent;
  final String taxableAmount;
  final String taxAmount;

  TaxwiseReport({
    required this.billNo,
    required this.billDate,
    required this.taxName,
    required this.taxPercent,
    required this.taxableAmount,
    required this.taxAmount,
  });

  factory TaxwiseReport.fromJson(Map<String, dynamic> json) {
    return TaxwiseReport(
      billNo: json['billNo']?.toString() ?? '',
      billDate: json['billDate']?.toString() ?? '',
      taxName: json['taxName']?.toString() ?? '',
      taxPercent: json['taxPercent']?.toString() ?? '0.00',
      taxableAmount: json['taxableAmount']?.toString() ?? '0.00',
      taxAmount: json['taxAmount']?.toString() ?? '0.00',
    );
  }
}

class SettlementwiseReport {
  final String billDate;
  final String settlementModeName;
  final String grossAmount;
  final String numberOfBills;
  final String percentToGross;

  SettlementwiseReport({
    required this.billDate,
    required this.settlementModeName,
    required this.grossAmount,
    required this.numberOfBills,
    required this.percentToGross,
  });

  factory SettlementwiseReport.fromJson(Map<String, dynamic> json) {
    return SettlementwiseReport(
      billDate: json['billDate']?.toString() ?? '',
      settlementModeName: json['settlementModeName']?.toString() ?? '',
      grossAmount: json['grossAmount']?.toString() ?? '0.00',
      numberOfBills: json['numberOfBills']?.toString() ?? '0',
      percentToGross: json['percentToGross']?.toString() ?? '0.00',
    );
  }
}

class DiscountwiseReport {
  final String billNo;
  final String billDate;
  final String amount;
  final String discount;
  final String netAmount;
  final String discountOnAmt;
  final String discountPercent;
  final String? remark;

  DiscountwiseReport({
    required this.billNo,
    required this.billDate,
    required this.amount,
    required this.discount,
    required this.netAmount,
    required this.discountOnAmt,
    required this.discountPercent,
    required this.remark,
  });

  factory DiscountwiseReport.fromJson(Map<String, dynamic> json) {
    return DiscountwiseReport(
      billNo: json['billNo']?.toString() ?? '',
      billDate: json['billDate']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0.00',
      discount: json['discount']?.toString() ?? '0.00',
      netAmount: json['netAmount']?.toString() ?? '0.00',
      discountOnAmt: json['discountOnAmt']?.toString() ?? '0.00',
      discountPercent: json['discountPercent']?.toString() ?? '0.00',
      remark: json['remark']?.toString(),
    );
  }
}

class OnlineCancelOrderReport {
  final String restaurantName;
  final String orderFrom;
  final String onlineOrderId;
  final String itemName;
  final int quantity;
  final double totalAmount;
  final double itemGrossTotal;
  final double unitPrice;
  final double orderGrossTotal;

  OnlineCancelOrderReport({
    required this.restaurantName,
    required this.orderFrom,
    required this.onlineOrderId,
    required this.itemName,
    required this.quantity,
    required this.totalAmount,
    required this.itemGrossTotal,
    required this.unitPrice,
    required this.orderGrossTotal,
  });

  factory OnlineCancelOrderReport.fromJson(Map<String, dynamic> json) {
    return OnlineCancelOrderReport(
      restaurantName: json['restaurantName']?.toString() ?? '',
      orderFrom: json['orderFrom']?.toString() ?? '',
      onlineOrderId: json['onlineOrderId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      quantity: int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      totalAmount: double.tryParse(json['totalAmount']?.toString() ?? '0') ?? 0.0,
      itemGrossTotal: double.tryParse(json['itemGrossTotal']?.toString() ?? '0') ?? 0.0,
      unitPrice: double.tryParse(json['unitPrice']?.toString() ?? '0') ?? 0.0,
      orderGrossTotal: double.tryParse(json['orderGrossTotal']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class KOTAnalysisReport {
  final String kotId;
  final String operation;
  final String date;
  final String time;
  final String billNo;
  final String qty;
  final String tableNumber;
  final String waiter;
  final String? reason;
  final String product; // comma separated

  KOTAnalysisReport({
    required this.kotId,
    required this.operation,
    required this.date,
    required this.time,
    required this.billNo,
    required this.qty,
    required this.tableNumber,
    required this.waiter,
    required this.reason,
    required this.product,
  });

  factory KOTAnalysisReport.fromJson(Map<String, dynamic> json) {
    return KOTAnalysisReport(
      kotId: json['kotId']?.toString() ?? '',
      operation: json['operation']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      billNo: json['billNo']?.toString() ?? '',
      qty: json['qty']?.toString() ?? '',
      tableNumber: json['tableNumber']?.toString() ?? '',
      waiter: json['waiter']?.toString() ?? '',
      reason: json['reason']?.toString(),
      product: json['product']?.toString() ?? '',
    );
  }
}

class TimeAuditReport {
  final String billNo;
  final String tableNo;
  final String kotTime;
  final String billDate;
  final String billTime;
  final String settleDate;
  final String settleTime;
  final String userCreated;
  final String userEdited;
  final String? remarks;
  final String timeDifference;
  final String billAmount;
  final String settlementMode;

  TimeAuditReport({
    required this.billNo,
    required this.tableNo,
    required this.kotTime,
    required this.billDate,
    required this.billTime,
    required this.settleDate,
    required this.settleTime,
    required this.userCreated,
    required this.userEdited,
    required this.remarks,
    required this.timeDifference,
    required this.billAmount,
    required this.settlementMode,
  });

  factory TimeAuditReport.fromJson(Map<String, dynamic> json) {
    return TimeAuditReport(
      billNo: json['billNo']?.toString() ?? "",
      tableNo: json['tableNo']?.toString() ?? "",
      kotTime: json['kotTime']?.toString() ?? "",
      billDate: json['billDate']?.toString() ?? "",
      billTime: json['billTime']?.toString() ?? "",
      settleDate: json['settleDate']?.toString() ?? "",
      settleTime: json['settleTime']?.toString() ?? "",
      userCreated: json['userCreated']?.toString() ?? "",
      userEdited: json['userEdited']?.toString() ?? "",
      remarks: json['remarks']?.toString(),
      timeDifference: json['timeDifference']?.toString() ?? "",
      billAmount: json['billAmount']?.toString() ?? "",
      settlementMode: json['settlementMode']?.toString() ?? "",
    );
  }
}

class CancelBillReport {
  final String kotId;
  final String billNo;
  final String billDate;
  final String cancelDate;
  final String createdTime;
  final String cancelTime;
  final String createdUser;
  final String cancelUser;
  final String? notes;
  final String billType;
  final String items;
  final String taxes;
  final String grandTotal;
  final String netTotal;

  CancelBillReport({
    required this.kotId,
    required this.billNo,
    required this.billDate,
    required this.cancelDate,
    required this.createdTime,
    required this.cancelTime,
    required this.createdUser,
    required this.cancelUser,
    required this.notes,
    required this.billType,
    required this.items,
    required this.taxes,
    required this.grandTotal,
    required this.netTotal,
  });

  factory CancelBillReport.fromJson(Map<String, dynamic> json) {
    return CancelBillReport(
      kotId: json['kot_ID']?.toString() ?? '',
      billNo: json['bill_No']?.toString() ?? '',
      billDate: json['billDate']?.toString() ?? '',
      cancelDate: json['cancelDate']?.toString() ?? '',
      createdTime: json['createdTime']?.toString() ?? '',
      cancelTime: json['cancelTime']?.toString() ?? '',
      createdUser: json['createdUser']?.toString() ?? '',
      cancelUser: json['cancelUser']?.toString() ?? '',
      notes: json['notes']?.toString(),
      billType: json['billType']?.toString() ?? '',
      items: json['items']?.toString() ?? '',
      taxes: json['taxes']?.toString() ?? '',
      grandTotal: json['grandTotal']?.toString() ?? '',
      netTotal: json['netTotal']?.toString() ?? '',
    );
  }
}

class PaxWiseReport {
  final String billDate;
  final int totalPax;
  final String totalAmount;

  PaxWiseReport({
    required this.billDate,
    required this.totalPax,
    required this.totalAmount,
  });

  factory PaxWiseReport.fromJson(Map<String, dynamic> json) {
    return PaxWiseReport(
      billDate: json['billDate']?.toString() ?? "",
      totalPax: int.tryParse(json['totalPax']?.toString() ?? "") ?? 0,
      totalAmount: json['totalAmount']?.toString() ?? "",
    );
  }
}

class OnlineDayWiseOrder {
  final String source;
  final String merchantId;
  final String orderId;
  final String orderDate;
  final String orderType;
  final String paymentMode;
  final String subtotal;
  final String discount;
  final String packagingCharge;
  final String deliveryCharge;
  final String tax;
  final String total;
  final String status;
  final String billNo;

  OnlineDayWiseOrder({
    required this.source,
    required this.merchantId,
    required this.orderId,
    required this.orderDate,
    required this.orderType,
    required this.paymentMode,
    required this.subtotal,
    required this.discount,
    required this.packagingCharge,
    required this.deliveryCharge,
    required this.tax,
    required this.total,
    required this.status,
    required this.billNo,
  });

  factory OnlineDayWiseOrder.fromJson(Map<String, dynamic> json) {
    return OnlineDayWiseOrder(
      source: json['source']?.toString() ?? "",
      merchantId: json['merchantId']?.toString() ?? "",
      orderId: json['orderId']?.toString() ?? "",
      orderDate: json['orderDate']?.toString() ?? "",
      orderType: json['orderType']?.toString() ?? "",
      paymentMode: json['paymentMode']?.toString() ?? "",
      subtotal: json['subtotal']?.toString() ?? "",
      discount: json['discount']?.toString() ?? "",
      packagingCharge: json['packagingCharge']?.toString() ?? "",
      deliveryCharge: json['deliveryCharge']?.toString() ?? "",
      tax: json['tax']?.toString() ?? "",
      total: json['total']?.toString() ?? "",
      status: json['status']?.toString() ?? "",
      billNo: json['billNo']?.toString() ?? "",
    );
  }
}