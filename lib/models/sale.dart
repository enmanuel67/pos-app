class Sale {
  final int? id;
  final String date;
  final double total;        // Monto total original de la venta
  final double amountDue;    // Monto restante por pagar (para ventas a crédito)
  final String? clientPhone;
  final bool isCredit;
  final bool isPaid;

  // ✅ NUEVO: Auditoría / anulación
  final bool isVoided;
  final String? voidedAt;

  // ⚠️ Campo temporal para reportes (NO se guarda en la BD)
  double? discount;

  Sale({
    this.id,
    required this.date,
    required this.total,
    required this.amountDue,
    this.clientPhone,
    required this.isCredit,
    this.isPaid = false,

    this.isVoided = false,
    this.voidedAt,

    this.discount,
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

      // ✅ si existe en BD, lo guardamos (no afecta si aún no está)
      'isVoided': isVoided ? 1 : 0,
      'voidedAt': voidedAt,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    final totalVal =
        (map['total'] is num) ? (map['total'] as num).toDouble() : 0.0;

    final amountDueRaw = map['amountDue'];

    final amountDueVal =
        (amountDueRaw == null)
            ? totalVal
            : (amountDueRaw is num)
                ? amountDueRaw.toDouble()
                : double.tryParse(amountDueRaw.toString()) ?? totalVal;

    return Sale(
      id: map['id'] as int?,
      date: map['date']?.toString() ?? "",
      total: totalVal,
      amountDue: amountDueVal,
      clientPhone: map['clientPhone']?.toString(),
      isCredit: (map['isCredit'] as int? ?? 0) == 1,
      isPaid: (map['isPaid'] as int? ?? 0) == 1,

      // ✅ NUEVO: si no existe en la DB vieja, cae en default false/null
      isVoided: (map['isVoided'] as int? ?? 0) == 1,
      voidedAt: map['voidedAt']?.toString(),
    );
  }
}
