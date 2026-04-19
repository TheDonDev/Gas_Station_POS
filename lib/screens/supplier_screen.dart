import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:gas_store_pos/data/api_config.dart';
import 'package:gas_store_pos/providers/auth_provider.dart';
import 'package:gas_store_pos/providers/theme_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _refreshDeliveries();
  }

  Future<List<Map<String, dynamic>>> _fetchDeliveries() async {
    final auth = context.read<AuthProvider>();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/deliveries'),
      headers: {'Authorization': 'Bearer ${auth.token}'},
    );
    return List<Map<String, dynamic>>.from(jsonDecode(response.body));
  }

  void _refreshDeliveries() {
    setState(() {
      _deliveriesFuture = _fetchDeliveries();
    });
  }

  void _showAddSupplierDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Supplier"),
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
                  final response = await http.post(
                    Uri.parse('${ApiConfig.baseUrl}/suppliers'),
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer ${auth.token}',
                    },
                    body: jsonEncode({
                      'name': _nameController.text,
                      'phone': _phoneController.text,
                    }),
                  );
                  if (response.statusCode == 201) {
                    Navigator.pop(ctx);
                    _refreshDeliveries();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New Supplier Registered Successfully")));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: const Text("Save Supplier"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final bool isDark = themeProvider.isDarkMode;

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
          onPressed: _showAddSupplierDialog,
          backgroundColor: Colors.indigoAccent,
          icon: const Icon(Icons.add),
          label: const Text("Add Supplier"),
        ),
      ),
    );
  }
}