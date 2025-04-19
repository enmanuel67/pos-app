class SaleItem {
  final int? id;
  final int saleId;
  final int productId;
  final int quantity;
  final double subtotal;

  SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'],
      saleId: map['sale_id'],
      productId: map['product_id'],
      quantity: map['quantity'],
      subtotal: map['subtotal'],
    );
  }
}
