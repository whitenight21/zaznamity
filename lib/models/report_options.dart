import '../models/transaction_model.dart';

class ReportOptions {
  final DateTime startDate;
  final DateTime endDate;
  final String ownerFilter;
  final String poolFilter;
  final String labelFilter;
  final String currencyFilter;
  final bool maskAmounts;
  final String templatePreset;
  final bool includePreviousPeriodComparison;
  
  // Section & Card Toggles
  final bool includeSummaryCard;
  final bool includeSavingsGoalsCard;
  final bool includeBudgetCard;
  final bool includeLiabilitiesCard;
  final bool includePoolBalancesCard;
  final bool includeCategoryBreakdownTable;
  final bool includeTransactionTableHistory;

  // Chart Toggles
  final bool includeBarChart;
  final bool includePieChart;
  final bool includeBalanceTrendChart;
  final bool includeCashFlowTrendChart;
  final bool includeSankeyFlowChart;
  final bool includeMoneyBreakdownChart;

  ReportOptions({
    required this.startDate,
    required this.endDate,
    required this.ownerFilter,
    required this.poolFilter,
    required this.labelFilter,
    required this.currencyFilter,
    required this.maskAmounts,
    required this.templatePreset,
    required this.includePreviousPeriodComparison,
    required this.includeSummaryCard,
    required this.includeSavingsGoalsCard,
    required this.includeBudgetCard,
    required this.includeLiabilitiesCard,
    required this.includePoolBalancesCard,
    required this.includeCategoryBreakdownTable,
    required this.includeBarChart,
    this.includePieChart = false,
    this.includeBalanceTrendChart = false,
    this.includeCashFlowTrendChart = false,
    this.includeSankeyFlowChart = false,
    this.includeMoneyBreakdownChart = false,
    required this.includeTransactionTableHistory,
  });
}

/// One bar group of the cash flow chart (a week for short ranges, else a month).
class CashflowBucket {
  final String label;
  final String? sublabel;
  final double income;
  final double expense;

  const CashflowBucket({
    required this.label,
    this.sublabel,
    required this.income,
    required this.expense,
  });

  double get net => income - expense;
}

class ReportData {
  final List<TransactionModel> filteredTransactions;
  final double totalIncome;
  final double totalExpense;
  final double netBalance;
  final double prevTotalIncome;
  final double prevTotalExpense;
  final double initialBalance;
  final double endBalance;
  final String currencySymbol;
  final List savingsGoals;
  final List budgets;
  final List liabilities;
  final Map<String, double> poolBalances;
  final Map<String, double> categoryBreakdown;

  // Chart data
  final List<double> balanceSeries; // end-of-day balance, one value per day in range
  final List<CashflowBucket> cashflowBuckets;
  final Map<String, double> incomeBreakdown;

  ReportData({
    required this.filteredTransactions,
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.prevTotalIncome,
    required this.prevTotalExpense,
    required this.initialBalance,
    required this.endBalance,
    required this.currencySymbol,
    required this.savingsGoals,
    required this.budgets,
    required this.liabilities,
    required this.poolBalances,
    required this.categoryBreakdown,
    this.balanceSeries = const [],
    this.cashflowBuckets = const [],
    this.incomeBreakdown = const {},
  });
}