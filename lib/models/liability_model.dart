class LiabilityModel {
  final int? id;
  final String name;
  final double originalAmount;
  final double remainingBalance;
  final double monthlyInstallment;
  final double interestRate;
  final int dueDay;
  final String owner;
  final DateTime startDate;
  final String? lastProcessedDate;
  final String? projectionEndDate;
  final bool isBiWeekly;
  final String liabilityType;
  final String recurrenceUnit;
  final int recurrenceInterval;

  LiabilityModel({
    this.id,
    required this.name,
    required this.originalAmount,
    required this.remainingBalance,
    required this.monthlyInstallment,
    required this.interestRate,
    required this.dueDay,
    required this.owner,
    required this.startDate,
    this.lastProcessedDate,
    this.projectionEndDate,
    this.isBiWeekly = false,
    this.liabilityType = 'Long-Term Loan / Mortgage',
    this.recurrenceUnit = 'Months',
    this.recurrenceInterval = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'original_amount': originalAmount,
      'remaining_balance': remainingBalance,
      'monthly_installment': monthlyInstallment,
      'interest_rate': interestRate,
      'due_day': dueDay,
      'owner': owner,
      'start_date': startDate.toIso8601String(),
      'last_processed_date': lastProcessedDate,
      'projection_end_date': projectionEndDate,
      'is_bi_weekly': isBiWeekly ? 1 : 0,
      'liability_type': liabilityType,
      'recurrence_unit': recurrenceUnit,
      'recurrence_interval': recurrenceInterval,
    };
  }

  factory LiabilityModel.fromMap(Map<String, dynamic> map) {
    return LiabilityModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      originalAmount: (map['original_amount'] as num?)?.toDouble() ?? ((map['remaining_balance'] as num?)?.toDouble() ?? 0.0),
      remainingBalance: (map['remaining_balance'] as num?)?.toDouble() ?? 0.0,
      monthlyInstallment: (map['monthly_installment'] as num?)?.toDouble() ?? 0.0,
      interestRate: (map['interest_rate'] as num?)?.toDouble() ?? 0.0,
      dueDay: map['due_day'] as int? ?? 1,
      owner: map['owner'] as String? ?? 'Shared',
      startDate: map['start_date'] != null ? DateTime.tryParse(map['start_date']) ?? DateTime.now() : DateTime.now(),
      lastProcessedDate: map['last_processed_date'] as String?,
      projectionEndDate: map['projection_end_date'] as String?,
      isBiWeekly: (map['is_bi_weekly'] as int? ?? 0) == 1,
      liabilityType: map['liability_type'] as String? ?? 'Long-Term Loan / Mortgage',
      recurrenceUnit: map['recurrence_unit'] as String? ?? 'Months',
      recurrenceInterval: map['recurrence_interval'] as int? ?? 1,
    );
  }
}