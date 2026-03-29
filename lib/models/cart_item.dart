import 'package:gas_store_pos/models/product.dart';

class CartItem {
  final Product product;
  final bool isRefill;
  int quantity;

  CartItem({
    required this.product,
    required this.isRefill,
    this.quantity = 1,
  });

  double get total {
    final price = isRefill ? product.priceRefill : product.priceFull;
    return price * quantity;
  }
}