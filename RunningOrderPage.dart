import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:merchant/KotSummaryReport.dart';
import 'SidePanel.dart';
import 'main.dart' as app;

class TableStatus {
  final String tableName;
  final String status;
  final String area;
  final String db;

  TableStatus({
    required this.tableName,
    required this.status,
    required this.area,
    required this.db,
  });

  factory TableStatus.fromJson(Map<String, dynamic> json, String db) {
    return TableStatus(
      tableName: json['tableName'] ?? '',
      status: json['status'] ?? '',
      area: json['area'] ?? '',
      db: db,
    );
  }
}

class RunningOrderPage extends StatefulWidget {
  final Map<String, String> dbToBrandMap;
  const RunningOrderPage({super.key, this.dbToBrandMap = const {}});
  @override
  State<RunningOrderPage> createState() => _RunningOrderPageState();
}

class _RunningOrderPageState extends State<RunningOrderPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? selectedBrand;
  List<KotSummaryReport> orders = [];
  bool isLoading = false;
  List<TableStatus> occupiedTables = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    selectedBrand = "All";
    fetchKotOrders();
    fetchOccupiedTables();
  }

  Future<void> fetchKotOrders() async {
    setState(() { isLoading = true; });
    final config = await app.Config.loadFromAsset();
    final dbNames = widget.dbToBrandMap.keys.toList();
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy').format(now);
    Map<String, List<KotSummaryReport>> dbToKotSummaryMap =
    await app.UserData.fetchKotSummaryForDbs(config, dbNames, dateStr, dateStr);
    List<KotSummaryReport> allOrders = dbToKotSummaryMap.values.expand((x) => x).toList();
    List<KotSummaryReport> activeOrders = allOrders.where((o) => o.kotStatus == "active").toList();
    setState(() {
      orders = activeOrders;
      isLoading = false;
    });
  }

  Future<void> fetchOccupiedTables() async {
    print("fetchOccupiedTables CALLED");
    List<TableStatus> allOccupied = [];
    final config = await app.Config.loadFromAsset();
    for (final db in widget.dbToBrandMap.keys) {
      final url = "${config.apiUrl}table/getAll?DB=$db";
      print("Requesting table status from: $url");
      try {
        final response = await http.get(Uri.parse(url));
        print("Status for table DB '$db': ${response.statusCode}");
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            final tables = decoded
                .map<TableStatus>((e) => TableStatus.fromJson(e, db))
                .where((t) => t.status.toLowerCase() == "occupied")
                .toList();
            allOccupied.addAll(tables);
            print("Total occupied tables fetched: ${allOccupied.length}");
          }
        }
      } catch (e) {
        print("❌ Exception: $e");
      }
    }
    setState(() {
      occupiedTables = allOccupied;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brandNames = widget.dbToBrandMap.values.toSet();
    final screenWidth = MediaQuery.of(context).size.width;
    List<KotSummaryReport> filteredOrders = orders.where((o) =>
    selectedBrand == "All" ||
        widget.dbToBrandMap[o.kotId] == selectedBrand
    ).toList();
    return SidePanel(
      dbToBrandMap: widget.dbToBrandMap,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 90,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(width: 16),
                      Image.asset(
                        'assets/images/reddpos.png',
                        height: 40,
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 120,
                          maxWidth: 200,
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
                              ...brandNames.map(
                                    (brand) => DropdownMenuItem(
                                  value: brand,
                                  child: Text(
                                    brand,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedBrand = value;
                                fetchOccupiedTables();
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.refresh, size: 18, color: Colors.black87),
                        label: const Text(
                          "Refresh",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: () {
                          fetchKotOrders();
                          fetchOccupiedTables();
                        },
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFFD5282B),
                  unselectedLabelColor: Colors.black,
                  indicatorColor: const Color(0xFFD5282B),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  tabs: const [
                    Tab(text: "Running Orders"),
                    Tab(text: "Running Tables"),
                  ],
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOrdersTab(screenWidth, filteredOrders),
                    _buildTablesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),

      ),
    );
  }

  Widget _buildOrdersTab(double screenWidth, List<KotSummaryReport> orders) {
    // ... same as before ...
    final dineOrders = orders.where((o) => o.orderType?.toLowerCase() == 'dine').toList();
    final pickupOrders = orders.where((o) => o.orderType?.toLowerCase() == 'pickup').toList();
    final deliveryOrders = orders.where((o) => o.orderType?.toLowerCase() == 'delivery').toList();
    final counterOrders = orders.where((o) => o.orderType?.toLowerCase() == 'counter').toList();
    double dineTotal = dineOrders.length * 0.0;
    double pickupTotal = pickupOrders.length * 0.0;
    double deliveryTotal = deliveryOrders.length * 0.0;
    double counterTotal = counterOrders.length * 0.0;
    int crossAxisCount;
    if (screenWidth >= 1200) {
      crossAxisCount = 4;
    } else if (screenWidth >= 800) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 2;
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F8FE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text("Order", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                      Text("${orders.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))
                    ],
                  ),
                ),
                Container(
                  height: 32,
                  width: 1,
                  color: Colors.grey[300],
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text("₹", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                      Text("0.00", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 20,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _orderCard("Dine In", dineOrders.length, dineTotal),
              _orderCard("Pick Up", pickupOrders.length, pickupTotal),
              _orderCard("Delivery", deliveryOrders.length, deliveryTotal),
              _orderCard("Counter", counterOrders.length, counterTotal),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orderCard(String title, int orderCount, double amount, {String? subtitle}) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 6),
                  child: Text(
                    subtitle!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 8),
              const Text("Orders", style: TextStyle(color: Colors.grey, fontSize: 11)),
              Text(
                "$orderCount",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "₹ ${amount.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        )

      ),
    );
  }

  Widget _buildTablesTab() {
    // Filter by selectedBrand
    final selectedDb = selectedBrand == "All"
        ? null
        : widget.dbToBrandMap.entries.firstWhere((e) => e.value == selectedBrand, orElse: () => MapEntry('', '')).key;
    List<TableStatus> filteredTables = selectedDb == null || selectedDb.isEmpty
        ? occupiedTables
        : occupiedTables.where((t) => t.db == selectedDb).toList();

    // Group by area, then show tableName inside
    Map<String, List<TableStatus>> areaMap = {};
    for (final t in filteredTables) {
      areaMap.putIfAbsent(t.area, () => []).add(t);
    }
    return areaMap.isEmpty
        ? const Center(
      child: Text(
        "No Running Tables",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
    )
        : ListView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      children: areaMap.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.key,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD5282B)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 18,
              runSpacing: 14,
              children: entry.value
                  .map((t) => Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.09),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.tableName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      t.status,
                      style: TextStyle(
                        color: t.status.toLowerCase() == 'occupied'
                            ? Colors.red
                            : Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],
        );
      }).toList(),
    );
  }
}