import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gas_store_pos/data/database_service.dart';
import 'package:gas_store_pos/models/cart_item.dart';
import 'package:gas_store_pos/models/product.dart';
import 'package:gas_store_pos/models/customer.dart'; // Import Customer model
import 'package:gas_store_pos/models/transaction_record.dart';
import 'package:intl/intl.dart';

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => _items;

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, item) {
      total += item.total;
    });
    return total;
  }

  void addToCart(Product product, {int quantity = 1}) {
    // Simplified key as the station only performs refills
    final String key = '${product.id}';

    if (_items.containsKey(key)) {
      _items.update(
        key,
        (existing) => CartItem(
          product: existing.product,
          isRefill: existing.isRefill,
          quantity: existing.quantity + quantity,
        ),
      );
    } else {
      _items.putIfAbsent(
        key,
        () => CartItem(
          product: product,
          isRefill: true,
          quantity: quantity,
        ),
      );
    }
    notifyListeners();
  }

  void removeSingleItem(String key) {
    if (!_items.containsKey(key)) return;
    if (_items[key]!.quantity > 1) {
      _items.update(
        key,
        (existing) => CartItem(
          product: existing.product,
          isRefill: existing.isRefill,
          quantity: existing.quantity - 1,
        ),
      );
    } else {
      _items.remove(key);
    }
    notifyListeners();
  }

  void updateQuantity(String key, int newQuantity) {
    if (!_items.containsKey(key)) return;
    if (newQuantity <= 0) {
      _items.remove(key);
    } else {
      _items.update(
        key,
        (existing) => CartItem(product: existing.product, isRefill: existing.isRefill, quantity: newQuantity),
      );
    }
    notifyListeners();
  }

  void removeItem(String key) {
    _items.remove(key);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  Future<void> checkout(String paymentMethod, {Customer? customer}) async {
    if (_items.isEmpty) return;

    // Prepare Stock Updates
    // Map<ProductId, Map<String, int>>
    Map<int, Map<String, int>> stockUpdates = {};
    
    // Prepare Items JSON for history
    List<Map<String, dynamic>> itemsList = [];

    // Track total gas weight to deduct from bulk storage
    double totalGasWeight = 0.0;

    _items.forEach((key, cartItem) {
      final pid = cartItem.product.id ?? 0;
      
      if (!stockUpdates.containsKey(pid)) {
        stockUpdates[pid] = {'full_change': 0, 'empty_change': 0};
      }

      // Service Logic: Customer gives Empty (+1 Empty), Takes Refilled Full (-1 Full)
      int fullReduction = -(cartItem.quantity);
      int emptyAddition = cartItem.quantity;

      // Calculate gas weight for refills (cylinder size * quantity)
      totalGasWeight += (cartItem.product.size * cartItem.quantity);

      stockUpdates[pid]!['full_change'] = (stockUpdates[pid]!['full_change'] ?? 0) + fullReduction;
      stockUpdates[pid]!['empty_change'] = (stockUpdates[pid]!['empty_change'] ?? 0) + emptyAddition;

      itemsList.add({
        'name': '${cartItem.product.name} (${cartItem.product.brand})',
        'type': 'Refill',
        'qty': cartItem.quantity,
        'price': cartItem.product.priceRefill,
        'total': cartItem.total
      });
    });

    final transaction = TransactionRecord(
      totalAmount: totalAmount,
      date: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      itemsJson: jsonEncode(itemsList),
      paymentMethod: paymentMethod,
    );

    await DatabaseService().processSale(transaction, stockUpdates, bulkGasDeduction: totalGasWeight);

    // If Credit (Debt), update the retailer's directory debt
    if (paymentMethod == 'Credit (Debt)' && customer != null && customer.id != null) {
      await DatabaseService().updateCustomerDebt(customer.id!, totalAmount);
    }

    clearCart();
  }
}