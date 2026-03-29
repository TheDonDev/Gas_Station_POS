import 'package:flutter/material.dart';
import 'package:gas_store_pos/data/database_service.dart';
import 'package:gas_store_pos/models/product.dart';

class InventoryProvider with ChangeNotifier {
  List<Product> _products = [];

  List<Product> get products => _products;

  Future<void> loadProducts() async {
    final List<Map<String, dynamic>> data = await DatabaseService().getProducts();
    _products = data.map((item) => Product.fromMap(item)).toList();
    notifyListeners();
  }

  Future<void> addProduct(Product product) async {
    await DatabaseService().insertProduct(product);
    await loadProducts();
  }

  Future<void> updateProduct(Product product) async {
    await DatabaseService().updateProduct(product);
    await loadProducts();
  }

  Future<void> deleteProduct(int id) async {
    await DatabaseService().deleteProduct(id);
    await loadProducts();
  }
}