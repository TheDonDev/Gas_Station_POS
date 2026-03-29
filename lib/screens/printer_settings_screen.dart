import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gas_store_pos/providers/printer_provider.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  @override
  void dispose() {
    // Stop scanning when the screen is left
    Provider.of<PrinterProvider>(context, listen: false).stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer Settings')),
      body: Consumer<PrinterProvider>(
        builder: (context, printer, child) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Available Printers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ElevatedButton(
                      onPressed: printer.isScanning ? null : () => printer.startScan(),
                      child: printer.isScanning ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Scan'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: printer.devices.length,
                  itemBuilder: (context, index) {
                    final device = printer.devices[index];
                    return ListTile(
                      leading: const Icon(Icons.usb),
                      title: Text(device.name ?? 'Unknown'),
                      subtitle: Text(device.address ?? ''),
                      trailing: printer.selectedDevice?.name == device.name ? const Icon(Icons.check_circle, color: Colors.green) : null,
                      onTap: () => printer.selectDevice(device),
                    );
                  },
                ),
              ),
              if (printer.selectedDevice != null) Padding(padding: const EdgeInsets.all(16.0), child: Text('Selected: ${printer.selectedDevice!.name}', style: const TextStyle(fontWeight: FontWeight.bold)))
            ],
          );
        },
      ),
    );
  }
}