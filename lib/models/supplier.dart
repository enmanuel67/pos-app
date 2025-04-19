class Supplier {
  final int? id;
  final String name;
  final String phone;
  final String description;
  final String address;
  final String email;

  Supplier({
    this.id,
    required this.name,
    required this.phone,
    required this.description,
    required this.address,
    required this.email,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'description': description,
      'address': address,
      'email': email,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      description: map['description'],
      address: map['address'],
      email: map['email'],
    );
  }
}
