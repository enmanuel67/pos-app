class SaleItem {
  final int? id;
  final int saleId;
  final int productId;
  final int quantity;
  final double subtotal;
  final double discount;

  SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.subtotal,
    this.discount = 0.0, // por defecto 0 si no hay descuento
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'quantity': quantity,
      'subtotal': subtotal,
      'discount': discount,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'],
      saleId: map['sale_id'],
      productId: map['product_id'],
      quantity: map['quantity'],
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
    );
  }
}
