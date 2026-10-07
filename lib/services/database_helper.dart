import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/label.dart';
import '../models/transaction_model.dart';

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
      version: 2, // Upgraded version for budgets table
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
        is_confirmed INTEGER DEFAULT 1
      );
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label_id INTEGER NOT NULL,
        limit_amount REAL NOT NULL,
        FOREIGN KEY (label_id) REFERENCES labels (id) ON DELETE CASCADE
      );
    ''');

    // Insert default labels matching the web version[cite: 7]
    await db.rawInsert("INSERT INTO labels (name, color) VALUES ('General', '#6366f1')");
    await db.rawInsert("INSERT INTO labels (name, color) VALUES ('Food', '#f97316')");
    await db.rawInsert("INSERT INTO labels (name, color) VALUES ('Utilities', '#06b6d4')");
    await db.rawInsert("INSERT INTO labels (name, color) VALUES ('Salary', '#10b981')");
    await db.rawInsert("INSERT INTO labels (name, color) VALUES ('Investments', '#3b82f6')");
    await db.rawInsert("INSERT INTO labels (name, color) VALUES ('Side Hustles', '#8b5cf6')");
    await db.rawInsert("INSERT INTO labels (name, color) VALUES ('Transfer', '#64748b')");
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budgets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          label_id INTEGER NOT NULL,
          limit_amount REAL NOT NULL,
          FOREIGN KEY (label_id) REFERENCES labels (id) ON DELETE CASCADE
        );
      ''');
    }
  }

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

  Future<List<Map<String, dynamic>>> getBudgets() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT b.id, b.label_id, b.limit_amount, l.name as label_name, l.color as label_color
      FROM budgets b
      LEFT JOIN labels l ON b.label_id = l.id
    ''');
  }

  Future<int> insertBudget(int labelId, double limitAmount) async {
    final db = await instance.database;
    return await db.insert('budgets', {'label_id': labelId, 'limit_amount': limitAmount});
  }

  Future<int> updateBudget(int id, double limitAmount) async {
    final db = await instance.database;
    return await db.update('budgets', {'limit_amount': limitAmount}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteBudget(int id) async {
    final db = await instance.database;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

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

  // Bulk edit transactions by label: change all transactions labeled "x" to "y"
  Future<int> bulkUpdateTransactionsLabel(String oldLabelName, String newLabelName) async {
    final db = await instance.database;
    
    // Find old label ID
    final oldLabelResult = await db.query(
      'labels',
      where: 'name = ?',
      whereArgs: [oldLabelName],
    );
    if (oldLabelResult.isEmpty) return 0;
    final int oldLabelId = oldLabelResult.first['id'] as int;

    // Find or create new label ID
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

    // Update all matching transactions
    return await db.update(
      'transactions',
      {'label_id': newLabelId},
      where: 'label_id = ?',
      whereArgs: [oldLabelId],
    );
  }
}