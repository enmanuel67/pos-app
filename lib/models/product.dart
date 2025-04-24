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
  final String? businessType;
   final bool? isRentable;


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
    required this.businessType,
    this.isRentable,
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
    String? businessType,
    bool? isRentable,
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
      businessType: businessType?? this.businessType,
      isRentable: isRentable ?? this.isRentable,

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
      'business_type': businessType,
      'is_rentable': isRentable == true ? 1 : 0,
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
      businessType: map['business_type'],
      isRentable: map['is_rentable'] == 1,
    );
  }
}
