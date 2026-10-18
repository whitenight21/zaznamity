// ignore_for_file: unnecessary_this

class LiabilityModel {
  final int? id;
  final String name;
  final double remainingBalance;
  final double monthlyInstallment;
  final double interestRate;
  final int dueDay;
  final String owner;
  final String? lastProcessedDate;

  LiabilityModel({
    this.id,
    required this.name,
    required this.remainingBalance,
    required this.monthlyInstallment,
    required this.interestRate,
    required this.dueDay,
    required this.owner,
    this.lastProcessedDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'remaining_balance': remainingBalance,
      'monthly_installment': monthlyInstallment,
      'interest_rate': interestRate,
      'due_day': dueDay,
      'owner': owner,
      'last_processed_date': lastProcessedDate,
    };
  }

  factory LiabilityModel.fromMap(Map<String, dynamic> map) {
    return LiabilityModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      remainingBalance: (map['remaining_balance'] as num?)?.toDouble() ?? 0.0,
      monthlyInstallment: (map['monthly_installment'] as num?)?.toDouble() ?? 0.0,
      interestRate: (map['interest_rate'] as num?)?.toDouble() ?? 0.0,
      dueDay: (map['due_day'] as int?) ?? 1,
      owner: map['owner'] as String? ?? 'Shared',
      lastProcessedDate: map['last_processed_date'] as String?,
    );
  }
}