class ExpenseEntry {
  final int? id;
  final int expenseId;
  final double amount;
  final String date;

  ExpenseEntry({
    this.id,
    required this.expenseId,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'expense_id': expenseId, 'amount': amount, 'date': date};
  }

  factory ExpenseEntry.fromMap(Map<String, dynamic> map) {
    return ExpenseEntry(
      id: (map['id'] as num?)?.toInt(),
      expenseId: (map['expense_id'] as num?)?.toInt() ?? 0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: map['date']?.toString() ?? '',
    );
  }
}
