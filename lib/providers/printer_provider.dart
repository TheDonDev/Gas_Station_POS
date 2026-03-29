import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';

class PrinterProvider extends ChangeNotifier {
  String _companyName = "Gas Store";
  List<dynamic> _devices = [];
  dynamic _selectedDevice;
  bool _isScanning = false;
  final PrinterManager _printerManager = PrinterManager.instance;
  StreamSubscription<PrinterDevice>? _subscription;

  String get companyName => _companyName;
  List<dynamic> get devices => _devices;
  dynamic get selectedDevice => _selectedDevice;
  bool get isScanning => _isScanning;

  PrinterProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _companyName = prefs.getString('company_name') ?? "Gas Store";
    notifyListeners();
  }

  Future<void> setCompanyName(String name) async {
    _companyName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('company_name', name);
    notifyListeners();
  }

  void startScan() {
    _isScanning = true;
    _devices.clear();
    notifyListeners();

    // Scan for USB printers (Typical for Windows POS)
    // Using `dynamic` for the device type to handle a potential dependency issue
    // where the base package's `PrinterInfo` is returned instead of `PrinterDevice`.
    // We use dynamic for the subscription to avoid type errors in the stream callback.
    // The package seems to emit PrinterInfo objects which cause type errors if typed strictly.
    _subscription = _printerManager.discovery(type: PrinterType.usb).listen((dynamic result) {
      // We just add the result to our list. The UI and print logic will handle the dynamic properties.
      // This bypasses the strict type check failure.
      final deviceName = result.name; 
      
      // Avoid duplicates
      if (!_devices.any((d) => d.name == deviceName)) {
        _devices.add(result);
        notifyListeners();
      }
    });
  }

  void stopScan() {
    _isScanning = false;
    _subscription?.cancel();
    notifyListeners();
  }

  void selectDevice(dynamic device) {
    _selectedDevice = device;
    notifyListeners();
  }

  Future<void> printReceipt(List<int> bytes) async {
    if (_selectedDevice == null) return;
    
    // Safely access properties dynamically
    final name = _selectedDevice.name;
    final productId = _selectedDevice.productId;
    final vendorId = _selectedDevice.vendorId;

    await _printerManager.connect(
      type: PrinterType.usb,
      model: UsbPrinterInput(name: name, productId: productId, vendorId: vendorId),
    );
    
    await _printerManager.send(type: PrinterType.usb, bytes: bytes);
    await _printerManager.disconnect(type: PrinterType.usb);
  }
}