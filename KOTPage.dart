import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:merchant/KotSummaryReport.dart';
import 'package:merchant/SidePanel.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'main.dart' as app; // For UserData

class KOTPage extends StatefulWidget {
  final Map<String, String> dbToBrandMap;
  const KOTPage({super.key, required this.dbToBrandMap});

  @override
  State<KOTPage> createState() => _KOTPageState();
}

class _KOTPageState extends State<KOTPage> {
  String? selectedBrand = "All";
  String selectedOrderType = "All";
  String selectedStatus = "All";
  String selectedFilter = "All";
  DateTime startDate = DateTime.now().subtract(const Duration(days: 1));
  DateTime endDate = DateTime.now();
  final TextEditingController kotIdController = TextEditingController();
  final TextEditingController custNameController = TextEditingController();
  final TextEditingController custPhoneController = TextEditingController();

  final List<String> orderTypes = ["All", "Dine In", "Takeaway", "Delivery"];
  final List<String> statuses = ["All", "Used In Bill", "Open", "Cancelled"];
  final List<String> filters = ["All"];

  List<Map<String, dynamic>> kotRecords = [];
  bool isLoading = false;
  int currentPage = 1;
  int pageSize = 10;
  int totalRecords = 0;

  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _verticalScroll = ScrollController();

  String? currentBrandName = "";

  @override
  void initState() {
    super.initState();
    fetchKotSummary();
  }

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  Future<void> fetchKotSummary() async {
    setState(() => isLoading = true);
    final config = await app.Config.loadFromAsset();

    List<String> dbNames;
    if (selectedBrand == null || selectedBrand == "All") {
      dbNames = widget.dbToBrandMap.keys.toList();
      currentBrandName = "All";
    } else {
      dbNames = widget.dbToBrandMap.entries
          .where((entry) => entry.value == selectedBrand)
          .map((entry) => entry.key)
          .toList();
      currentBrandName = selectedBrand ?? "";
    }

    final start = DateFormat('dd-MM-yyyy').format(startDate);
    final end = DateFormat('dd-MM-yyyy').format(endDate);

    Map<String, List<dynamic>> dbToKotSummaryMap =
    await app.UserData.fetchKotSummaryForDbs(config, dbNames, start, end);

    List<Map<String, dynamic>> all = [];
    dbToKotSummaryMap.forEach((db, list) {
      for (final k in list) {
        all.add({'dbName': db, 'record': k});
      }
    });

    final kotId = kotIdController.text.trim();
    final custName = custNameController.text.trim().toLowerCase();
    final custPhone = custPhoneController.text.trim();

    List<Map<String, dynamic>> filtered = all.where((m) {
      final k = m['record'] as KotSummaryReport;
      bool match = true;
      if (kotId.isNotEmpty) match &= (k.kotId?.toLowerCase().contains(kotId.toLowerCase()) ?? false);
      if (custName.isNotEmpty) match &= (k.customerName?.toLowerCase().contains(custName) ?? false);
      if (custPhone.isNotEmpty) match &= (k.customerPhone?.contains(custPhone) ?? false);
      if (selectedOrderType != "All") match &= (k.orderType?.toLowerCase() == selectedOrderType.toLowerCase());
      if (selectedStatus != "All") match &= (k.kotStatus?.toLowerCase() == selectedStatus.toLowerCase());
      return match;
    }).toList();

    setState(() {
      kotRecords = filtered;
      totalRecords = filtered.length;
      currentPage = 1;
      isLoading = false;
    });
  }

  List<Map<String, dynamic>> get paginatedRecords {
    int start = (currentPage - 1) * pageSize;
    int end = (start + pageSize).clamp(0, kotRecords.length);
    if (start >= kotRecords.length) return [];
    return kotRecords.sublist(start, end);
  }

  void handleSearch() {
    fetchKotSummary();
  }

  void handleShowAll() {
    kotIdController.clear();
    custNameController.clear();
    custPhoneController.clear();
    setState(() {
      selectedOrderType = "All";
      selectedStatus = "All";
      selectedFilter = "All";
    });
    fetchKotSummary();
  }

  void goToPage(int page) {
    setState(() {
      currentPage = page;
    });
  }

  Future<void> exportToExcel() async {
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile['KOT Summary Report'];
    final headerStyle = excel.CellStyle(
      bold: true,
      fontFamily: excel.getFontFamily(excel.FontFamily.Calibri),
    );

    Map<String, List<KotSummaryReport>> brandWiseData = {};
    for (var row in kotRecords) {
      final dbName = row['dbName'] as String;
      final brand = widget.dbToBrandMap[dbName] ?? "Unknown";
      brandWiseData.putIfAbsent(brand, () => []).add(row['record']);
    }

    int rowIndex = 0;
    for (var entry in brandWiseData.entries) {
      sheet.appendRow([entry.key]);
      rowIndex++;
      final headerRow = [
        'KOT ID',
        'Order Type',

        'No. Of Item',
        'Items',
        'Status',
      ];
      sheet.appendRow(headerRow);
      for (int i = 0; i < headerRow.length; i++) {
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex))
          ..cellStyle = headerStyle;
      }
      rowIndex++;
      for (var row in entry.value) {
        sheet.appendRow([
          row.kotId ?? '',
          row.orderType ?? '',
          row.customerName ?? '',
          row.customerPhone ?? '',
          _sumNoOfItem(row.items),
          _itemsForRow(row.items),
          row.kotStatus ?? '',
        ]);
        rowIndex++;
      }
      rowIndex++;
      sheet.appendRow([]);
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/KOTSummaryReport.xlsx';
    final fileBytes = excelFile.encode();
    final file = File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);

    OpenFile.open(filePath);
  }

  static String _itemsForRow(String? itemsStr) {
    if (itemsStr == null || itemsStr.trim().isEmpty) return '';
    return itemsStr;
  }

  static String _sumNoOfItem(String? itemsStr) {
    if (itemsStr == null || itemsStr.trim().isEmpty) return '0';
    final List<String> items = itemsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    int sum = 0;
    for (var item in items) {
      final match = RegExp(r'^(.*?)(?:\s*[xX](\d+))?$').firstMatch(item);
      if (match != null) {
        final count = int.tryParse(match.group(2) ?? '1') ?? 1;
        sum += count;
      } else {
        sum += 1;
      }
    }
    return sum.toString();
  }

  @override
  Widget build(BuildContext context) {
    int totalPages = (totalRecords / pageSize).ceil();
    final brandNames = widget.dbToBrandMap.values.toSet();
    final isMobile = MediaQuery.of(context).size.width < 600;

    double headerHeight = 54;
    double rowHeight = 48;

    // For table rows
    final paginatedKots = paginatedRecords.map((m) => m['record'] as KotSummaryReport).toList();

    // Table columns and width
    final columns = [
      _Col('KOT ID', 90.0, (KotSummaryReport k) => k.kotId ?? ''),
      _Col('Order Type', 130.0, (KotSummaryReport k) => k.orderType ?? ''),

      _Col('No. Of Item', 110.0, (KotSummaryReport k) => _sumNoOfItem(k.items)),
      _Col('Items', 320.0, (KotSummaryReport k) => _itemsForRow(k.items)),
      _Col('Status', 120.0, (KotSummaryReport k) => k.kotStatus ?? ''),
    ];

    return SidePanel(
      dbToBrandMap: widget.dbToBrandMap,
      child: Column(
        children: [
          // ... (Filters/Header UI unchanged) ...
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 10),
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
                          await fetchKotSummary();
                        },
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await fetchKotSummary();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8), // You can adjust or remove this
                      ),
                    ),
                    child: const Icon(Icons.refresh, color: Colors.black),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text("Export to Excel"),
                    onPressed: exportToExcel,
                  ),
                ],
              ),
            ),
          ),
          // Section Title

          const SizedBox(height: 30),
          Container(
            color: Colors.white,
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _labeledField(
                        "Start Date",
                        _datePickerField(startDate, (d) => setState(() => startDate = d), width: 120),
                      ),
                      Transform.translate(
                        offset: const Offset(-40, 0),
                        child: _labeledField(
                          "End Date",
                          _datePickerField(endDate, (d) => setState(() => endDate = d), width: 120),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(-80, 0),
                        child: _labeledField("Kot ID", _inputField(kotIdController, width: 100)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _labeledField(
                        "Order Type",
                        _dropdownField(orderTypes, selectedOrderType, (v) => setState(() => selectedOrderType = v!), width: 120),
                      ),
                      Transform.translate(
                        offset: const Offset(-40, 0),
                        child: _labeledField(
                          "Status",
                          _dropdownField(statuses, selectedStatus, (v) => setState(() => selectedStatus = v!), width: 120),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(-80, 0),
                        child: _labeledField(
                          "Filter",
                          _dropdownField(filters, selectedFilter, (v) => setState(() => selectedFilter = v!), width: 120),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: handleSearch,
                        child: const Text("Search"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: handleShowAll,
                        child: const Text("Show All"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
,
          if (selectedBrand != null && selectedBrand != "All")
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Center(
                child: Text(
                  selectedBrand ?? "",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),
          // MAIN TABLE AREA - header, rows, total row horizontally scroll together
          Expanded(
            child: Scrollbar(
              controller: _verticalScroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalScroll,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: columns.fold<double>(0, (sum, col) => sum + col.width),
                  child: Column(
                    children: [
                      _buildHeaderRow(columns, headerHeight),
                      Expanded(
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                          controller: _verticalScroll,
                          itemCount: paginatedKots.length,
                          itemBuilder: (context, i) {
                            final k = paginatedKots[i];
                            return Row(
                              children: columns.map((col) {
                                return Container(
                                  width: col.width,
                                  height: rowHeight,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: i % 2 == 0 ? Colors.white : const Color(0xFFF8F9FB),
                                    border: Border(
                                      right: BorderSide(color: Colors.grey.shade200),
                                      bottom: BorderSide(color: Colors.grey.shade200),
                                    ),
                                  ),
                                  child: Text(
                                    col.value(k).toString(),
                                    overflow: col.title == 'Items' ? TextOverflow.ellipsis : TextOverflow.visible,
                                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),
                      _buildTotalRow(columns, paginatedKots, rowHeight),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Pagination bar
          Container(
            color: Colors.redAccent.withOpacity(0.08),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Row(
              children: [
                Text(
                  "Showing ${kotRecords.isEmpty ? 0 : ((currentPage - 1) * pageSize + 1)}"
                      " to ${(currentPage * pageSize).clamp(0, kotRecords.length)}"
                      " of $totalRecords records",
                  style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
                ),
                const Spacer(),
                ..._paginationBar(totalPages),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Table header
  Widget _buildHeaderRow(List<_Col> columns, double height) {
    return Container(
      color: const Color(0xFFF8F9FB),
      child: Row(
        children: columns.map((col) {
          return Container(
            width: col.width,
            height: height,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade200),
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Text(col.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          );
        }).toList(),
      ),
    );
  }

  // Total row
  Widget _buildTotalRow(List<_Col> columns, List<KotSummaryReport> rows, double rowHeight) {
    int totalNoOfItem = 0;
    for (final k in rows) {
      totalNoOfItem += int.tryParse(_sumNoOfItem(k.items)) ?? 0;
    }
    return Container(
      height: rowHeight,
      color: const Color(0xFFFFFDD0),
      child: Row(
        children: columns.map((col) {
          String value = '';
          if (col.title == 'KOT ID') value = 'Total';
          else if (col.title == 'No. Of Item') value = totalNoOfItem.toString();
          return Container(
            width: col.width,
            height: rowHeight,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          );
        }).toList(),
      ),
    );
  }

  // Filter fields
  Widget _labeledField(String label, Widget input) {
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 3),
          input,
        ],
      ),
    );
  }

  Widget _datePickerField(DateTime date, Function(DateTime) onSelect, {double width = 120, bool isEndDate = false}) {
    return SizedBox(
      width: width,
      child: TextField(
        readOnly: true,
        controller: TextEditingController(
          text: DateFormat('dd MMM yyyy').format(date),
        ),
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        ),
        onTap: () async {
          final res = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (res != null) {
            if (isEndDate) {
              onSelect(DateTime(res.year, res.month, res.day, 23, 59, 59));
            } else {
              onSelect(DateTime(res.year, res.month, res.day, 0, 0, 0));
            }
            fetchKotSummary();
          }
        },
      ),
    );
  }

  Widget _inputField(TextEditingController controller, {double width = 120}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        ),
      ),
    );
  }

  Widget _dropdownField(List<String> options, String value, ValueChanged<String?> onChanged, {double width = 120}) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: value,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        ),
        items: options.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  List<Widget> _paginationBar(int totalPages) {
    List<Widget> buttons = [];
    if (totalPages <= 1) return buttons;
    buttons.add(_paginationBtn("1", 1));
    if (currentPage > 2) {
      buttons.add(const SizedBox(width: 6));
      if (currentPage > 3) {
        buttons.add(const Text("..."));
      }
    }
    for (int i = currentPage - 1; i <= currentPage + 1; i++) {
      if (i > 1 && i <= totalPages) {
        buttons.add(_paginationBtn("$i", i));
      }
    }
    if (currentPage < totalPages - 1) {
      if (currentPage < totalPages - 2) {
        buttons.add(const Text("..."));
      }
      buttons.add(_paginationBtn("$totalPages", totalPages));
    }
    if (currentPage < totalPages) {
      buttons.add(const SizedBox(width: 6));
      buttons.add(
        _paginationBtn("Next", currentPage + 1, enabled: currentPage < totalPages),
      );
    }
    if (currentPage < totalPages) {
      buttons.add(const SizedBox(width: 6));
      buttons.add(
        _paginationBtn("Last", totalPages, enabled: currentPage < totalPages),
      );
    }
    return buttons;
  }

  Widget _paginationBtn(String label, int page, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: currentPage == page && label != "Next" && label != "Last"
              ? Colors.redAccent
              : Colors.white,
          foregroundColor: currentPage == page && label != "Next" && label != "Last"
              ? Colors.white
              : Colors.black,
          minimumSize: const Size(36, 36),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          elevation: 0,
        ),
        onPressed: enabled
            ? () {
          setState(() {
            currentPage = page;
          });
        }
            : null,
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: currentPage == page && label != "Next" && label != "Last"
                    ? Colors.white
                    : Colors.black)),
      ),
    );
  }
}

// Helper class for columns
class _Col {
  final String title;
  final double width;
  final String Function(KotSummaryReport) value;
  _Col(this.title, this.width, this.value);
}