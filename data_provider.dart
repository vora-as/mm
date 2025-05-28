  import 'dart:async';
  import 'dart:convert';
  import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:flutter/material.dart';
  import 'package:http/http.dart' as http;
  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:audioplayers/audioplayers.dart';
  import 'package:flutter_esc_pos_network/flutter_esc_pos_network.dart';
  import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
  import 'Delivery_partner_model.dart';
import 'FireConstants.dart';
  import 'Online_order_model.dart';
  import 'Tax_model.dart';
import 'canceled_order_model.dart';
import 'list_of_product_screen.dart';

  import 'package:intl/intl.dart';

  class BackgroundFetchService extends StateNotifier<List<String>> {
    BackgroundFetchService() : super([]) {
      // Initialization
      _startFetchingOrders();
      fetchOnlineItems();
      fetchProducts();
      fetchAddons();
      fetchApplicableTaxes();
      fetchDeliveryPartners();
      fetchDeliveryAgentStatus();
      _loadAutoAcceptPreference(); // Load the auto-accept preference
    }

    Timer? _orderRefreshTimer;
    Set<String> previousOrderIds = {};
    Set<String> previousCanceledOrders = {};
    bool isFirstLoad = true;
    bool isAutoAcceptEnabled = false; // Auto-accept setting
    final AudioPlayer _audioPlayer = AudioPlayer();
    bool isBeeping = false;
    List<Map<String, dynamic>> onlineItems = [];
    Map<int, bool> itemStatus = {};

    List<DeliveryPartner> deliveryPartners = [];
    String selectedCategory = '';
    int selectedButtonIndex = -1;
    String whattofollow = '';
    FocusNode searchFocusNode = FocusNode();
    TextEditingController _searchController = TextEditingController();

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
    // Load Auto-Accept Preference
    Future<void> _loadAutoAcceptPreference() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      isAutoAcceptEnabled = prefs.getBool('autoAccept') ?? false;
      print("Auto-Accept is ${isAutoAcceptEnabled ? 'Enabled' : 'Disabled'}");
    }

    // Save Auto-Accept Preference
    Future<void> saveAutoAcceptPreference(bool value) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('autoAccept', value);
      isAutoAcceptEnabled = value;
      print("Auto-Accept updated to: $isAutoAcceptEnabled");
    }

    // Fetch Online Orders and Handle Auto-Accept Logic
    Future<void> fetchOnlineOrders() async {
      try {
        final response = await http.get(Uri.parse('${apiUrl}onlineorder/getAll?DB=$CLIENTCODE'));
        print("API Response for Online Ordersssss: ${response.body}");

        if (response.statusCode == 200) {
          final parsed = json.decode(response.body).cast<Map<String, dynamic>>();
          List<OnlineOrder> allOrders = parsed.map<OnlineOrder>((json) => OnlineOrder.fromMap(json)).toList();
          List<OnlineOrder> newOrders = allOrders.where((order) => order.status.toLowerCase() != "delivered").toList();

          Set<String> currentOrderIds = newOrders.map((order) => order.orderId).toSet();
          Set<String> newIncomingOrders = currentOrderIds.difference(previousOrderIds);

          // Play a beep for new orders
          if (!isFirstLoad && newIncomingOrders.isNotEmpty) {
            playBeep(newIncomingOrders.first);
          }

          // Handle Auto-Accept Logic
          if (isAutoAcceptEnabled) {
            for (var order in newOrders) {
              print('Order ID: ${order.orderId}, Statuseses: ${order.status}');

              if (!previousOrderIds.contains(order.orderId) && order.status.toLowerCase() == "active") {
                previousOrderIds.add(order.orderId);
                bool autoAcceptSuccess = await _autoAcceptAndProcessOrder(order);

                if (autoAcceptSuccess) {
                  print("Order ${order.orderId} auto-accepted successfully.");
                }
              }
            }
          }

          previousOrderIds = currentOrderIds;
          isFirstLoad = false;
        } else {
          throw Exception('Failed to load Online Orders');
        }
      } catch (e) {
        print("Error fetching orders: $e");
      }
    }

    // Auto-Accept and Process Order
    Future<bool> _autoAcceptAndProcessOrder(OnlineOrder order) async {
      try {
        playBeep(order.orderId, isAutoAccepted: true);
        await Future.delayed(Duration(seconds: 10)); // Delay to simulate processing

        bool autoAcceptSuccess = await autoAcceptOrder(order.orderId);
        if (autoAcceptSuccess) {
          bool success = await acceptOrder(order);
          if (success) {
            stopBeep();

            // Call testOrder and testBILLForOnlineOrder
            String kotId = await createKOT( order.orderFrom, order.onlineOrderItemList, order);
            await testOrder(
              order.orderFrom + " : " + order.orderId,
              order.orderId,
              order.orderInstructions ?? "",
              order.orderFrom,
              order.onlineOrderItemList,
              order.externalOrderId,
              kotId,
            );

            String billNo = await createOnlineBill(order);
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
          }
          return success;
        }
        return false;
      } catch (e) {
        print("Error in auto-accepting order: $e");
        return false;
      }
    }

    // Auto-Accept Order API Call
    Future<bool> autoAcceptOrder(String orderId) async {
      try {
        final response = await http.post(
          Uri.parse('${apiUrl}onlineorder/auto-accept'),
          headers: {
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "restaurant_id": merchantId,
            "order_id": orderId,
            "merchant_id": merchantId
          }),
        );

        print("API Response Body: ${response.body}");
        return response.statusCode == 200;
      } catch (e) {
        print("Error in auto-accept API call: $e");
        return false;
      }
    }

    Future<String> createKOT(String orderFrom, List<OnlineOrderItemList> onlineOrderItems, OnlineOrder order) async {
      final String apiUrlKOT = '${apiUrl}order/create?DB=$CLIENTCODE';

      final List<Map<String, dynamic>> orderItems = onlineOrderItems.map((item) => {
        "itemName": item.itemName,
        "itemCode": item.itemId,
        "quantity": item.itemQuantity,
        "price": item.itemUnitPrice,
        "costCenterCode": "c01",
      }).toList();

      if (orderItems.isEmpty) {
        print(" ERROR: No items in order. Cannot create KOT.");
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
              print(" KotID Updated in Online Order Table");
            } else {
              print(" Failed to update KotID in Online Order Table");
            }
          }
          return kotId;
        }
      } catch (e) {
        print(" Error Creating KOT: $e");
      }

      return "";
    }


    Future<String> createOnlineBill( OnlineOrder order) async {
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
    // Accept Order API Call
    Future<bool> acceptOrder(OnlineOrder order) async {
      try {
        final String apiUrl = "https://api.werafoods.com/pos/v2/order/accept";
        final Map<String, dynamic> requestBody = {
          "merchant_id": merchantId,
          "order_id": order.orderId,
          "preparation_time": 15,
        };

        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            "Content-Type": "application/json",
            "X-Wera-Api-Key": WeraApiKey,
          },
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          print("Order Accepted Successfully: ${order.orderId}");
          await updateOrderStatus(order.orderId, "Food Ready");
          return true;
        } else {
          print("Failed to Accept Order: ${response.body}");
          return false;
        }
      } catch (e) {
        print("Error Accepting Order: $e");
        return false;
      }
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
            canceledOrders = canceledOrdersList;

          }

        } else {
          print("Failed to fetch canceled orders. Status: ${response.statusCode}");
        }
      } catch (e) {
        print("Error fetching canceled orders: $e");
      }
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

    Future<void> fetchAddons() async {
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
            latestRiderStatuses = latestStatuses; // Just assign directly
            // Optionally notify listeners here if using ChangeNotifier
          }

          print("Updated Rider Statuses: $latestRiderStatuses");
        } else {
          print("Failed to fetch delivery agent status. Status: ${response.statusCode}");
        }
      } catch (e) {
        print("Error fetching delivery agent status: $e");
      }
    }


    // Play Beep Sound
    Future<void> playBeep(String orderId, {bool isAutoAccepted = false}) async {
      if (!isBeeping) {
        isBeeping = true;
        final DateTime stopTime = DateTime.now().add(Duration(seconds: 10));

        try {
          while (isBeeping && (isAutoAccepted || DateTime.now().isBefore(stopTime))) {
            if (!isBeeping) break;

            await _audioPlayer.stop();
            await _audioPlayer.play(AssetSource('sounds/order.mp3'));

            await Future.delayed(Duration(seconds: 2));

            if (!isAutoAccepted && !previousOrderIds.contains(orderId)) {
              break;
            }
          }
        } finally {
          isBeeping = false;
        }
      }
    }

    // Stop Beep Sound
    void stopBeep() {
      if (isBeeping) {
        isBeeping = false;
        _audioPlayer.stop();
      }
    }

    // Update Order Status
    Future<void> updateOrderStatus(String orderId, String status) async {
      // Simulated API call
      await Future.delayed(Duration(seconds: 1));
      print("Updated Order Status: $orderId to $status");
    }

    // Start Fetching Orders Periodically
    void _startFetchingOrders() {
      _orderRefreshTimer = Timer.periodic(Duration(seconds: 10), (timer) {
        fetchOnlineOrders();
        fetchCanceledOrders();
        fetchDeliveryAgentStatus();
      });
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
        ) async
    {
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



    @override
    void dispose() {
      _orderRefreshTimer?.cancel();
      stopBeep();
      _audioPlayer.dispose();
      super.dispose();
    }
  }

  final backgroundFetchServiceProvider = StateNotifierProvider<BackgroundFetchService, List<String>>((ref) {
    return BackgroundFetchService();
  });