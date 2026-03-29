import 'package:flutter/material.dart';
import 'package:gas_store_pos/data/database_service.dart';
import 'package:gas_store_pos/models/customer.dart';

class CustomerProvider with ChangeNotifier {
  List<Customer> _customers = [];

  List<Customer> get customers => _customers;

  Future<void> loadCustomers() async {
    final List<Map<String, dynamic>> data = await DatabaseService().getCustomers();
    _customers = data.map((item) => Customer.fromMap(item)).toList();
    notifyListeners();
  }

  Future<void> addCustomer(Customer customer) async {
    await DatabaseService().insertCustomer(customer);
    await loadCustomers();
  }

  Future<void> updateCustomer(Customer customer) async {
    await DatabaseService().updateCustomer(customer);
    await loadCustomers();
  }

  Future<void> deleteCustomer(int id) async {
    await DatabaseService().deleteCustomer(id);
    await loadCustomers();
  }
  
  // Useful for searching in the UI
  List<Customer> filterCustomers(String query) {
    return _customers.where((c) => c.name.toLowerCase().contains(query.toLowerCase()) || c.phone.contains(query)).toList();
  }
}