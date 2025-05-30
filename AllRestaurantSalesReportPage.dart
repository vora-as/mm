import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'SidePanel.dart';
import 'main.dart';
import 'TotalSalesReport.dart';

class AllRestaurantSalesReportPage extends StatefulWidget {
  final Map<String, String> dbToBrandMap;
  const AllRestaurantSalesReportPage({super.key, required this.dbToBrandMap});

  @override
  State<AllRestaurantSalesReportPage> createState() => _AllRestaurantSalesReportPageState();
}

class _AllRestaurantSalesReportPageState extends State<AllRestaurantSalesReportPage> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String? selectedBrand = "All";
  final List<_Col> _allColumns = [
    _Col('Restaurants', 'restaurant'),
    _Col('Dine In Sales', 'dineInSales'),
    _Col('Take Away Sales', 'takeAwaySales'),
    _Col('Online Sales', 'onlineSales'),
    _Col('Home Delivery Sales', 'homeDeliverySales'),
    _Col('Counter Sales', 'counterSales'),
    _Col('Grand Total', 'grandTotal'),
    _Col('Bill Tax', 'billTax'),
    _Col('Bill Discount', 'billDiscount'),
    _Col('Round Off', 'roundOffTotal'),
    _Col('Occupied Table Count', 'occupiedTableCount'),
    _Col('Cash Sales', 'cashSales'),
    _Col('Card Sales', 'cardSales'),
    _Col('UPI Sales', 'upiSales'),
    _Col('Others Sales', 'othersSales'),
    _Col('Net Total', 'netTotal'),
  ];
  late List<_Col> _visibleColumns;
  List<_SalesRow> _allRows = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _visibleColumns = List.from(_allColumns);
    selectedBrand = "All";
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    _allRows = [];
    final config = await Config.loadFromAsset();
    String startDate = DateFormat('dd-MM-yyyy').format(_startDate);
    String endDate = DateFormat('dd-MM-yyyy').format(_endDate);

    List<String> dbList;
    if (selectedBrand == null || selectedBrand == "All") {
      dbList = widget.dbToBrandMap.keys.toList();
    } else {
      dbList = widget.dbToBrandMap.entries
          .where((entry) => entry.value == selectedBrand)
          .map((entry) => entry.key)
          .toList();
    }

    Map<String, TotalSalesReport> dbToReport =
    (await UserData.fetchTotalSalesForDbs(config, dbList, startDate, endDate)).cast<String, TotalSalesReport>();

    // Remove 'ALL' if present
    dbToReport.remove('ALL');
    dbToReport.remove('all');

    _allRows = dbToReport.entries.map((e) {
      final r = e.value;
      return _SalesRow(
        restaurant: widget.dbToBrandMap[e.key] ?? e.key,
        dineInSales: double.tryParse(r.getField("dineInSales", fallback: "0")) ?? 0.0,
        takeAwaySales: double.tryParse(r.getField("takeAwaySales", fallback: "0")) ?? 0.0,
        onlineSales: double.tryParse(r.getField("onlineSales", fallback: "0")) ?? 0.0,
        homeDeliverySales: double.tryParse(r.getField("homeDeliverySales", fallback: "0")) ?? 0.0,
        counterSales: double.tryParse(r.getField("counterSales", fallback: "0")) ?? 0.0,
        grandTotal: double.tryParse(r.getField("grandTotal", fallback: "0")) ?? 0.0,
        billTax: double.tryParse(r.getField("billTax", fallback: "0")) ?? 0.0,
        billDiscount: double.tryParse(r.getField("billDiscount", fallback: "0")) ?? 0.0,
        roundOffTotal: double.tryParse(r.getField("roundOffTotal", fallback: "0")) ?? 0.0,
        occupiedTableCount: double.tryParse(r.getField("occupiedTableCount", fallback: "0")) ?? 0.0,
        cashSales: double.tryParse(r.getField("cashSales", fallback: "0")) ?? 0.0,
        cardSales: double.tryParse(r.getField("cardSales", fallback: "0")) ?? 0.0,
        upiSales: double.tryParse(r.getField("upiSales", fallback: "0")) ?? 0.0,
        othersSales: double.tryParse(r.getField("othersSales", fallback: "0")) ?? 0.0,
        netTotal: double.tryParse(r.getField("netTotal", fallback: "0")) ?? 0.0,
      );
    }).toList();

    setState(() => _loading = false);
  }

  _SalesRow get totalRow {
    return _SalesRow(
      restaurant: "Total",
      dineInSales: _allRows.fold(0.0, (a, b) => a + b.dineInSales),
      takeAwaySales: _allRows.fold(0.0, (a, b) => a + b.takeAwaySales),
      onlineSales: _allRows.fold(0.0, (a, b) => a + b.onlineSales),
      homeDeliverySales: _allRows.fold(0.0, (a, b) => a + b.homeDeliverySales),
      counterSales: _allRows.fold(0.0, (a, b) => a + b.counterSales),
      grandTotal: _allRows.fold(0.0, (a, b) => a + b.grandTotal),
      billTax: _allRows.fold(0.0, (a, b) => a + b.billTax),
      billDiscount: _allRows.fold(0.0, (a, b) => a + b.billDiscount),
      roundOffTotal: _allRows.fold(0.0, (a, b) => a + b.roundOffTotal),
      occupiedTableCount: _allRows.fold(0.0, (a, b) => a + b.occupiedTableCount),
      cashSales: _allRows.fold(0.0, (a, b) => a + b.cashSales),
      cardSales: _allRows.fold(0.0, (a, b) => a + b.cardSales),
      upiSales: _allRows.fold(0.0, (a, b) => a + b.upiSales),
      othersSales: _allRows.fold(0.0, (a, b) => a + b.othersSales),
      netTotal: _allRows.fold(0.0, (a, b) => a + b.netTotal),
    );
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
    final boldStyle = excel.CellStyle(bold: true);

    int rowNum = 0;

    // Write the report name (bold and large)
    final reportCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum));
    reportCell.value = "All Restaurant Sales Report";
    reportCell.cellStyle = boldStyle;
    rowNum++;
    rowNum++; // blank row for spacing

    // Brand/DB Heading (bold)
    if (selectedBrand == null || selectedBrand == "All") {
      final brands = widget.dbToBrandMap.values.toSet().toList();
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum));
      cell.value = "Brands/DBs:";
      cell.cellStyle = boldStyle;
      rowNum++;
      for (int i = 0; i < brands.length; i++) {
        final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum));
        cell.value = brands[i];
        cell.cellStyle = boldStyle;
      }
      rowNum++;
      rowNum++; // blank row
    } else {
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum));
      cell.value = "Brand/DB:";
      cell.cellStyle = boldStyle;
      rowNum++;
      final brandCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum));
      brandCell.value = selectedBrand;
      brandCell.cellStyle = boldStyle;
      rowNum++;
      rowNum++; // blank row
    }

    // Filter info (not bold)
    sheet.appendRow([
      "Date From", DateFormat('dd-MM-yyyy').format(_startDate),
      "Date To", DateFormat('dd-MM-yyyy').format(_endDate)
    ]);
    rowNum++;
    sheet.appendRow([]);
    rowNum++;

    // Table header (bold)
    final headerRow = _visibleColumns.map((c) => c.title).toList();
    for (int i = 0; i < headerRow.length; i++) {
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum));
      cell.value = headerRow[i];
      cell.cellStyle = boldStyle;
    }
    rowNum++;

    // Data
    for (final row in _allRows) {
      for (int i = 0; i < _visibleColumns.length; i++) {
        final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum));
        cell.value = row.getField(_visibleColumns[i].key);
      }
      rowNum++;
    }

    // Total row (bold)
    final total = _visibleColumns.map((c) => totalRow.getField(c.key)).toList();
    for (int i = 0; i < total.length; i++) {
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum));
      cell.value = total[i];
      cell.cellStyle = boldStyle;
    }

    final fileBytes = excelFile.encode();
    final String path = '${Directory.current.path}/AllRestaurantSalesReport.xlsx';
    final file = File(path);
    await file.writeAsBytes(fileBytes!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel exported to $path')));
    }
    // Open the Excel file after export
    try {
      if (Platform.isWindows) {
        await Process.run('start', [path], runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final brandNames = <String>{"All", ...widget.dbToBrandMap.values};
    String safeSelectedBrand = brandNames.contains(selectedBrand) ? selectedBrand! : "All";
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1024;

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
                        _fetchData();
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
                      "All Restaurant Sales Report",
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
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 26),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Start Date + End Date
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 160,
                              child: _dateFilter("Start Date", _startDate, (d) {
                                setState(() => _startDate = d);
                                _fetchData();
                              }),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 160,
                              child: _dateFilter("End Date", _endDate, (d) {
                                setState(() => _endDate = d);
                                _fetchData();
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Row 2: Dropdown + Search Button
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center, // Align vertically centered
                          children: [
                            SizedBox(
                              width: 170,
                              child: _dropdownFilter(
                                "Restaurants",
                                brandNames.toList(),
                                safeSelectedBrand,
                                    (val) {
                                  setState(() => selectedBrand = val);
                                  _fetchData();
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Padding(
                              padding: const EdgeInsets.only(top: 20), // Adjust this value as needed
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _fetchData,
                                icon: const Icon(Icons.search),
                                label: const Text("Search"),
                              ),
                            ),

                          ],
                        ),
                      ),

                    ],
                  );
                },
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
                            color: col.title == 'Dine In Sales' ? Colors.red[700] : Colors.black,
                            fontWeight: col.title == 'Dine In Sales' ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                    onSelected: (col) {
                      final isVisible = _visibleColumns.contains(col);
                      _toggleColumn(col, !isVisible);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red[700],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.view_column, color: Colors.white),
                          SizedBox(width: 8),
                          Text("Columns", style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _exportExcel,
                    icon: const Icon(Icons.file_download),
                    label: const Text("Excel"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                ],
              ),
            ),
            // Table
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
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
                      // DB Rows
                      ..._allRows.map((row) => Row(
                        children: _visibleColumns.map((col) =>
                            Container(
                              width: 180,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              alignment: Alignment.centerLeft,
                              child: Text(row.getField(col.key).toString(),
                                style: null,
                              ),
                            )
                        ).toList(),
                      )),
                      // Total Row
                      Container(
                        color: const Color(0xFFFFFDD0),
                        child: Row(
                          children: _visibleColumns.map((col) =>
                              Container(
                                width: 180,
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                alignment: Alignment.centerLeft,
                                child: Text(totalRow.getField(col.key).toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                              )
                          ).toList(),
                        ),
                      ),
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

class _SalesRow {
  final String restaurant;
  final double dineInSales;
  final double takeAwaySales;
  final double onlineSales;
  final double homeDeliverySales;
  final double counterSales;
  final double grandTotal;
  final double billTax;
  final double billDiscount;
  final double roundOffTotal;
  final double occupiedTableCount;
  final double cashSales;
  final double cardSales;
  final double upiSales;
  final double othersSales;
  final double netTotal;

  _SalesRow({
    required this.restaurant,
    this.dineInSales = 0.0,
    this.takeAwaySales = 0.0,
    this.onlineSales = 0.0,
    this.homeDeliverySales = 0.0,
    this.counterSales = 0.0,
    this.grandTotal = 0.0,
    this.billTax = 0.0,
    this.billDiscount = 0.0,
    this.roundOffTotal = 0.0,
    this.occupiedTableCount = 0.0,
    this.cashSales = 0.0,
    this.cardSales = 0.0,
    this.upiSales = 0.0,
    this.othersSales = 0.0,
    this.netTotal = 0.0,
  });

  dynamic getField(String key) {
    switch (key) {
      case 'restaurant': return restaurant;
      case 'dineInSales': return dineInSales.toStringAsFixed(2);
      case 'takeAwaySales': return takeAwaySales.toStringAsFixed(2);
      case 'onlineSales': return onlineSales.toStringAsFixed(2);
      case 'homeDeliverySales': return homeDeliverySales.toStringAsFixed(2);
      case 'counterSales': return counterSales.toStringAsFixed(2);
      case 'grandTotal': return grandTotal.toStringAsFixed(2);
      case 'billTax': return billTax.toStringAsFixed(2);
      case 'billDiscount': return billDiscount.toStringAsFixed(2);
      case 'roundOffTotal': return roundOffTotal.toStringAsFixed(2);
      case 'occupiedTableCount': return occupiedTableCount.toStringAsFixed(2);
      case 'cashSales': return cashSales.toStringAsFixed(2);
      case 'cardSales': return cardSales.toStringAsFixed(2);
      case 'upiSales': return upiSales.toStringAsFixed(2);
      case 'othersSales': return othersSales.toStringAsFixed(2);
      case 'netTotal': return netTotal.toStringAsFixed(2);
      default: return '';
    }
  }
}