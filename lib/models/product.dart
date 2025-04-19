class Product {
  final int? id;
  final String name;
  final String? barcode;
  final String? description;
  final double price;
  final int quantity;
  final int? supplierId;

  Product({
    this.id,
    required this.name,
    this.barcode,
    this.description,
    required this.price,
    required this.quantity,
    this.supplierId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'description': description,
      'price': price,
      'quantity': quantity,
      'supplierId': supplierId,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      barcode: map['barcode'],
      description: map['description'],
      price: map['price'],
      quantity: map['quantity'],
      supplierId: map['supplierId'],
    );
  }
}
