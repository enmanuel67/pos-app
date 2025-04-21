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
    return {
      'id': id,
      'expense_id': expenseId,
      'amount': amount,
      'date': date,
    };
  }

  factory ExpenseEntry.fromMap(Map<String, dynamic> map) {
    return ExpenseEntry(
      id: map['id'],
      expenseId: map['expense_id'],
      amount: map['amount'],
      date: map['date'],
    );
  }
}
