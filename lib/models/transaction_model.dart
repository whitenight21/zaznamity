class TransactionModel {
  final int? id;
  final String description;
  final double amount;
  final String type; // 'income' or 'expense'
  final int labelId;
  final String owner; // 'Mathias' or 'Julia'
  final int isSavings;
  final String pool; // 'checking', 'cash', 'credit_card', 'savings'
  final String createdAt;
  final int isRecurring;
  final String? recurringFreq;
  final int? recurringDay;
  final String? recurringEndDate;
  final int isConfirmed;

  // Joined fields
  final String? labelName;
  final String? labelColor;

  TransactionModel({
    this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.labelId,
    required this.owner,
    required this.isSavings,
    required this.pool,
    required this.createdAt,
    this.isRecurring = 0,
    this.recurringFreq,
    this.recurringDay,
    this.recurringEndDate,
    this.isConfirmed = 1,
    this.labelName,
    this.labelColor,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      description: map['description'] ?? '',
      amount: map['amount']?.toDouble() ?? 0.0,
      type: map['type'] ?? 'expense',
      labelId: map['label_id'] ?? 1,
      owner: map['owner'] ?? 'Mathias',
      isSavings: map['is_savings'] ?? 0,
      pool: map['pool'] ?? 'checking',
      createdAt: map['created_at'] ?? '',
      isRecurring: map['is_recurring'] ?? 0,
      recurringFreq: map['recurring_freq'],
      recurringDay: map['recurring_day'],
      recurringEndDate: map['recurring_end_date'],
      isConfirmed: map['is_confirmed'] ?? 1,
      labelName: map['label_name'],
      labelColor: map['label_color'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'type': type,
      'label_id': labelId,
      'owner': owner,
      'is_savings': isSavings,
      'pool': pool,
      'created_at': createdAt,
      'is_recurring': isRecurring,
      'recurring_freq': recurringFreq,
      'recurring_day': recurringDay,
      'recurring_end_date': recurringEndDate,
      'is_confirmed': isConfirmed,
    };
  }
}