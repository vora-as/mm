import 'package:flutter/material.dart';
import 'package:merchant/KOTPage.dart';
import 'package:merchant/KotSummaryReport.dart';
import 'package:merchant/OnlineOrderRunningPage.dart';
import 'package:merchant/ReportPage.dart';
import 'package:merchant/RunningOrderPage.dart';
import 'package:merchant/main.dart';

class SidePanel extends StatefulWidget {
  final Widget child;
  final Map<String, String> dbToBrandMap;
  final List<KotSummaryReport>? activeOrders;

  const SidePanel({
    super.key,
    required this.child,
    required this.dbToBrandMap,
    this.activeOrders,
  });

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  bool isPanelOpen = false;

  final Map<String, bool> sectionStates = {
    "Daily Operations": false,
    "Menu": false,
    "CRM": false,
  };

  void togglePanel() {
    setState(() {
      isPanelOpen = !isPanelOpen;
    });
  }

  void toggleSection(String section) {
    setState(() {
      sectionStates[section] = !(sectionStates[section] ?? false);
    });
  }

  void logout() {
    // Remove all previous routes and go to login
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()), // SplashScreen defined in your main.dart
          (route) => false,
    );

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main Content
          GestureDetector(
            onTap: () {
              if (isPanelOpen) togglePanel();
            },
            child: Container(
              color: Colors.grey[200],
              child: widget.child,
            ),
          ),

          // Side Panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            left: isPanelOpen ? 0 : -250,
            top: 0,
            bottom: 0,
            child: Material(
              elevation: 4,
              child: Container(
                width: 250,
                color: Colors.white,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: GestureDetector(
                                  onTap: togglePanel,
                                  child: const Icon(Icons.close, size: 28, color: Colors.black),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            _buildNavItem(
                              icon: Icons.dashboard_outlined,
                              label: 'Dashboard',
                              onTap: () {
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/dashboard',
                                  arguments: {'dbToBrandMap': widget.dbToBrandMap},
                                );
                              },
                            ),
                            const Divider(),

                            _buildCollapsibleSection(
                              title: "Daily Operations",
                              items: [
                                _buildNavItem(
                                  icon: Icons.access_time,
                                  label: "Running Orders",
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RunningOrderPage(
                                          dbToBrandMap: widget.dbToBrandMap,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _buildNavItem(
                                  icon: Icons.language,
                                  label: "Online Orders",
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => OnlineOrderRunningPage(
                                          dbToBrandMap: widget.dbToBrandMap,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _buildNavItem(
                                  icon: Icons.receipt_long,
                                  label: "KOT",
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => KOTPage(
                                          dbToBrandMap: widget.dbToBrandMap,
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                _buildNavItem(
                                  icon: Icons.store,
                                  label: "Menu & Store Actions",
                                  onTap: () {
                                    Navigator.pushReplacementNamed(context, '/menu-store-actions');
                                  },
                                ),
                              ],
                            ),
                            const Divider(),

                            _buildNavItem(
                              icon: Icons.bar_chart,
                              label: "Reports",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReportPage(
                                      dbToBrandMap: widget.dbToBrandMap,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Divider(),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text(
                          "Logout",
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: logout,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Toggle menu icon (when closed)
          if (!isPanelOpen)
            Positioned(
              top: 60,
              left: 16,
              child: GestureDetector(
                onTap: togglePanel,
                child: const Icon(Icons.menu, size: 30, color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: Icon(
            sectionStates[title] ?? false
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down,
          ),
          onTap: () => toggleSection(title),
        ),
        if (sectionStates[title] ?? false) Column(children: items),
      ],
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? extraLabel,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Row(
        children: [
          Expanded(child: Text(label)), // Use Expanded for label only if needed
          if (extraLabel != null)
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                extraLabel,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}

// You must import your SplashScreen from main.dart so that logout brings user there.
// If you want to use named routes and '/login', make sure your main.dart has:
// onGenerateRoute: (settings) {
//   if (settings.name == '/login') return MaterialPageRoute(builder: (_) => ResponsiveLoginPage(users: ...));
// }