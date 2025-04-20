class Sale {
  final int? id;
  final String date;
  final double total;        // Monto total original de la venta
  final double amountDue;    // Monto restante por pagar (para ventas a crédito)
  final String? clientPhone;
  final bool isCredit;
  final bool isPaid;

  Sale({
    this.id,
    required this.date,
    required this.total,
    required this.amountDue,
    this.clientPhone,
    required this.isCredit,
    this.isPaid = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'total': total,
      'amountDue': amountDue,
      'clientPhone': clientPhone,
      'isCredit': isCredit ? 1 : 0,
      'isPaid': isPaid ? 1 : 0,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'],
      date: map['date'],
      total: (map['total'] as num).toDouble(),
      amountDue: (map['amountDue'] ?? map['total']) is num
          ? (map['amountDue'] ?? map['total']).toDouble()
          : double.tryParse(map['amountDue'].toString()) ?? 0.0,
      clientPhone: map['clientPhone'],
      isCredit: map['isCredit'] == 1,
      isPaid: map['isPaid'] == 1,
    );
  }
}
