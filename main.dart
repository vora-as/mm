import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:merchant/OnlineOrderReport.dart';
import 'package:merchant/TotalSalesReport.dart';
import 'package:merchant/KotSummaryReport.dart';
import 'Dashboard.dart';

final dbNamesProvider = StateProvider<List<String>>((ref) => []);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ProviderScope( // <-- Add this
      child: MyApp(),
    ),
  );
}


class Config {
  final String apiUrl;
  final String clientCode;

  Config({required this.apiUrl, required this.clientCode});

  factory Config.fromJson(Map<String, dynamic> json) {
    return Config(
      apiUrl: json['apiUrl'],
      clientCode: json['clientCode'],
    );
  }

  static Future<Config> loadFromAsset() async {
    final jsonString = await rootBundle.loadString('assets/config.json');
    final jsonMap = json.decode(jsonString);
    return Config.fromJson(jsonMap);
  }
}

class UserData {
  final int id;
  final String dbName;
  final int usercode;
  final String username;
  final String password;

  UserData({
    required this.id,
    required this.dbName,
    required this.usercode,
    required this.username,
    required this.password,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'],
      dbName: json['dbName'],
      usercode: json['usercode'],
      username: json['username'],
      password: json['password'],
    );
  }

  static Future<List<UserData>> fetchUsers(Config config) async {
    final url =
        "${config.apiUrl}${config.clientCode}/getAll?DB=${config.clientCode}";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => UserData.fromJson(e)).toList();
    } else {
      throw Exception("Failed to fetch user data");
    }
  }
  static Future<Map<String, String>> fetchBrandNames(Config config, List<String> dbNames) async {
    final Map<String, String> dbToBrandMap = {}; // Map to store DB-Brand mapping

    for (final db in dbNames) {
      final url = "${config.apiUrl}config/getAll?DB=$db";
      print("🔗 Requesting brand name from: $url");

      try {
        final response = await http.get(Uri.parse(url));
        print("📡 Status for DB '$db': ${response.statusCode}");

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);

          String? brandName;
          if (decoded is Map<String, dynamic>) {
            brandName = decoded['brandName'];
          } else if (decoded is List && decoded.isNotEmpty && decoded[0] is Map) {
            brandName = decoded[0]['brandName'];
          }

          if (brandName != null) {
            dbToBrandMap[db] = brandName; // Map the DB to its brand name
            print("✅ DB: $db → Brand Name: $brandName");
          } else {
            print("❓ Unexpected response format for DB: $db → $decoded");
          }
        } else {
          print("❌ Failed to fetch brand name for DB: $db → ${response.reasonPhrase}");
        }
      } catch (e) {
        print("🔥 Exception while fetching DB: $db → $e");
      }
    }

    return dbToBrandMap; // Return the populated map
  }
  static Future<Map<String, TotalSalesReport>> fetchTotalSalesForDbs(
      Config config, List<String> dbNames, String startDate, String endDate
      ) async {
    final Map<String, TotalSalesReport> dbToTotalSalesMap = {};

    // 1. Fetch combined/merged result (for cards)
    if (dbNames.length > 1) {
      final dbParams = dbNames.map((db) => "DB=$db").join("&");
      final urlAll = "${config.apiUrl}report/totalsale?startDate=$startDate&endDate=$endDate&$dbParams";
      print("🔗 Requesting merged total sales from: $urlAll");
      try {
        final response = await http.get(Uri.parse(urlAll));
        print("📡 Status for merged total sales: ${response.statusCode}");
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic>) {
            dbToTotalSalesMap["ALL"] = TotalSalesReport.fromJson(decoded);
          }
        }
      } catch (e) {
        print("🔥 Exception while fetching merged total sales: $e");
      }
    }

    // 2. Fetch each DB's stats (for table)
    for (final db in dbNames) {
      final url = "${config.apiUrl}report/totalsale?startDate=$startDate&endDate=$endDate&DB=$db";
      print("🔗 Requesting total sales for $db from: $url");
      try {
        final response = await http.get(Uri.parse(url));
        print("📡 Status for total sales DB '$db': ${response.statusCode}");
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic>) {
            dbToTotalSalesMap[db] = TotalSalesReport.fromJson(decoded);
          }
        }
      } catch (e) {
        print("🔥 Exception while fetching total sales for DB: $db → $e");
      }
    }
    return dbToTotalSalesMap;
  }
  static Future<List<TimeslotSales>> fetchTimeslotSalesForDbs(
      Config config, List<String> dbNames, String startDate, String endDate) async {
    final dbParams = dbNames.map((db) => "DB=$db").join("&");
    final url = "${config.apiUrl}report/timeslotsale?startDate=$startDate&endDate=$endDate&$dbParams";
    print("🔗 Requesting timeslot sales from: $url");

    try {
      final response = await http.get(Uri.parse(url));
      print("📡 Status for timeslot sales: ${response.statusCode}");

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          return decoded.map((e) => TimeslotSales.fromJson(e)).toList();
        }
      }
    } catch (e) {
      print("❌ Exception in fetchTimeslotSalesForDbs: $e");
    }
    return [];
  }
  static Future<Map<String, List<KotSummaryReport>>> fetchKotSummaryForDbs(
      Config config, List<String> dbNames, String startDate, String endDate) async {
    final Map<String, List<KotSummaryReport>> dbToKotSummaryMap = {};

    for (final db in dbNames) {
      final url =
          "${config.apiUrl}report/kotsummary?startDate=$startDate&endDate=$endDate&DB=$db";
      print("🔗 Requesting KOT summary from: $url");

      try {
        final response = await http.get(Uri.parse(url));
        print("📡 Status for KOT summary DB '$db': ${response.statusCode}");

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            dbToKotSummaryMap[db] =
                decoded.map<KotSummaryReport>((e) => KotSummaryReport.fromJson(e)).toList();
          } else {
            print("❓ Unexpected response format for KOT summary DB: $db → $decoded");
          }
        } else {
          print("❌ Failed to fetch KOT summary for DB: $db → ${response.reasonPhrase}");
        }
      } catch (e) {
        print("🔥 Exception while fetching KOT summary for DB: $db → $e");
      }
    }

    return dbToKotSummaryMap;
  }
  static Future<Map<String, List<ItemwiseReport>>> fetchItemwiseForDbs(
      Config config,
      List<String> dbNames,
      String startDate,
      String endDate,
      ) async {
    final Map<String, List<ItemwiseReport>> dbToItemwiseMap = {};

    final dbParams = dbNames.map((db) => "DB=$db").join("&");
    final url = "${config.apiUrl}report/itemwise?startDate=$startDate&endDate=$endDate&$dbParams";
    print("🔗 Requesting itemwise report from: $url");

    try {
      final response = await http.get(Uri.parse(url));
      print("📡 Status for itemwise report: ${response.statusCode}");

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        print("Itemwise decoded: $decoded");

        // If API returns {db1: [...], db2: [...]} structure
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((db, itemsJson) {
            if (itemsJson is List) {
              dbToItemwiseMap[db] = itemsJson
                  .map<ItemwiseReport>((e) => ItemwiseReport.fromJson(e))
                  .toList();
            }
          });
        }
        // If API returns just a List (for "All" case)
        else if (decoded is List) {
          dbToItemwiseMap['ALL'] = decoded
              .map<ItemwiseReport>((e) => ItemwiseReport.fromJson(e))
              .toList();
        }
      }
    } catch (e) {
      print("🔥 Exception while fetching itemwise report: $e");
    }

    return dbToItemwiseMap;
  }
  static Future<Map<String, List<BillwiseReport>>> fetchBillwiseForDbs(
      Config config,
      List<String> dbNames,
      String startDate,
      String endDate,
      ) async {
    final Map<String, List<BillwiseReport>> dbToBillwiseMap = {};

    for (final db in dbNames) {
      final url =
          "${config.apiUrl}report/billwise?startDate=$startDate&endDate=$endDate&DB=$db";
      print("🔗 Requesting billwise report from: $url");

      try {
        final response = await http.get(Uri.parse(url));
        print("📡 Status for billwise report DB '$db': ${response.statusCode}");

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            dbToBillwiseMap[db] = decoded
                .map<BillwiseReport>((e) => BillwiseReport.fromJson(e))
                .toList();
          } else {
            print("❓ Unexpected response format for billwise report DB: $db → $decoded");
          }
        } else {
          print("❌ Failed to fetch billwise report for DB: $db → ${response.reasonPhrase}");
        }
      } catch (e) {
        print("🔥 Exception while fetching billwise report for DB: $db → $e");
      }
    }

    return dbToBillwiseMap;
  }
  static Future<Map<String, List<OnlineOrderReport>>> fetchOnlineOrdersForDbs(
      Config config,
      List<String> dbNames,
      String startDate,
      String endDate,
      ) async {
    final Map<String, List<OnlineOrderReport>> dbToOnlineOrdersMap = {};

    for (final db in dbNames) {
      final url =
          "${config.apiUrl}report/onlinesales?DB=$db&startDate=$startDate&endDate=$endDate";
      print("🔗 Requesting online orders from: $url");

      try {
        final response = await http.get(Uri.parse(url));
        print("📡 Status for online orders DB '$db': ${response.statusCode}");

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            dbToOnlineOrdersMap[db] = decoded
                .map<OnlineOrderReport>((e) => OnlineOrderReport.fromJson(e))
                .toList();
          } else {
            print(
                "❓ Unexpected response format for online orders DB: $db → $decoded");
          }
        } else {
          print(
              "❌ Failed to fetch online orders for DB: $db → ${response.reasonPhrase}");
        }
      } catch (e) {
        print("🔥 Exception while fetching online orders for DB: $db → $e");
      }
    }

    return dbToOnlineOrdersMap;
  }
  static Future<Map<String, List<TaxwiseReport>>> fetchTaxwiseForDbs(
      Config config,
      List<String> dbNames,
      String startDate,
      String endDate,
      ) async {
    final Map<String, List<TaxwiseReport>> dbToTaxwiseMap = {};

    for (final db in dbNames) {
      final url =
          "${config.apiUrl}report/taxwise?startDate=$startDate&endDate=$endDate&DB=$db";
      print("🔗 Requesting taxwise report from: $url");

      try {
        final response = await http.get(Uri.parse(url));
        print("📡 Status for taxwise report DB '$db': ${response.statusCode}");

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            dbToTaxwiseMap[db] = decoded
                .map<TaxwiseReport>((e) => TaxwiseReport.fromJson(e))
                .toList();
          } else {
            print("❓ Unexpected response format for taxwise report DB: $db → $decoded");
          }
        } else {
          print("❌ Failed to fetch taxwise report for DB: $db → ${response.reasonPhrase}");
        }
      } catch (e) {
        print("🔥 Exception while fetching taxwise report for DB: $db → $e");
      }
    }

    return dbToTaxwiseMap;
  }
  static Future<Map<String, List<SettlementwiseReport>>> fetchSettlementwiseForDbs(
      Config config,
      List<String> dbNames,
      String startDate,
      String endDate,
      ) async {
    final Map<String, List<SettlementwiseReport>> dbToSettlementwiseMap = {};

    for (final db in dbNames) {
      final url =
          "${config.apiUrl}report/settlementwise?startDate=$startDate&endDate=$endDate&DB=$db";
      print("🔗 Requesting settlementwise report from: $url");

      try {
        final response = await http.get(Uri.parse(url));
        print("📡 Status for settlementwise report DB '$db': ${response.statusCode}");

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            dbToSettlementwiseMap[db] = decoded
                .map<SettlementwiseReport>((e) => SettlementwiseReport.fromJson(e))
                .toList();
          } else {
            print("❓ Unexpected response format for settlementwise report DB: $db → $decoded");
          }
        } else {
          print("❌ Failed to fetch settlementwise report for DB: $db → ${response.reasonPhrase}");
        }
      } catch (e) {
        print("🔥 Exception while fetching settlementwise report for DB: $db → $e");
      }
    }

    return dbToSettlementwiseMap;
  }
  static Future<Map<String, List<DiscountwiseReport>>> fetchDiscountwiseForDbs(
      Config config,
      List<String> dbNames,
      String startDate,
      String endDate,
      ) async {
    final Map<String, List<DiscountwiseReport>> dbToDiscountwiseMap = {};

    for (final db in dbNames) {
      final url =
          "${config.apiUrl}report/discountwise?startDate=$startDate&endDate=$endDate&DB=$db";
      print("🔗 Requesting discountwise report from: $url");

      try {
        final response = await http.get(Uri.parse(url));
        print("📡 Status for discountwise report DB '$db': ${response.statusCode}");

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            dbToDiscountwiseMap[db] = decoded
                .map<DiscountwiseReport>((e) => DiscountwiseReport.fromJson(e))
                .toList();
          } else {
            print("❓ Unexpected response format for discountwise report DB: $db → $decoded");
          }
        } else {
          print("❌ Failed to fetch discountwise report for DB: $db → ${response.reasonPhrase}");
        }
      } catch (e) {
        print("🔥 Exception while fetching discountwise report for DB: $db → $e");
      }
    }

    return dbToDiscountwiseMap;
  }
  static Future<Map<String, List<OnlineCancelOrderReport>>> fetchOnlineCancelOrderwiseForDbs(
      Config config,
      List<String> dbNames,
      String startDate,
      String endDate,
      ) async {
    final Map<String, List<OnlineCancelOrderReport>> dbToOnlineCancelOrderwiseMap = {};

    for (final db in dbNames) {
      final url =
          "${config.apiUrl}report/onlinecanceled?startDate=$startDate&endDate=$endDate&DB=$db";
      print("🔗 Requesting online cancel orderwise report from: $url");

      try {
        final response = await http.get(Uri.parse(url));
        print("📡 Status for online cancel orderwise report DB '$db': ${response.statusCode}");

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            dbToOnlineCancelOrderwiseMap[db] = decoded
                .map<OnlineCancelOrderReport>((e) => OnlineCancelOrderReport.fromJson(e))
                .toList();
          } else {
            print("❓ Unexpected response format for online cancel orderwise report DB: $db → $decoded");
          }
        } else {
          print("❌ Failed to fetch online cancel orderwise report for DB: $db → ${response.reasonPhrase}");
        }
      } catch (e) {
        print("🔥 Exception while fetching online cancel orderwise report for DB: $db → $e");
      }
    }

    return dbToOnlineCancelOrderwiseMap;
  }
  static Future<Map<String, List<KOTAnalysisReport>>> fetchKOTAnalysisForDbs(
      Config config,
      List<String> dbNames,
      String startDate,
      String endDate,
      ) async {
    final Map<String, List<KOTAnalysisReport>> dbToKOTAnalysisMap = {};

    for (final db in dbNames) {
      final url =
          "${config.apiUrl}report/kotanalysis?startDate=$startDate&endDate=$endDate&DB=$db";
      print("🔗 Requesting KOT analysis report from: $url");

      try {
        final response = await http.get(Uri.parse(url));
        print("📡 Status for KOT analysis report DB '$db': ${response.statusCode}");

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            dbToKOTAnalysisMap[db] = decoded
                .map<KOTAnalysisReport>((e) => KOTAnalysisReport.fromJson(e))
                .toList();
          } else {
            print("❓ Unexpected response format for KOT analysis report DB: $db → $decoded");
          }
        } else {
          print("❌ Failed to fetch KOT analysis report for DB: $db → ${response.reasonPhrase}");
        }
      } catch (e) {
        print("🔥 Exception while fetching KOT analysis report for DB: $db → $e");
      }
    }

    return dbToKOTAnalysisMap;
  }
  static Future<Map<String, List<CancelBillReport>>> fetchCancelBillForDbs(
      Config config,
      List<String> dbNames,
      String startDate,
      String endDate,
      ) async {
    final Map<String, List<CancelBillReport>> dbToCancelBillMap = {};

    for (final db in dbNames) {
      final url =
          "${config.apiUrl}report/cancelbill?startDate=$startDate&endDate=$endDate&DB=$db";
      print("🔗 Requesting cancelbill report from: $url");

      try {
        final response = await http.get(Uri.parse(url));
        print("📡 Status for cancelbill report DB '$db': ${response.statusCode}");

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            dbToCancelBillMap[db] = decoded
                .map<CancelBillReport>((e) => CancelBillReport.fromJson(e))
                .toList();
          } else {
            print("❓ Unexpected response format for cancelbill report DB: $db → $decoded");
          }
        } else {
          print("❌ Failed to fetch cancelbill report for DB: $db → ${response.reasonPhrase}");
        }
      } catch (e) {
        print("🔥 Exception while fetching cancelbill report for DB: $db → $e");
      }
    }

    return dbToCancelBillMap;
  }
  static Future<Map<String, List<TimeAuditReport>>> fetchTimeAuditForDbs(
      Config config,
      List<String> dbNames,
      String startDate,
      String endDate,
      ) async {
    final Map<String, List<TimeAuditReport>> dbToTimeAuditMap = {};

    for (final db in dbNames) {
      final url =
          "${config.apiUrl}report/timeaudit?startDate=$startDate&endDate=$endDate&DB=$db";
      print("🔗 Requesting time audit report from: $url");

      try {
        final response = await http.get(Uri.parse(url));
        print("📡 Status for time audit report DB '$db': ${response.statusCode}");

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            dbToTimeAuditMap[db] = decoded
                .map<TimeAuditReport>((e) => TimeAuditReport.fromJson(e))
                .toList();
          } else {
            print("❓ Unexpected response format for time audit report DB: $db → $decoded");
          }
        } else {
          print("❌ Failed to fetch time audit report for DB: $db → ${response.reasonPhrase}");
        }
      } catch (e) {
        print("🔥 Exception while fetching time audit report for DB: $db → $e");
      }
    }

    return dbToTimeAuditMap;
  }
  static Future<Map<String, List<PaxWiseReport>>> fetchPaxWiseForDbs(
      Config config,
      List<String> dbNames,
      String startDate,
      String endDate,
      )
  async {
    final Map<String, List<PaxWiseReport>> dbToPaxWiseMap = {};

    for (final db in dbNames) {
      final url =
          "${config.apiUrl}report/paxwise?startDate=$startDate&endDate=$endDate&DB=$db";

      try {
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            dbToPaxWiseMap[db] = decoded
                .map<PaxWiseReport>((e) => PaxWiseReport.fromJson(e))
                .toList();
          }
        } else {
        }
      } catch (e) {
      }
    }

    return dbToPaxWiseMap;
  }
  static Future<Map<String, List<OnlineDayWiseOrder>>> fetchOnlineDayWiseForDbs(
      String apiUrl,
      List<String> dbNames,
      String startDate,
      String endDate,
      String merchantId,
      {String source = "All"}
      )
  async {
    final Map<String, List<OnlineDayWiseOrder>> dbToOnlineDayWiseMap = {};

    for (final db in dbNames) {
      final url =
          "$apiUrl/report/onlinedaywiselist?startDate=$startDate&endDate=$endDate&DB=$db&merchantId=$merchantId&source=$source";
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            dbToOnlineDayWiseMap[db] = decoded
                .map<OnlineDayWiseOrder>((e) => OnlineDayWiseOrder.fromJson(e))
                .toList();
          }
        }
        // Optionally handle errors or log for non-200 responses
      } catch (e) {
        // Optionally handle errors/logging
      }
    }
    return dbToOnlineDayWiseMap;
  }
  Map<String, List<KotSummaryReport>> dbToKotSummaryMap = {};
  List<KotSummaryReport> allOrders = [];
  List<KotSummaryReport> activeOrders = [];

  void fetchAllKOTOrders(Config config, List<String> dbNames, String startDate, String endDate) async {
    dbToKotSummaryMap = await UserData.fetchKotSummaryForDbs(config, dbNames, startDate, endDate);
    allOrders = dbToKotSummaryMap.values.expand((x) => x).toList();
    activeOrders = allOrders.where((o) => o.kotStatus == "active").toList();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Merchant Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD5282B)),
      ),
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/dashboard') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => Dashboard(dbToBrandMap: args['dbToBrandMap']),
          );
        }
        if (settings.name == '/login') {
          return MaterialPageRoute(
            builder: (context) => ResponsiveLoginPage(
              users: [], // You can refetch the user list here or manage it globally
            ),
          );
        }
        return null;
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserData>>(
      future:
      Config.loadFromAsset().then((config) => UserData.fetchUsers(config)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFF090000),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset("assets/images/reddpos.png", height: 120),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
              body: Center(child: Text('Error: ${snapshot.error}')));
        } else {
          return ResponsiveLoginPage(users: snapshot.data!);
        }
      },
    );
  }
}

class ResponsiveLoginPage extends StatelessWidget {
  final List<UserData> users;

  const ResponsiveLoginPage({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine layout based on screen size
    if (screenWidth < 600) {
      return LoginPageMobile(users: users);
    } else {
      return LoginPageDesktop(users: users);
    }
  }
}

// Desktop Login Page
class LoginPageDesktop extends ConsumerStatefulWidget {
  final List<UserData> users;

  const LoginPageDesktop({super.key, required this.users});

  @override
  ConsumerState<LoginPageDesktop> createState() => _LoginPageDesktopState();
}

class _LoginPageDesktopState extends ConsumerState<LoginPageDesktop> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  String? errorMessage;

  Future<void> login(BuildContext context, WidgetRef ref) async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final matchedUsers = widget.users.where((u) =>
    u.username.toLowerCase() == username.toLowerCase() &&
        u.password == password).toList();

    if (matchedUsers.isNotEmpty) {
      final dbNames =
      matchedUsers.map((user) => user.dbName).toSet().toList();
      ref.read(dbNamesProvider.notifier).state = dbNames;
      final config = await Config.loadFromAsset();
      final dbToBrandMap = await UserData.fetchBrandNames(config, dbNames);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => Dashboard(dbToBrandMap: dbToBrandMap), // Pass dbToBrandMap
        ),      );
    } else {
      setState(() {
        errorMessage = "Invalid username or password.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEDEB),
      body: Center(
        child: Row(
          children: [
            // Left Side: Image and Content
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(0.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/dposnewlogopn.png',
                      width: 200,
                      height: 150,
                    ),
                    Container(
                      width: 550, // Set the width explicitly
                      child: Image.asset(
                        'assets/images/login.png',
                        fit: BoxFit.fill,  // Ensures the image stretches to fill the space
                        height: 500, // Keep the height fixed or adjust
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right Side: Form
            Expanded(
              flex: 1,
              child: Center(
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Sign in",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Username Field with Icon
                      TextField(
                        controller: usernameController,
                        decoration: InputDecoration(
                          hintText: "Username",
                          prefixIcon: Icon(
                            Icons.person, // Icon for username field
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password Field with Icon
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: "Password",
                          prefixIcon: Icon(
                            Icons.lock, // Icon for password field
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sign In Button with Icon
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => login(context, ref),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD5282B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.login, // Icon for the sign-in button
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10), // Space between icon and text
                              const Text(
                                "Sign in",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Error message (if any)
                      if (errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

}


class LoginPageMobile extends ConsumerStatefulWidget {
  final List<UserData> users;

  const LoginPageMobile({super.key, required this.users});

  @override
  ConsumerState<LoginPageMobile> createState() => _LoginPageMobileState();
}

class _LoginPageMobileState extends ConsumerState<LoginPageMobile> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String? errorMessage;

  // In LoginPageMobile's _LoginPageMobileState
  void login(BuildContext context, WidgetRef ref) async { // Make this async
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final matchedUsers = widget.users.where((u) =>
    u.username.toLowerCase() == username.toLowerCase() &&
        u.password == password).toList();

    if (matchedUsers.isNotEmpty) {
      final dbNames = matchedUsers.map((user) => user.dbName).toSet().toList();
      ref.read(dbNamesProvider.notifier).state = dbNames;
      final config = await Config.loadFromAsset(); // Fetch config
      final dbToBrandMap = await UserData.fetchBrandNames(config, dbNames); // Get brand mapping

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => Dashboard(dbToBrandMap: dbToBrandMap), // Pass the map
        ),
      );
    } else {
      setState(() {
        errorMessage = "Invalid username or password.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEDEB),
      body: SingleChildScrollView(
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Red POS Logo
              Positioned(
                left: 10,
                top: 20,
                child: Image.asset(
                  'assets/images/dposnewlogopn.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  margin: const EdgeInsets.only(top: 140, left: 0, right: 60),
                  padding: const EdgeInsets.all(24),
                  width: 300,  // Adjust the width to make it smaller
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Image
                      SizedBox(
                        width: double.infinity,
                        height: 100,
                        child: Image.asset(
                          'assets/images/mobiletop.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        "Sign in",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Username Field
                      TextField(
                        controller: usernameController,
                        decoration: InputDecoration(
                          hintText: "Username",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: "Password",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 24),

                      // Sign in Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => login(context, ref),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD5282B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Sign in",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.red, fontWeight: FontWeight.w500)),
                      ]
                    ],
                  ),
                ),
              ),

              // Man Image (b.png)
              Positioned(
                right: -30,
                top: 240,
                child: SizedBox(
                  height: 350,
                  child: Image.asset(
                    'assets/images/b.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // Top-right Image (c.png)
              Positioned(
                right: 10,
                top: 20,
                child: Image.asset(
                  'assets/images/c.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                right: 10,
                bottom: -200,
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.1), // Adjust darkness
                    BlendMode.modulate, // Darkens image pixels
                  ),
                  child: Image.asset(
                    'assets/images/d.png',
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
