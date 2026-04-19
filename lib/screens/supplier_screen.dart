import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:gas_store_pos/providers/theme_provider.dart';
import 'package:gas_store_pos/widgets/animated_background.dart';
import 'package:gas_store_pos/data/database_service.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _deliveryAmountController = TextEditingController();
  final _costController = TextEditingController();
  Future<List<Map<String, dynamic>>>? _deliveriesFuture;

  @override
  void initState() {
    super.initState();
    _refreshDeliveries();
  }

  void _refreshDeliveries() {
    setState(() {
      _deliveriesFuture = DatabaseService().getSupplierDeliveries();
    });
  }

  void _showAddSupplierDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.blueGrey.shade900,
        title: const Text("Log Bulk Delivery", style: TextStyle(color: Colors.white)),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Supplier Name", labelStyle: TextStyle(color: Colors.white70)),
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _deliveryAmountController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Amount Delivered (KG)", labelStyle: TextStyle(color: Colors.white70)),
                keyboardType: TextInputType.number,
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _costController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Total Cost (KES)", labelStyle: TextStyle(color: Colors.white70)),
                keyboardType: TextInputType.number,
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                await DatabaseService().addSupplierDelivery(
                  _nameController.text, 
                  double.parse(_deliveryAmountController.text),
                  double.parse(_costController.text)
                );
                Navigator.pop(ctx);
                _refreshDeliveries();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Delivery Logged Successfully")));
              }
            },
            child: const Text("Save Delivery"),
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
                              return ListTile(
                                title: Text(log['supplier_name'] ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                                subtitle: Text("Delivery: ${log['amount']} KG • ${DateFormat('yMMMd').format(DateTime.parse(log['date']))}", style: const TextStyle(color: Colors.white70)),
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
          label: const Text("Log Delivery"),
        ),
      ),
    );
  }
}