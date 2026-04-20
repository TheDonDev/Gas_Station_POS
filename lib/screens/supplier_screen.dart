import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:gas_store_pos/data/api_config.dart';
import 'package:gas_store_pos/providers/auth_provider.dart';
import 'package:gas_store_pos/providers/theme_provider.dart';
import 'package:gas_store_pos/screens/welcome_screen.dart';
import 'package:gas_store_pos/widgets/animated_background.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  Future<List<Map<String, dynamic>>>? _deliveriesFuture;
  Future<List<dynamic>>? _suppliersFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<List<Map<String, dynamic>>> _fetchDeliveries() async {
    final auth = context.read<AuthProvider>();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/deliveries'),
      headers: {'Authorization': 'Bearer ${auth.token}'},
    );
    
    if (response.statusCode == 401 || response.statusCode == 403) {
      _handleUnauthorized();
      return [];
    }
    
    return List<Map<String, dynamic>>.from(jsonDecode(response.body));
  }

  Future<void> _deleteSupplier(String id) async {
    final auth = context.read<AuthProvider>();
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/suppliers/$id'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );
      
      if (response.statusCode == 401 || response.statusCode == 403) {
        _handleUnauthorized();
        return;
      }

      _refreshData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Supplier removed successfully")));
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  Future<List<dynamic>> _fetchSuppliersList() async {
    final auth = context.read<AuthProvider>();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/suppliers'),
      headers: {'Authorization': 'Bearer ${auth.token}'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  void _handleUnauthorized() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_session');
    auth.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()), (route) => false);
    }
  }

  void _refreshData() {
    setState(() {
      _deliveriesFuture = _fetchDeliveries();
      _suppliersFuture = _fetchSuppliersList();
    });
  }

  void _showSupplierDialog({Map<String, dynamic>? supplier}) {
    if (supplier != null) {
      _nameController.text = supplier['name'] ?? '';
      _phoneController.text = supplier['phone'] ?? '';
    } else {
      _nameController.clear();
      _phoneController.clear();
    }

    showDialog(
      context: context,
      builder: (ctx) => Consumer<ThemeProvider>(
        builder: (context, theme, _) => AlertDialog(
          backgroundColor: theme.isDarkMode ? Colors.blueGrey.shade900 : Colors.white,
        title: Text(supplier == null ? "Add New Supplier" : "Edit Supplier"),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Supplier Name"),
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: "Contact Phone"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                try {
                  final auth = context.read<AuthProvider>();
                  final url = supplier == null 
                    ? '${ApiConfig.baseUrl}/suppliers' 
                    : '${ApiConfig.baseUrl}/suppliers/${supplier['_id']}';
                  
                  final response = await (supplier == null 
                    ? http.post(Uri.parse(url), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${auth.token}'}, body: jsonEncode({'name': _nameController.text, 'phone': _phoneController.text}))
                    : http.put(Uri.parse(url), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${auth.token}'}, body: jsonEncode({'name': _nameController.text, 'phone': _phoneController.text})));

                  if (response.statusCode == 401 || response.statusCode == 403) {
                    _handleUnauthorized();
                    return;
                  }

                  final bool isJson = response.headers['content-type']?.contains('application/json') ?? false;

                  if (response.statusCode == 201 || response.statusCode == 200) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    _refreshData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(supplier == null ? "New Supplier Registered Successfully" : "Supplier Updated Successfully")));
                    }
                  } else if (isJson) {
                    final errorData = jsonDecode(response.body);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(errorData['error'] ?? "Failed to save supplier")),
                      );
                    }
                  } else {
                    throw Exception("Server error: ${response.statusCode}");
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: Text(supplier == null ? "Save Supplier" : "Update Changes"),
          ),
        ],
      ), // AlertDialog
    ), // Consumer builder
  ); // showDialog
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final bool isDark = themeProvider.isDarkMode;

    if (!auth.isAdmin) {
      return const Scaffold(
        body: Center(child: Text("Access Denied: Administrators Only")),
      );
    }

    return AnimatedMeshBackground(
      child: Scaffold(
        backgroundColor: isDark ? Colors.black.withOpacity(0.45) : Colors.white.withOpacity(0.6),
        appBar: AppBar(
          title: const Text("Supplier Management"),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Registered Suppliers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: FutureBuilder<List<dynamic>>(
                        future: _suppliersFuture,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          final suppliers = snapshot.data!;
                          return ListView.builder(
                            itemCount: suppliers.length,
                            itemBuilder: (ctx, i) {
                              final s = suppliers[i];
                              return ListTile(
                                title: Text(s['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text(s['phone'] ?? 'No phone', style: const TextStyle(color: Colors.white70)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(icon: const Icon(Icons.edit, color: Colors.white70), onPressed: () => _showSupplierDialog(supplier: s)),
                                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteSupplier(s['_id'])),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text("Bulk Gas Delivery History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 20),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _deliveriesFuture,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          final logs = snapshot.data!;
                          if (logs.isEmpty) return const Center(child: Text("No deliveries logged yet.", style: TextStyle(color: Colors.white70)));

                          return ListView.separated(
                            itemCount: logs.length,
                            separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                            itemBuilder: (context, index) {
                              final log = logs[index];
                              final supplier = log['supplierId'];
                              return ListTile(
                                title: Text(supplier != null ? supplier['name'] : 'Unknown Supplier', 
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  "Contact: ${supplier != null ? supplier['phone'] : 'N/A'}\n"
                                  "Delivery: ${log['amount']} KG • ${DateFormat('yMMMd').format(DateTime.parse(log['date']))}", 
                                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                trailing: Text("KES ${NumberFormat("#,###").format(log['cost'])}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showSupplierDialog(),
          backgroundColor: Colors.indigoAccent,
          icon: const Icon(Icons.add),
          label: const Text("Add Supplier"),
        ),
      ),
    );
  }
}