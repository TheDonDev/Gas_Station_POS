import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:gas_store_pos/providers/auth_provider.dart';
import 'package:gas_store_pos/providers/theme_provider.dart';
import 'package:gas_store_pos/data/database_service.dart';
import 'package:gas_store_pos/screens/inventory_screen.dart';
import 'package:gas_store_pos/screens/pos_screen.dart';
import 'package:gas_store_pos/screens/transaction_history_screen.dart';
import 'package:gas_store_pos/screens/customer_screen.dart';
import 'package:gas_store_pos/screens/settings_screen.dart';
import 'package:gas_store_pos/screens/reports_screen.dart';
import 'package:gas_store_pos/screens/login_screen.dart';
import 'package:gas_store_pos/screens/welcome_screen.dart';
import 'package:gas_store_pos/screens/change_password_screen.dart';
import 'package:gas_store_pos/screens/supplier_screen.dart';
import 'package:gas_store_pos/screens/branch_management_screen.dart';
import 'package:gas_store_pos/screens/user_management_screen.dart';
import 'package:gas_store_pos/widgets/animated_background.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Logic for the Animated Banner
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;
  
  Future<List<Map<String, dynamic>>>? _topProductsFuture;
  Future<double>? _totalRevenueFuture;
  Key _chartKey = UniqueKey();

  final List<Map<String, dynamic>> _bannerData = [
    {
      "color": Colors.blueAccent,
      "title": "Bulk LPG Tracking",
      "subtitle": "Monitor Trailer intake & Depot levels",
      "icon": Icons.ev_station,
    },
    {
      "color": Colors.orangeAccent,
      "title": "Wholesale Payments",
      "subtitle": "Direct STK Push for Retailer Refills",
      "icon": Icons.payment,
    },
    {
      "color": Colors.green,
      "title": "Retailer Management",
      "subtitle": "Manage cylinder refill queues efficiently",
      "icon": Icons.propane_tank,
    },
  ];

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
    // Auto-scroll animation logic
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_currentPage < _bannerData.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _refreshDashboard() {
    setState(() {
      _topProductsFuture = DatabaseService().getTopProducts();
      _totalRevenueFuture = DatabaseService().getTotalRevenue();
      _chartKey = UniqueKey(); // Ensures the chart widget resets visually on data refresh
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _showLogoutConfirmation(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to end your session?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('user_session'); 
              auth.logout(); 
              if (ctx.mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()), (route) => false);
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final String dateStr = DateFormat('EEEE, d MMMM').format(now);
    
    final bool isDark = themeProvider.isDarkMode;

    return AnimatedMeshBackground(
      child: Scaffold(
      backgroundColor: isDark ? Colors.black.withOpacity(0.45) : Colors.white.withOpacity(0.6),
      appBar: AppBar(
        title: const Text('City Gas POS'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: () => themeProvider.toggleTheme(), icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode)),
          const SizedBox(width: 10),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueAccent),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.store, color: Colors.white, size: 40),
                  SizedBox(height: 10),
                  Text('My Gas Store', style: TextStyle(color: Colors.white, fontSize: 20)),
                  Text('Version 1.0.0', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('Change Password'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: () => _showLogoutConfirmation(context, auth),
            ),
            if (auth.isAdmin)
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back, Manager!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(dateStr, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white70 : Colors.black87)),
              
              const SizedBox(height: 20),

              // Animated Banner Section
              SizedBox(
                height: 180,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _bannerData.length,
                  itemBuilder: (context, index) {
                    final item = _bannerData[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: item['color'],
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            bottom: -20,
                            child: Icon(item['icon'], size: 150, color: Colors.white.withOpacity(0.2)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(item['title'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(item['subtitle'], style: const TextStyle(color: Colors.white, fontSize: 16)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),
              Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 15),

              // Grid Menu
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.3,
                children: [
                  _buildMenuCard(context, "Refill Order (POS)", Icons.oil_barrel, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PosScreen())).then((_) => _refreshDashboard())),
                  _buildMenuCard(context, "Bulk Inventory", Icons.storage, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())).then((_) => _refreshDashboard())),
                  _buildMenuCard(context, "Sales Ledger", Icons.table_chart, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionHistoryScreen())).then((_) => _refreshDashboard())),
                  _buildMenuCard(context, "Retailer Directory", Icons.groups, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerScreen())).then((_) => _refreshDashboard())),
                  _buildMenuCard(context, "Manage Suppliers", Icons.local_shipping, Colors.indigo, () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SupplierScreen()),
                  )),
                  if (auth.isAdmin)
                    _buildMenuCard(context, "Manage Branches", Icons.add_business, Colors.brown, () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BranchManagementScreen()),
                    )),
                  if (auth.isAdmin)
                    _buildMenuCard(context, "User Management", Icons.person_add, Colors.blueGrey, () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UserManagementScreen()),
                    )),
                  if (auth.isAdmin)
                    _buildMenuCard(context, "Reports", Icons.bar_chart, Colors.redAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()))),
                ],
              ),

              const SizedBox(height: 30),

              // Total Revenue Summary Card
              FutureBuilder<double>(
                future: _totalRevenueFuture,
                builder: (context, snapshot) {
                  final revenue = snapshot.data ?? 0.0;
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade700, Colors.green.shade400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Total Sales Revenue", style: TextStyle(color: Colors.white70, fontSize: 16)),
                          const SizedBox(height: 5),
                          Text(
                            "KES ${NumberFormat("#,###.00").format(revenue)}",
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              // Top Selling Products Chart
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _topProductsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Top Selling Products", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        Center(child: Text("No transactions recorded yet.", style: TextStyle(color: Colors.grey[600]))),
                      ],
                    );
                  }

                  final data = List<Map<String, dynamic>>.from(snapshot.data!);
                  // Sort data descending so the top seller is always the first slice
                  data.sort((a, b) => (double.tryParse(b['qty']?.toString() ?? '0') ?? 0.0)
                      .compareTo(double.tryParse(a['qty']?.toString() ?? '0') ?? 0.0));
                      
                  // Calculate total for percentage
                  final totalQty = data.fold<double>(0.0, (sum, item) => sum + (double.tryParse(item['qty']?.toString() ?? '0') ?? 0.0));
                  final colors = [Colors.blue, Colors.orange, Colors.green, Colors.red, Colors.purple];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Top Selling Products", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 200,
                              child: PieChart( 
                                key: _chartKey, 
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                  sections: List.generate(data.length, (i) {
                                    final product = data[i];
                                    final String name = product['name']?.toString() ?? 'Unknown';
                                    final double qty = double.tryParse(product['qty']?.toString() ?? '0') ?? 0.0;
                                    final double percentage = totalQty > 0 ? (qty / totalQty * 100) : 0;
                                    final radius = i == 0 ? 60.0 : 50.0; // Emphasize the top seller
                                    
                                    return PieChartSectionData(
                                      color: colors[i % colors.length],
                                      value: qty,
                                      title: '${percentage.toStringAsFixed(0)}%',
                                      radius: radius,
                                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(data.length, (i) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Container(width: 12, height: 12, color: colors[i % colors.length]),
                                    const SizedBox(width: 8),
                                    Text(data[i]['name']?.toString() ?? 'Unknown', style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), spreadRadius: 2, blurRadius: 10)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 30),
                ),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}