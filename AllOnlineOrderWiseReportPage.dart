import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'SidePanel.dart';

class AllOnlineOrderWiseReportPage extends StatefulWidget {
  final Map<String, String> dbToBrandMap;
  const AllOnlineOrderWiseReportPage({super.key, required this.dbToBrandMap});

  @override
  State<AllOnlineOrderWiseReportPage> createState() => _AllOnlineOrderWiseReportPageState();
}

class _AllOnlineOrderWiseReportPageState extends State<AllOnlineOrderWiseReportPage> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String _selectedStatus = "All";
  String? selectedBrand = "All";
  final List<String> _orderStatuses = ["All", "Zomato", "Swiggy", "Dunzo"]; // Example online sources

  // Columns for Online Order Wise Report
  final List<_Col> _allColumns = [
    _Col('Restaurants', 'restaurant'),
    _Col('Order No.', 'orderNo'),
    _Col('Order Source', 'orderSource'),
    _Col('Order Date', 'orderDate'),
    _Col('Order Status', 'orderStatus'),
    _Col('Gross Amount', 'grossAmount'),
    _Col('Discount', 'discount'),
    _Col('Tax', 'tax'),
    _Col('Net Amount', 'netAmount'),
    // Add more columns as needed
  ];
  late List<_Col> _visibleColumns;

  // Data
  List<_OnlineOrderRow> _allRows = [];
  List<_OnlineOrderRow> _filteredRows = [];

  @override
  void initState() {
    super.initState();
    _visibleColumns = List.from(_allColumns);
    selectedBrand = "All";
    _fetchData();
  }

  void _fetchData() {
    // TODO: Replace with actual API call and parse data!
    // For demo, we use static/mock data:
    _allRows = [
      _OnlineOrderRow(
        restaurant: "Ebony//The Flip Bar",
        orderNo: "ZOM20240501-0012",
        orderSource: "Zomato",
        orderDate: "2025-05-01",
        orderStatus: "Delivered",
        grossAmount: 800.0,
        discount: 50.0,
        tax: 25.0,
        netAmount: 775.0,
      ),
      // Add more rows for demo if needed
    ];
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filteredRows = _allRows.where((row) {
        // Brand filter
        if (selectedBrand != null && selectedBrand != "All") {
          return row.restaurant == selectedBrand;
        }
        // Status/Source filter
        if (_selectedStatus != "All" && row.orderSource != _selectedStatus) {
          return false;
        }
        // TODO: Add more filters as needed (date, etc)
        return true;
      }).toList();
    });
  }

  void _toggleColumn(_Col col, bool value) {
    setState(() {
      if (value) {
        if (!_visibleColumns.contains(col)) _visibleColumns.add(col);
      } else {
        _visibleColumns.remove(col);
      }
    });
  }

  Future<void> _exportExcel() async {
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile['Sheet1'];

    // Header
    sheet.appendRow(_visibleColumns.map((c) => c.title).toList());

    // Data
    for (final row in _filteredRows) {
      sheet.appendRow(_visibleColumns.map((c) => row.getField(c.key)).toList());
    }

    final fileBytes = excelFile.encode();
    final String path = '/storage/emulated/0/Download/AllOnlineOrderWiseReport.xlsx';
    final file = File(path);
    await file.writeAsBytes(fileBytes!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel exported to $path')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1024;

    // Consistent dropdown logic as above
    final brandNames = <String>{"All", ...widget.dbToBrandMap.values};
    String safeSelectedBrand = brandNames.contains(selectedBrand) ? selectedBrand! : "All";

    return SidePanel(
      dbToBrandMap: widget.dbToBrandMap,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: Padding(
            padding: EdgeInsets.only(left: isMobile ? 0 : 8.0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
              tooltip: "Back",
            ),
          ),
          titleSpacing: isMobile ? 0 : 12,
          title: Row(
            children: [
              Image.asset('assets/images/reddpos.png', height: isMobile ? 28 : isTablet ? 34 : 38),
              SizedBox(width: isMobile ? 5 : 10),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: BoxConstraints(
                    minWidth: isMobile ? 70 : 100,
                    maxWidth: isMobile ? 140 : isTablet ? 180 : 260,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: safeSelectedBrand,
                      hint: const Text(
                        "All Outlets",
                        style: TextStyle(color: Colors.black),
                        overflow: TextOverflow.ellipsis,
                      ),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                      isExpanded: true,
                      items: brandNames.map((brand) => DropdownMenuItem(
                        value: brand,
                        child: Text(
                          brand,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedBrand = value;
                        });
                        _applyFilters();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: const [],
        ),
        body: Column(
          children: [
            // Breadcrumb
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.only(
                left: isMobile ? 8 : 22,
                top: isMobile ? 10 : 18,
                bottom: isMobile ? 0 : 3,
              ),
              child: Row(
                children: [
                  Icon(Icons.home, color: Colors.grey, size: isMobile ? 16 : 18),
                  SizedBox(width: isMobile ? 3 : 7),
                  GestureDetector(
                    onTap: () => Navigator.pop(context), // Go back if Reports clicked
                    child: Text(
                      "Reports",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: isMobile ? 13 : 16,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey, size: isMobile ? 16 : 18),
                  Expanded(
                    child: Text(
                      "Online Order Wise Report",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 14 : 17,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Filters
            Container(
              color: const Color(0xFFF3F3F3),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1st Row: Start Date & End Date (scrollable horizontally)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 160,
                          child: _dateFilter("Order Date", _startDate, (d) {
                            setState(() => _startDate = d);
                            _applyFilters();
                          }),
                        ),
                        const SizedBox(width: 18),
                        SizedBox(
                          width: 160,
                          child: _dateFilter("Order Date", _endDate, (d) {
                            setState(() => _endDate = d);
                            _applyFilters();
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2nd Row: Order Source, Restaurants dropdowns + Search button with icon (scrollable horizontally)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dropdownFilter("Order Source", _orderStatuses, _selectedStatus, (val) {
                          setState(() => _selectedStatus = val!);
                          _applyFilters();
                        }),
                        const SizedBox(width: 18),
                        _dropdownFilter("Restaurants", brandNames.toList(), safeSelectedBrand, (val) {
                          setState(() => selectedBrand = val);
                          _applyFilters();
                        }),
                        const SizedBox(width: 18),
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _applyFilters,
                            icon: const Icon(Icons.search),
                            label: const Text("Search"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )

            ,
            // Columns + Export buttons
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
              child: Row(
                children: [
                  PopupMenuButton<_Col>(
                    offset: const Offset(0, 42),
                    tooltip: "Show/Hide Columns",
                    constraints: const BoxConstraints(maxHeight: 350, minWidth: 250),
                    itemBuilder: (context) => _allColumns.map((col) {
                      return CheckedPopupMenuItem<_Col>(
                        value: col,
                        checked: _visibleColumns.contains(col),
                        child: Text(
                          col.title,
                          style: TextStyle(
                            color: col.title == 'Order No.' ? Colors.red[700] : Colors.black,
                            fontWeight: col.title == 'Order No.' ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                    onSelected: (col) {
                      final isVisible = _visibleColumns.contains(col);
                      _toggleColumn(col, !isVisible);
                    },
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.view_column),
                      label: const Text("Columns"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                      ),
                      onPressed: null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _exportExcel,
                    child: const Text("Excel"),
                  ),
                ],
              ),
            ),
            // Table
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _visibleColumns.length * 180,
                  child: ListView(
                    children: [
                      // Table Header
                      Container(
                        color: const Color(0xFFF3F3F3),
                        child: Row(
                          children: _visibleColumns.map((col) =>
                              Container(
                                width: 180,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                alignment: Alignment.centerLeft,
                                child: Text(col.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              )
                          ).toList(),
                        ),
                      ),
                      // Data Rows
                      ..._filteredRows.map((row) => Row(
                        children: _visibleColumns.map((col) =>
                            Container(
                              width: 180,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              alignment: Alignment.centerLeft,
                              child: Text(row.getField(col.key).toString()),
                            )
                        ).toList(),
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateFilter(String label, DateTime date, ValueChanged<DateTime> onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 4),
        SizedBox(
          width: 160,
          child: TextField(
            readOnly: true,
            decoration: InputDecoration(
              hintText: DateFormat('yyyy-MM-dd').format(date),
              prefixIcon: Icon(Icons.calendar_today, color: Colors.red[700]),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) onPicked(picked);
            },
          ),
        ),
      ],
    );
  }

  Widget _dropdownFilter(String label, List<String> options, String selected, ValueChanged<String?> onChanged) {
    String safeSelected = options.contains(selected) ? selected : options.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 4),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: safeSelected,
            items: options.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            ),
          ),
        ),
      ],
    );
  }
}

class _Col {
  final String title;
  final String key;
  const _Col(this.title, this.key);

  @override
  bool operator ==(Object other) => other is _Col && other.key == key;
  @override
  int get hashCode => key.hashCode;
}

class _OnlineOrderRow {
  final String restaurant;
  final String orderNo;
  final String orderSource;
  final String orderDate;
  final String orderStatus;
  final double grossAmount;
  final double discount;
  final double tax;
  final double netAmount;

  _OnlineOrderRow({
    required this.restaurant,
    required this.orderNo,
    required this.orderSource,
    required this.orderDate,
    required this.orderStatus,
    required this.grossAmount,
    required this.discount,
    required this.tax,
    required this.netAmount,
  });

  dynamic getField(String key) {
    switch (key) {
      case 'restaurant': return restaurant;
      case 'orderNo': return orderNo;
      case 'orderSource': return orderSource;
      case 'orderDate': return orderDate;
      case 'orderStatus': return orderStatus;
      case 'grossAmount': return grossAmount.toStringAsFixed(2);
      case 'discount': return discount.toStringAsFixed(2);
      case 'tax': return tax.toStringAsFixed(2);
      case 'netAmount': return netAmount.toStringAsFixed(2);
      default: return '';
    }
  }
}