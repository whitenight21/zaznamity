class SavingsGoalModel {
  final int? id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final double monthlyContribution;
  final String? dueDate;
  final String owner;

  SavingsGoalModel({
    this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.monthlyContribution = 0.0,
    this.dueDate,
    this.owner = 'Shared',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'monthly_contribution': monthlyContribution,
      'due_date': dueDate,
      'owner': owner,
    };
  }

  factory SavingsGoalModel.fromMap(Map<String, dynamic> map) {
    return SavingsGoalModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      targetAmount: (map['target_amount'] as num?)?.toDouble() ?? 0.0,
      currentAmount: (map['current_amount'] as num?)?.toDouble() ?? 0.0,
      monthlyContribution: (map['monthly_contribution'] as num?)?.toDouble() ?? 0.0,
      dueDate: map['due_date'] as String?,
      owner: map['owner'] as String? ?? 'Shared',
    );
  }

  SavingsGoalModel copyWith({
    int? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    double? monthlyContribution,
    String? dueDate,
    String? owner,
  }) {
    return SavingsGoalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      dueDate: dueDate ?? this.dueDate,
      owner: owner ?? this.owner,
    );
  }
}