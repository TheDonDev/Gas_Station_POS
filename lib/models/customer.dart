class Customer {
  final int? id;
  final String name;
  final String phone;
  final String? nationalId; // Added nationalId field
  final String? address; // Assuming address might be useful later
  final double debt;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.nationalId,
    this.address,
    this.debt = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'national_id': nationalId,
      'address': address,
      'debt': debt,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      nationalId: map['national_id'],
      address: map['address'],
      debt: map['debt'] ?? 0.0,
    );
  }
}