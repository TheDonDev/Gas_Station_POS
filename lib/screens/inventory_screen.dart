import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:gas_store_pos/providers/inventory_provider.dart';
import 'package:gas_store_pos/screens/edit_product_screen.dart';
import 'package:gas_store_pos/data/database_service.dart';
import 'package:intl/intl.dart';
import 'package:gas_store_pos/data/backup_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _intakeController = TextEditingController();
  double _currentBulkKg = 0.0;
  final double _maxCapacity = 10000.0; // Placeholder for Max Storage Capacity
  bool _isLoading = true;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final BackupService _backupService = BackupService();

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    _fetchBulkData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).loadProducts();
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchBulkData() async {
    final kg = await DatabaseService().getBulkGasKg();
    final double threshold = _maxCapacity * 0.15;
    final bool breached = kg < threshold && _currentBulkKg >= threshold;

    setState(() {
      _currentBulkKg = kg;
      _isLoading = false;
    });

    if (breached && mounted) {
      _audioPlayer.play(AssetSource('sounds/warning.mp3'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("CRITICAL LEVEL: Bulk Storage is below ${threshold.toStringAsFixed(0)} KG (15%)"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _processIntake() async {
    final double? intake = double.tryParse(_intakeController.text);
    if (intake == null || intake <= 0) return;

    await DatabaseService().updateBulkGas(intake);
    _intakeController.clear();
    _fetchBulkData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bulk Gas Storage Updated Successfully")),
      );
    }
  }

  void _showEditDialog() {
    final controller = TextEditingController(text: _currentBulkKg.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Adjust Bulk Inventory"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Current Amount (KG)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final double? amount = double.tryParse(controller.text);
              if (amount != null) {
                await DatabaseService().setBulkGasKg(amount);
                _fetchBulkData();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Inventory Adjusted Successfully")),
                  );
                }
              }
            },
            child: const Text("Save Changes"),
          ),
        ],
      ),
    );
  }

  void _handleBackup() {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    // Convert product models back to maps for JSON export
    // Ensure keys match database column names exactly
    final List<Map<String, dynamic>> data = provider.products.map((p) => {
      'name': p.name,
      'brand': p.brand,
      'size': p.size,
      'price_refill': p.priceRefill,
      'price_full': p.priceFull,
      'stock_full': p.stockFull,
      'stock_empty': p.stockEmpty,
    }).toList();

    _backupService.exportData(
      fileNamePrefix: 'products_export',
      data: data,
      onSuccess: (msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))),
      onError: (err) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red)),
    );
  }

  void _handleRestore() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Restore Inventory"),
        content: const Text("How would you like to restore the product list?\n\n'Clear & Restore' will delete current products first."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startImport(clearFirst: false);
            },
            child: const Text("Append"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startImport(clearFirst: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Clear & Restore"),
          ),
        ],
      ),
    );
  }

  void _startImport({required bool clearFirst}) {
    _backupService.importData(
      onSuccess: (data) async {
        final ds = DatabaseService();
        final db = await ds.database;
        
        if (clearFirst) await ds.clearTable('products');

        for (var item in data) {
          final raw = Map<String, dynamic>.from(item as Map);
          // Explicit mapping ensures we don't try to insert 'priceRefill' into 'price_refill'
          final map = {
            'name': raw['name']?.toString() ?? 'Unknown',
            'brand': raw['brand']?.toString() ?? 'N/A',
            'size': double.tryParse(raw['size']?.toString() ?? '0') ?? 0.0,
            'price_refill': double.tryParse((raw['price_refill'] ?? raw['priceRefill'] ?? '0').toString()) ?? 0.0,
            'price_full': double.tryParse((raw['price_full'] ?? raw['priceFull'] ?? '0').toString()) ?? 0.0,
            'stock_full': int.tryParse((raw['stock_full'] ?? raw['stockFull'] ?? '0').toString()) ?? 0,
            'stock_empty': int.tryParse((raw['stock_empty'] ?? raw['stockEmpty'] ?? '0').toString()) ?? 0,
          };
          await db.insert('products', map);
        }
        _refreshData();
        _showSuccessDialog("Successfully imported ${data.length} products.");
      },
      onError: (err) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      ),
    );
  }

  void _showSuccessDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Success"),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wholesale Inventory'),
        actions: [
          IconButton(icon: const Icon(Icons.upload_file), onPressed: _handleRestore, tooltip: "Import Products"),
          IconButton(icon: const Icon(Icons.backup), onPressed: _handleBackup, tooltip: "Backup Inventory"),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Main LPG Storage Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.ev_station, size: 40, color: Colors.blue),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Current Bulk Level"),
                                    Text("${NumberFormat("#,###.00").format(_currentBulkKg)} KG", 
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: _showEditDialog,
                                tooltip: "Adjust total amount",
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: (_currentBulkKg / _maxCapacity).clamp(0.0, 1.0),
                              minHeight: 15,
                              backgroundColor: Colors.blue.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _currentBulkKg < (_maxCapacity * 0.15) ? Colors.red : Colors.blue
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("${((_currentBulkKg / _maxCapacity) * 100).toStringAsFixed(1)}% Full", 
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text("Capacity: ${NumberFormat("#,###").format(_maxCapacity)} KG", 
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text("Trailer Delivery Intake", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text("Record new bulk delivery from Trailer"),
                          const SizedBox(height: 15),
                          TextField(
                            controller: _intakeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Intake Amount (KG)",
                              prefixIcon: Icon(Icons.add_shopping_cart),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _processIntake,
                              icon: const Icon(Icons.local_shipping),
                              label: const Text("Confirm Trailer Intake", style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text("Cylinder Types (Wholesale Products)", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Consumer<InventoryProvider>(
                    builder: (context, provider, child) {
                      if (provider.products.isEmpty) {
                        return const Card(
                          child: ListTile(
                            title: Text("No cylinder types added yet."),
                            subtitle: Text("Add products from the POS screen to see them here."),
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: provider.products.length,
                        itemBuilder: (context, index) {
                          final p = provider.products[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.propane_tank, color: Colors.blueGrey),
                              title: Text("${p.name} (${p.brand})"),
                              subtitle: Text("Size: ${p.size}kg | Refill: KES ${p.priceRefill}"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => EditProductScreen(product: p)),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => provider.deleteProduct(p.id!),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}