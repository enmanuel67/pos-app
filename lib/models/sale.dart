class Sale {
  final int? id;
  final String date;
  final double total;
  final String? clientPhone;
  final bool isCredit;

  Sale({
    this.id,
    required this.date,
    required this.total,
    this.clientPhone,
    required this.isCredit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'total': total,
      'clientPhone': clientPhone,
      'isCredit': isCredit ? 1 : 0,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'],
      date: map['date'],
      total: map['total'],
      clientPhone: map['clientPhone'],
      isCredit: map['isCredit'] == 1,
    );
  }
}
