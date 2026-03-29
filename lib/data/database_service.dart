import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:gas_store_pos/models/product.dart';
import 'package:gas_store_pos/models/customer.dart';
import 'package:gas_store_pos/models/transaction_record.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for Windows/Linux
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path = join(await getDatabasesPath(), 'gas_store.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE,
            password TEXT,
            role TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            brand TEXT,
            size REAL,
            category TEXT,
            price_full REAL,
            price_refill REAL,
            stock_full INTEGER,
            stock_empty INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            phone TEXT,
            national_id TEXT,
            address TEXT,
            debt REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            total_amount REAL,
            date TEXT,
            items_json TEXT,
            payment_method TEXT
          )
        ''');
        // Initialize bulk storage and prices
        await db.insert('app_settings', {'key': 'bulk_gas_kg', 'value': 0.0});
        await db.insert('app_settings', {'key': 'price_6kg', 'value': 600.0});
        await db.insert('app_settings', {'key': 'price_13kg', 'value': 1200.0});
        await db.insert('app_settings', {'key': 'price_50kg', 'value': 4500.0});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Adding missing columns to the products table
          await db.execute('ALTER TABLE products ADD COLUMN brand TEXT');
          await db.execute('ALTER TABLE products ADD COLUMN size REAL');
        }
        if (oldVersion < 3) {
          // Migration to add national_id to customers table
          await db.execute('ALTER TABLE customers ADD COLUMN national_id TEXT');
        }
      },
    );
  }

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<bool> registerUser(String username, String password, String role) async {
    final db = await database;
    try {
      await db.insert('users', {
        'username': username,
        'password': _hashPassword(password),
        'role': role,
      });
      return true;
    } catch (e) {
      return false; // Likely username already exists
    }
  }

  Future<Map<String, dynamic>?> loginUser(String username, String password) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, _hashPassword(password)],
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<double> getBulkGasKg() async {
    final db = await database;
    final res = await db.query('app_settings', where: 'key = ?', whereArgs: ['bulk_gas_kg']);
    return res.isNotEmpty ? (res.first['value'] as double) : 0.0;
  }

  Future<void> updateBulkGas(double addedKg) async {
    final db = await database;
    await db.execute(
      'UPDATE app_settings SET value = value + ? WHERE key = "bulk_gas_kg"',
      [addedKg],
    );
  }

  Future<void> setBulkGasKg(double totalKg) async {
    final db = await database;
    await db.execute(
      'UPDATE app_settings SET value = ? WHERE key = "bulk_gas_kg"',
      [totalKg],
    );
  }

  Future<void> restoreDatabase(String backupPath) async {
    final dbPath = join(await getDatabasesPath(), 'gas_store.db');
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    await File(backupPath).copy(dbPath);
  }

  Future<void> resetDatabase() async {
    final dbPath = join(await getDatabasesPath(), 'gas_store.db');
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    await deleteDatabase(dbPath);
  }

  Future<void> clearTable(String tableName) async {
    final db = await database;
    await db.delete(tableName);
  }

  // Products CRUD
  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await database;
    return await db.query('products');
  }

  Future<void> insertProduct(Product product) async {
    final db = await database;
    await db.insert('products', product.toMap());
  }

  Future<void> updateProduct(Product product) async {
    final db = await database;
    await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // Customers CRUD
  Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await database;
    return await db.query('customers');
  }

  Future<void> insertCustomer(Customer customer) async {
    final db = await database;
    await db.insert('customers', customer.toMap());
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = await database;
    await db.update('customers', customer.toMap(), where: 'id = ?', whereArgs: [customer.id]);
  }

  Future<void> deleteCustomer(int id) async {
    final db = await database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateCustomerDebt(int id, double amount) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE customers SET debt = debt + ? WHERE id = ?',
      [amount, id],
    );
  }

  // Sales Processing
  Future<void> processSale(TransactionRecord transaction, Map<int, Map<String, int>> stockUpdates, {double bulkGasDeduction = 0.0}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('transactions', transaction.toMap());
      for (var entry in stockUpdates.entries) {
        await txn.rawUpdate(
          'UPDATE products SET stock_full = stock_full + ?, stock_empty = stock_empty + ? WHERE id = ?',
          [entry.value['full_change'], entry.value['empty_change'], entry.key],
        );
      }
      if (bulkGasDeduction != 0.0) {
        await txn.rawUpdate(
          'UPDATE app_settings SET value = value - ? WHERE key = "bulk_gas_kg"',
          [bulkGasDeduction],
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await database;
    // Fetch transactions ordered by most recent first
    return await db.query('transactions', orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getTransactionsByRange(DateTime start, DateTime end) async {
    final db = await database;
    String s = DateFormat('yyyy-MM-dd').format(start);
    String e = DateFormat('yyyy-MM-dd').format(end);
    return await db.query(
      'transactions',
      where: "date(date) BETWEEN ? AND ?",
      whereArgs: [s, e],
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getTodayTransactions() async {
    final db = await database;
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return await db.query(
      'transactions',
      where: "date(date) = ?",
      whereArgs: [today],
    );
  }

  Future<List<Map<String, dynamic>>> getDailySales() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT date(date) as sale_date, SUM(total_amount) as total 
      FROM transactions 
      GROUP BY sale_date 
      ORDER BY sale_date DESC 
      LIMIT 7
    ''');
  }

  Future<double> getTotalRevenue() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(total_amount) as total FROM transactions');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getTopProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> txs = await db.query('transactions');
    
    final Map<String, double> aggregation = {};
    for (var tx in txs) {
      try {
        final List items = jsonDecode(tx['items_json'] as String? ?? '[]');
        for (var item in items) {
          final name = item['name']?.toString() ?? 'Unknown';
          final qty = (item['qty'] as num?)?.toDouble() ?? 0.0;
          aggregation[name] = (aggregation[name] ?? 0.0) + qty;
        }
      } catch (_) {}
    }

    return aggregation.entries.map((e) => {'name': e.key, 'qty': e.value}).toList();
  }
}