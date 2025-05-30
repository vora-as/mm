import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'SidePanel.dart';
import 'main.dart';
import 'package:merchant/TotalSalesReport.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
class Dashboard extends ConsumerStatefulWidget {
  final Map<String, String> dbToBrandMap;

  const Dashboard({super.key, required this.dbToBrandMap});

  @override
  ConsumerState<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<Dashboard> {
  String? selectedBrand;
  DateTimeRange? selectedDateRange;
  String get selectedDate => selectedDateRange != null
      ? "${DateFormat('dd-MM-yyyy').format(selectedDateRange!.start)} to ${DateFormat('dd-MM-yyyy').format(selectedDateRange!.end)}"
      : DateFormat('dd-MM-yyyy').format(DateTime.now());
  Map<String, dynamic> apiResponses = {};
  Map<String, TotalSalesReport> totalSalesResponses = {};
  bool isLoading = false;
  String chartType = "Bar Chart"; // or "Line Chart"
  Key chartKey = UniqueKey();
  List<TimeslotSales> timeslotSalesList = [];
  bool isLoadingTimeslotSales = false;
  List<Map<String, dynamic>> onlineOrderRecords = [];
  bool isLoadingOnlineOrders = false;
  Future<void> fetchTimeslotSales() async {
    setState(() => isLoadingTimeslotSales = true);
    final config = await Config.loadFromAsset();
    String startDate = DateFormat('dd-MM-yyyy').format(selectedDateRange!.start);
    String endDate = DateFormat('dd-MM-yyyy').format(selectedDateRange!.end);

    List<String> dbs;
    if (selectedBrand == null || selectedBrand == "All") {
      dbs = widget.dbToBrandMap.keys.toList();
    } else {
      dbs = widget.dbToBrandMap.entries
          .where((entry) => entry.value == selectedBrand)
          .map((entry) => entry.key)
          .toList();
    }

    timeslotSalesList = await UserData.fetchTimeslotSalesForDbs(
      config,
      dbs,
      startDate,
      endDate,
    );
    setState(() => isLoadingTimeslotSales = false);
  }
  Future<void> fetchOnlineOrders() async {
    setState(() => isLoadingOnlineOrders = true);
    final config = await Config.loadFromAsset();
    List<String> dbNames;
    if (selectedBrand == null || selectedBrand == "All") {
      dbNames = widget.dbToBrandMap.keys.toList();
    } else {
      dbNames = widget.dbToBrandMap.entries
          .where((entry) => entry.value == selectedBrand)
          .map((entry) => entry.key)
          .toList();
    }
    String startDate = DateFormat('dd-MM-yyyy').format(selectedDateRange!.start);
    String endDate = DateFormat('dd-MM-yyyy').format(selectedDateRange!.end);

    final dbToOrders = await UserData.fetchOnlineOrdersForDbs(config, dbNames, startDate, endDate);

    // Flatten and attach dbName to each row
    List<Map<String, dynamic>> all = [];
    dbToOrders.forEach((db, list) {
      for (final k in list) {
        all.add({'dbName': db, 'record': k});
      }
    });

    setState(() {
      onlineOrderRecords = all;
      isLoadingOnlineOrders = false;
    });
  }

  Map<String, dynamic> get onlineOrderTotals {
    int totalOrders = 0;
    double totalAmount = 0;

    for (var row in onlineOrderRecords) {
      final record = row['record'];
      // You may need to adjust this check based on how your channels are named.
      // Here, we assume Zomato, Swiggy, and Online are all considered "online orders"
      if ((record.orderFrom ?? "").toLowerCase().contains("zomato") ||
          (record.orderFrom ?? "").toLowerCase().contains("swiggy") ||
          (record.orderFrom ?? "").toLowerCase().contains("online")) {
        totalOrders++;
        totalAmount += double.tryParse(record.netAmount?.toString() ?? '0') ?? 0;
      }
    }
    return {
      "orders": totalOrders,
      "amount": totalAmount,
    };
  }

  List<ChartBarData> get barData {
    if (timeslotSalesList.isNotEmpty) {
      return timeslotSalesList.map((slot) => ChartBarData(
        slot.timeslot,
        slot.dineInSales.round(),
        slot.takeAwaySales.round(),
        slot.deliverySales.round(),
        slot.onlineSales.round(),
        slot.counterSales.round(),
      )).toList();
    } else if (selectedBrand != null && selectedBrand != "All" && totalSalesResponses.isNotEmpty) {
      // Fallback to summary for single outlet
      final entry = widget.dbToBrandMap.entries.firstWhere(
            (e) => e.value == selectedBrand,
        orElse: () => MapEntry('', ''),
      );
      final dbKey = entry.key.isNotEmpty ? entry.key : null;
      final report = dbKey != null ? totalSalesResponses[dbKey] : null;
      if (report != null) {
        return [
          ChartBarData(
            "Total",
            double.tryParse(report.getField("dineInSales", fallback: "0"))?.round() ?? 0,
            double.tryParse(report.getField("takeAwaySales", fallback: "0"))?.round() ?? 0,
            double.tryParse(report.getField("homeDeliverySales", fallback: "0"))?.round() ?? 0,
            double.tryParse(report.getField("onlineSales", fallback: "0"))?.round() ?? 0,
            double.tryParse(report.getField("counterSales", fallback: "0"))?.round() ?? 0,
          ),
        ];
      }
    }
    return [];
  }

  List<ChartLineData> get lineData {
    if (timeslotSalesList.isNotEmpty) {
      return timeslotSalesList.map((slot) => ChartLineData(
        slot.timeslot,
        slot.dineInSales.round(),
        slot.takeAwaySales.round(),
        slot.deliverySales.round(),
        slot.onlineSales.round(),
        slot.counterSales.round(),
      )).toList();
    } else if (selectedBrand != null && selectedBrand != "All" && totalSalesResponses.isNotEmpty) {
      final entry = widget.dbToBrandMap.entries.firstWhere(
            (e) => e.value == selectedBrand,
        orElse: () => MapEntry('', ''),
      );
      final dbKey = entry.key.isNotEmpty ? entry.key : null;
      final report = dbKey != null ? totalSalesResponses[dbKey] : null;
      if (report != null) {
        return [
          ChartLineData(
            "Total",
            double.tryParse(report.getField("dineInSales", fallback: "0"))?.round() ?? 0,
            double.tryParse(report.getField("takeAwaySales", fallback: "0"))?.round() ?? 0,
            double.tryParse(report.getField("homeDeliverySales", fallback: "0"))?.round() ?? 0,
            double.tryParse(report.getField("onlineSales", fallback: "0"))?.round() ?? 0,
            double.tryParse(report.getField("counterSales", fallback: "0"))?.round() ?? 0,
          ),
        ];
      }
    }
    return [];
  }




  // Add in your state:
  String quickDateLabel = "Today";
  DateTimeRange? selectedQuickDateRange;

  void onQuickDateSelected(String label) async {
    DateTime now = DateTime.now();
    DateTime start, end;
    switch (label) {
      case "Today":
        start = end = DateTime(now.year, now.month, now.day);
        break;
      case "Yesterday":
        start = end = DateTime(now.year, now.month, now.day).subtract(Duration(days: 1));
        break;
      case "Last 7 Days":
        end = DateTime(now.year, now.month, now.day);
        start = end.subtract(Duration(days: 6));
        break;
      case "Last 30 Days":
        end = DateTime(now.year, now.month, now.day);
        start = end.subtract(Duration(days: 29));
        break;
      case "This Month":
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month, now.day);
        break;
      case "Last Month":
        DateTime firstDayThisMonth = DateTime(now.year, now.month, 1);
        DateTime lastDayLastMonth = firstDayThisMonth.subtract(Duration(days: 1));
        start = DateTime(lastDayLastMonth.year, lastDayLastMonth.month, 1);
        end = DateTime(lastDayLastMonth.year, lastDayLastMonth.month, lastDayLastMonth.day);
        break;
      case "Custom Range":
      // Show popup date range picker (white, not fullscreen)
        DateTimeRange? picked = await showDialog<DateTimeRange>(
          context: context,
          builder: (context) => Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 350,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: CalendarDateRangePicker(
                  initialRange: selectedQuickDateRange ?? DateTimeRange(start: now, end: now),
                  onRangeSelected: (range) {
                    Navigator.of(context).pop(range);
                  },
                ),
              ),
            ),
          ),
        );
        if (picked != null) {
          setState(() {
            quickDateLabel = "Custom Range";
            selectedQuickDateRange = picked;
            selectedDateRange = picked;
          });
          await fetchTotalSales();
          await fetchTimeslotSales();
          await fetchOnlineOrders();
        }
        return;
      default:
        return;
    }
    setState(() {
      quickDateLabel = label;
      selectedQuickDateRange = DateTimeRange(start: start, end: end);
      selectedDateRange = DateTimeRange(start: start, end: end);
    });
    await fetchTotalSales();
    await fetchTimeslotSales();
    await fetchOnlineOrders();
  }
  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    selectedDateRange = DateTimeRange(start: today, end: today);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchTotalSales();
      fetchTimeslotSales();
      fetchOnlineOrders();
    });
  }

  List<Map<String, dynamic>> get summaryTabs {
    // Helper to format amount and orders
    String formatAmount(double value) => "₹ ${value.toStringAsFixed(2)}";
    String formatOrders(int value) => "$value Order${value == 1 ? "" : "s"}";

    if (selectedBrand == null || selectedBrand == "All") {
      // Aggregate for all outlets
      double totalSales = 0, dineIn = 0, takeAway = 0, delivery = 0;
      int totalOrders = 0, dineOrders = 0, takeAwayOrders = 0, deliveryOrders = 0;double counter = 0;
      int counterOrders = 0;

      for (final report in totalSalesResponses.values) {
        totalSales   += double.tryParse(report.getField("grandTotal", fallback: "0.00")) ?? 0;
        dineIn       += double.tryParse(report.getField("dineInSales", fallback: "0.00")) ?? 0;
        takeAway     += double.tryParse(report.getField("takeAwaySales", fallback: "0.00")) ?? 0;
        delivery     += double.tryParse(report.getField("homeDeliverySales", fallback: "0.00")) ?? 0;
        counter += double.tryParse(report.getField("counterSales", fallback: "0.00")) ?? 0;
        counterOrders += int.tryParse(report.getField("counterOrders", fallback: "0")) ?? 0;

        // Example: if you have these orders fields in your API/model, use them.
        totalOrders      += int.tryParse(report.getField("totalOrders", fallback: "0")) ?? 0;
        dineOrders       += int.tryParse(report.getField("dineInOrders", fallback: "0")) ?? 0;
        takeAwayOrders   += int.tryParse(report.getField("takeAwayOrders", fallback: "0")) ?? 0;
        deliveryOrders   += int.tryParse(report.getField("homeDeliveryOrders", fallback: "0")) ?? 0;
      }

      return [
        {
          "title": "Total Salesswds",
          "amount": formatAmount(totalSales),
          "orders": formatOrders(totalOrders),
          "icon": Icons.local_activity,
          "iconColor": Color(0xFFFCA2A2),
        },
        {
          "title": "Dine In",
          "amount": formatAmount(dineIn),
          "orders": formatOrders(dineOrders),
          "icon": Icons.restaurant,
          "iconColor": Color(0xFF93E5F9),
        },
        {
          "title": "TAKE AWAY",
          "amount": formatAmount(takeAway),
          "orders": formatOrders(takeAwayOrders),
          "icon": Icons.local_drink,
          "iconColor": Color(0xFFEEE6FF),
        },
        {
          "title": "Delivery",
          "amount": formatAmount(delivery),
          "orders": formatOrders(deliveryOrders),
          "icon": Icons.delivery_dining,
          "iconColor": Color(0xFFFFE6B9),
        },
        {
          "title": "Counter",
          "amount": "₹ ${getField("counterSales", fallback: "0.00")}",
          "orders": "",
          "icon": Icons.point_of_sale,
          "iconColor": const Color(0xFFF0C987),
        },
      ];
    } else {
      // Single outlet
      final entry = widget.dbToBrandMap.entries.firstWhere(
            (e) => e.value == selectedBrand,
        orElse: () => MapEntry('', ''),
      );
      final dbKey = entry.key.isNotEmpty ? entry.key : null;
      final report = dbKey != null ? totalSalesResponses[dbKey] : null;

      String safeAmount(String? value) => "₹ ${(value != null && value.isNotEmpty) ? value : "0.00"}";
      String safeOrders(String? value) {
        final num = int.tryParse(value ?? "0") ?? 0;
        return "$num Order${num == 1 ? "" : "s"}";
      }

      return [
        {
          "title": "Total Sales",
          "amount": safeAmount(report?.getField("grandTotal")),
          "orders": safeOrders(report?.getField("totalOrders")),
          "icon": Icons.local_activity,
          "iconColor": Color(0xFFFCA2A2),
        },
        {
          "title": "Dine In",
          "amount": safeAmount(report?.getField("dineInSales")),
          "orders": safeOrders(report?.getField("dineInOrders")),
          "icon": Icons.restaurant,
          "iconColor": Color(0xFF93E5F9),
        },
        {
          "title": "TAKE AWAYss",
          "amount": safeAmount(report?.getField("takeAwaySales")),
          "orders": safeOrders(report?.getField("takeAwayOrders")),
          "icon": Icons.local_drink,
          "iconColor": Color(0xFFEEE6FF),
        },
        {
          "title": "Delivery",
          "amount": safeAmount(report?.getField("homeDeliverySales")),
          "orders": safeOrders(report?.getField("homeDeliveryOrders")),
          "icon": Icons.delivery_dining,
          "iconColor": Color(0xFFFFE6B9),
        },
        {
          "title": "Counter",
          "amount": "₹ ${getField("counterSales", fallback: "0.00")}",
          "orders": "",
          "icon": Icons.point_of_sale,
          "iconColor": const Color(0xFFF0C987),
        },
      ];
    }
  }


  List<Map<String, dynamic>> get onlineOrderChannels {
    // Group orders by channel
    int zomatoOrders = 0, swiggyOrders = 0, onlineOrders = 0;
    double zomatoAmount = 0, swiggyAmount = 0, onlineAmount = 0;

    for (var row in onlineOrderRecords) {
      final record = row['record'];
      final channel = (record.orderFrom ?? "").toLowerCase();
      final amount = double.tryParse(record.netAmount?.toString() ?? '0') ?? 0;
      if (channel.contains('zomato')) {
        zomatoOrders++;
        zomatoAmount += amount;
      } else if (channel.contains('swiggy')) {
        swiggyOrders++;
        swiggyAmount += amount;
      } else if (channel.contains('online')) {
        onlineOrders++;
        onlineAmount += amount;
      }
    }

    return [
      {
        "icon": "assets/images/zomato.png",
        "name": "Zomato",
        "amount": "₹ ${zomatoAmount.toStringAsFixed(2)}",
        "orders": zomatoOrders.toString(),
        "active": zomatoOrders > 0,
      },
      {
        "icon": "assets/images/SWIGGY.png",
        "name": "Swiggy",
        "amount": "₹ ${swiggyAmount.toStringAsFixed(2)}",
        "orders": swiggyOrders.toString(),
        "active": swiggyOrders > 0,
      },
      {
        "icon": "assets/images/online.png", // Use your online generic icon
        "name": "Online",
        "amount": "₹ ${onlineAmount.toStringAsFixed(2)}",
        "orders": onlineOrders.toString(),
        "active": onlineOrders > 0,
      },
    ];
  }

  List<Map<String, dynamic>> get paymentBifurcation {
    // Get the correct TotalSalesReport based on selectedBrand
    TotalSalesReport? report;
    if (selectedBrand == null || selectedBrand == "All") {
      report = totalSalesResponses.values.isNotEmpty ? totalSalesResponses.values.first : null;
    } else {
      // FIX: Use a dummy MapEntry for orElse, then check .key
      final entry = widget.dbToBrandMap.entries.firstWhere(
            (e) => e.value == selectedBrand,
        orElse: () => MapEntry('', ''),
      );
      final dbKey = entry.key.isNotEmpty ? entry.key : null;
      report = dbKey != null ? totalSalesResponses[dbKey] : null;
    }

    String safeAmount(String? value) => "₹ ${(value != null && value.isNotEmpty) ? value : "0.00"}";

    return [
      {
        "color": Colors.amber,
        "label": "Cash",
        "value": safeAmount(report?.getField("cashSales")),
      },
      {
        "color": Colors.cyan,
        "label": "Card",
        "value": safeAmount(report?.getField("cardSales")),
      },
      {
        "color": Color(0xFF4886FF),
        "label": "UPI",
        "value": safeAmount(report?.getField("upiSales")),
      },
      {
        "color": Colors.green,
        "label": "Other",
        "value": safeAmount(report?.getField("othersSales")),
      },
    ];
  }
  Future<void> fetchData({bool reset = false}) async {
    if (reset) {
      setState(() {
        apiResponses = {};
      });
    }
    setState(() {
      isLoading = true;
    });

    final config = await Config.loadFromAsset();
    final apiUrl = config.apiUrl;

    for (final dbName in widget.dbToBrandMap.keys) {
      final brandName = widget.dbToBrandMap[dbName];

      if (selectedBrand != null &&
          selectedBrand != "All" &&
          brandName != selectedBrand) {
        continue;
      }

    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchTotalSales() async {
    setState(() {
      isLoading = true;
      totalSalesResponses = {};
    });

    final config = await Config.loadFromAsset();
    String startDate = DateFormat('dd-MM-yyyy').format(selectedDateRange!.start);
    String endDate = DateFormat('dd-MM-yyyy').format(selectedDateRange!.end);

    List<String> dbs;
    if (selectedBrand == null || selectedBrand == "All") {
      dbs = widget.dbToBrandMap.keys.toList();
    } else {
      dbs = widget.dbToBrandMap.entries
          .where((entry) => entry.value == selectedBrand)
          .map((entry) => entry.key)
          .toList();
    }

    // <<<----  ONLY CALL THE MAIN API LOGIC ---->>>
    totalSalesResponses = await UserData.fetchTotalSalesForDbs(
      config,
      dbs,
      startDate,
      endDate,
    );

    setState(() {
      isLoading = false;
    });
  }

  String getField(String key, {String fallback = "0.00"}) {
    // For ALL: only one merged response (key = 'ALL'), else per DB
    if (selectedBrand == null || selectedBrand == "All") {
      if (totalSalesResponses.isEmpty) return fallback;
      final report = totalSalesResponses.entries.isNotEmpty ? totalSalesResponses.entries.first.value : null;
      if (report == null) return fallback;
      return report.getField(key, fallback: fallback);
    } else {
      // get only selected DB's value
      final dbKey = widget.dbToBrandMap.entries.firstWhere((e) => e.value == selectedBrand).key;
      final report = totalSalesResponses[dbKey];
      if (report == null) return fallback;
      return report.getField(key, fallback: fallback);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onlineTotals = onlineOrderTotals;
    final brandNames = widget.dbToBrandMap.values.toSet();
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final isMobile = size.width < 600;

    return SidePanel(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/reddpos.png',
                    height: isMobile ? 32 : 40,
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: BoxConstraints(
                      minWidth: isMobile ? 70 : 100,
                      maxWidth: isMobile ? 180 : 260,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedBrand,
                        hint: const Text(
                          "All Outlets",
                          style: TextStyle(color: Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: "All",
                            child: Text("All Outlets"),
                          ),
                          ...brandNames.map((brand) => DropdownMenuItem(
                            value: brand,
                            child: Text(
                              brand,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                        ],
                        onChanged: (value) async {
                          setState(() {
                            selectedBrand = value;
                          });
                          await fetchTotalSales();
                          await fetchTimeslotSales();
                          await fetchOnlineOrders();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  PopupMenuButton<String>(
                    offset: const Offset(0, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    color: Colors.white,
                    padding: EdgeInsets.zero,
                    onSelected: onQuickDateSelected,
                    itemBuilder: (context) => [
                      for (final label in [
                        "Today", "Yesterday", "Last 7 Days", "Last 30 Days", "This Month", "Last Month", "Custom Range"
                      ])
                        PopupMenuItem<String>(
                          value: label,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontWeight: quickDateLabel == label ? FontWeight.bold : FontWeight.normal,
                              color: quickDateLabel == label ? Colors.black : Colors.grey[700],
                            ),
                          ),
                        ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            quickDateLabel == "Custom Range" && selectedQuickDateRange != null
                                ? "${DateFormat('dd MMM').format(selectedQuickDateRange!.start)} - ${DateFormat('dd MMM').format(selectedQuickDateRange!.end)}"
                                : quickDateLabel == "Today"
                                ? DateFormat('dd MMM').format(DateTime.now())
                                : quickDateLabel,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Fetch Sales"),
                    onPressed: () async {
                      await fetchTotalSales();
                      await fetchTimeslotSales();
                      await fetchOnlineOrders();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final int gridCol = width > 1200
                  ? 4
                  : width > 900
                  ? 3
                  : width > 600
                  ? 2
                  : 1;
              final double aspect = width < 400
                  ? 1.4
                  : width < 600
                  ? 1.7
                  : 2.1;
              return SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 8 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Brand specific summary bar (show only if selectedBrand != null && selectedBrand != "All") ---
                    if (selectedBrand != null && selectedBrand != "All")
                      Padding(
                        padding: EdgeInsets.only(bottom: isMobile ? 10 : 18),
                        child: buildSummaryTabs(isMobile),
                      ),

                    // --- Sales Chart Section ---
                    if (selectedBrand != null && selectedBrand != "All")
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18.0),
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 1,
                          color: Colors.white,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 10 : 24,
                                vertical: isMobile ? 12 : 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      const Text(
                                        "Sales",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                      ),

                                      const SizedBox(width: 12),

                                      // Chart Type Dropdown
                                      Container(
                                        margin: const EdgeInsets.only(right: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: chartType,
                                            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                            style: const TextStyle(fontSize: 15, color: Colors.black87),
                                            borderRadius: BorderRadius.circular(8),
                                            isDense: true,
                                            items: [
                                              DropdownMenuItem(
                                                value: "Bar Chart",
                                                child: Row(
                                                  children: const [
                                                    Icon(Icons.bar_chart, size: 18, color: Colors.black54),
                                                    SizedBox(width: 4),
                                                    Text("Bar Chart"),
                                                  ],
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: "Line Chart",
                                                child: Row(
                                                  children: const [
                                                    Icon(Icons.show_chart, size: 18, color: Colors.black54),
                                                    SizedBox(width: 4),
                                                    Text("Line Chart"),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            onChanged: (v) => setState(() => chartType = v!),
                                          ),
                                        ),
                                      ),

                                      // Quick Date Range Selector
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        margin: const EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              quickDateLabel == "Custom Range" && selectedQuickDateRange != null
                                                  ? "${DateFormat('dd MMM').format(selectedQuickDateRange!.start)} - ${DateFormat('dd MMM').format(selectedQuickDateRange!.end)}"
                                                  : quickDateLabel == "Today"
                                                  ? DateFormat('dd MMM').format(DateTime.now())
                                                  : quickDateLabel,
                                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black54),
                                          ],
                                        ),
                                      ),

                                      // Quick Date Options Popup
                                      PopupMenuButton<String>(
                                        offset: const Offset(0, 45),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        color: Colors.white,
                                        padding: EdgeInsets.zero,
                                        onSelected: onQuickDateSelected,
                                        itemBuilder: (context) => [
                                          for (final label in [
                                            "Today", "Yesterday", "Last 7 Days", "Last 30 Days", "This Month", "Last Month", "Custom Range"
                                          ])
                                            PopupMenuItem<String>(
                                              value: label,
                                              child: Text(
                                                label,
                                                style: TextStyle(
                                                  fontWeight: quickDateLabel == label ? FontWeight.bold : FontWeight.normal,
                                                  color: quickDateLabel == label ? Colors.black : Colors.grey[700],
                                                ),
                                              ),
                                            ),
                                        ],
                                        child: const Icon(Icons.date_range, color: Colors.black54),
                                      ),

                                      // Refresh Icon Button
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.refresh, size: 20, color: Colors.black54),
                                        onPressed: () {
                                          setState(() {
                                            chartKey = UniqueKey();
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 7.0),
                                  child: Row(
                                    children: [
                                      _legendDot(Colors.blue),
                                      const SizedBox(width: 4),
                                      const Text("Dine In", style: TextStyle(fontSize: 13)),
                                      const SizedBox(width: 14),
                                      _legendDot(Colors.cyan),
                                      const SizedBox(width: 4),
                                      const Text("TAKE Away", style: TextStyle(fontSize: 13)),
                                      const SizedBox(width: 14),
                                      _legendDot(Colors.green),
                                      const SizedBox(width: 4),
                                      const Text("Delivery", style: TextStyle(fontSize: 13)),
                                      const SizedBox(width: 14),
                                      _legendDot(Colors.orange),
                                      const SizedBox(width: 4),
                                      const Text("Online", style: TextStyle(fontSize: 13)),
                                      _legendDot(Colors.purple),
                                      const SizedBox(width: 4),
                                      const Text("Counter", style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: isLoadingTimeslotSales
                                      ? const Center(child: CircularProgressIndicator())
                                      : (chartType == "Bar Chart"
                                      ? _SalesBarChartWidget(data: barData, key: chartKey)
                                      : SalesLineChartWidget(data: lineData, key: chartKey)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // --- End chart section ---

                    // --- Online Orders Channel Grid ---
                    if (selectedBrand != null && selectedBrand != "All")
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18.0),
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 1,
                          color: Colors.white,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 10 : 24,
                                vertical: isMobile ? 14 : 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text("Online Orders", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                    const Spacer(),
                                    PopupMenuButton<String>(
                                      offset: const Offset(0, 45),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      color: Colors.white,
                                      padding: EdgeInsets.zero,
                                      onSelected: onQuickDateSelected,
                                      itemBuilder: (context) => [
                                        for (final label in [
                                          "Today", "Yesterday", "Last 7 Days", "Last 30 Days", "This Month", "Last Month", "Custom Range"
                                        ])
                                          PopupMenuItem<String>(
                                            value: label,
                                            child: Text(
                                              label,
                                              style: TextStyle(
                                                fontWeight: quickDateLabel == label ? FontWeight.bold : FontWeight.normal,
                                                color: quickDateLabel == label ? Colors.black : Colors.grey[700],
                                              ),
                                            ),
                                          ),
                                      ],
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              quickDateLabel == "Custom Range" && selectedQuickDateRange != null
                                                  ? "${DateFormat('dd MMM').format(selectedQuickDateRange!.start)} - ${DateFormat('dd MMM').format(selectedQuickDateRange!.end)}"
                                                  : quickDateLabel == "Today"
                                                  ? DateFormat('dd MMM').format(DateTime.now())
                                                  : quickDateLabel,
                                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black54),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.refresh, color: Colors.black54),
                                      onPressed: () {},
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text("Total Sales", style: TextStyle(fontWeight: FontWeight.w600, fontSize: isMobile ? 14 : 17)),
                                    ),
                                    Expanded(
                                      child: Text("Total Orders", style: TextStyle(fontWeight: FontWeight.w600, fontSize: isMobile ? 14 : 17)),
                                    ),
                                    const Spacer(),
                                  ],
                                ),
              Row(
              children: [
              Expanded(
              child: Text(
              "₹ ${onlineTotals['amount'].toStringAsFixed(2)}",
              style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold),
              ),
              ),
              Expanded(
              child: Text(
              "${onlineTotals['orders']}",
              style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold),
              ),
              ),
              const Spacer(),
              ],
              ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: isMobile ? 100 : 140,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: onlineOrderChannels.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                                    itemBuilder: (context, index) {
                                      final channel = onlineOrderChannels[index];
                                      return Container(
                                        width: isMobile ? 180 : 220,
                                        padding: EdgeInsets.all(isMobile ? 10 : 18),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: channel["active"] ? Colors.grey[300]! : Colors.grey[200]!),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min, // prevent Row from expanding unnecessarily
                                              children: [
                                                Image.asset(channel["icon"], width: 24, height: 24), // slightly smaller icon
                                                const SizedBox(width: 4), // tighter spacing
                                                Flexible(
                                                  child: Text(
                                                    channel["name"],
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: isMobile ? 15 : 17,
                                                      color: Colors.black87,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    softWrap: false,
                                                  ),
                                                ),
                                              ],
                                            )
,
                                            const SizedBox(height: 10),
                                            Text(channel["amount"], style: TextStyle(fontSize: isMobile ? 17 : 20, fontWeight: FontWeight.bold)),


                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // --- Payment Bifurcation Section ---
                    if (selectedBrand != null && selectedBrand != "All")
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18.0),
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 1,
                          color: Colors.white,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 10 : 24,
                              vertical: isMobile ? 14 : 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 40, // or whatever fits your design
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        const Text(
                                          "Payment Bifurcation",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                        ),
                                        const SizedBox(width: 10),
                                        PopupMenuButton<String>(
                                          offset: const Offset(0, 45),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          color: Colors.white,
                                          padding: EdgeInsets.zero,
                                          onSelected: onQuickDateSelected,
                                          itemBuilder: (context) => [
                                            for (final label in [
                                              "Today", "Yesterday", "Last 7 Days", "Last 30 Days", "This Month", "Last Month", "Custom Range"
                                            ])
                                              PopupMenuItem<String>(
                                                value: label,
                                                child: Text(
                                                  label,
                                                  style: TextStyle(
                                                    fontWeight: quickDateLabel == label ? FontWeight.bold : FontWeight.normal,
                                                    color: quickDateLabel == label ? Colors.black : Colors.grey[700],
                                                  ),
                                                ),
                                              ),
                                          ],
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(color: Colors.grey.shade300),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  quickDateLabel == "Custom Range" && selectedQuickDateRange != null
                                                      ? "${DateFormat('dd MMM').format(selectedQuickDateRange!.start)} - ${DateFormat('dd MMM').format(selectedQuickDateRange!.end)}"
                                                      : quickDateLabel == "Today"
                                                      ? DateFormat('dd MMM').format(DateTime.now())
                                                      : quickDateLabel,
                                                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black54),
                                              ],
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.refresh, color: Colors.black54),
                                          onPressed: () {},
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, box) {
                                    double totalWidth = min(320.0, box.maxWidth - 20);
                                    double barHeight = isMobile ? 24 : 28;

                                    // Parse values from paymentBifurcation
                                    List<double> values = paymentBifurcation
                                        .map((p) => double.tryParse(p["value"].toString().replaceAll("₹", "").replaceAll(",", "").trim()) ?? 0)
                                        .toList();
                                    double total = values.fold(0.0, (a, b) => a + b);

                                    // Calculate widths
                                    List<double> widths = total > 0
                                        ? values.map((v) => totalWidth * (v / total)).toList()
                                        : List.filled(values.length, totalWidth / values.length);

                                    // Optional: show % value over the biggest section (UPI in your case)
                                    int maxIdx = values.indexOf(values.reduce(max));
                                    String percentText = total > 0 ? "100%" : "";

                                    return Center(
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width: totalWidth,
                                            height: barHeight,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(barHeight / 2),
                                              color: Colors.grey[100],
                                            ),
                                            child: Row(
                                              children: List.generate(paymentBifurcation.length, (i) {
                                                return Container(
                                                  width: widths[i],
                                                  height: barHeight,
                                                  decoration: BoxDecoration(
                                                    color: paymentBifurcation[i]["color"],
                                                    borderRadius: BorderRadius.horizontal(
                                                      left: i == 0 ? Radius.circular(barHeight / 2) : Radius.zero,
                                                      right: i == paymentBifurcation.length - 1 ? Radius.circular(barHeight / 2) : Radius.zero,
                                                    ),
                                                  ),
                                                  child: (i == maxIdx && total > 0)
                                                      ? Center(
                                                    child: Text(
                                                      percentText,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  )
                                                      : null,
                                                );
                                              }),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: paymentBifurcation.map((p) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 3.0),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: p["color"],
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              p["label"],
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: isMobile ? 14 : 15,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            p["value"],
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 14 : 16),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
,

                    // Statistics Grid (unchanged) shown only for "All"

                    if (selectedBrand == null || selectedBrand == "All") ...[
                      // Responsive grid for stats (desktop: 4 per row, mobile: 2 per row)
                      buildStatsGrid(context, stats),
                      const SizedBox(height: 20),
                      _buildOutletwiseStatisticsTable(context, isMobile: isMobile),
                      const SizedBox(height: 20),
                      // Show total sales API response
                      if (totalSalesResponses.isNotEmpty)
                        Card(
                          color: Colors.white,
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Total Sales API Result", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                for (final entry in totalSalesResponses.entries)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                    child: Text("${entry.key}: ${entry.value.totalSales}"),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
      dbToBrandMap: widget.dbToBrandMap,
    );
  }

  Widget buildSummaryTabs(bool isMobile) {
    final tabs = summaryTabs;
    if (tabs.isEmpty) return SizedBox.shrink();

    // For single outlet: force horizontal scroll for all cards
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          return Container(
            width: isMobile ? 180 : 220,
            margin: EdgeInsets.only(right: isMobile ? 10 : 18),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 18, vertical: isMobile ? 14 : 22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(tab["title"],
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isMobile ? 13 : 17,
                                  color: Colors.black87)),
                          const SizedBox(height: 10),
                          Text(tab["amount"],
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isMobile ? 18 : 22,
                                  color: Colors.black87)),
                          const SizedBox(height: 3),
                          Text(tab["orders"],
                              style: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  fontSize: isMobile ? 13 : 14,
                                  color: Colors.grey[700])),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: tab["iconColor"] as Color?,
                        shape: BoxShape.circle,
                      ),
                      padding: EdgeInsets.all(isMobile ? 10 : 16),
                      child: Icon(tab["icon"], color: Colors.black54, size: isMobile ? 28 : 38),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
  List<Map<String, dynamic>> get stats => [
    {
      "title": "Total Salessssss",
      "amount": "₹ ${getField("grandTotal", fallback: "0.00")}",
      "orders": "Occupied: ${getField("occupiedTableCount", fallback: "0")}",
      "icon": Icons.bar_chart,
      "iconColor": const Color(0xFFFCA2A2),
    },
    {
      "title": "Dine In",
      "amount": "₹ ${getField("dineInSales", fallback: "0.00")}",
      "orders": "",
      "icon": Icons.restaurant,
      "iconColor": const Color(0xFF93E5F9),
    },
    {
      "title": "TAKE AWAY",
      "amount": "₹ ${getField("takeAwaySales", fallback: "0.00")}",
      "orders": "",
      "icon": Icons.local_drink,
      "iconColor": const Color(0xFFEEE6FF),
    },
    {
      "title": "Delivery",
      "amount": "₹ ${getField("homeDeliverySales", fallback: "0.00")}",
      "orders": "",
      "icon": Icons.delivery_dining,
      "iconColor": const Color(0xFFFFE6B9),
    },
    {
      "title": "Online",
      "amount": "₹ ${getField("onlineSales", fallback: "0.00")}",
      "orders": "",
      "icon": Icons.shopping_cart,
      "iconColor": Colors.blue[100],
    },
    {
      "title": "Counter",
      "amount": "₹ ${getField("counterSales", fallback: "0.00")}",
      "orders": "",
      "icon": Icons.point_of_sale,
      "iconColor": const Color(0xFFF0C987),
    },
    {
      "title": "Net Sales",
      "amount": "₹ ${getField("netTotal", fallback: "0.00")}",
      "orders": "",
      "icon": Icons.show_chart,
      "iconColor": Colors.orange[100],
    },
    {
      "title": "Discounts",
      "amount": "₹ ${getField("billDiscount", fallback: "0.00")}",
      "orders": "",
      "icon": Icons.discount,
      "iconColor": Colors.green[100],
    },
    {
      "title": "Taxes",
      "amount": "₹ ${getField("billTax", fallback: "0.00")}",
      "orders": "",
      "icon": Icons.account_balance,
      "iconColor": Colors.purple[100],
    },
  ];
  Widget _legendDot(Color color) {
    return Container(
      width: 12, height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  bool showOutletStatsTable = true; // in your _DashboardState

  Widget _buildOutletwiseStatisticsTable(BuildContext context, {required bool isMobile}) {
    final outlets = <Map<String, String>>[];

    // Calculate totals by summing all outlets
    num totalOrders = 0;
    num totalSales = 0;
    num totalNetSales = 0;
    num totalTax = 0;
    num totalDiscount = 0;
    num totalModified = 0;
    num totalReprinted = 0;
    num totalWaivedOff = 0;
    num totalRoundOff = 0;
    num totalCharges = 0;

    // Prepare per-outlet rows
    widget.dbToBrandMap.forEach((dbKey, outletName) {
      final report = totalSalesResponses[dbKey];
      final outletOrders = num.tryParse(report?.getField("occupiedTableCount", fallback: "0") ?? "0") ?? 0;
      final outletSales = num.tryParse(report?.getField("grandTotal", fallback: "0.00") ?? "0.00") ?? 0;
      final outletNetSales = num.tryParse(report?.getField("netTotal", fallback: "0.00") ?? "0.00") ?? 0;
      final outletTax = num.tryParse(report?.getField("billTax", fallback: "0.00") ?? "0.00") ?? 0;
      final outletDiscount = num.tryParse(report?.getField("billDiscount", fallback: "0.00") ?? "0.00") ?? 0;
      final outletModified = num.tryParse(report?.getField("modifiedCount", fallback: "0") ?? "0") ?? 0;
      final outletReprinted = num.tryParse(report?.getField("reprintCount", fallback: "0") ?? "0") ?? 0;
      final outletWaivedOff = num.tryParse(report?.getField("waivedOff", fallback: "0.00") ?? "0.00") ?? 0;
      final outletRoundOff = num.tryParse(report?.getField("roundOff", fallback: "0.00") ?? "0.00") ?? 0;
      final outletCharges = num.tryParse(report?.getField("charges", fallback: "0.00") ?? "0.00") ?? 0;

      totalOrders += outletOrders;
      totalSales += outletSales;
      totalNetSales += outletNetSales;
      totalTax += outletTax;
      totalDiscount += outletDiscount;
      totalModified += outletModified;
      totalReprinted += outletReprinted;
      totalWaivedOff += outletWaivedOff;
      totalRoundOff += outletRoundOff;
      totalCharges += outletCharges;

      outlets.add({
        "Outlet Name": outletName,
        "Orders": outletOrders.toStringAsFixed(0),
        "Sales": outletSales.toStringAsFixed(2),
        "Net Sales": outletNetSales.toStringAsFixed(2),
        "Tax": outletTax.toStringAsFixed(2),
        "Discount": outletDiscount.toStringAsFixed(2),
        "Modified": outletModified.toStringAsFixed(0),
        "Re-Printed": outletReprinted.toStringAsFixed(0),
        "Waived Off": outletWaivedOff.toStringAsFixed(2),
        "Round Off": outletRoundOff.toStringAsFixed(2),
        "Charges": outletCharges.toStringAsFixed(2),
        "": "",
      });
    });

    // Add "Total" row FIRST
    outlets.insert(0, {
      "Outlet Name": "Total",
      "Orders": totalOrders.toStringAsFixed(0),
      "Sales": totalSales.toStringAsFixed(2),
      "Net Sales": totalNetSales.toStringAsFixed(2),
      "Tax": totalTax.toStringAsFixed(2),
      "Discount": totalDiscount.toStringAsFixed(2),
      "Modified": totalModified.toStringAsFixed(0),
      "Re-Printed": totalReprinted.toStringAsFixed(0),
      "Waived Off": totalWaivedOff.toStringAsFixed(2),
      "Round Off": totalRoundOff.toStringAsFixed(2),
      "Charges": totalCharges.toStringAsFixed(2),
      "": "",
    });

    final columns = [
      "Outlet Name",
      "Orders",
      "Sales",
      "Net Sales",
      "Tax",
      "Discount",
      "Modified",
      "Re-Printed",
      "Waived Off",
      "Round Off",
      "Charges",
      "",
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Outlet Wise Statistics",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    showOutletStatsTable ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                  tooltip: showOutletStatsTable ? "Collapse" : "Expand",
                  onPressed: () {
                    setState(() {
                      showOutletStatsTable = !showOutletStatsTable;
                    });
                  },
                ),
              ],
            ),
          ),
          if (showOutletStatsTable)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: isMobile ? 800 : 1050),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFEAF3FF)),
                  columnSpacing: isMobile ? 12 : 20,
                  headingRowHeight: isMobile ? 38 : 44,
                  dataRowHeight: isMobile ? 38 : 48,
                  showCheckboxColumn: false,
                  columns: columns.map((key) {
                    return DataColumn(
                      label: Row(
                        children: [
                          Text(
                            key,
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 14,
                              fontWeight: FontWeight.w600,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (key != "" && key != "Outlet Name")
                            const Icon(Icons.unfold_more, size: 16, color: Color(0xFFB0BEC5)),
                        ],
                      ),
                    );
                  }).toList(),
                  rows: outlets.map((outlet) {
                    final isTotal = outlet["Outlet Name"] == "Total";
                    return DataRow(
                      cells: columns.map((key) {
                        final isMenu = key == "";
                        final value = outlet[key] ?? '';
                        Widget cellWidget;

                        if (isMenu) {
                          cellWidget = IconButton(
                            icon: const Icon(Icons.more_vert, size: 22, color: Colors.grey),
                            onPressed: () {},
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          );
                        } else if (key == "Outlet Name" && value != "Total") {
                          cellWidget = Row(
                            children: [
                              Flexible(
                                child: Text(
                                  value,
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 13,
                                    fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.open_in_new, size: 16, color: Color(0xFF90A4AE)),
                            ],
                          );
                        } else {
                          cellWidget = Text(
                            value,
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 13,
                              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }

                        return DataCell(
                          Container(
                            width: isMobile ? 90 : 120,
                            child: cellWidget,
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildStatsGrid(BuildContext context, List<Map<String, dynamic>> stats) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 600;
    final crossAxisCount = isMobile ? 2 : 4;
    final aspectRatio = isMobile ? 1.1 : 2.1;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 12, vertical: isMobile ? 6 : 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: isMobile ? 8 : 14,
          mainAxisSpacing: isMobile ? 8 : 14,
          childAspectRatio: aspectRatio,
        ),
        itemCount: stats.length,
        itemBuilder: (context, index) {
          final stat = stats[index];
          return Card(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 10 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          stat["title"]!,
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.bold,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Icon(stat["icon"], color: stat["iconColor"], size: isMobile ? 20 : 24),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    stat["amount"]!,
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((stat["orders"] ?? "").toString().isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: isMobile ? 2 : 4),
                      child: Text(
                        stat["orders"]!,
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


}

class _SalesBarChartWidget extends StatelessWidget {
  final List<ChartBarData> data;
  const _SalesBarChartWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {

    if (data.isEmpty) {
      return const SizedBox(height: 180, child: Center(child: Text("No Data")));
    }

    double maxY = data
        .expand((d) => [d.dineIn, d.takeAway, d.delivery, d.online])
        .fold(0, (a, b) => a > b ? a : b)
        .toDouble();
    maxY = maxY > 0 ? maxY * 1.25 : 100;

    // Increased width per bar group for more spacing
    double groupWidth = 150;

    return SizedBox(
      height: 250,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12), // nice side padding
        physics: const BouncingScrollPhysics(), // smooth scrolling effect
        child: SizedBox(
          width: groupWidth * data.length,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barGroups: List.generate(data.length, (i) {
                final d = data[i];
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: d.dineIn.toDouble(),
                      width: 16,
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    BarChartRodData(
                      toY: d.takeAway.toDouble(),
                      width: 16,
                      color: Colors.cyan,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    BarChartRodData(
                      toY: d.delivery.toDouble(),
                      width: 16,
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    BarChartRodData(
                      toY: d.online.toDouble(),
                      width: 16,
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    BarChartRodData(
                      toY: d.counter.toDouble(),
                      width: 16,
                      color: Colors.purple, // Choose a unique color
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                  barsSpace: 6, // increased spacing between bars in a group
                  showingTooltipIndicators: [],
                );
              }),
              gridData: FlGridData(show: false),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: Colors.black26, width: 1),
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (double value, meta) {
                      int idx = value.toInt();
                      if (idx < 0 || idx >= data.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          data[idx].label,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              barTouchData: BarTouchData(enabled: false),
            ),
          ),
        ),
      ),
    );
  }
}



class SalesLineChartWidget extends StatelessWidget {
  final List<ChartLineData> data;
  const SalesLineChartWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {

    if (data.isEmpty) {
      return const SizedBox(height: 180, child: Center(child: Text("No Data")));
    }

    List<FlSpot> dineSpots = [];
    List<FlSpot> takeAwaySpots = [];
    List<FlSpot> deliverySpots = [];
    List<FlSpot> onlineSpots = [];
    List<FlSpot> counterSpots = [];
    for (int i = 0; i < data.length; i++) {
      dineSpots.add(FlSpot(i.toDouble(), data[i].dineIn.toDouble()));
      takeAwaySpots.add(FlSpot(i.toDouble(), data[i].takeAway.toDouble()));
      deliverySpots.add(FlSpot(i.toDouble(), data[i].delivery.toDouble()));
      onlineSpots.add(FlSpot(i.toDouble(), data[i].online.toDouble()));
      counterSpots.add(FlSpot(i.toDouble(), data[i].counter.toDouble()));
    }

    double maxY = [
      ...dineSpots, ...takeAwaySpots, ...deliverySpots, ...onlineSpots,
    ].map((e) => e.y).fold(0.0, (a, b) => a > b ? a : b);
    if (maxY < 100) maxY = 100;
    int yStep = maxY > 10000 ? 5000 : 1000;
    maxY = (((maxY / yStep).ceil()) * yStep).toDouble();

    double chartWidth = (data.length * 140).toDouble();  // Adjusted width per label
    if (chartWidth < MediaQuery.of(context).size.width) {
      chartWidth = MediaQuery.of(context).size.width - 48;
    }

    List<LineChartBarData> lines = [
      if (dineSpots.any((e) => e.y > 0))
        LineChartBarData(
          spots: dineSpots,
          isCurved: true,
          color: Colors.blue,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      if (takeAwaySpots.any((e) => e.y > 0))
        LineChartBarData(
          spots: takeAwaySpots,
          isCurved: true,
          color: Colors.cyan,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      if (deliverySpots.any((e) => e.y > 0))
        LineChartBarData(
          spots: deliverySpots,
          isCurved: true,
          color: const Color(0xFF63B32D),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      if (onlineSpots.any((e) => e.y > 0))
        LineChartBarData(
          spots: onlineSpots,
          isCurved: true,
          color: Colors.orange,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      if (counterSpots.any((e) => e.y > 0))
        LineChartBarData(
          spots: counterSpots,
          isCurved: true,
          color: Colors.purple,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
    ];

    if (lines.isEmpty) {
      lines.add(
        LineChartBarData(
          spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), 0)),
          isCurved: true,
          color: Colors.blue,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    return SizedBox(
      height: 320,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: chartWidth,
          child: LineChart(
            LineChartData(
              lineBarsData: lines,
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yStep.toDouble(),
                getDrawingHorizontalLine: (value) => FlLine(
                  color: const Color(0xFFE0E0E0),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: Colors.black26, width: 1),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: yStep.toDouble(),
                    getTitlesWidget: (value, meta) {
                      if (value % yStep != 0) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          "${(value ~/ 1000)}k",
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF9E9E9E),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60, // more reserved space for multi-line + rotated text
                    getTitlesWidget: (value, meta) {
                      int idx = value.round();
                      if (value != idx.toDouble() || idx < 0 || idx >= data.length) return const SizedBox();
                      String label = data[idx].label;

                      return Transform.rotate(
                        angle: -0.5, // ~ -28 degrees for better fit, adjust if needed
                        child: SizedBox(
                          width: 100,
                          child: Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9E9E9E),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineTouchData: LineTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                getTouchedSpotIndicator: (barData, spotIndexes) {
                  return spotIndexes.map((spotIdx) {
                    return TouchedSpotIndicatorData(
                      FlLine(color: Colors.transparent),
                      FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, idx) {
                          return FlDotCirclePainter(
                            radius: 8,
                            color: bar.color ?? Colors.blue,
                            strokeWidth: 3,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                    );
                  }).toList();
                },
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: Colors.white,
                  tooltipRoundedRadius: 8,
                  tooltipPadding: const EdgeInsets.all(10),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (touchedSpots) {
                    if (touchedSpots.isEmpty) return [];
                    final idx = touchedSpots.first.x.toInt();
                    if (idx < 0 || idx >= data.length) return [];
                    final d = data[idx];
                    List<String> lines = [];
                    lines.add('${d.label}');
                    if (d.dineIn > 0) lines.add('Dine In : ₹ ${d.dineIn}');
                    if (d.takeAway > 0) lines.add('TAKE AWAY : ₹ ${d.takeAway}');
                    if (d.delivery > 0) lines.add('Delivery : ₹ ${d.delivery}');
                    if (d.online > 0) lines.add('Online : ₹ ${d.online}');
                    lines.add('Total : ₹ ${d.dineIn + d.takeAway + d.delivery + d.online}');
                    return [
                      LineTooltipItem(
                        lines.join('\n'),
                        const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ];
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChartBarData {
  final String label;
  final int dineIn;
  final int takeAway;
  final int delivery;
  final int online;
  final int counter; // ADD THIS

  ChartBarData(this.label, this.dineIn, this.takeAway, this.delivery, this.online, this.counter);
}

class ChartLineData {
  final String label;
  final int dineIn;
  final int takeAway;
  final int delivery;
  final int online;
  final int counter;
  ChartLineData(this.label, this.dineIn, this.takeAway, this.delivery, this.online,this.counter);
}


class CalendarDateRangePicker extends StatelessWidget {
  final DateTimeRange initialRange;
  final void Function(DateTimeRange range) onRangeSelected;

  const CalendarDateRangePicker({super.key, required this.initialRange, required this.onRangeSelected});

  @override
  Widget build(BuildContext context) {

    return SizedBox(
      width: 300,
      child: CalendarDatePicker(
        initialDate: initialRange.start,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        onDateChanged: (date) {
          // Demo: for production use a custom date range picker here.
        },
      ),
    );
  }
}