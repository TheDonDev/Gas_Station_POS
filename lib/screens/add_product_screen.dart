import 'package:flutter/material.dart';
import 'package:gas_store_pos/screens/edit_product_screen.dart';

class AddProductScreen extends StatelessWidget {
  const AddProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Reuses the EditProductScreen logic, passing no product implies a new addition.
    return const EditProductScreen();
  }
}