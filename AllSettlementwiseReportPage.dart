import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:merchant/TotalSalesReport.dart';
import 'package:merchant/main.dart';
import 'SidePanel.dart';

class AllSettlementwiseReportPage extends StatefulWidget {
  final Map<String, String> dbToBrandMap;
  const AllSettlementwiseReportPage({super.key, required this.dbToBrandMap});

  @override
  State<AllSettlementwiseReportPage> createState() => _AllSettlementwiseReportPageState();
}

class _AllSettlementwiseReportPageState extends State<AllSettlementwiseReportPage> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String? selectedDbKey = "All";
  bool _loading = false;

  final List<_Col> _allColumns = [
    _Col('Restaurants', 'restaurant'),
    _Col('Bill Date', 'billDate'),
    _Col('Settlement Mode', 'settlementModeName'),
    _Col('Gross Amount', 'grossAmount'),
    _Col('Number of Bills', 'numberOfBills'),
    _Col('Percent To Gross', 'percentToGross'),
  ];
  late List<_Col> _visibleColumns;

  List<_SettlementwiseRow> _allRows = [];

  final _horizontalScroll = ScrollController();
  final _verticalScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _visibleColumns = List.from(_allColumns);
    selectedDbKey = "All";
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    _allRows = [];
    final config = await Config.loadFromAsset();
    String startDate = DateFormat('dd-MM-yyyy').format(_startDate);
    String endDate = DateFormat('dd-MM-yyyy').format(_endDate);

    List<String> dbList;
    if (selectedDbKey == null || selectedDbKey == "All") {
      dbList = widget.dbToBrandMap.keys.toList();
    } else {
      dbList = [selectedDbKey!];
    }

    Map<String, List<SettlementwiseReport>> dbToSettlementwise =
    await UserData.fetchSettlementwiseForDbs(config, dbList, startDate, endDate);

    if (selectedDbKey == null || selectedDbKey == "All") {
      for (final list in dbToSettlementwise.values) {
        for (final report in list) {
          _allRows.add(_SettlementwiseRow.fromReport(
            report: report,
            restaurant: "ALL",
          ));
        }
      }
    } else {
      for (final list in dbToSettlementwise.values) {
        for (final report in list) {
          _allRows.add(_SettlementwiseRow.fromReport(
            report: report,
            restaurant: widget.dbToBrandMap[selectedDbKey!] ?? selectedDbKey!,
          ));
        }
      }
    }
    setState(() => _loading = false);
  }

  _SettlementwiseRow get totalRow {
    double sum(String Function(_SettlementwiseRow) getter) => _allRows.fold(0.0, (a, b) => a + double.tryParse(getter(b))!);

    return _SettlementwiseRow(
      restaurant: "Total",
      billDate: "",
      settlementModeName: "",
      grossAmount: sum((r) => r.grossAmount).toStringAsFixed(2),
      numberOfBills: sum((r) => r.numberOfBills).toStringAsFixed(0),
      percentToGross: "", // Not summed
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

    // Report name (bold)
    final reportCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum));
    reportCell.value = "All Settlementwise Report";
    reportCell.cellStyle = boldStyle;
    rowNum++;
    rowNum++; // blank row

    // Brand/DB Heading (bold)
    if (selectedDbKey == null || selectedDbKey == "All") {
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
      brandCell.value = widget.dbToBrandMap[selectedDbKey!] ?? selectedDbKey!;
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
    final String path = '${Directory.current.path}/AllSettlementwiseReport.xlsx';
    final file = File(path);
    await file.writeAsBytes(fileBytes!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel exported to $path')));
    }
    // Open Excel file after export (Windows/Mac/Linux)
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
    final dbKeys = widget.dbToBrandMap.keys.toList();
    final brandDropdownItems = ["All", ...dbKeys];
    final brandDisplayMap = {
      "All": "All Outlets",
      ...{for (final db in dbKeys) db: widget.dbToBrandMap[db]!}
    };

    String safeSelectedDbKey = brandDropdownItems.contains(selectedDbKey) ? selectedDbKey! : "All";
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1024;
    final rowHeight = 48.0;
    final headerHeight = 56.0;

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
                      value: safeSelectedDbKey,
                      isExpanded: true,
                      items: brandDropdownItems.map((db) => DropdownMenuItem(
                        value: db,
                        child: Text(brandDisplayMap[db]!),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedDbKey = value;
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
                    onTap: () => Navigator.pop(context),
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
                      "Settlementwise Report",
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
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20), // ✅ updated
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ Horizontally scrollable Start + End Date
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
                            const SizedBox(width: 18),
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
                      const SizedBox(height: 16),
                      // ✅ Restaurants dropdown + updated Search button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _dropdownFilter(
                            "Restaurants",
                            brandDropdownItems,
                            safeSelectedDbKey,
                                (val) {
                              setState(() => selectedDbKey = val);
                              _fetchData();
                            },
                            brandDisplayMap,
                          ),
                          const SizedBox(width: 16),
                          Padding(
                            padding: const EdgeInsets.only(top: 20), // ✅ consistent alignment
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8), // ✅ square round border
                                ),
                              ),
                              onPressed: _fetchData,
                              icon: const Icon(Icons.search),
                              label: const Text("Search"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),

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
                            color: col.title == 'Settlement Mode' ? Colors.red[700] : Colors.black,
                            fontWeight: col.title == 'Settlement Mode' ? FontWeight.bold : FontWeight.normal,
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
            // Table with sticky header and sticky total row
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                children: [
                  // Sticky Header
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _horizontalScroll,
                    child: _buildHeaderRow(headerHeight),
                  ),
                  // Data Rows (vertical + horizontal scroll)
                  Expanded(
                    child: Scrollbar(
                      controller: _verticalScroll,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _verticalScroll,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _horizontalScroll,
                          child: _buildDataRows(rowHeight),
                        ),
                      ),
                    ),
                  ),
                  // Sticky Total Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _horizontalScroll,
                    child: _buildTotalRow(rowHeight),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(double height) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        border: Border(
          bottom: BorderSide(color: Colors.grey[400]!),
          top: BorderSide(color: Colors.grey[400]!),
        ),
      ),
      child: Row(
        children: _visibleColumns.map((col) {
          return Container(
            width: 180,
            height: height,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey[400]!),
              ),
            ),
            child: Text(col.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDataRows(double rowHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_allRows.length, (i) {
        final row = _allRows[i];
        return Row(
          children: _visibleColumns.map((col) {
            return Container(
              width: 180,
              height: rowHeight,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: i % 2 == 0 ? Colors.white : Colors.grey[100],
                border: Border(
                  right: BorderSide(color: Colors.grey[300]!),
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Text(row.getField(col.key).toString()),
            );
          }).toList(),
        );
      }),
    );
  }

  Widget _buildTotalRow(double rowHeight) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDD0),
        border: Border(
          top: BorderSide(color: Colors.grey[400]!, width: 2),
          bottom: BorderSide(color: Colors.grey[400]!),
        ),
      ),
      child: Row(
        children: _visibleColumns.map((col) {
          return Container(
            width: 180,
            height: rowHeight,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey[400]!),
              ),
            ),
            child: Text(totalRow.getField(col.key).toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
          );
        }).toList(),
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

  Widget _dropdownFilter(String label, List<String> dbKeys, String selectedDbKey, ValueChanged<String?> onChanged, Map<String, String> dbKeyToBrand) {
    String safeSelected = dbKeys.contains(selectedDbKey) ? selectedDbKey : dbKeys.first;
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
            items: dbKeys.map((db) => DropdownMenuItem(
              value: db,
              child: Text(dbKeyToBrand[db] ?? db),
            )).toList(),
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

class _SettlementwiseRow {
  final String restaurant;
  final String billDate;
  final String settlementModeName;
  final String grossAmount;
  final String numberOfBills;
  final String percentToGross;

  _SettlementwiseRow({
    required this.restaurant,
    required this.billDate,
    required this.settlementModeName,
    required this.grossAmount,
    required this.numberOfBills,
    required this.percentToGross,
  });

  factory _SettlementwiseRow.fromReport({required SettlementwiseReport report, required String restaurant}) {
    return _SettlementwiseRow(
      restaurant: restaurant,
      billDate: report.billDate,
      settlementModeName: report.settlementModeName,
      grossAmount: report.grossAmount,
      numberOfBills: report.numberOfBills,
      percentToGross: report.percentToGross,
    );
  }

  dynamic getField(String key) {
    switch (key) {
      case 'restaurant': return restaurant ?? "";
      case 'billDate': return billDate ?? "";
      case 'settlementModeName': return settlementModeName ?? "";
      case 'grossAmount': return grossAmount ?? "0.00";
      case 'numberOfBills': return numberOfBills ?? "0";
      case 'percentToGross': return percentToGross ?? "0.00";
      default: return '';
    }
  }
}