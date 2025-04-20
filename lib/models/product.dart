class Product {
  final int? id;
  final String name;
  final String barcode;
  final String description;
  final double price;
  final int quantity;
  final double cost;
  final int supplierId;
  final String createdAt; // 🆕 nuevo campo

  Product({
    this.id,
    required this.name,
    required this.barcode,
    required this.description,
    required this.price,
    required this.quantity,
    required this.cost,
    required this.supplierId,
    required this.createdAt, // 🆕 requerido
  });

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    String? description,
    double? price,
    int? quantity,
    double? cost,
    int? supplierId,
    String? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      description: description ?? this.description,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      cost: cost ?? this.cost,
      supplierId: supplierId ?? this.supplierId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'description': description,
      'price': price,
      'quantity': quantity,
      'cost': cost,
      'supplierId': supplierId,
      'createdAt': createdAt, // 🆕 exportar
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
      cost: map['cost'],
      supplierId: map['supplierId'],
      createdAt: map['createdAt'], // 🆕 importar
    );
  }
}
