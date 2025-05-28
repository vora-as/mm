import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:excel/excel.dart';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'Tax_model.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_sample/Online_order_model.dart';
import 'package:flutter_sample/Delivery_partner_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter_esc_pos_network/flutter_esc_pos_network.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:audioplayers/audioplayers.dart';
import 'FireConstants.dart';
import 'canceled_order_model.dart';
import 'data_provider.dart';
import 'global_constatnts.dart';
import 'list_of_product_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'global_constatnts.dart';

class OnlineOrdersScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(backgroundFetchServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Online Orders')),
      body: ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return ListTile(
            title: Text(order),
          );
        },
      ),
    );
  }
}

class OnlineOrdersScreenStateful extends StatefulWidget {
  @override
  _OnlineOrdersScreenStatefulState createState() => _OnlineOrdersScreenStatefulState();
}

class _OnlineOrdersScreenStatefulState extends State<OnlineOrdersScreenStateful> {
  List<Map<String, dynamic>> onlineItems = [];
  Map<int, bool> itemStatus = {};

  List<DeliveryPartner> deliveryPartners = [];
  String selectedCategory = '';
  int selectedButtonIndex = -1;
  String whattofollow = '';
  FocusNode searchFocusNode = FocusNode();
  TextEditingController _searchController = TextEditingController();

  Timer? _orderRefreshTimer;

  List<SelectedProductModifier> selectedModifiersList = [];
  List<SelectedProduct> selectedProductsList = [];

  double cgst = 0.00;
  double sgst = 0.00;
  double vat = 0.00;
  double sc = 0.00;
  double subtotal = 0.00;
  double grandtotal = 0.00;
  double billamount = 0.00;
  double discount = 0.00;
  String discountremark = "";
  String settlementModeName = "";
  String tableName = "";
  double cgstpercentage = 2.50;
  double sgstpercentage = 2.50;
  double vatpercentage = 0.00;
  double scpercentage = 0.00;
  double discountpercentage = 0;
  double sumoftax = 0.0;
  double deliveryCharge=0.00;
  String tablenumber = "0";
  List<OnlineOrder> onlineOrders = [];
  List<CanceledOrder> canceledOrders = [];
  Set<String> previousOrderIds = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isBeeping = false;
  bool isFirstLoad = true;
  Set<String> previousCanceledOrders = {};
  bool isAutoAcceptEnabled = false;
  bool isSidebarOpen = false;
  @override
  void initState() {
    super.initState();
    fetchOnlineOrders();
    fetchCanceledOrders(skipPrint: true);
    _startOrderRefreshTimer();
    fetchDeliveryPartners();
    fetchOnlineItems();
    fetchProducts();
    fetchDeliveryAgentStatus();
    loadAutoAcceptPreference();
  }
  void _startOrderRefreshTimer() {
    _orderRefreshTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      fetchOnlineOrders();
      fetchCanceledOrders();
      fetchDeliveryAgentStatus();
    });
  }

  @override
  void dispose() {
    _orderRefreshTimer?.cancel();
    stopBeep();
    _audioPlayer.dispose();
    super.dispose();

  }


  /// Load saved Auto-Accept preference
  Future<void> loadAutoAcceptPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isAutoAcceptEnabled = prefs.getBool('autoAccept') ?? false;
    });
  }

  /// Save Auto-Accept preference
  Future<void> saveAutoAcceptPreference(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoAccept', value);
  }

  Future<bool> autoAcceptOrder(String orderId) async {
    final response = await http.post(Uri.parse('${apiUrl}onlineorder/auto-accept'),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "restaurant_id": merchantId,
        "order_id": orderId,
        "merchant_id": merchantId
      }),
    );
    print("API Response Code: ${response.statusCode}");
    print("API Response Body: ${response.body}");

    return response.statusCode == 200;
  }



  Future<List<Map<String, dynamic>>> fetchOnlineItems() async {
    try {
      final response = await http.get(Uri.parse('${apiUrl}pricing/getAll?DB=$CLIENTCODE'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print("Fetched Online Items: $data");

        List<Map<String, dynamic>> filteredItems = data
            .where((json) => json is Map<String, dynamic> && json["area"] == "Online")
            .map((json) => {
          "id": json["id"] ?? 0,
          "itemName": json["itemName"] ?? "Unknown Itemsss",
          "itemcode": json["itemcode"]?.toString() ?? "0",
          "price": json["price"] ?? 0,
          "area": json["area"] ?? "Unknown Area",
          "status": json["status"] != null
              ? json["status"].toString().toLowerCase() == "true"
              : false,
        })
            .toList();

        return filteredItems;
      } else {
        print("Error fetching online items: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error fetching online items: $e");
      return [];
    }
  }
  Future<List<Map<String, dynamic>>> fetchProducts() async {
    try {
      final response = await http.get(Uri.parse('${apiUrl}product/getAll?DB=$CLIENTCODE'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        List<Map<String, dynamic>> filteredProducts = data
            .where((json) => json is Map<String, dynamic>)
            .map((json) => {
          "productName": json["productName"] ?? "Unknown Product",
          "productCode": json["productCode"]?.toString() ?? "0",
          "categoryName": json["categoryName"]?.toString() ?? "Unknown Category",
        })
            .toList();

        return filteredProducts;
      } else {
        print("Error fetching products: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error fetching products: $e");
      return [];
    }
  }
  Future<List<Map<String, dynamic>>> fetchAddons() async {
    try {
      final response = await http.get(Uri.parse('${apiUrl}modifiers/getAll?DB=$CLIENTCODE'));

      print("Response Ccode: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<Map<String, dynamic>> addons = data.map((json) => {
          "id": json["modifierCode"],
          "name": json["modifierName"],
          "price": json["price"],
          "status": true,
        }).toList();

        print("Fetched Addons: $addons");
        return addons;
      } else {
        throw Exception('Failed to load addons. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching addons: $e");
      return Future.error('Error fetching addons: $e');
    }
  }
  Future<List<Tax>> fetchApplicableTaxes() async {
    final String taxApiUrl = '${apiUrl}taxmaster/getAll?DB=$CLIENTCODE';

    try {
      final response = await http.get(Uri.parse(taxApiUrl));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<Tax> taxes = data.map((json) => Tax.fromMap(json)).toList();
        return taxes.where((tax) => tax.isApplicableOnlineorder == "Y").toList();
      } else {
        print(" Failed to fetch taxes: ${response.body}");
        return [];
      }
    } catch (e) {
      print(" Error fetching taxes: $e");
      return [];
    }
  }
  Future<bool> updateItemStatusWera(List<int> itemIds, bool status, DateTime? fromTime, DateTime? toTime) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.werafoods.com/pos/v2/item/toggle'),
        headers: {
          "Content-Type": "application/json",
          "X-Wera-Api-Key": "9b0ffbebd-ebc7g-4215-9e51p-obb49c054e276s",
        },
        body: json.encode({
          "merchant_id": merchantId,
          "status": status,
          "item_ids": itemIds,
          "from_time": fromTime != null ? fromTime.toIso8601String() : null,
          "to_time": toTime != null ? toTime.toIso8601String() : null,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData["code"] == 1) {
        print("Wera API updated successfully for items ${itemIds.join(", ")}");
        return true;
      } else {
        print("Error updating Wera API: ${responseData["msg"]}");
        return false;
      }
    } catch (e) {
      print("Error updating Wera API: $e");
      return false;
    }
  }

  Future<bool> updateItemStatusLocal(int itemId, bool status) async {
    try {
      final requestBody = json.encode({
        "status": status,
      });

      final response = await http.put(
        Uri.parse('${apiUrl}pricing/update/$itemId?DB=$CLIENTCODE'),
        headers: {
          "Content-Type": "application/json",
        },
        body: requestBody,
      );

      print("Request Sent: $requestBody");
      print("Local API Response Code: ${response.statusCode}");
      print("Local API Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData["status"] == "true") {
          return true;
        } else if (responseData["status"] == "false") {
          return false;
        }
      }
      return false;
    } catch (e) {
      print("Error updating Local API status: $e");
      return false;
    }
  }
  Future<bool> toggleAddonStatus(int addonId, bool status) async {
    try {
      final weraResponse = await http.post(
        Uri.parse('https://api.werafoods.com/pos/v2/menu/addontoggle'),
        headers: {
          "Content-Type": "application/json",
          "X-Wera-Api-Key": "9b0ffbebd-ebc7g-4215-9e51p-obb49c054e276s",
        },
        body: json.encode({
          "merchant_id": merchantId,
          "status": status,
          "addon_ids": [addonId]
        }),
      );

      final weraResponseData = json.decode(weraResponse.body);
      bool weraSuccess = weraResponse.statusCode == 200 && weraResponseData["code"] == 1;

      bool localSuccess = await updateModifierStatusLocal(addonId, status);

      if (weraSuccess && localSuccess) {
        print("Both Wera and local updates successful");
        return true;
      }

      if (!weraSuccess) {
        print("Wera API failed: ${weraResponseData["msg"]}");
      }

      if (!localSuccess) {
        print("Local update failed");
      }

      return false;

    } catch (e) {
      print("Error toggling addon: $e");
      return false;
    }
  }
  ///update///deliverypartner////
  Future<bool> updateDeliveryPartnerStatus(int partnerCode, String partnerName, bool status) async {
    final String apidpstatus = '${apiUrl}deliverypartner/update/$partnerCode?DB=$CLIENTCODE';

    final Map<String, dynamic> requestBody = {
      "deliveryPartnerCode": partnerCode,
      "deliveryPartnerName": partnerName,
      "status": status ? "Y" : "N"
    };

    try {
      print("API URL: $apidpstatus");
      print("Request Body: ${jsonEncode(requestBody)}");

      final response = await http.put(
        Uri.parse(apidpstatus),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(requestBody),
      );

      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        print(" Delivery partner status updated successfully");
        return true;
      } else {
        print(" Failed to update delivery partner status: ${response.body}");
        return false;
      }
    } catch (e) {
      print(" Error updating delivery partner status: $e");
      return false;
    }
  }
////
  Future<void> fetchOnlineOrders() async {
    try {
      final response = await http.get(Uri.parse('${apiUrl}onlineorder/getAll?DB=$CLIENTCODE'));
      printFullResponse(response.body);

      if (response.statusCode == 200) {
        final parsed = json.decode(response.body).cast<Map<String, dynamic>>();
        List<OnlineOrder> allOrders = parsed.map<OnlineOrder>((json) => OnlineOrder.fromMap(json)).toList();
        List<OnlineOrder> newOrders = allOrders.where((order) => order.status.toLowerCase() != "delivered").toList();

        Set<String> currentOrderIds = newOrders.map((order) => order.orderId).toSet();
        Set<String> newIncomingOrders = currentOrderIds.difference(previousOrderIds);
        if (!isInitialLoad && newIncomingOrders.isNotEmpty) {
          playBeep(newIncomingOrders.first);
        }

        if (isAutoAcceptEnabled) {
          for (var order in newOrders) {
            if (!previousOrderIds.contains(order.orderId) && order.status.toLowerCase() == "active") {
              previousOrderIds.add(order.orderId);
              playBeep(order.orderId, isAutoAccepted: true);
              await Future.delayed(Duration(seconds: 10));
              bool autoAcceptSuccess = await autoAcceptOrder(order.orderId);

              if (autoAcceptSuccess) {
                bool success = await acceptOrder(
                    context,
                    order.orderId,
                    order.orderFrom,
                    15,
                    order.orderInstructions ?? "",
                    order.onlineOrderItemList,
                    order.externalOrderId,
                    selectedModifiersList,
                    selectedProductsList,
                    order
                );

                if (success) {
                  stopBeep();
                  String kotId = await createKOT(context, order.orderFrom, order.onlineOrderItemList, order);
                  await testOrder(order.orderFrom + " : " + order.orderId, order.orderId, order.orderInstructions ?? "", order.orderFrom, order.onlineOrderItemList, order.externalOrderId, kotId);
                  String billNo = await createOnlineBill(context, order);
                  await testBILLForOnlineOrder(
                    billNo,
                    order.orderId,
                    order.orderFrom,
                    order.onlineOrderItemList,
                    order.onlineOrderItemList.expand((item) => item.onlineOrderItemAddonList.map(
                          (addon) => SelectedProductModifier(
                        name: addon.addonName,
                        price_per_unit: addon.addonPrice,
                        code: addon.addonId.toString(),
                        product_code: '',
                      ),
                    )).toList(),
                    order.grossAmount,
                    order.cgstPercent ?? 0.0,
                    order.sgstPercent ?? 0.0,
                    order.cgst,
                    order.sgst,
                    order.vatPercent ?? 0.0,
                    order.vat ?? 0.0,
                    order.orderInstructions ?? "",
                    order.discount,
                    customerName: order.customerDetail?.custname ?? "",
                    customerPhone: order.customerDetail?.phoneNumber ?? "",
                    deliveryArea: order.customerDetail?.deliveryArea ?? "",
                  );
                  await updateOrderStatus(order.orderId, "Food Ready");
                }
              }
            }
          }
        }


        setState(() {
          onlineOrders = newOrders;
          previousOrderIds = currentOrderIds;
        });
        _checkForNewOrders();
        isInitialLoad = false;
      } else {
        throw Exception('Failed to load Online Orders');
      }
    } catch (e) {
      print("Error fetching orders: $e");
    }
  }


  void printFullResponse(String text) {
    final pattern = RegExp('.{1,800}'); // 800 character chunks
    pattern.allMatches(text).forEach((match) => print(match.group(0)));
  }




  bool isInitialLoad = true;

  Future<void> fetchCanceledOrders({bool skipPrint = false}) async {
    try {
      final response = await http.get(Uri.parse('${apiUrl}onlineorder/cancelorder?DB=$CLIENTCODE'));

      print("API Response for Canceled Orders: ${response.body}");

      if (response.statusCode == 200) {
        List<CanceledOrder> canceledOrdersList = canceledOrderFromMap(response.body);

        if (skipPrint) {
          previousCanceledOrders = canceledOrdersList.map((order) => order.orderId).toSet();
        } else {
          List<CanceledOrder> newCanceledOrders = canceledOrdersList
              .where((order) => !previousCanceledOrders.contains(order.orderId))
              .toList();
          for (var order in newCanceledOrders) {
            List<CanceledOrderItem> canceledItems = order.items;

            await testOrder(
              "${order.restaurantName} : ${order.orderId}",
              order.orderId,
              order.orderInstructions ?? "",
              order.orderFrom,
              canceledItems,
              order.externalOrderId,
              order.kotId,
              isCanceled: true,
            );

            await testBILLForOnlineOrder(
              order.billNo,
              order.orderId,
              order.orderFrom,
              order.items,
              order.items.expand((item) => item.onlineOrderItemAddonList.map(
                    (addon) => SelectedProductModifier(
                  name: addon.addonName,
                  price_per_unit: addon.addonPrice,
                  code: addon.addonId.toString(),
                  product_code: '',
                ),
              )).toList(),
              order.grossAmount,
              order.cgstPercent ?? 0.0,
              order.sgstPercent ?? 0.0,
              order.cgst,
              order.sgst,
              0.0,
              0.0,
              order.orderInstructions ?? "",
              order.discount,
              isCanceled: true,
              customerName: order.customerDetail?.custname ?? "",
              customerPhone: order.customerDetail?.phoneNumber ?? "",
              deliveryArea: order.customerDetail?.deliveryArea ?? "",
            );
          }

          previousCanceledOrders.addAll(newCanceledOrders.map((order) => order.orderId));
        }

        if (!listEquals(canceledOrders, canceledOrdersList)) {
          setState(() {
            canceledOrders = canceledOrdersList;
          });
        }

      } else {
        print("Failed to fetch canceled orders. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching canceled orders: $e");
    }
  }

  ////////
  Map<String, Map<String, String>> latestRiderStatuses = {};
  Future<void> fetchDeliveryAgentStatus() async {
    try {
      final response = await http.get(Uri.parse('${apiUrl}onlineorder/deliveryagentstatus?DB=$CLIENTCODE'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        Map<String, Map<String, String>> latestStatuses = {};

        for (var entry in data) {
          String orderId = entry["order_id"];
          if (!latestStatuses.containsKey(orderId) || entry["id"] > int.parse(latestStatuses[orderId]?["id"] ?? "0")) {
            latestStatuses[orderId] = {
              "id": entry["id"].toString(),
              "riderName": entry["rider_name"],
              "riderNumber": entry["rider_phone_number"],
              "riderStatus": entry["rider_status"],
            };
          }
        }

        if (!mapEquals(latestRiderStatuses, latestStatuses)) {
          setState(() {
            latestRiderStatuses = latestStatuses;
          });
        }


        print("Updated Rider Statuses: $latestRiderStatuses");
      } else {
        print("Failed to fetch delivery agent status. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching delivery agent status: $e");
    }
  }
  Future<void> acceptOrderManually(OnlineOrder order, int preparationTime) async {
    if (!previousOrderIds.contains(order.orderId)) return;

    bool success = await acceptOrder(
        context,
        order.orderId,
        order.orderFrom,
        preparationTime,
        order.orderInstructions ?? "",
        order.onlineOrderItemList,
        order.externalOrderId,
        selectedModifiersList,
        selectedProductsList,
        order
    );

    if (success) {
      print("Automatically accepted order: ${order.orderId}");
      stopBeep();
    }
  }

  void _checkForNewOrders() {
    Set<String> currentOrderIds = onlineOrders.map((order) => order.orderId).toSet();
    Set<String> newOrders = currentOrderIds.difference(previousOrderIds);

    if (!isInitialLoad && newOrders.isNotEmpty) {
      for (String orderId in newOrders) {
        if (isAutoAcceptEnabled) {
          playBeep(orderId);
          autoAcceptOrder(orderId).then((autoAccepted) {
            playBeep(orderId, isAutoAccepted: autoAccepted);
            if (autoAccepted) stopBeep();
          });
        } else {
          playBeep(orderId);
        }
      }
    }

    previousOrderIds = currentOrderIds;
  }



  Future<void> playBeep(String orderId, {bool isAutoAccepted = false}) async {
    if (!isBeeping) {
      isBeeping = true;
      final DateTime stopTime = DateTime.now().add(Duration(seconds: 10));

      try {
        while (isBeeping && (isAutoAccepted || DateTime.now().isBefore(stopTime))) {
          if (!isBeeping) break;

          await _audioPlayer.stop();
          await _audioPlayer.play(AssetSource('sounds/order.mp3'));

          // Check every 2 seconds if we should stop
          await Future.delayed(Duration(seconds: 2));

          // For manual orders: Continue until stopBeep() is called
          if (!isAutoAccepted && !previousOrderIds.contains(orderId)) {
            break;
          }
        }
      } finally {
        isBeeping = false;
      }
    }
  }


  void stopBeep() {
    if (isBeeping) {
      isBeeping = false;
      _audioPlayer.stop();
      print("🔇  Beeping stopped");
    }
  }

  void _showRejectionDialog(BuildContext context, String orderId) {
    int selectedRejectionId = 1;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Reject Order"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Select a reason for rejection:"),
              SizedBox(height: 10),
              DropdownButton<int>(
                value: selectedRejectionId,
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    selectedRejectionId = newValue;
                  }
                },
                items: [
                  DropdownMenuItem(value: 1, child: Text("Items out of stock")),
                  DropdownMenuItem(value: 2, child: Text("No delivery boys available")),
                  DropdownMenuItem(value: 3, child: Text("Nearing closing time")),
                  DropdownMenuItem(value: 4, child: Text("Out of Subzone/Area")),
                  DropdownMenuItem(value: 5, child: Text("Kitchen is Full")),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text("Reject Order"),
              onPressed: () async {
                bool success = await rejectOrder(orderId, selectedRejectionId);
                if (success) {
                  previousOrderIds.remove(orderId);
                  stopBeep();

                  Navigator.of(context).pop();

                  _showSuccessMessage(context, "Order Rejected Successfully");
                }
              },
            ),
          ],
        );
      },
    );
  }
  void _showSuccessMessage(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        Future.delayed(Duration(seconds: 2), () {
          Navigator.of(context).pop();
        });

        return AlertDialog(
          title: Text("Success"),
          content: Text(message),
        );
      },
    );
  }

  Future<List<DeliveryPartner>> fetchDeliveryPartners() async {
    try {
      final response = await http.get(Uri.parse('${apiUrl}deliverypartner/getAll?DB=$CLIENTCODE'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => DeliveryPartner.fromMap(json)).toList();
      } else {
        throw Exception('Failed to load delivery partners');
      }
    } catch (e) {
      print(' Error fetching delivery partners: $e');
      return [];
    }
  }

  Widget getOrderIcon(String orderFrom) {
    switch (orderFrom) {
      case 'Swiggy':
        return Image.asset('assets/images/SWIGGY.png', width: 40, height: 40);
      case 'Online':
        return Image.asset('assets/images/ONLINE.png', width: 40, height: 40);
      default:
        return Icon(Icons.error, color: Colors.red);
    }
  }

  void handleOrderAction(String orderId) {
    try {
      OnlineOrder order = onlineOrders.firstWhere((o) => o.orderId == orderId);

      if (order.status == "Food Ready") {
        markFoodReady(orderId);
      } else if (order.status == "Pick Up") {
        markOrderAsDelivered(orderId);
      } else {
        print("No action needed for status: ${order.status}");
      }
    } catch (e) {
      print("Order not found: $orderId");
    }
    _searchController.clear();
    FocusScope.of(context).requestFocus(searchFocusNode);
  }
  void _showPreparationTimeDialog(BuildContext context, OnlineOrder order) {
    int preparationTime = 15;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Set Preparation Time"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Select the preparation time for the order."),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          if (preparationTime > 5) {
                            setState(() {
                              preparationTime -= 5;
                            });
                          }
                        },
                      ),
                      Text(
                        "$preparationTime min",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle, color: Colors.green),
                        onPressed: () {
                          if (preparationTime < 120) {
                            setState(() {
                              preparationTime += 5;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text("Cancel"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: Text("Confirm"),
                  onPressed: () async {
                    Navigator.of(context).pop(); // Close the dialog

                    bool success = await acceptOrder(
                        context,
                        order.orderId,
                        order.orderFrom,
                        preparationTime,
                        order.orderInstructions ?? "",
                        order.onlineOrderItemList,
                        order.externalOrderId,
                        selectedModifiersList,
                        selectedProductsList,
                        order
                    );

                    if (success) {
                      previousOrderIds.remove(order.orderId);
                      stopBeep();
                      String kotId = await createKOT(context, order.orderFrom, order.onlineOrderItemList, order);
                      await testOrder(order.orderFrom + " : " + order.orderId, order.orderId, order.orderInstructions ?? "", order.orderFrom, order.onlineOrderItemList, order.externalOrderId, kotId);
                      String billno = await createOnlineBill(context, order);
                      await testBILLForOnlineOrder(
                        billno,
                        order.orderId,
                        order.orderFrom,
                        order.onlineOrderItemList,
                        order.onlineOrderItemList.expand((item) => item.onlineOrderItemAddonList.map(
                              (addon) => SelectedProductModifier(
                            name: addon.addonName,
                            price_per_unit: addon.addonPrice,
                            code: addon.addonId.toString(),
                            product_code: '',
                          ),
                        )).toList(),
                        order.grossAmount,
                        order.cgstPercent ?? 0.0,
                        order.sgstPercent ?? 0.0,
                        order.cgst,
                        order.sgst,
                        order.vatPercent ?? 0.0,
                        order.vat ?? 0.0,
                        order.orderInstructions ?? "",
                        order.discount,
                        customerName: order.customerDetail?.custname ?? "",
                        customerPhone: order.customerDetail?.phoneNumber ?? "",
                        deliveryArea: order.customerDetail?.deliveryArea ?? "",
                      );
                      Navigator.of(context, rootNavigator: true).pop();                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override


  Future<bool> acceptOrder(
      BuildContext context,
      String orderId,
      String orderFrom,
      int preparationTime,
      String orderInstructions,
      List<OnlineOrderItemList> onlineOrderItemList,
      String externalOrderId,
      List<SelectedProductModifier> sms,
      List<SelectedProduct> sps,
      OnlineOrder order
      )
  async {
    final String apiUrl = "https://api.werafoods.com/pos/v2/order/accept";

    final Map<String, dynamic> requestBody = {
      "merchant_id": merchantId,
      "order_id": orderId,
      "preparation_time": preparationTime,
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json",
          "X-Wera-Api-Key": WeraApiKey,
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        print("Order Accepted Successfully: $orderId");


        //  await createKOT(context, orderFrom, onlineOrderItemList, order);
        await updateOrderStatus(orderId, "Food Ready");

        return true;
      } else {
        print(" Failed to Accept Order: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error Accepting Order: $e");
      return false;
    }
  }
  Future<bool> rejectOrder(String orderId, int rejectionId) async {
    final String apiUrl = "https://api.werafoods.com/pos/v2/order/reject";

    final Map<String, dynamic> requestBody = {
      "merchant_id": merchantId,
      "order_id": orderId,
      "rejection_id": rejectionId,
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json",
          "X-Wera-Api-Key": WeraApiKey,
        },
        body: jsonEncode(requestBody),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData["code"] == 1) {
        print("Order Rejected Successfully: $orderId");
        await updateOrderStatus(orderId, "reject");
        return true;
      } else {
        print("Failed to Reject Order: ${responseData["msg"]}");
        return false;
      }
    } catch (e) {
      print("Error Rejecting Order: $e");
      return false;
    }
  }
  //after accept food ready////
  Future<void> markFoodReady(String orderId) async {
    final String apiUrl = "https://api.werafoods.com/pos/v2/order/food-ready";

    final Map<String, dynamic> requestBody = {
      "merchant_id": merchantId,
      "order_id": orderId,
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json",
          "X-Wera-Api-Key": WeraApiKey,
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        print("Food Ready Confirmed for Order: $orderId");
        await updateOrderStatus(orderId, "Pick Up");
        fetchOnlineOrders();
      } else {
        print("Failed to Mark Food Ready: ${response.body}");
      }
    } catch (e) {
      print("Error Marking Food Ready: $e");
    }
  }
  //after food ready pickup///
  Future<void> markOrderAsDelivered(String orderId) async {
    await updateOrderStatus(orderId, "delivered");
    fetchOnlineOrders();
  }

/////
  Future<bool> toggleStoreStatus(bool status, String reason, List<int> aggregators) async {
    final String apiUrl = "https://api.werafoods.com/pos/v2/merchant/toggle";

    final Map<String, dynamic> requestBody = {
      "merchant_id": merchantId,
      "status": status,
      "reason": reason,
      "aggregator": aggregators,
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json",
          "X-Wera-Api-Key": WeraApiKey,
        },
        body: jsonEncode(requestBody),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData["code"] == 1) {
        print("Store status updated successfully");
        return true;
      } else {
        print("Failed to update store status: ${responseData["msg"]}");
        print("Request Bodyyy: ${jsonEncode(requestBody)}");

        return false;
      }
    } catch (e) {
      print("Error toggling store status: $e");
      return false;
    }
  }

  Future<String> createKOT(BuildContext context, String orderFrom, List<OnlineOrderItemList> onlineOrderItems, OnlineOrder order) async {
    final String apiUrlKOT = '${apiUrl}order/create?DB=$CLIENTCODE';

    final List<Map<String, dynamic>> orderItems = onlineOrderItems.map((item) => {
      "itemName": item.itemName,
      "itemCode": item.itemId,
      "quantity": item.itemQuantity,
      "price": item.itemUnitPrice,
      "costCenterCode": "c01",
    }).toList();

    if (orderItems.isEmpty) {
      print("⚠ ERROR: No items in order. Cannot create KOT.");
      return "";
    }

    final Map<String, dynamic> requestBody = {
      "orderItems": orderItems,
      "orderModifiers": [],
      "order_type": "Online",
      "tableName": "0",
      "orderId": order.orderId,
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrlKOT),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        String kotId = responseData["orderNumber"] ?? "";

        if (kotId.isNotEmpty) {

          final String apiUpdateKot = '${apiUrl}online_order/updateKOT?DB=$CLIENTCODE';
          final Map<String, dynamic> updateRequest = {
            "orderId": order.orderId,
            "kotId": kotId
          };

          final kotUpdateResponse = await http.post(
            Uri.parse(apiUpdateKot),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(updateRequest),
          );

          if (kotUpdateResponse.statusCode == 200) {
            print("✅ KotID Updated in Online Order Table");
          } else {
            print("❌ Failed to update KotID in Online Order Table");
          }
        }
        return kotId;
      }
    } catch (e) {
      print("❌ Error Creating KOT: $e");
    }

    return "";
  }

  Future<String> createOnlineBill(BuildContext context, OnlineOrder order) async {
    final String apiUrlBill = '${apiUrl}bill/create?DB=$CLIENTCODE';

    List<Tax> applicableTaxes = await fetchApplicableTaxes();

    final List<Map<String, dynamic>> billItems = order.onlineOrderItemList.map((item) {
      return {
        "productName": item.itemName,
        "productCode": item.itemId.toString(),
        "quantity": item.itemQuantity,
        "pricePerUnit": item.itemUnitPrice.toString(),
      };
    }).toList();

    final List<Map<String, dynamic>> billModifiers = order.onlineOrderItemList.expand((item) {
      return item.onlineOrderItemAddonList.map((addon) {
        return {
          "productCode": addon.addonId.toString(),
          "productName": addon.addonName,
          "quantity": 1,
          "pricePerUnit": addon.addonPrice.toString(),
          "totalPrice": addon.addonPrice.toString(),
        };
      });
    }).toList();

    final List<Map<String, dynamic>> billTaxes = applicableTaxes.map((tax) {
      return {
        "billTaxId": 0,
        "taxCode": tax.taxCode,
        "taxName": tax.taxName,
        "taxPercent": tax.taxPercent,
        "taxAmount": ((order.grossAmount * double.parse(tax.taxPercent)) / 100).toString(),
      };
    }).toList();

    final String dateandtime = DateFormat("dd-MM-yyyy").format(DateTime.now());

    final Map<String, dynamic> requestBody = {
      "orderId": order.orderId,
      "billItems": billItems,
      "billModifiers": billModifiers,
      "billTaxes": billTaxes,
      "customerName": order.customerDetail?.custname ?? "Online Customer",
      "customerMobile": order.customerDetail?.phoneNumber ?? "",
      "customerGst": "",
      "waiter": "",
      "user": "System",
      "tableNumber": "0",
      "billDate": dateandtime,
      "totalAmount": order.netAmount,
      "isSettle": "Y",
      "settlement_mode_name": order.orderType,
      "home_deliverycharge": order.deliveryCharge.toString(),
      "order_type": "Online",
      "bill_tax": order.cgst + order.sgst,
      "bill_discount": order.discount,
      "billTime": DateTime.now().toIso8601String(),
      "GrandTotal": order.grossAmount,
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrlBill),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      final Map<String, dynamic> responseData = json.decode(response.body);
      if (response.statusCode == 201 && responseData.containsKey("billNo")) {
        return responseData["billNo"];
      }
    } catch (e) {
      print("Error Creating Online Bill: $e");
    }

    return "";
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final String apiUrlStatus = "${apiUrl}onlineorder/update/$orderId?DB=$CLIENTCODE";

    final Map<String, dynamic> requestBody = {
      "status": newStatus,

    };

    try {
      print("Updating order at: $apiUrlStatus");
      print("Request Body: ${jsonEncode(requestBody)}");

      final response = await http.put(
        Uri.parse(apiUrlStatus),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(requestBody),
      );

      print("Response Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        print("Order Status Updated Successfully: $newStatus");
        if (newStatus.toLowerCase() == "delivered") {
          await fetchOnlineOrders();
        }
      } else {
        print("Failed to Update Order Status: ${response.body}");
      }
    } catch (e) {
      print("Error Updating Order Status: $e");
    }
  }
  Future<bool> updateModifierStatusLocal(int modifierId, bool status) async {
    final String apiUrlStatus = "${apiUrl}modifiers/update/$modifierId?DB=$CLIENTCODE";

    final Map<String, dynamic> requestBody = {
      "status": status.toString(),
    };

    try {
      final response = await http.put(
        Uri.parse(apiUrlStatus),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(requestBody),
      );

      print("Local Modifier Update Response: ${response.statusCode}");
      print("Response Body: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      print("Error updating local modifier status: $e");
      return false;
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 15),
            color: Colors.grey[900],
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Online Orders',
                      style: TextStyle(
                        fontFamily: 'HammersmithOne',
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start, // top align sidebar & content
              children: [
                isSidebarOpen
                    ? Container(
                  width: 200,
                  color: Colors.grey[850],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            isSidebarOpen = false;
                          });
                        },
                      ),
                      ListTile(
                        title: Text('Online Items', style: TextStyle(color: Colors.white)),
                        onTap: () {
                          setState(() {
                            isSidebarOpen = false;  // Close sidebar
                          });
                          Future.delayed(Duration(milliseconds: 100), () {
                            OnlineItemsDialog(context);
                          });
                        },
                      ),
                      ListTile(
                        title: Text('Addons', style: TextStyle(color: Colors.white)),
                        onTap: () {
                          setState(() {
                            isSidebarOpen = false;  // Close sidebar
                          });
                          Future.delayed(Duration(milliseconds: 100), () {
                            showOnlineAddonsDialog(context);
                          });
                        },
                      ),

                      ListTile(
                        title: Text('Reports', style: TextStyle(color: Colors.white)),
                        onTap: () {
                          showReportsDialog(context);
                        },
                      ),
                      ListTile(
                        title: Text('Settings', style: TextStyle(color: Colors.white)),
                        onTap: () {
                          showSettingsDialog(context);
                        },
                      ),

                    ],
                  ),
                )
                    : Container(
                  width: 50,
                  color: Colors.grey[850],
                  child: IconButton(
                    icon: Icon(Icons.menu, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        isSidebarOpen = true;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: TextField(
                          focusNode: searchFocusNode,
                          style: const TextStyle(color: Colors.white),
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {});
                          },
                          onSubmitted: (value) {
                            handleOrderAction(value);
                          },
                          decoration: InputDecoration(
                            hintText: 'Search for order...',
                            hintStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.search, color: Colors.white),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white),
                              borderRadius: BorderRadius.circular(25.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white),
                              borderRadius: BorderRadius.circular(25.0),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          key: PageStorageKey('ordersList'),
                          padding: EdgeInsets.all(8.0),
                          itemCount: onlineOrders.length + canceledOrders.length,
                          itemBuilder: (context, index) {
                            final dynamic order = index < onlineOrders.length
                                ? onlineOrders[index] as OnlineOrder
                                : canceledOrders[index - onlineOrders.length] as CanceledOrder;

                            bool isCanceled = order is CanceledOrder;

                            String formattedTime = formatDateTime(
                                isCanceled ? (order as CanceledOrder).orderDateTime : (order as OnlineOrder).orderDateTime
                            );

                            List<String> itemNames = [];
                            if (isCanceled) {
                              if (order.items != null) {
                                itemNames = (order.items as List<CanceledOrderItem>)
                                    .map((item) => item.itemName.toString())
                                    .toList();
                              }
                            } else {
                              if (order.onlineOrderItemList != null) {
                                itemNames = (order.onlineOrderItemList as List<OnlineOrderItemList>)
                                    .map((item) => item.itemName.toString())
                                    .toList();
                              }
                            }

                            String items = itemNames.isNotEmpty ? itemNames.join(", ") : "No items found";

                            Widget getOrderIcon(String orderFrom) {
                              switch (orderFrom) {
                                case 'Swiggy':
                                  return Image.asset('assets/images/SWIGGY.png', width: 50, height: 50);
                                case 'Zomato':
                                  return Image.asset('assets/images/ZOMATO.png', width: 50, height: 50);
                                case 'Online':
                                  return Image.asset('assets/images/ONLINE.png', width: 40, height: 40);
                                default:
                                  return Icon(Icons.error, color: Colors.red);
                              }
                            }

                            return Card(
                              key: ValueKey(order.orderId),
                              color: isCanceled ? Colors.red[500] : Colors.white,
                              child: Column(
                                children: [
                                  ListTile(
                                    title: Text(
                                      "Order #${order.orderId} ${isCanceled ? "(Canceled)" : ""}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isCanceled ? Colors.black : Colors.black,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "$formattedTime | $items | ₹${order.grossAmount.toStringAsFixed(3)}",
                                      style: TextStyle(color: Colors.black),
                                    ),
                                    leading: getOrderIcon(order.orderFrom),
                                    onTap: () {
                                      if (!isCanceled) showOrderDetails(context, order as OnlineOrder);
                                    },
                                    trailing: order.status == "Food Ready"
                                        ? ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      ),
                                      onPressed: () => markFoodReady(order.orderId),
                                      child: Text("Food Ready"),
                                    )
                                        : order.status == "Pick Up"
                                        ? ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      ),
                                      onPressed: () => markOrderAsDelivered(order.orderId),
                                      child: Text("Pick Up"),
                                    )
                                        : null,
                                  ),
                                  if (!isCanceled && latestRiderStatuses.containsKey(order.orderId)) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                      margin: EdgeInsets.zero,
                                      decoration: BoxDecoration(
                                        color: Color(0xFFFCF3CF),
                                        borderRadius: BorderRadius.only(
                                          bottomLeft: Radius.circular(8.0),
                                          bottomRight: Radius.circular(8.0),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: "Rider : ",
                                                  style: TextStyle(fontWeight: FontWeight.normal, color: Colors.black),
                                                ),
                                                TextSpan(
                                                  text: "${latestRiderStatuses[order.orderId]?['riderName'] ?? 'N/A'}",
                                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: "Number : ",
                                                  style: TextStyle(fontWeight: FontWeight.normal, color: Colors.black),
                                                ),
                                                TextSpan(
                                                  text: "${latestRiderStatuses[order.orderId]?['riderNumber'] ?? 'N/A'}",
                                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                                ),
                                              ],
                                            ),
                                          ),
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: "Status: ",
                                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                                ),
                                                TextSpan(
                                                  text: latestRiderStatuses[order.orderId]?['riderStatus'] ?? 'N/A',
                                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                            );
                          },
                        ),
                      ),


                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String formatDateTime(DateTime dateTime) {
    String formattedTime = DateFormat('hh:mm a').format(dateTime);
    return formattedTime;
  }
  void showOrderDetails(BuildContext context, OnlineOrder order) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topNavHeight = 30.0;
    final double searchBarHeight = 60.0;

    int preparationTime = 15;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.only(
            top: topNavHeight + searchBarHeight,
            left: 0,
            right: 0,
            bottom: 0,
          ),
          backgroundColor: Colors.transparent,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Container(
                height: screenHeight - topNavHeight - searchBarHeight,
                width: MediaQuery.of(context).size.width,
                color: Colors.white,
                child: Column(
                  children: [
                    Container(
                      color: Colors.grey[300],
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: Colors.black),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          Text(
                            'Order Type: ${order.orderType} | Order ID: ${order.orderId}',
                            style: TextStyle(color: Colors.black, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),


                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Order ID
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Order ID:', style: TextStyle(fontSize: 16)),
                                Text(order.orderId, style: TextStyle(fontSize: 16)),
                              ],
                            ),
                            Divider(height: 1),

                            // Order Type
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Order Type:', style: TextStyle(fontSize: 16)),
                                Text(order.orderType, style: TextStyle(fontSize: 16)),
                              ],
                            ),
                            Divider(height: 1),

                            // Payment Mode
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Payment Mode:', style: TextStyle(fontSize: 16)),
                                Text(order.paymentMode, style: TextStyle(fontSize: 16)),
                              ],
                            ),

                            Divider(height: 1),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Customer Name:', style: TextStyle(fontSize: 16)),
                                Text(order.customerDetail?.custname ?? 'N/A', style: TextStyle(fontSize: 16)),
                              ],
                            ),
                            Divider(height: 1),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Customer Phone:', style: TextStyle(fontSize: 16)),
                                Text(order.customerDetail?.phoneNumber ?? 'N/A', style: TextStyle(fontSize: 16)),
                              ],
                            ),
                            Divider(height: 1),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Order Date/Time', style: TextStyle(fontSize: 16)),
                                Text(
                                  DateFormat('yyyy-MM-dd HH:mm:ss').format(order.orderDateTime),
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            Divider(height: 1),

                            Container(
                              height: 60,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(order.onlineOrderItemList[0].itemName, style: TextStyle(fontSize: 16)),
                                  Text(order.onlineOrderItemList[0].itemQuantity.toString(), style: TextStyle(fontSize: 16)),
                                  Text(order.onlineOrderItemList[0].itemUnitPrice.toStringAsFixed(2), style: TextStyle(fontSize: 16)),
                                ],
                              ),
                            ),
                            Divider(height: 1),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Item Total', style: TextStyle(fontSize: 16)),
                                Text( order.onlineOrderItemList[0].subtotal.toStringAsFixed(2), style: TextStyle(fontSize: 16)),
                              ],
                            ),
                            Divider(height: 1),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('CGST', style: TextStyle(fontSize: 16)),
                                Text(order.cgst.toStringAsFixed(2),
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            Divider(height: 1),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('SGST', style: TextStyle(fontSize: 16)),
                                Text(order.sgst.toStringAsFixed(2),
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            Divider(height: 1),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Grand Total', style: TextStyle(fontSize: 20)),
                                Text(order.grossAmount.toStringAsFixed(2),
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            Divider(height: 1),

                            SizedBox(height: 10),

                            Align(
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (order.status == "active")
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      ),
                                      icon: Icon(Icons.check_circle, color: Colors.white),
                                      label: Text("Accept Order", style: TextStyle(color: Colors.white)),
                                      onPressed: () {
                                        _showPreparationTimeDialog(context, order);
                                      },
                                    ),

                                  SizedBox(width: 10),

                                  if (order.status == "active")
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      ),
                                      icon: Icon(Icons.cancel, color: Colors.white),
                                      label: Text("Reject Order", style: TextStyle(color: Colors.white)),
                                      onPressed: () {
                                        _showRejectionDialog(context, order.orderId);
                                      },
                                    ),

                                  SizedBox(width: 10),
                                  if (order.status.toLowerCase() != "active")
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [

                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          ),
                                          icon: Icon(Icons.receipt, color: Colors.white),
                                          label: Text("Reprint Bill", style: TextStyle(color: Colors.white)),
                                          onPressed: () async {
                                            if (order.billNo != null && order.billNo!.trim().isNotEmpty) {

                                              await testBILLForOnlineOrder(
                                                order.billNo!,
                                                order.orderId,
                                                order.orderFrom,
                                                order.onlineOrderItemList,
                                                [],
                                                order.grossAmount,
                                                order.cgstPercent ?? 0.0,
                                                order.sgstPercent ?? 0.0,
                                                order.cgst,
                                                order.sgst,
                                                order.vatPercent ?? 0.0,
                                                order.vat ?? 0.0,
                                                order.orderInstructions ?? "",
                                                order.discount,
                                                customerName: order.customerDetail?.custname ?? "",
                                                customerPhone: order.customerDetail?.phoneNumber ?? "",
                                                deliveryArea: order.customerDetail?.deliveryArea ?? "",
                                              );
                                            } else {
                                            }
                                          },
                                        ),

                                        SizedBox(width: 10),

                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.purple,
                                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          ),
                                          icon: Icon(Icons.kitchen, color: Colors.white),
                                          label: Text("Reprint KOT", style: TextStyle(color: Colors.white)),
                                          onPressed: () async {
                                            if (order.kotID != null && order.kotID!.trim().isNotEmpty) {
                                              print(" Reprinting KOT: ${order.kotID} for Order ID: ${order.orderId}");

                                              await testOrder(
                                                "${order.orderFrom} : ${order.orderId}",
                                                order.orderId,
                                                order.orderInstructions ?? "",
                                                order.orderFrom,
                                                order.onlineOrderItemList,
                                                order.externalOrderId,
                                                order.kotID!,
                                              );
                                            } else {
                                            }
                                          },
                                        ),
                                      ],
                                    ),



                                ],
                              ),
                            ),



                            SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void OnlineItemsDialog(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topNavHeight = 80.0;
    final double searchBarHeight = 60.0;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.only(
            top: topNavHeight + searchBarHeight,
            left: 0,   // NO left inset, so takes full width
            right: 0,
            bottom: 0,
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            height: screenHeight - topNavHeight - searchBarHeight,
            width: MediaQuery.of(context).size.width,
            color: Colors.white,
            child: Column(
              children: [
                // Header
                Container(
                  color: Colors.grey[300],
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      Text(
                        'Online Items',
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),

                // Online Items List
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(  // Fetch products
                    future: fetchProducts(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(child: Text('No products found.'));
                      }

                      final List<Map<String, dynamic>> products = snapshot.data!;

                      return FutureBuilder<List<Map<String, dynamic>>>(  // Fetch pricing data
                        future: fetchOnlineItems(),
                        builder: (context, pricingSnapshot) {
                          if (pricingSnapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          } else if (pricingSnapshot.hasError) {
                            return Center(child: Text('Error: ${pricingSnapshot.error}'));
                          } else if (!pricingSnapshot.hasData || pricingSnapshot.data!.isEmpty) {
                            return Center(child: Text('No pricing data found.'));
                          }

                          final List<Map<String, dynamic>> pricingItems = pricingSnapshot.data!;

                          // Group items by category
                          Map<String, List<Map<String, dynamic>>> categorizedItems = {};

                          // Iterate through products and group by categoryName
                          for (var product in products) {
                            String categoryName = product["categoryName"] ?? "Unknown Category";
                            String productCode = product["productCode"]?.toString() ?? "0";

                            // Find corresponding pricing items based on productCode and itemcode
                            var matchingPricingItems = pricingItems.where((item) {
                              return item["itemcode"]?.toString() == productCode;
                            }).toList();

                            if (matchingPricingItems.isNotEmpty) {
                              if (!categorizedItems.containsKey(categoryName)) {
                                categorizedItems[categoryName] = [];
                              }
                              categorizedItems[categoryName]!.addAll(matchingPricingItems);
                            }
                          }

                          // Now display items categorized by categoryName
                          return ListView(
                            children: categorizedItems.entries.map((entry) {
                              String categoryName = entry.key;
                              List<Map<String, dynamic>> items = entry.value;

                              bool allItemsEnabled = items.every((item) => item["status"] == true);
                              bool allItemsDisabled = items.every((item) => item["status"] == false);

                              return ExpansionTile(
                                title: Text(
                                  categoryName,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                leading: Switch(
                                  value: allItemsEnabled && !allItemsDisabled,
                                  onChanged: (value) async {
                                    // Toggle all items in the category
                                    // Iterate over each item and update its status individually
                                    for (var item in items) {
                                      bool weraUpdated = await updateItemStatusWera(item["id"], value, null, null);
                                      bool localUpdated = await updateItemStatusLocal(item["id"], value);

                                      if (weraUpdated && localUpdated) {
                                        setState(() {
                                          item["status"] = value;
                                        });
                                      } else {
                                        print("Failed to update status for item in category $categoryName");
                                      }
                                    }
                                  },
                                ),
                                children: items.map((item) {
                                  return StatefulBuilder(
                                    builder: (context, setState) {
                                      return ListTile(
                                        title: Text(item["itemName"] ?? "Unknown Item"),
                                        trailing: Switch(
                                          value: item["status"] != null
                                              ? item["status"].toString().toLowerCase() == "true"
                                              : false,
                                          onChanged: (value) async {
                                            if (!value) {
                                              // Show combined Date-Time picker
                                              showDateTimePickerDialog(context, item["itemName"], item["id"], setState);
                                            } else {
                                              // Update status directly
                                              bool weraUpdated = await updateItemStatusWera(item["id"], value, null, null);
                                              bool localUpdated = await updateItemStatusLocal(item["id"], value);

                                              if (weraUpdated && localUpdated) {
                                                setState(() {
                                                  item["status"] = value;
                                                });
                                              } else {
                                                print("Failed to update status for item ${item["itemName"]}");
                                              }
                                            }
                                          },
                                        ),
                                      );
                                    },
                                  );
                                }).toList(),
                              );
                            }).toList(),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> showDateTimePickerDialog(
      BuildContext context, String itemName, int itemId, Function setState)
  async {
    DateTime fromTime = DateTime.now();
    DateTime toTime = fromTime;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            "Set Disable Time",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // **From Time (Fixed - Current Time)**
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(Icons.access_time, color: Colors.grey),
                        Text(
                          "Start: ${DateFormat('EEE, MMM d, yyyy | hh:mm a').format(fromTime)}",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),

                  // **To Time Picker (User Selects)**
                  GestureDetector(
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: fromTime,
                        firstDate: fromTime,
                        lastDate: fromTime.add(Duration(days: 30)),
                      );

                      if (pickedDate == null) return;

                      TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );

                      if (pickedTime == null) return;

                      // Combine selected date and time
                      setDialogState(() {
                        toTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        // border: Border.all(color: Colors.blue),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.timer, color: Colors.blue),
                          Text(
                            "End: ${DateFormat('EEE, MMM d, yyyy | hh:mm a').format(toTime)}",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("CANCEL", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                List<int> itemIds = [itemId];
                bool weraUpdated = await updateItemStatusWera(itemId as List<int>, false, fromTime, toTime);
                bool localUpdated = await updateItemStatusLocal(itemId, false);

                if (weraUpdated && localUpdated) {
                  setState(() {});
                  Navigator.pop(context);
                } else {
                  print("Failed to update status");
                }
              },
              child: Text("CONFIRM"),
            ),
          ],
        );
      },
    );
  }



  void showOnlineAddonsDialog(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topNavHeight = 30.0;
    final double searchBarHeight = 60.0;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.only(
            top: topNavHeight + searchBarHeight,
            left: 0,     // NO sidebar inset here
            right: 0,
            bottom: 0,
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            height: screenHeight - topNavHeight - searchBarHeight,
            width: MediaQuery.of(context).size.width,  // Full width
            color: Colors.white,
            child: Column(
              children: [

                Container(
                  color: Colors.grey[300],
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      Text(
                        'Available Addons',
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),

                // Display addons with toggle buttons
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: fetchAddons(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: TextStyle(color: Colors.red),
                          ),
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Text(
                            'No addons found.',
                            style: TextStyle(color: Colors.black),
                          ),
                        );
                      }

                      final List<Map<String, dynamic>> addons = snapshot.data!;
                      return ListView.builder(
                        key: ObjectKey(onlineOrders),
                        itemCount: addons.length,
                        itemBuilder: (context, index) {
                          final addon = addons[index];
                          return StatefulBuilder(
                            builder: (context, setState) {
                              return ListTile(
                                title: Text("${addon["name"]} - ₹${addon["price"]}"),
                                trailing: Switch(
                                  value: addon["status"] ?? true,
                                  onChanged: (value) async {
                                    bool success = await toggleAddonStatus(addon["id"], value);
                                    if (success) {
                                      final freshAddons = await fetchAddons();
                                      setState(() {
                                        addon["status"] = value;
                                        addons.clear();
                                        addons.addAll(freshAddons);
                                      });
                                    } else {
                                      print("Failed to toggle ${addon["name"]}");
                                    }
                                  },
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  void showSettingsDialog(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topNavHeight = 30.0;
    final double searchBarHeight = 60.0;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.only(
            top: topNavHeight + searchBarHeight,
            left: 0,     // NO sidebar inset here
            right: 0,
            bottom: 0,
          ),
          backgroundColor: Colors.transparent,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Container(
                height: screenHeight - topNavHeight - searchBarHeight,
                width: MediaQuery.of(context).size.width,  // Full width
                color: Colors.white,
                child: Column(
                  children: [
                    Container(
                      color: Colors.grey[300],
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: Colors.black),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          Text(
                            'Settings',
                            style: TextStyle(color: Colors.black, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),

                    // Auto-Accept Toggle
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Auto-Accept Orders"),
                          Switch(
                            value: isAutoAcceptEnabled,
                            onChanged: (value) {
                              setDialogState(() {
                                isAutoAcceptEnabled = value;
                              });
                              saveAutoAcceptPreference(value);
                            },
                          ),
                        ],
                      ),
                    ),

                    Divider(),

                    // Delivery Partners List
                    Expanded(
                      child: FutureBuilder<List<DeliveryPartner>>(
                        future: fetchDeliveryPartners(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error: ${snapshot.error}',
                                style: TextStyle(color: Colors.red),
                              ),
                            );
                          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Center(
                              child: Text(
                                'No delivery partners found.',
                                style: TextStyle(color: Colors.black),
                              ),
                            );
                          }

                          final List<DeliveryPartner> deliveryPartners = snapshot.data!;
                          return ListView.builder(
                            key: ObjectKey(onlineOrders),
                            itemCount: deliveryPartners.length,
                            itemBuilder: (context, index) {
                              final partner = deliveryPartners[index];
                              return StatefulBuilder(
                                builder: (context, setState) {
                                  return ListTile(
                                    title: Text(partner.deliveryPartnerName),
                                    trailing: Switch(
                                      value: partner.status == "Y",
                                      onChanged: (value) async {
                                        TextEditingController reasonController = TextEditingController();

                                        await showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text('Reason for status change'),
                                            content: TextField(
                                              controller: reasonController,
                                              decoration: InputDecoration(hintText: "Enter reason"),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () async {
                                                  bool success = await updateDeliveryPartnerStatus(
                                                    partner.deliveryPartnerCode,
                                                    partner.deliveryPartnerName,
                                                    value,
                                                  );

                                                  if (success) {
                                                    setDialogState(() {
                                                      partner.status = value ? "Y" : "N";
                                                    });
                                                  } else {
                                                    print(" Failed to update ${partner.deliveryPartnerName}");
                                                  }
                                                  Navigator.of(context).pop();
                                                },
                                                child: Text('Submit'),
                                              )
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void showReportsDialog(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topNavHeight = 30.0;
    final double searchBarHeight = 60.0;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.only(
            top: topNavHeight + searchBarHeight,
            left: 0,     // NO sidebar inset here
            right: 0,
            bottom: 0,
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            height: screenHeight - topNavHeight - searchBarHeight,
            width: MediaQuery.of(context).size.width,  // Full width
            color: Colors.white,
            child: Column(
              children: [

                Container(
                  color: Colors.grey[300],
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      Text(
                        'Reports',
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),


                Expanded(
                  child: ListView.builder(
                    key: ObjectKey(onlineOrders),
                    itemCount: reportList.length,
                    itemBuilder: (context, index) {
                      final report = reportList[index];
                      return ListTile(
                        title: Text(report['title']),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        onTap: () => report['onTap'](context),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> printTicket(List<int> ticket,String targetip) async {
    final printer = PrinterNetworkManager(targetip);
    PosPrintResult connect = await printer.connect();
    if (connect == PosPrintResult.success) {
      PosPrintResult printing = await printer.printTicket(ticket);

      print(printing.msg);
      printer.disconnect();
    }

  }
  Future<List<int>> testOrder(
      String name,
      String orderId,
      String orderInstructions,
      String orderFrom,
      dynamic items, // Accept both List<OnlineOrderItemList> and List<CanceledOrderItem>
      String externalOrderId,
      String kotId,
      {bool isCanceled = false}
      ) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    String prefix = orderId.substring(0, orderId.length - 3);
    String suffix = orderId.substring(orderId.length - 4);
    List<int> bytes = [];


    bytes += generator.text(isCanceled ? "[Cancel Order]" : " KOT",
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.center,
        ));

    bytes += generator.text('', styles: const PosStyles(
      fontType: PosFontType.fontA,
      bold: false,
      height: PosTextSize.size1,
      width: PosTextSize.size1,
    ));
    bytes += generator.text('',  styles:  const PosStyles(fontType: PosFontType.fontA,
      bold: false,
      height: PosTextSize.size1,
      width: PosTextSize.size1,
    ));

    bytes += generator.text(brandName,
        styles: const PosStyles(fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.center,
        ));


    bytes += generator.text('',  styles:  const PosStyles(fontType: PosFontType.fontA,
      bold: false,
      height: PosTextSize.size1,
      width: PosTextSize.size1,
    ));



    bytes += generator.text(orderFrom,
        styles: const PosStyles(
          fontType: PosFontType.fontB,
          bold: true,
          height: PosTextSize.size3,
          width: PosTextSize.size3,
          align: PosAlign.center,
        ));

    bytes += generator.text('________________________________________________',
        styles: PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ));

    bytes += generator.row([
      PosColumn(
        text: orderFrom + ' Id    :',
        width: 4,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: prefix,
        width: 2,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: suffix,
        width: 6,
        styles: const PosStyles(
          fontType: PosFontType.fontB,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.left,
        ),
      ),
    ]);

    bytes += generator.row([
      PosColumn(
        text: ' ',
        width: 12,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        text: 'KOT Id       :',
        width: 4,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: kotId,
        width: 3,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: ' ',
        width: 5,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
    ]);

// Date and Time Row (unchanged)
    bytes += generator.row([
      PosColumn(
        text: 'Date and Time:',
        width: 4,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now()).toString(),
        width: 8,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
    ]);

    bytes += generator.row([
      PosColumn(
        text: 'Instructions :',
        width: 4,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: orderInstructions ?? "",
        width: 8,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),

    ]);

    bytes += generator.text('________________________________________________',
        styles: PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ));


    bytes += generator.row([
      PosColumn(
        text: 'Qty',
        width: 2,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: 'Item Name',
        width: 10,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
    ]);

    bytes += generator.text('________________________________________________',
        styles: PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ));

    // Iterate through items (handle both OnlineOrderItemList and CanceledOrderItem)
    for (var item in items) {
      bytes += generator.row([
        PosColumn(
          text: item.itemQuantity.toString(),
          width: 2,
          styles: const PosStyles(
            fontType: PosFontType.fontB,
            bold: false,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            align: PosAlign.left,
          ),
        ),
        PosColumn(
          text: item.itemName.toString(),
          width: 10,
          styles: const PosStyles(
            fontType: PosFontType.fontB,
            bold: false,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            align: PosAlign.left,
          ),
        ),
      ]);

      for (var addon in item.onlineOrderItemAddonList) {
        bytes += generator.row([
          PosColumn(
            text: ">>   ${addon.addonName}",
            width: 12,
            styles: const PosStyles(
              fontType: PosFontType.fontB,
              bold: false,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
              align: PosAlign.left,
            ),
          ),


        ]);
      }
    }


    bytes += generator.text('________________________________________________',
        styles: PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ));
    bytes += generator.barcode(
      Barcode.code128(orderId.split('').map((e) => int.parse(e)).toList()),
      height: 60,
    );

    bytes += generator.feed(1);
    bytes += generator.cut();

    printTicket(bytes, "192.168.1.222");

    return bytes;
  }

  Future<List<int>> testBILLForOnlineOrder(
      String billno,
      String orderId,
      String orderFrom,
      dynamic items,
      List<SelectedProductModifier> modifiers,
      double grossAmount,
      double cgstpercentt,
      double sgstpercentt,
      double cgst,
      double sgst,
      double vattpercentt,
      double vatt,
      String orderInstructions,
      double disc,{bool isCanceled = false,String? customerName, String? customerPhone,String? deliveryArea}) async
  {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);


    List<int> bytes = [];


    double subtotal = items.fold(0, (sum, item) => sum + (item.itemUnitPrice * item.itemQuantity));
    double netAmount = subtotal - discount + deliveryCharge;
    double grandTotal = netAmount + cgst + sgst;

    bytes += generator.text(
      isCanceled ? "[Cancel Order]" : "",
      styles: const PosStyles(
        fontType: PosFontType.fontA,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        align: PosAlign.center,
      ),
    );

    bytes += generator.feed(2);

    bytes += generator.text(brandName,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.center,
        ));

    bytes += generator.text(Addresslineone,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        ));
    bytes += generator.text(Addresslinetwo,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        ));

    bytes += generator.text(Addresslinethree,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        ));
    bytes += generator.text('________________________________________________',
        styles: PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ));

    bytes += generator.text(
      "$orderFrom",
      styles: const PosStyles(
        fontType: PosFontType.fontB,
        bold: false,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        align: PosAlign.center,
      ),
    );

    bytes += generator.text('________________________________________________',
        styles: PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ));
////
    bytes += generator.row([
      PosColumn(
        text: '  Customer Name    ',
        width: 4,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),

      PosColumn(
        text: '  : ' +customerName!,
        width: 8,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        text: '  Number ',
        width: 5,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),

      PosColumn(
        text: ':  ' +customerPhone!,
        width: 7,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),

    ]);
    bytes += generator.row([
      PosColumn(
        text: '  Address  ',
        width: 4,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),

      PosColumn(
        text: ': ' +deliveryArea!,
        width: 8,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),

    ]);
    bytes += generator.text('________________________________________________',
        styles: PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ));
    //////
    bytes += generator.row([
      PosColumn(
        text: '  Bill No      ',
        width: 4,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),

      PosColumn(
        text: ':      ' +billno,
        width: 8,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),

    ]);


    bytes += generator.row([
      PosColumn(
        text: '  Date and Time',
        width: 4,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: ':      ' +
            DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now()).toString(),
        width: 8,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
    ]);

    String prefix = orderId.length > 4 ? orderId.substring(0, orderId.length - 4) : "";
    String suffix = orderId.substring(orderId.length - 4);

    bytes += generator.row([
      PosColumn(
        text: '  $orderFrom Id    ',
        width: 4,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: '       $prefix',
        width: 3,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: '$suffix',
        width: 5,
        styles: const PosStyles(
          fontType: PosFontType.fontB,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.left,
        ),
      ),
    ]);

    bytes += generator.row([
      PosColumn(
        text: '  Bill By',
        width: 3,
        styles: const PosStyles(fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: '    :     ' + username,
        width: 9,
        styles: const PosStyles(fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        text: '  Instructions',
        width: 4,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: ':      ' + orderInstructions,

        width: 8,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
    ]);

    bytes += generator.text('________________________________________________',
        styles: PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ));

    bytes += generator.row([
      PosColumn(
        text: 'Item Name',
        width: 5,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: '   Qty',
        width: 2,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        ),
      ),
      PosColumn(
        text: 'Price' ,
        width: 2,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.right,
        ),
      ),
      PosColumn(
        text: 'Amount',
        width: 3,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.right,
        ),
      ),
    ]);
    bytes += generator.text('________________________________________________',
        styles: PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ));

    for (var item in items) {
      bytes += generator.row([
        PosColumn(
          text: item.itemName,
          width: 6,
          styles: const PosStyles(
            align: PosAlign.left,
            bold: true,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        ),        PosColumn(
          text: item.itemQuantity.toString(),
          width: 1,
          styles: const PosStyles(
            align: PosAlign.left,
            bold: true,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        ),        PosColumn(
          text: '  ${item.itemUnitPrice.toStringAsFixed(2)}',
          width: 3,
          styles: const PosStyles(
            align: PosAlign.left,
            bold: true,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        ),        PosColumn(
          text: '${(item.itemUnitPrice * item.itemQuantity).toStringAsFixed(2)}',
          width: 2,
          styles: const PosStyles(
            align: PosAlign.right,
            bold: true,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        ),      ]);

      for (var addon in item.onlineOrderItemAddonList) {
        bytes += generator.row([
          PosColumn(
            text: ">> ${addon.addonName}",
            width: 6,
            styles: const PosStyles(
              align: PosAlign.left,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,
            ),
          ),        PosColumn(
            text: ' ',
            width: 1,
            styles: const PosStyles(
              align: PosAlign.left,
              bold: false,
              height: PosTextSize.size1,
              width: PosTextSize.size1,
            ),
          ),
          PosColumn(
            text: ' ${addon.addonPrice.toStringAsFixed(2)}',
            width: 3,
            styles: const PosStyles(
              align: PosAlign.left,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,
            ),
          ),
          PosColumn(
            text: ' ${addon.addonPrice.toStringAsFixed(2)}',
            width: 2,
            styles: const PosStyles(
              align: PosAlign.right,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,
            ),
          ),      ]);
        ///////

      }
    }






    bytes += generator.text('________________________________________________',
        styles: PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ));

    bytes += generator.row([
      PosColumn(
        text: 'Sub Total',
        width: 4,
        styles: const PosStyles(
          align: PosAlign.left,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      ),
      PosColumn(
        width: 4,
      ),
      PosColumn(
        text: netAmount.toStringAsFixed(2) + ' ',
        width: 4,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      ),
    ]);

    bytes += generator.row([
      PosColumn(
        text: 'CGST',
        width: 4,
        styles: const PosStyles(
          align: PosAlign.left,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      ),
      PosColumn(
        width: 4,
      ),
      PosColumn(
        text: cgst.toStringAsFixed(2) + ' ',
        width: 4,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        text: 'SGST',
        width: 4,
        styles: const PosStyles(
          align: PosAlign.left,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      ),
      PosColumn(
        width: 4,
      ),
      PosColumn(
        text: sgst.toStringAsFixed(2) + ' ',
        width: 4,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      ),
    ]);


    if (disc > 0.0) {
      bytes += generator.row([
        PosColumn(
          text: 'Bill Amount',
          width: 5,
          styles: const PosStyles(
            align: PosAlign.left,
            underline: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        ),
        PosColumn(
          width: 3,
        ),
        PosColumn(
          text: billamount.toStringAsFixed(2) + ' ',
          width: 4,
          styles: const PosStyles(
            align: PosAlign.right,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        ),
      ]);
    }

    /*   for (var tax in globaltaxlist) {
      String isApplicableOncurrentmodlue = "N";

      switch (Lastclickedmodule) {
        case 'Dine':
          isApplicableOncurrentmodlue = tax.isApplicableonDinein;
          break;
        case 'Take Away':
          isApplicableOncurrentmodlue = tax.isApplicableonTakeaway;
          break;
        case 'Home Delivery':
          isApplicableOncurrentmodlue = tax.isApplicableonHomedelivery;
          break;
        case 'Counter':
          isApplicableOncurrentmodlue = tax.isApplicableCountersale;
          break;
        case 'Online':
          isApplicableOncurrentmodlue = tax.isApplicableOnlineorder;
          break;
      }

      if (isApplicableOncurrentmodlue == "Y") {
        double pec = double.parse(tax.taxPercent);
        double taxable = 0.0;

        if (discount > 0.0) {
          if (tax.taxName == "Service Charge") {
            if (GLOBALNSC == "Y") {
              taxable = (0.0 / 100.00) * billamount;
            } else {
              taxable = (pec / 100.00) * billamount;
            }
          } else {
            taxable = (pec / 100.00) * billamount;
          }
        } else {
          if (tax.taxName == "Service Charge") {
            if (GLOBALNSC == "Y") {
              taxable = (0.0 / 100.00) * subtotal;
            } else {
              taxable = (pec / 100.00) * subtotal;
            }
          } else {
            taxable = (pec / 100.00) * subtotal;
          }
        }
        bytes += generator.row([
          PosColumn(
            text: '${tax.taxName} ${tax.taxPercent}%',
            width: 5,
            styles: const PosStyles(
              align: PosAlign.left,
              underline: false,
              height: PosTextSize.size1,
              width: PosTextSize.size1,
            ),
          ),
          PosColumn(
            width: 3,
          ),
          PosColumn(
            text: taxable.toStringAsFixed(2) + ' ',
            width: 4,
            styles: const PosStyles(
              align: PosAlign.right,
              height: PosTextSize.size1,
              width: PosTextSize.size1,
            ),
          ),
        ]);
      }
    }*/

    bytes += generator.text('________________________________________________',
        styles: PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ));

    bytes += generator.row([
      PosColumn(
        text: 'Grand Total',
        width: 5,
        styles: const PosStyles(
          fontType: PosFontType.fontB,
          bold: false,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        width: 3,
      ),
      PosColumn(
          text: grossAmount.toStringAsFixed(2) + ' ',
          width: 4,
          styles: const PosStyles(
            fontType: PosFontType.fontB,
            bold: false,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            align: PosAlign.right,
          )),
    ]);

    bytes += generator.text('________________________________________________',
        styles: PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ));
    bytes += generator.row([
      PosColumn(
        text: '  Paid By',
        width: 3,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: '    :    ' + orderFrom,
        width: 9,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
    ]);
    bytes += generator.text(
      '',
      styles: PosStyles(
        fontType: PosFontType.fontA,
        bold: false,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
      ),
    );
    bytes += generator.barcode(
      Barcode.code128(orderId.split('').map((e) => int.parse(e)).toList()),
      height: 60,
    );

    bytes += generator.feed(1);
    bytes += generator.cut();

    printTicket(bytes, "192.168.1.222");

    return bytes;
  }

}



//////////////////////////////////////////////////////////////////////////////////////////
Future<List<Map<String, dynamic>>> fetchOnlineDaywiselist(String startDate, String endDate) async {
  try {
    final response = await http.get(
      Uri.parse('${apiUrl}report/onlinedaywiselist?startDate=$startDate&endDate=$endDate&DB=$CLIENTCODE'),
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to fetch summary data.');
    }
  } catch (e) {
    print("Error fetching summary data: $e");
    return [];
  }
}
Future<List<Map<String, dynamic>>> fetchOnlineDaywiseSummary(String startDate, String endDate) async {
  try {
    final response = await http.get(
      Uri.parse('${apiUrl}report/onlinedaywisesum?startDate=$startDate&endDate=$endDate&DB=$CLIENTCODE'),
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to fetch summary data.');
    }
  } catch (e) {
    print(" Error fetching summary data: $e");
    return [];
  }
}
Future<List<Map<String, dynamic>>> fetchOnlineItemWiseReport(String startDate, String endDate) async {
  try {
    final response = await http.get(
      Uri.parse('${apiUrl}report/onlineitemwise?startDate=$startDate&endDate=$endDate&DB=$CLIENTCODE'),
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to fetch item-wise report data.');
    }
  } catch (e) {
    print("Error fetching item-wise report data: $e");
    return [];
  }
}
Future<List<Map<String, dynamic>>> fetchOnlineCanceledOrdersReport(String startDate, String endDate) async {
  try {
    final response = await http.get(
      Uri.parse('${apiUrl}report/onlinecanceled?startDate=$startDate&endDate=$endDate&DB=$CLIENTCODE'),
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to fetch canceled orders report.');
    }
  } catch (e) {
    print("Error fetching canceled orders report: $e");
    return [];
  }
}

final List<Map<String, dynamic>> reportList = [
  {
    'title': "Today's Sales Summary Report",
    'onTap': (context) {
      String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      showDaywiseSummaryDialog(context, currentDate, currentDate);
    }
  },
  {
    'title': "Detailed Sales Report",
    'onTap': (context) {
      showDetailedSalesReportDialog(context);
    }
  },
  {
    'title': "Item-Wise Sales Report",
    'onTap': (context) {
      showItemWiseReportDialog(context);
    }},
  {
    'title': "Canceled Orders Report",
    'onTap': (context) {
      showCanceledOrdersReportDialog(context);
    }
  },
];

Future<void> exportToExcel(List<Map<String, dynamic>> data, String fileName) async {
  var excelFile = excel.Excel.createExcel();
  excel.Sheet sheetObject = excelFile['Sheet1'];

  if (data.isEmpty) {
    print("No data to export.");
    return;
  }

  // Add Headers
  List<String> headers = data.first.keys.toList();
  sheetObject.appendRow(headers);

  // Add Data
  for (var row in data) {
    sheetObject.appendRow(headers.map((header) => row[header].toString()).toList());
  }

  // Request Permission
  if (await Permission.storage.request().isGranted) {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    String filePath = '${directory!.path}/$fileName.xlsx';

    List<int> bytes = excelFile.encode()!;
    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);

    print("Excel file saved: $filePath");
  } else {
    print("Storage permission denied.");
  }
}

void showDaywiseSummaryDialog(BuildContext context, String startDate, String endDate) async {
  final double screenHeight = MediaQuery.of(context).size.height;
  final double topNavHeight = 30.0;
  final double searchBarHeight = 60.0;

  final List<Map<String, dynamic>> listData = await fetchOnlineDaywiselist(startDate, endDate);
  final List<Map<String, dynamic>> summaryData = await fetchOnlineDaywiseSummary(startDate, endDate);

  bool showSummary = false;

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding: EdgeInsets.only(
              top: topNavHeight + searchBarHeight,
              left: 0,     // NO sidebar inset here
              right: 0,
              bottom: 0,
            ),
            backgroundColor: Colors.transparent,
            child: Container(
              height: screenHeight - topNavHeight - searchBarHeight,
              width: MediaQuery.of(context).size.width,  // Full width
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    color: Colors.grey[300],
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Text(
                          "Today's Sales Summary",
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Start Date:", style: TextStyle(color: Colors.black, fontSize: 14)),
                            Text(startDate, style: TextStyle(color: Colors.black, fontSize: 14)),
                          ],
                        ),
                        Divider(color: Colors.grey),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("End Date:", style: TextStyle(color: Colors.black, fontSize: 14)),
                            Text(endDate, style: TextStyle(color: Colors.black, fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () async {
                          await exportToExcel(showSummary ? summaryData : listData, 'Todaysales');
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300], // Light grey background
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8), // Square round shape (rounded corners)
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0), // Add padding for size
                        ),
                        child: Text(
                          'Download',
                          style: TextStyle(color: Colors.black), // Text color inside button
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => setState(() => showSummary = false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !showSummary ? Colors.black : Colors.grey,
                          ),
                          child: Text("Order Listing", style: TextStyle(color: Colors.white)),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () => setState(() => showSummary = true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: showSummary ? Colors.black : Colors.grey,
                          ),
                          child: Text("Summary", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 10),

                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateColor.resolveWith((states) => Colors.black),
                        headingTextStyle: const TextStyle(color: Colors.white),
                        columnSpacing: 20.0,

                        columns: showSummary
                            ? const [
                          DataColumn(label: Text('Restaurant Name')),
                          DataColumn(label: Text('Source')),
                          DataColumn(label: Text('Total Orders')),
                          DataColumn(label: Text('Total Amount')),
                          DataColumn(label: Text('Subtotal')),
                          DataColumn(label: Text('Total Discount')),
                          DataColumn(label: Text('Tax Sum')),
                          DataColumn(label: Text('Total Delivery Charge')),
                          DataColumn(label: Text('Canceled Orders')),
                          DataColumn(label: Text('Canceled Order Amount')),
                        ]
                            : const [
                          DataColumn(label: Text('Merchant Id')),
                          DataColumn(label: Text('Source')),
                          DataColumn(label: Text('OrderId')),
                          DataColumn(label: Text('Order Date')),
                          DataColumn(label: Text('Order Type')),
                          DataColumn(label: Text('Payment Mode')),
                          DataColumn(label: Text('Subtotal')),
                          DataColumn(label: Text('Discount')),
                          DataColumn(label: Text('Packaging Charge')),
                          DataColumn(label: Text('Delivery Charge')),
                          DataColumn(label: Text('Tax')),
                          DataColumn(label: Text('Total')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Bill No')),
                        ],

                        rows: showSummary
                            ? summaryData.map((row) {
                          return DataRow(cells: [
                            DataCell(Text(row['restaurantName'] ?? 'N/A')),
                            DataCell(Text(row['source'] ?? 'N/A')),
                            DataCell(Text(row['totalOrders'].toString())),
                            DataCell(Text(row['totalAmount'].toString())),
                            DataCell(Text(row['subtotal'].toString())),
                            DataCell(Text(row['totalDiscount'].toString())),
                            DataCell(Text(row['taxSum'].toString())),
                            DataCell(Text(row['totalDeliveryCharge'].toString())),
                            DataCell(Text(row['canceledOrders'].toString())),
                            DataCell(Text(row['canceledOrderAmount'].toString())),
                          ]);
                        }).toList()
                            : listData.map((row) {
                          return DataRow(cells: [
                            DataCell(Text(row['merchantId'] ?? 'N/A')),
                            DataCell(Text(row['source'] ?? 'N/A')),
                            DataCell(Text(row['orderId'].toString())),
                            DataCell(Text(row['orderDate'].toString())),
                            DataCell(Text(row['orderType'].toString())),
                            DataCell(Text(row['paymentMode'].toString())),
                            DataCell(Text(row['subtotal'].toString())),
                            DataCell(Text(row['discount'].toString())),
                            DataCell(Text(row['packagingCharge'].toString())),
                            DataCell(Text(row['deliveryCharge'].toString())),
                            DataCell(Text(row['tax'].toString())),
                            DataCell(Text(row['total'].toString())),
                            DataCell(Text(row['status'].toString())),
                            DataCell(Text(row['billNo'].toString())),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),


                ],
              ),
            ),
          );
        },
      );
    },
  );
}
void showDetailedSalesReportDialog(BuildContext context) async {
  final double screenHeight = MediaQuery.of(context).size.height;
  final double topNavHeight = 30.0;
  final double searchBarHeight = 60.0;


  DateTime selectedStartDate = DateTime.now().subtract(Duration(days: 1));
  DateTime selectedEndDate = DateTime.now().subtract(Duration(days: 1));

  bool showSummary = false;
  List<Map<String, dynamic>> listData = [];
  List<Map<String, dynamic>> summaryData = [];

  Future<void> fetchData() async {
    listData = await fetchOnlineDaywiselist(
      DateFormat('yyyy-MM-dd').format(selectedStartDate),
      DateFormat('yyyy-MM-dd').format(selectedEndDate),
    );
    summaryData = await fetchOnlineDaywiseSummary(
      DateFormat('yyyy-MM-dd').format(selectedStartDate),
      DateFormat('yyyy-MM-dd').format(selectedEndDate),
    );
  }

  await fetchData();

  Future<void> _selectDate(BuildContext context, bool isStartDate, Function setStateCallback) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? selectedStartDate : selectedEndDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      if (isStartDate) {
        selectedStartDate = picked;
      } else {
        selectedEndDate = picked;
      }
      await fetchData();
      setStateCallback(() {});
    }
  }

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding: EdgeInsets.only(
              top: topNavHeight + searchBarHeight,
              left: 0,     // NO sidebar inset here
              right: 0,
              bottom: 0,
            ),
            backgroundColor: Colors.transparent,
            child: Container(
              height: screenHeight - topNavHeight - searchBarHeight,
              width: MediaQuery.of(context).size.width,  // Full width
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Container(
                    color: Colors.grey[300],
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Text(
                          "Detailed Sales Report",
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Start Date:", style: TextStyle(color: Colors.black, fontSize: 14)),
                            GestureDetector(
                              onTap: () async {
                                await _selectDate(context, true, setState);
                              },
                              child: Text(
                                DateFormat('yyyy-MM-dd').format(selectedStartDate),
                                style: TextStyle(color: Colors.black, fontSize: 14, decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                        Divider(color: Colors.grey),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("End Date:", style: TextStyle(color: Colors.black, fontSize: 14)),
                            GestureDetector(
                              onTap: () async {
                                await _selectDate(context, false, setState);
                              },
                              child: Text(
                                DateFormat('yyyy-MM-dd').format(selectedEndDate),
                                style: TextStyle(color: Colors.black, fontSize: 14, decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Download button below the End Date
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                    child: Align(
                      alignment: Alignment.centerRight,  // Align the button to the right
                      child: ElevatedButton(
                        onPressed: () async {
                          await exportToExcel(showSummary ? summaryData : listData, 'Detailsales');
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300], // Light grey background
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8), // Square round shape (rounded corners)
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0), // Add padding for size
                        ),
                        child: Text(
                          'Download',
                          style: TextStyle(color: Colors.black), // Text color inside button
                        ),
                      ),
                    ),
                  ),


                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => setState(() => showSummary = false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !showSummary ? Colors.black : Colors.grey,
                          ),
                          child: Text("Order Listing", style: TextStyle(color: Colors.white)),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () => setState(() => showSummary = true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: showSummary ? Colors.black : Colors.grey,
                          ),
                          child: Text("Summary", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 5),

                  Expanded(
                    child: Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: MaterialStateColor.resolveWith((states) => Colors.black),
                            headingTextStyle: const TextStyle(color: Colors.white),
                            columnSpacing: 20.0,

                            columns: showSummary
                                ? const [
                              DataColumn(label: Text('Restaurant Name')),
                              DataColumn(label: Text('Source')),
                              DataColumn(label: Text('Total Orders')),
                              DataColumn(label: Text('Total Amount')),
                              DataColumn(label: Text('Subtotal')),
                              DataColumn(label: Text('Total Discount')),
                              DataColumn(label: Text('Tax Sum')),
                              DataColumn(label: Text('Total Delivery Charge')),
                              DataColumn(label: Text('Canceled Orders')),
                              DataColumn(label: Text('Canceled Order Amount')),
                            ]
                                : const [
                              DataColumn(label: Text('Merchant Id')),
                              DataColumn(label: Text('Source')),
                              DataColumn(label: Text('OrderId')),
                              DataColumn(label: Text('Order Date')),
                              DataColumn(label: Text('Order Type')),
                              DataColumn(label: Text('Payment Mode')),
                              DataColumn(label: Text('Subtotal')),
                              DataColumn(label: Text('Discount')),
                              DataColumn(label: Text('Packaging Charge')),
                              DataColumn(label: Text('Delivery Charge')),
                              DataColumn(label: Text('Tax')),
                              DataColumn(label: Text('Total')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Bill No')),
                            ],

                            rows: showSummary
                                ? summaryData.map((row) {
                              return DataRow(cells: [
                                DataCell(Text(row['restaurantName'] ?? 'N/A')),
                                DataCell(Text(row['source'] ?? 'N/A')),
                                DataCell(Text(row['totalOrders'].toString())),
                                DataCell(Text(row['totalAmount'].toString())),
                                DataCell(Text(row['subtotal'].toString())),
                                DataCell(Text(row['totalDiscount'].toString())),
                                DataCell(Text(row['taxSum'].toString())),
                                DataCell(Text(row['totalDeliveryCharge'].toString())),
                                DataCell(Text(row['canceledOrders'].toString())),
                                DataCell(Text(row['canceledOrderAmount'].toString())),
                              ]);
                            }).toList()
                                : listData.map((row) {
                              return DataRow(cells: [
                                DataCell(Text(row['merchantId'] ?? 'N/A')),
                                DataCell(Text(row['source'] ?? 'N/A')),
                                DataCell(Text(row['orderId'].toString())),
                                DataCell(Text(row['orderDate'].toString())),
                                DataCell(Text(row['orderType'].toString())),
                                DataCell(Text(row['paymentMode'].toString())),
                                DataCell(Text(row['subtotal'].toString())),
                                DataCell(Text(row['discount'].toString())),
                                DataCell(Text(row['packagingCharge'].toString())),
                                DataCell(Text(row['deliveryCharge'].toString())),
                                DataCell(Text(row['tax'].toString())),
                                DataCell(Text(row['total'].toString())),
                                DataCell(Text(row['status'].toString())),
                                DataCell(Text(row['billNo'].toString())),
                              ]);
                            }).toList(),
                          ),
                        ),

                        // Grey Container Below the Summary Table
                        if (showSummary)
                          Container(
                            width: double.infinity,
                            height: 200,
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[200], // Light grey background
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Summary Information",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 8),
                                // Add more widgets inside as needed
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void showItemWiseReportDialog(BuildContext context) async {
  final double screenHeight = MediaQuery.of(context).size.height;
  final double topNavHeight = 30.0;
  final double searchBarHeight = 60.0;


  DateTime selectedStartDate = DateTime.now().subtract(Duration(days: 1));
  DateTime selectedEndDate = DateTime.now().subtract(Duration(days: 1));
  String selectedStatus = "All";

  List<Map<String, dynamic>> itemWiseData = [];

  Future<void> fetchData() async {
    List<Map<String, dynamic>> allData = await fetchOnlineItemWiseReport(
      DateFormat('yyyy-MM-dd').format(selectedStartDate),
      DateFormat('yyyy-MM-dd').format(selectedEndDate),
    );

    // Filter the data in the UI based on selectedStatus
    if (selectedStatus != "All") {
      itemWiseData = allData.where((row) => row['orderStatus'] == selectedStatus).toList();
    } else {
      itemWiseData = allData;
    }
  }

  await fetchData();

  Future<void> _selectDate(BuildContext context, bool isStartDate, Function setStateCallback) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? selectedStartDate : selectedEndDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      if (isStartDate) {
        selectedStartDate = picked;
      } else {
        selectedEndDate = picked;
      }
      await fetchData();
      setStateCallback(() {});
    }
  }

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding: EdgeInsets.only(
              top: topNavHeight + searchBarHeight,
              left: 0,     // NO sidebar inset here
              right: 0,
              bottom: 0,
            ),
            backgroundColor: Colors.transparent,
            child: Container(
              height: screenHeight - topNavHeight - searchBarHeight,
              width: MediaQuery.of(context).size.width,  // Full width
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    color: Colors.grey[300],
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Text(
                          "Item-Wise Sales Report",
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Start Date:", style: TextStyle(color: Colors.black, fontSize: 14)),
                            GestureDetector(
                              onTap: () async {
                                await _selectDate(context, true, setState);
                              },
                              child: Text(
                                DateFormat('yyyy-MM-dd').format(selectedStartDate),
                                style: TextStyle(color: Colors.black, fontSize: 14, decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                        Divider(color: Colors.grey),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("End Date:", style: TextStyle(color: Colors.black, fontSize: 14)),
                            GestureDetector(
                              onTap: () async {
                                await _selectDate(context, false, setState);
                              },
                              child: Text(
                                DateFormat('yyyy-MM-dd').format(selectedEndDate),
                                style: TextStyle(color: Colors.black, fontSize: 14, decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                        Divider(color: Colors.grey),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Status:", style: TextStyle(color: Colors.black, fontSize: 14)),
                            DropdownButton<String>(
                              value: selectedStatus,
                              items: ["All", "delivered", "canceled"].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value, style: TextStyle(color: Colors.black, fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                setState(() {
                                  selectedStatus = newValue!;
                                  fetchData();
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () async {
                          await exportToExcel(itemWiseData, 'Itemsales');
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
                        ),
                        child: Text(
                          'Download',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 5),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: MediaQuery.of(context).size.width - 200,
                        ),
                        child: DataTable(
                          headingRowColor: MaterialStateColor.resolveWith((states) => Colors.black),
                          headingTextStyle: const TextStyle(color: Colors.white),
                          columnSpacing: 100.0,
                          columns: const [
                            DataColumn(label: Expanded(child: Text('Item Name', textAlign: TextAlign.center))),
                            DataColumn(label: Expanded(child: Text('Total Quantity', textAlign: TextAlign.center))),
                            DataColumn(
                              label: Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Total Amount'),
                                ),
                              ),
                            ),
                          ],
                          rows: itemWiseData.map((row) {
                            return DataRow(cells: [
                              DataCell(Center(child: Text(row['itemName'] ?? 'N/A'))),
                              DataCell(Center(child: Text(row['totalQuantity'].toString() ?? '0'))),
                              DataCell(Align(
                                alignment: Alignment.centerLeft,
                                child: Text(row['totalAmount'].toString() ?? '0.00'),
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),

                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void showCanceledOrdersReportDialog(BuildContext context) async {
  final double screenHeight = MediaQuery.of(context).size.height;
  final double topNavHeight = 30.0;
  final double searchBarHeight = 60.0;

  DateTime selectedStartDate = DateTime.now().subtract(Duration(days: 1));
  DateTime selectedEndDate = DateTime.now().subtract(Duration(days: 1));

  List<Map<String, dynamic>> canceledOrdersData = [];

  Future<void> fetchData() async {
    canceledOrdersData = await fetchOnlineCanceledOrdersReport(
      DateFormat('yyyy-MM-dd').format(selectedStartDate),
      DateFormat('yyyy-MM-dd').format(selectedEndDate),
    );
  }

  await fetchData();

  Future<void> _selectDate(BuildContext context, bool isStartDate, Function setStateCallback) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? selectedStartDate : selectedEndDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      if (isStartDate) {
        selectedStartDate = picked;
      } else {
        selectedEndDate = picked;
      }
      await fetchData();
      setStateCallback(() {});
    }
  }

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding: EdgeInsets.only(
              top: topNavHeight + searchBarHeight,
              left: 0,     // NO sidebar inset here
              right: 0,
              bottom: 0,
            ),
            backgroundColor: Colors.transparent,
            child: Container(
              height: screenHeight - topNavHeight - searchBarHeight,
              width: MediaQuery.of(context).size.width,  // Full width
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    color: Colors.grey[300],
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Text(
                          "Canceled Orders Report",
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Start Date:", style: TextStyle(color: Colors.black, fontSize: 14)),
                            GestureDetector(
                              onTap: () async {
                                await _selectDate(context, true, setState);
                              },
                              child: Text(
                                DateFormat('yyyy-MM-dd').format(selectedStartDate),
                                style: TextStyle(color: Colors.black, fontSize: 14, decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                        Divider(color: Colors.grey),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("End Date:", style: TextStyle(color: Colors.black, fontSize: 14)),
                            GestureDetector(
                              onTap: () async {
                                await _selectDate(context, false, setState);
                              },
                              child: Text(
                                DateFormat('yyyy-MM-dd').format(selectedEndDate),
                                style: TextStyle(color: Colors.black, fontSize: 14, decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () async {
                          await exportToExcel(canceledOrdersData, 'CanceledOrders');
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
                        ),
                        child: Text(
                          'Download',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 5),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: MediaQuery.of(context).size.width - 200,
                        ),
                        child: DataTable(
                          headingRowColor: MaterialStateColor.resolveWith((states) => Colors.black),
                          headingTextStyle: const TextStyle(color: Colors.white),
                          columnSpacing: 120.0,
                          columns: const [
                            DataColumn(label: Expanded(child: Text('Restaurant Name', textAlign: TextAlign.center))),
                            DataColumn(label: Expanded(child: Text('Order From', textAlign: TextAlign.center))),
                            DataColumn(label: Expanded(child: Text('Total Orders', textAlign: TextAlign.center))),
                            DataColumn(
                              label: Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Total Amount'),
                                ),
                              ),
                            ),
                          ],
                          rows: canceledOrdersData.map((row) {
                            return DataRow(cells: [
                              DataCell(Center(child: Text(row['restaurantName'] ?? 'N/A'))),
                              DataCell(Center(child: Text(row['orderFrom'] ?? 'N/A'))),
                              DataCell(Center(child: Text(row['totalOrders'].toString() ?? '0'))),
                              DataCell(Align(
                                alignment: Alignment.centerLeft,
                                child: Text(row['totalAmount'].toString() ?? '0.00'),
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),

                ],
              ),
            ),
          );
        },
      );
    },
  );
}




double _getMaxY(List<Map<String, dynamic>> summaryData) {
  if (summaryData.isEmpty) return 0;

  double maxY = summaryData
      .map((e) => (e['totalAmount'] as num?)?.toDouble() ?? 0)
      .reduce((a, b) => a > b ? a : b);

  return maxY;
}
















class SelectedProduct {
  final String name;
  final String code;
  final String status;
  final String notes;
  double price;
  double pricebckp;
  bool isComp;
  int quantity;


  SelectedProduct({
    required this.name,
    required this.code,
    required this.price,
    this.quantity = 1,
    this.status = "active",
    this.notes = "",
    this.isComp = false,
    this.pricebckp = 0.0

  });


  Map<String, dynamic> toJson() {

    OnlineOrdersScreen ma = OnlineOrdersScreen();


    return {
      "orderNumber": 1,
      "tableNumber": gReceivedStrings['id'],
      "itemName": name,
      "itemCode": code,
      "quantity": quantity,
      "notes": notes,
      "status": status,
      "price": price,
    };
  }}

