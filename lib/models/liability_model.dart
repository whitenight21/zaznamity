class LiabilityModel {
  final int? id;
  final String name;
  final double remainingBalance;
  final double monthlyInstallment;
  final double interestRate;
  final int dueDay;
  final String owner;

  LiabilityModel({
    this.id,
    required this.name,
    required this.remainingBalance,
    required this.monthlyInstallment,
    required this.interestRate,
    required this.dueDay,
    this.owner = 'Shared',
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
    };
  }

  factory LiabilityModel.fromMap(Map<String, dynamic> map) {
    return LiabilityModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      remainingBalance: map['remaining_balance'] as double,
      monthlyInstallment: map['monthly_installment'] as double,
      interestRate: map['interest_rate'] as double,
      dueDay: map['due_day'] as int,
      owner: map['owner'] as String? ?? 'Shared',
    );
  }
}