import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gas_store_pos/providers/printer_provider.dart';
import 'package:gas_store_pos/data/backup_service.dart';
import 'package:gas_store_pos/data/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final printer = Provider.of<PrinterProvider>(context, listen: false);
    _nameController = TextEditingController(text: printer.companyName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showBackupStatus(String msg, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final printer = Provider.of<PrinterProvider>(context);
    final backup = BackupService();

    return Scaffold(
      appBar: AppBar(title: const Text("Station Settings")),
      body: ListView(
        children: [
          // Section 1: Business Profile
          _buildSectionHeader("Business Profile"),
          ListTile(
            title: const Text("Store/Station Name"),
            subtitle: const Text("Appears on printed receipts"),
            trailing: SizedBox(
              width: 200,
              child: TextField(
                controller: _nameController,
                textAlign: TextAlign.end,
                onSubmitted: (val) => printer.setCompanyName(val),
                decoration: const InputDecoration(hintText: "Enter Name"),
              ),
            ),
          ),
          const Divider(),

          // Section 2: Hardware Settings
          _buildSectionHeader("Printing & Hardware"),
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text("Select Thermal Printer"),
            subtitle: Text(printer.selectedDevice?.name ?? "No printer selected"),
            trailing: ElevatedButton(
              onPressed: printer.isScanning ? null : () => _showPrinterPicker(context),
              child: const Text("Scan"),
            ),
          ),
          const Divider(),

          // Section 3: Data Maintenance
          _buildSectionHeader("Database & Maintenance"),
          ListTile(
            leading: const Icon(Icons.backup, color: Colors.blue),
            title: const Text("Backup Database"),
            onTap: () => backup.backupDatabase(
              onSuccess: (s) => _showBackupStatus(s, false),
              onError: (e) => _showBackupStatus(e, true),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.restore, color: Colors.orange),
            title: const Text("Restore Data"),
            onTap: () => backup.restoreDatabase(
              onSuccess: (s) => _showBackupStatus(s, false),
              onError: (e) => _showBackupStatus(e, true),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.red),
            title: const Text("Factory Reset"),
            onTap: () => _confirmReset(context, backup),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
    );
  }

  void _showPrinterPicker(BuildContext context) {
    final printer = Provider.of<PrinterProvider>(context, listen: false);
    printer.startScan();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Consumer<PrinterProvider>(
        builder: (context, p, child) => ListView.builder(
          itemCount: p.devices.length,
          itemBuilder: (context, i) => ListTile(
            title: Text(p.devices[i].name ?? "Unknown"),
            onTap: () {
              p.selectDevice(p.devices[i]);
              Navigator.pop(ctx);
            },
          ),
        ),
      ),
    ).then((_) => printer.stopScan());
  }

  void _confirmReset(BuildContext context, BackupService backup) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Factory Reset?"),
        content: const Text("This will delete all sales, products, and logs. This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              backup.resetDatabase(
                onSuccess: (s) => _showBackupStatus(s, false),
                onError: (e) => _showBackupStatus(e, true),
              );
              Navigator.pop(ctx);
            },
            child: const Text("Reset Everything", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}