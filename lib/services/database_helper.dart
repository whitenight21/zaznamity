// ignore_for_file: depend_on_referenced_packages, avoid_print

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/label.dart';
import '../models/transaction_model.dart';
import '../models/savings_goal_model.dart';
import '../models/liability_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('financeflow_db.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    const dbName = "financeflow_db";
    final path = join(dbPath, dbName);

    return await openDatabase(
      path,
      version: 8,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE labels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT,
        amount REAL,
        type TEXT,
        label_id INTEGER,
        owner TEXT,
        is_savings INTEGER,
        pool TEXT DEFAULT 'checking',
        created_at TEXT,
        is_recurring INTEGER DEFAULT 0,
        recurring_freq TEXT,
        recurring_day INTEGER,
        recurring_end_date TEXT,
        is_confirmed INTEGER DEFAULT 1,
        currency_code TEXT DEFAULT 'EUR'
      );
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label_id INTEGER NOT NULL,
        limit_amount REAL NOT NULL,
        owner TEXT DEFAULT 'Shared',
        FOREIGN KEY (label_id) REFERENCES labels (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE liabilities(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        remaining_balance REAL,
        monthly_installment REAL,
        interest_rate REAL,
        due_day INTEGER,
        owner TEXT,
        last_processed_date TEXT,
        projection_end_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE savings_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL NOT NULL DEFAULT 0.0,
        target_date TEXT,
        owner TEXT DEFAULT 'Shared'
      );
    ''');

    await db.rawInsert("INSERT INTO labels (name, color) VALUES ('General', '#6366f1')");
    await db.rawInsert("INSERT INTO labels (name, color) VALUES ('Food', '#f97316')");
    await db.rawInsert("INSERT INTO labels (name, color) VALUES ('Utilities', '#06b6d4')");
    await db.rawInsert("INSERT INTO labels (name, color) VALUES ('Salary', '#10b981')");
    await db.rawInsert("INSERT INTO labels (name, color) VALUES ('Investments', '#3b82f6')");
    await db.rawInsert("INSERT INTO labels (name, color) VALUES ('Side Hustles', '#8b5cf6')");
    await db.rawInsert("INSERT INTO labels (name, color) VALUES ('Transfer', '#64748b')");
    await db.rawInsert("INSERT INTO labels (name, color) VALUES ('GoalsSavings', '#10b981')");
    await db.rawInsert("INSERT INTO labels (name, color) VALUES ('Goals', '#10b981')");
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budgets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          label_id INTEGER NOT NULL,
          limit_amount REAL NOT NULL,
          owner TEXT DEFAULT 'Shared',
          FOREIGN KEY (label_id) REFERENCES labels (id) ON DELETE CASCADE
        );
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS savings_goals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          target_amount REAL NOT NULL,
          current_amount REAL NOT NULL DEFAULT 0.0,
          target_date TEXT,
          owner TEXT DEFAULT 'Shared'
        );
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN currency_code TEXT DEFAULT 'EUR';
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE budgets ADD COLUMN owner TEXT DEFAULT "Shared";');
      await db.execute('ALTER TABLE savings_goals ADD COLUMN owner TEXT DEFAULT "Shared";');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS liabilities (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          remaining_balance REAL NOT NULL,
          monthly_installment REAL NOT NULL,
          interest_rate REAL NOT NULL,
          due_day INTEGER,
          owner TEXT DEFAULT 'Shared',
          last_processed_date TEXT
        );
      ''');
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE liabilities ADD COLUMN last_processed_date TEXT;');
      } catch (_) {}
    }
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE liabilities ADD COLUMN projection_end_date TEXT;');
      } catch (_) {}
    }
  }

  // Liabilities Methods
  Future<List<LiabilityModel>> getLiabilities() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('liabilities');
    return List.generate(maps.length, (i) => LiabilityModel.fromMap(maps[i]));
  }

  Future<int> insertLiability(LiabilityModel liability) async {
    final db = await database;
    final map = liability.toMap();
    
    if (map['last_processed_date'] == null) {
      map['last_processed_date'] = DateTime.now().toIso8601String();
    }
    
    map.remove('lastProcessedDate');
    map.remove('projectionEndDate');
    map['projection_end_date'] = liability.projectionEndDate;

    final labelName = '${liability.name} (L)';
    final existingLabel = await db.query('labels', where: 'name = ?', whereArgs: [labelName]);
    if (existingLabel.isEmpty) {
      await db.insert(
        'labels',
        {'name': labelName, 'color': '#8B5CF6'},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    final existingLiability = await db.query(
      'liabilities',
      where: 'name = ? AND owner = ?',
      whereArgs: [liability.name, liability.owner],
    );

    if (existingLiability.isNotEmpty) {
      int existingId = existingLiability.first['id'] as int;
      await db.update(
        'liabilities',
        map,
        where: 'id = ?',
        whereArgs: [existingId],
      );
      return existingId;
    }

    return await db.insert(
      'liabilities',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteLiability(int id, String liabilityName) async {
    final db = await database;

    await db.delete(
      'liabilities',
      where: 'id = ?',
      whereArgs: [id],
    );

    await db.delete(
      'transactions',
      where: 'description LIKE ? OR description LIKE ?',
      whereArgs: ['%Liability: $liabilityName%', '%Liability Payment: $liabilityName%'],
    );

    final labelName = '$liabilityName (L)';
    final labelResult = await db.query('labels', where: 'name = ?', whereArgs: [labelName]);
    if (labelResult.isNotEmpty) {
      int labelId = labelResult.first['id'] as int;
      await db.delete('transactions', where: 'label_id = ?', whereArgs: [labelId]);
      await db.delete('labels', where: 'id = ?', whereArgs: [labelId]);
    }

    return id;
  }

  Future<int> deleteTransactionsByLabelId(int labelId) async {
    final db = await database;
    return await db.delete(
      'transactions',
      where: 'label_id = ?',
      whereArgs: [labelId],
    );
  }

  Future<void> deleteTransactionsByLabelOrDescription(String labelOrName) async {
    final db = await database;
    
    final labelResult = await db.query(
      'labels',
      where: 'name = ?',
      whereArgs: [labelOrName],
    );

    if (labelResult.isNotEmpty) {
      final labelId = labelResult.first['id'];
      await db.delete(
        'transactions',
        where: 'label_id = ? AND is_confirmed = 0',
        whereArgs: [labelId],
      );
    }

    await db.delete(
      'transactions',
      where: '(description LIKE ? OR description LIKE ?) AND is_confirmed = 0',
      whereArgs: ['%Liability: $labelOrName%', '%Liability Payment: $labelOrName%'],
    );
  }

  Future<void> checkAndApplyAutomaticLiabilityPayments() async {
    final db = await database;
    final liabilities = await db.query('liabilities');
    final now = DateTime.now();

    for (var row in liabilities) {
      int id = row['id'] as int;
      double balance = (row['remaining_balance'] as num).toDouble();
      double installment = (row['monthly_installment'] as num).toDouble();
      double apr = (row['interest_rate'] as num).toDouble();
      int dueDay = (row['due_day'] as int?) ?? 1;
      String owner = row['owner'] as String? ?? 'Shared';
      String name = row['name'] as String? ?? 'Loan';
      
      String? projectionEndDateStr = row['projection_end_date'] as String?;
      DateTime projectionEndDate = projectionEndDateStr != null && projectionEndDateStr.isNotEmpty
          ? (DateTime.tryParse(projectionEndDateStr) ?? DateTime(now.year + 1, now.month, now.day))
          : DateTime(now.year + 1, now.month, now.day);
      
      String? lastProcessedStr = row['last_processed_date'] as String?;
      
      DateTime lastProcessed = lastProcessedStr != null 
          ? (DateTime.tryParse(lastProcessedStr) ?? DateTime(now.year, now.month - 1, dueDay))
          : DateTime(now.year, now.month - 1, dueDay);

      DateTime nextDue = DateTime(lastProcessed.year, lastProcessed.month, dueDay);
      if (!nextDue.isAfter(lastProcessed)) {
        nextDue = DateTime(nextDue.year, nextDue.month + 1, dueDay);
      }

      bool updated = false;

      while (!nextDue.isAfter(projectionEndDate)) {
        bool isPastOrPresent = !nextDue.isAfter(now);

        if (isPastOrPresent) {
          double monthlyRate = (apr / 100.0) / 12.0;
          double interestAmount = balance * monthlyRate;
          double principalReduction = installment - interestAmount;
          if (principalReduction < 0) principalReduction = 0.0;
          
          balance -= principalReduction;
          if (balance < 0) balance = 0.0;
        }

        // Strict duplicate protection checking both formats across exact timestamps
        final existingTx = await db.query(
          'transactions',
          where: '(description = ? OR description = ? OR description = ?) AND created_at = ?',
          whereArgs: ['Liability: $name', 'Liability Payment: $name', 'Liability Payment: ${name.trim()}', nextDue.toIso8601String()],
        );

        if (existingTx.isEmpty) {
          final labelName = '$name (L)';
          final labelResult = await db.query('labels', where: 'name = ?', whereArgs: [labelName]);
          int targetLabelId = 1;
          if (labelResult.isNotEmpty) {
            targetLabelId = labelResult.first['id'] as int;
          } else {
            targetLabelId = await db.insert('labels', {'name': labelName, 'color': '#8B5CF6'});
          }

          final paymentTx = TransactionModel(
            createdAt: nextDue.toIso8601String(),
            description: 'Liability: $name',
            amount: installment,
            type: 'expense',
            pool: 'checking', 
            labelId: targetLabelId, 
            owner: owner,
            isConfirmed: isPastOrPresent ? 1 : 0,
            isSavings: 0,
            currencyCode: 'EUR',
          );
          
          await insertTransaction(paymentTx);
        }

        if (isPastOrPresent) {
          lastProcessed = nextDue;
          updated = true;
        }

        nextDue = DateTime(nextDue.year, nextDue.month + 1, dueDay);
      }

      if (updated) {
        await db.update(
          'liabilities',
          {
            'remaining_balance': balance,
            'last_processed_date': lastProcessed.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  Future<void> updateExistingLiabilityTransactions(int liabilityId, String oldName, LiabilityModel newLiability) async {
    final db = await database;
    
    final existingTxs = await db.query(
      'transactions',
      where: 'description = ? AND is_confirmed = 0',
      whereArgs: ['Liability: $oldName'],
    );

    for (var txMap in existingTxs) {
      int txId = txMap['id'] as int;
      await db.update(
        'transactions',
        {
          'description': 'Liability: ${newLiability.name}',
          'amount': newLiability.monthlyInstallment,
          'owner': newLiability.owner,
        },
        where: 'id = ?',
        whereArgs: [txId],
      );
    }

    final oldLabelName = '$oldName (L)';
    final newLabelName = '${newLiability.name} (L)';

    final oldLabelResult = await db.query('labels', where: 'name = ?', whereArgs: [oldLabelName]);
    if (oldLabelResult.isNotEmpty) {
      int oldLabelId = oldLabelResult.first['id'] as int;
      
      final newLabelResult = await db.query('labels', where: 'name = ?', whereArgs: [newLabelName]);
      int newLabelId;
      if (newLabelResult.isNotEmpty) {
        newLabelId = newLabelResult.first['id'] as int;
      } else {
        newLabelId = await db.insert('labels', {'name': newLabelName, 'color': '#8B5CF6'});
      }

      await db.update(
        'transactions',
        {'label_id': newLabelId},
        where: 'label_id = ?',
        whereArgs: [oldLabelId],
      );
    }
  }

  // Labels Methods
  Future<List<LabelModel>> getLabels() async {
    final db = await instance.database;
    final result = await db.query('labels', orderBy: 'name ASC');
    return result.map((json) => LabelModel.fromMap(json)).toList();
  }

  Future<int> insertLabel(String name, String color) async {
    final db = await instance.database;
    return await db.insert('labels', {'name': name, 'color': color});
  }

  Future<int> updateLabel(int id, String name, String color) async {
    final db = await instance.database;
    return await db.update('labels', {'name': name, 'color': color}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteLabel(int id) async {
    final db = await instance.database;
    return await db.delete('labels', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> bulkUpdateTransactionsPoolByOwnerAndLabel({
    required String owner,
    required int labelId,
    required String targetPool,
  }) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      {'pool': targetPool},
      where: 'owner = ? AND label_id = ?',
      whereArgs: [owner, labelId],
    );
  }

  // Budgets Methods
  Future<List<Map<String, dynamic>>> getBudgets() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT b.id, b.label_id, b.limit_amount, b.owner, l.name as label_name, l.color as label_color
      FROM budgets b
      LEFT JOIN labels l ON b.label_id = l.id
    ''');
  }

  Future<int> insertBudget(int labelId, double limitAmount, String owner) async {
    final db = await instance.database;
    return await db.insert('budgets', {
      'label_id': labelId,
      'limit_amount': limitAmount,
      'owner': owner,
    });
  }

  Future<int> updateBudget(int id, double limitAmount) async {
    final db = await instance.database;
    return await db.update('budgets', {'limit_amount': limitAmount}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateBudgetLimit(int budgetId, double newLimit) async {
    final db = await database;
    return await db.update(
      'budgets',
      {'limit_amount': newLimit},
      where: 'id = ?',
      whereArgs: [budgetId],
    );
  }

  Future<int> deleteBudget(int id) async {
    final db = await instance.database;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // Savings Goals Methods
  Future<List<SavingsGoalModel>> getSavingsGoals() async {
    final db = await instance.database;
    final result = await db.query('savings_goals', orderBy: 'name ASC');
    return result.map((json) => SavingsGoalModel.fromMap(json)).toList();
  }

  Future<int> insertSavingsGoal(SavingsGoalModel goal) async {
    final db = await instance.database;
    return await db.insert('savings_goals', goal.toMap());
  }

  Future<int> updateSavingsGoal(SavingsGoalModel goal) async {
    final db = await instance.database;
    return await db.update('savings_goals', goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);
  }

  Future<int> updateSavingsGoalCurrentAmount(int id, double currentAmount) async {
    final db = await instance.database;
    return await db.update('savings_goals', {'current_amount': currentAmount}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteSavingsGoal(int id) async {
    final db = await instance.database;
    return await db.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> subtractFromSavingsGoalByName(String goalName, double amount) async {
    final db = await instance.database;
    final result = await db.query(
      'savings_goals',
      where: 'name = ?',
      whereArgs: [goalName],
    );

    if (result.isNotEmpty) {
      final goal = SavingsGoalModel.fromMap(result.first);
      final newAmount = (goal.currentAmount - amount).clamp(0.0, double.infinity);
      await db.update(
        'savings_goals',
        {'current_amount': newAmount},
        where: 'id = ?',
        whereArgs: [goal.id],
      );
    }
  }

  // Transactions Methods
  Future<List<TransactionModel>> getTransactions() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT t.*, l.name as label_name, l.color as label_color 
      FROM transactions t 
      LEFT JOIN labels l ON t.label_id = l.id 
      ORDER BY created_at DESC
    ''');
    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  Future<int> insertTransaction(TransactionModel txn) async {
    final db = await instance.database;
    return await db.insert('transactions', txn.toMap());
  }

  Future<int> updateTransaction(TransactionModel txn) async {
    final db = await instance.database;
    return await db.update('transactions', txn.toMap(), where: 'id = ?', whereArgs: [txn.id]);
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> confirmTransaction(int id) async {
    final db = await instance.database;
    return await db.update('transactions', {'is_confirmed': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> bulkUpdateTransactionsLabel(String oldLabelName, String newLabelName) async {
    final db = await instance.database;
    
    final oldLabelResult = await db.query(
      'labels',
      where: 'name = ?',
      whereArgs: [oldLabelName],
    );
    if (oldLabelResult.isEmpty) return 0;
    final int oldLabelId = oldLabelResult.first['id'] as int;

    final newLabelResult = await db.query(
      'labels',
      where: 'name = ?',
      whereArgs: [newLabelName],
    );
    
    int newLabelId;
    if (newLabelResult.isNotEmpty) {
      newLabelId = newLabelResult.first['id'] as int;
    } else {
      newLabelId = await db.insert('labels', {'name': newLabelName, 'color': '#4338CA'});
    }

    return await db.update(
      'transactions',
      {'label_id': newLabelId},
      where: 'label_id = ?',
      whereArgs: [oldLabelId],
    );
  }
}