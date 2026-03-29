class TransactionRecord {
  final int? id;
  final double totalAmount;
  final String date;
  final String itemsJson;
  final String paymentMethod;

  TransactionRecord({
    this.id,
    required this.totalAmount,
    required this.date,
    required this.itemsJson,
    required this.paymentMethod,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'total_amount': totalAmount,
      'date': date,
      'items_json': itemsJson,
      'payment_method': paymentMethod,
    };
  }

  factory TransactionRecord.fromMap(Map<String, dynamic> map) {
    return TransactionRecord(
      id: map['id'],
      totalAmount: map['total_amount'],
      date: map['date'],
      itemsJson: map['items_json'],
      paymentMethod: map['payment_method'] ?? 'Cash',
    );
  }
}