class Product {
  final int? id;
  final String name;
  final String brand;
  final double size;
  final double priceRefill;
  final double priceFull;
  final int stockFull;
  final int stockEmpty;

  Product({
    this.id,
    required this.name,
    required this.brand,
    required this.size,
    required this.priceRefill,
    required this.priceFull,
    required this.stockFull,
    required this.stockEmpty,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'size': size,
      'price_refill': priceRefill,
      'price_full': priceFull,
      'stock_full': stockFull,
      'stock_empty': stockEmpty,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name']?.toString() ?? 'Unknown',
      brand: map['brand']?.toString() ?? 'N/A',
      size: (map['size'] is num) ? (map['size'] as num).toDouble() : (double.tryParse(map['size']?.toString() ?? '0') ?? 0.0),
      priceRefill: (map['price_refill'] is num) ? (map['price_refill'] as num).toDouble() : (double.tryParse(map['price_refill']?.toString() ?? '0') ?? 0.0),
      priceFull: (map['price_full'] is num) ? (map['price_full'] as num).toDouble() : (double.tryParse(map['price_full']?.toString() ?? '0') ?? 0.0),
      stockFull: (map['stock_full'] is num) ? (map['stock_full'] as num).toInt() : (int.tryParse(map['stock_full']?.toString() ?? '0') ?? 0),
      stockEmpty: (map['stock_empty'] is num) ? (map['stock_empty'] as num).toInt() : (int.tryParse(map['stock_empty']?.toString() ?? '0') ?? 0),
    );
  }
}