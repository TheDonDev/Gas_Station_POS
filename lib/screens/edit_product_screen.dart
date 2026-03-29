import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gas_store_pos/models/product.dart';
import 'package:gas_store_pos/providers/inventory_provider.dart';

class EditProductScreen extends StatefulWidget {
  final Product? product;
  const EditProductScreen({super.key, this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _sizeController;
  late TextEditingController _priceRefillController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _brandController = TextEditingController(text: widget.product?.brand ?? '');
    _sizeController = TextEditingController(text: widget.product?.size.toString() ?? '');
    _priceRefillController = TextEditingController(text: widget.product?.priceRefill.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _sizeController.dispose();
    _priceRefillController.dispose();
    super.dispose();
  }

  void _saveProduct() {
    if (_formKey.currentState!.validate()) {
      final updatedProduct = Product(
        id: widget.product?.id, // Null if new, existing ID if editing
        name: _nameController.text,
        brand: _brandController.text,
        size: double.tryParse(_sizeController.text) ?? 0.0,
        priceRefill: double.tryParse(_priceRefillController.text) ?? 0.0,
        priceFull: 0.0, // Not applicable for refill-only station
        stockFull: 0, 
        stockEmpty: 0,
      );

      final provider = Provider.of<InventoryProvider>(context, listen: false);
      if (widget.product == null) {
        provider.addProduct(updatedProduct);
      } else {
        provider.updateProduct(updatedProduct);
      }
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.product == null ? 'Product Added' : 'Product Updated')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.product == null ? 'Add Product' : 'Edit Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(labelText: 'Brand', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Please enter a brand' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _sizeController,
                decoration: const InputDecoration(labelText: 'Size (kg)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) => value!.isEmpty ? 'Please enter size' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceRefillController,
                      decoration: const InputDecoration(labelText: 'Refill Price (KES)', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveProduct,
                  icon: Icon(widget.product == null ? Icons.save : Icons.update),
                  label: Text(widget.product == null ? 'Save Product' : 'Update Product'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}