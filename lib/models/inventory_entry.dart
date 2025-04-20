class InventoryEntry {
  final int? id;
  final int productId;
  final int supplierId;
  final int quantity;
  final double cost;
  final String date;

  InventoryEntry({
    this.id,
    required this.productId,
    required this.supplierId,
    required this.quantity,
    required this.cost,
    required this.date,
  });

  factory InventoryEntry.fromMap(Map<String, dynamic> map) {
    return InventoryEntry(
      id: map['id'],
      productId: map['product_id'],
      supplierId: map['supplier_id'],
      quantity: map['quantity'],
      cost: map['cost'].toDouble(),
      date: map['date'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'supplier_id': supplierId,
      'quantity': quantity,
      'cost': cost,
      'date': date,
    };
  }
}
