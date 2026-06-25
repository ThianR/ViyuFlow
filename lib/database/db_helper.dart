import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/subcategory.dart';
import '../models/transaction.dart';
import '../models/scheduled_transaction.dart';
import '../models/budget.dart';

/// Clase controladora de la base de datos SQLite para la aplicación.
class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  factory DBHelper() => _instance;

  DBHelper._internal();

  /// Obtiene la instancia activa de la base de datos o la inicializa si es necesario.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  /// Inicializa la base de datos en la ruta del sistema.
  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'viyuflow_finance.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  /// Habilita las claves foráneas en SQLite.
  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Actualización de esquema de la base de datos sin perder datos.
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Agregar columna is_default a cuentas y establecer la cuenta id=1 como por defecto
      await db.execute('ALTER TABLE accounts ADD COLUMN is_default INTEGER NOT NULL DEFAULT 0');
      await db.execute('UPDATE accounts SET is_default = 1 WHERE id = 1');
    }
    if (oldVersion < 3) {
      // Crear tabla de transacciones programadas
      await db.execute('''
        CREATE TABLE scheduled_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          account_id INTEGER NOT NULL,
          category_id INTEGER NOT NULL,
          subcategory_id INTEGER,
          amount REAL NOT NULL,
          description TEXT NOT NULL,
          frequency TEXT NOT NULL,
          next_date TEXT NOT NULL,
          current_installment INTEGER NOT NULL DEFAULT 1,
          total_installments INTEGER,
          auto_apply INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
          FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
          FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
          FOREIGN KEY (subcategory_id) REFERENCES subcategories (id) ON DELETE SET NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE budgets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount REAL NOT NULL,
          currency TEXT NOT NULL,
          account_id INTEGER,
          category_id INTEGER,
          subcategory_id INTEGER,
          period TEXT NOT NULL DEFAULT 'monthly',
          is_active INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
          FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
          FOREIGN KEY (subcategory_id) REFERENCES subcategories (id) ON DELETE SET NULL
        )
      ''');
    }
  }

  /// Crea las tablas e inserta los datos predeterminados al crear la base de datos.
  Future _onCreate(Database db, int version) async {
    // 1. Crear Tabla de Cuentas
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        currency TEXT NOT NULL,
        color TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 2. Crear Tabla de Categorías
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense'))
      )
    ''');

    // 3. Crear Tabla de Subcategorías
    await db.execute('''
      CREATE TABLE subcategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // 4. Crear Tabla de Transacciones
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        subcategory_id INTEGER,
        amount REAL NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        sync_status INTEGER NOT NULL DEFAULT 0,
        sync_date TEXT,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
        FOREIGN KEY (subcategory_id) REFERENCES subcategories (id) ON DELETE SET NULL
      )
    ''');

    // 5. Crear Tabla de Transacciones Programadas (Agenda)
    await db.execute('''
      CREATE TABLE scheduled_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        subcategory_id INTEGER,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        frequency TEXT NOT NULL,
        next_date TEXT NOT NULL,
        current_installment INTEGER NOT NULL DEFAULT 1,
        total_installments INTEGER,
        auto_apply INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
        FOREIGN KEY (subcategory_id) REFERENCES subcategories (id) ON DELETE SET NULL
      )
    ''');

    // 6. Crear Tabla de Presupuestos
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        account_id INTEGER,
        category_id INTEGER,
        subcategory_id INTEGER,
        period TEXT NOT NULL DEFAULT 'monthly',
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
        FOREIGN KEY (subcategory_id) REFERENCES subcategories (id) ON DELETE SET NULL
      )
    ''');

    // Insertar datos por defecto (Cuentas, Categorías y Subcategorías comunes en español)
    await _insertDefaultData(db);
  }

  /// Inserta cuentas y categorías iniciales en español con sus respectivas subcategorías.
  Future _insertDefaultData(Database db) async {
    // Cuentas predeterminadas
    final List<Map<String, dynamic>> defaultAccounts = [
      {'name': 'Efectivo Personal', 'currency': '₲', 'color': '0xFF38EF7D', 'is_active': 1, 'is_default': 1},
      {'name': 'Cuenta Banco Itaú', 'currency': '₲', 'color': '0xFF0052D4', 'is_active': 1, 'is_default': 0},
      {'name': 'Efectivo Dólares', 'currency': '\$', 'color': '0xFFFFA502', 'is_active': 1, 'is_default': 0},
    ];

    for (var acc in defaultAccounts) {
      await db.insert('accounts', acc);
    }

    // Categorías y Subcategorías predeterminadas
    final List<Map<String, dynamic>> defaultCategories = [
      // Egresos (Gastos)
      {
        'id': 1,
        'name': 'Hogar',
        'icon': 'home',
        'color': '0xFFFF5252',
        'type': 'expense',
        'subcategories': ['Energía Eléctrica', 'Agua Corriente', 'Internet', 'Alquiler', 'Limpieza y Mantenimiento']
      },
      {
        'id': 2,
        'name': 'Alimentación',
        'icon': 'restaurant',
        'color': '0xFFFF9800',
        'type': 'expense',
        'subcategories': ['Supermercado', 'Restaurantes', 'Delivery', 'Cafetería', 'Meriendas']
      },
      {
        'id': 3,
        'name': 'Transporte',
        'icon': 'directions_car',
        'color': '0xFF29B6F6',
        'type': 'expense',
        'subcategories': ['Combustible', 'Pasajes de bus', 'Uber/Bolt', 'Mantenimiento Vehicular', 'Peaje']
      },
      {
        'id': 4,
        'name': 'Salud y Bienestar',
        'icon': 'medical_services',
        'color': '0xFFE040FB',
        'type': 'expense',
        'subcategories': ['Farmacia y Medicamentos', 'Consulta Médica', 'Odontología', 'Gimnasio', 'Seguro Médico']
      },
      {
        'id': 5,
        'name': 'Ocio y Entretenimiento',
        'icon': 'sports_esports',
        'color': '0xFF4CAF50',
        'type': 'expense',
        'subcategories': ['Cine y Streaming', 'Salidas y Fiestas', 'Suscripciones', 'Viajes', 'Hobbies']
      },
      {
        'id': 6,
        'name': 'Educación',
        'icon': 'school',
        'color': '0xFF673AB7',
        'type': 'expense',
        'subcategories': ['Cuota Universidad/Colegio', 'Libros y Materiales', 'Cursos Online', 'Idiomas']
      },
      // Ingresos
      {
        'id': 7,
        'name': 'Ingresos',
        'icon': 'payments',
        'color': '0xFF00E676',
        'type': 'income',
        'subcategories': ['Salario Mensual', 'Honorarios Profesionales', 'Ventas', 'Rendimientos/Intereses', 'Regalos']
      },
      {
        'id': 8,
        'name': 'Otros Ingresos',
        'icon': 'account_balance_wallet',
        'color': '0xFF00B0FF',
        'type': 'income',
        'subcategories': ['Aguinaldo', 'Reembolsos', 'Premios', 'Otros']
      }
    ];

    for (var cat in defaultCategories) {
      final categoryId = cat['id'] as int;
      
      // Insertar Categoría
      await db.insert('categories', {
        'id': categoryId,
        'name': cat['name'] as String,
        'icon': cat['icon'] as String,
        'color': cat['color'] as String,
        'type': cat['type'] as String,
      });

      // Insertar Subcategorías correspondientes
      final List<String> subcats = cat['subcategories'] as List<String>;
      for (var sub in subcats) {
        await db.insert('subcategories', {
          'category_id': categoryId,
          'name': sub,
        });
      }
    }
  }

  // ==========================================
  // MÉTODOS CRUD - CUENTAS
  // ==========================================

  Future<int> insertAccount(Account account) async {
    final db = await database;
    int id = 0;
    await db.transaction((txn) async {
      if (account.isDefault) {
        await txn.update('accounts', {'is_default': 0});
      }
      id = await txn.insert('accounts', account.toMap());
    });
    return id;
  }

  Future<List<Account>> getAllAccounts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('accounts', where: 'is_active = 1', orderBy: 'is_default DESC, id ASC');
    return List.generate(maps.length, (i) => Account.fromMap(maps[i]));
  }

  Future<int> updateAccount(Account account) async {
    final db = await database;
    int changes = 0;
    await db.transaction((txn) async {
      if (account.isDefault) {
        await txn.update('accounts', {'is_default': 0});
      }
      changes = await txn.update(
        'accounts',
        account.toMap(),
        where: 'id = ?',
        whereArgs: [account.id],
      );
    });
    return changes;
  }

  Future<int> deleteAccount(int id) async {
    final db = await database;
    // En lugar de borrar físicamente si hay transacciones, desactivamos la cuenta
    return await db.update(
      'accounts',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // MÉTODOS CRUD - CATEGORÍAS Y SUBCATEGORÍAS
  // ==========================================

  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  Future<List<Category>> getCategoriesByType(String type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'type = ?',
      whereArgs: [type],
    );
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertSubcategory(Subcategory subcategory) async {
    final db = await database;
    return await db.insert('subcategories', subcategory.toMap());
  }

  Future<List<Subcategory>> getSubcategoriesByCategory(int categoryId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'subcategories',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
    return List.generate(maps.length, (i) => Subcategory.fromMap(maps[i]));
  }

  Future<int> deleteSubcategory(int id) async {
    final db = await database;
    return await db.delete('subcategories', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // MÉTODOS CRUD - TRANSACCIONES
  // ==========================================

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    return await db.insert('transactions', transaction.toMap());
  }

  /// Obtiene todas las transacciones ordenadas de forma cronológica descendente.
  /// Incluye Joins con cuentas y categorías para facilitar su uso en la UI.
  Future<List<TransactionModel>> getAllTransactions({String? monthFilter}) async {
    final db = await database;
    
    String query = '''
      SELECT t.*, 
             a.name as account_name, a.currency as account_currency,
             c.name as category_name, c.icon as category_icon, c.color as category_color,
             s.name as subcategory_name
      FROM transactions t
      INNER JOIN accounts a ON t.account_id = a.id
      INNER JOIN categories c ON t.category_id = c.id
      LEFT JOIN subcategories s ON t.subcategory_id = s.id
    ''';

    List<dynamic> args = [];
    if (monthFilter != null) {
      // monthFilter debe venir en formato YYYY-MM
      query += " WHERE t.date LIKE ? ";
      args.add('$monthFilter%');
    }

    query += " ORDER BY t.date DESC ";

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteScheduledTransaction(int id) async {
    final db = await database;
    return await db.delete(
      'scheduled_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Procesa las transacciones programadas vencidas.
  /// Si autoApply es true, inserta la transacción y actualiza la fecha/estado.
  Future<void> processScheduledTransactions() async {
    final db = await database;
    final now = DateTime.now();
    // Normalizar a inicio del día para la comparación
    final today = DateTime(now.year, now.month, now.day);

    final scheduled = await getScheduledTransactions(onlyActive: true);

    for (var st in scheduled) {
      final nextDate = DateTime(st.nextDate.year, st.nextDate.month, st.nextDate.day);
      
      if (nextDate.isBefore(today) || nextDate.isAtSameMomentAs(today)) {
        if (st.autoApply) {
          await applyScheduledTransaction(st, db);
        }
      }
    }
  }

  /// Aplica una transacción programada manualmente o automáticamente.
  Future<void> applyScheduledTransaction(ScheduledTransaction st, [Database? dbInstance]) async {
    final db = dbInstance ?? await database;

    // 1. Insertar transacción real
    final tx = TransactionModel(
      accountId: st.accountId,
      categoryId: st.categoryId,
      subcategoryId: st.subcategoryId,
      amount: st.amount,
      description: st.description,
      date: DateTime.now(),
      type: st.type,
    );
    await insertTransaction(tx);

    // 2. Avanzar fecha y cuota
    DateTime newDate;
    switch (st.frequency) {
      case 'daily':
        newDate = st.nextDate.add(const Duration(days: 1));
        break;
      case 'weekly':
        newDate = st.nextDate.add(const Duration(days: 7));
        break;
      case 'monthly':
        newDate = DateTime(st.nextDate.year, st.nextDate.month + 1, st.nextDate.day);
        break;
      case 'yearly':
        newDate = DateTime(st.nextDate.year + 1, st.nextDate.month, st.nextDate.day);
        break;
      case 'once':
      default:
        newDate = st.nextDate; // won't be used if it deactivates
        break;
    }

    int newInstallment = st.currentInstallment + 1;
    bool isActive = true;

    if (st.frequency == 'once' || (st.totalInstallments != null && newInstallment > st.totalInstallments!)) {
      isActive = false;
    }

    final updatedSt = ScheduledTransaction(
      id: st.id,
      accountId: st.accountId,
      categoryId: st.categoryId,
      subcategoryId: st.subcategoryId,
      type: st.type,
      amount: st.amount,
      description: st.description,
      frequency: st.frequency,
      nextDate: newDate,
      currentInstallment: newInstallment,
      totalInstallments: st.totalInstallments,
      autoApply: st.autoApply,
      isActive: isActive,
    );

    await db.update(
      'scheduled_transactions',
      updatedSt.toMap(),
      where: 'id = ?',
      whereArgs: [st.id],
    );
  }

  // ==========================================
  // CONSULTAS AGREGADAS Y ESTADÍSTICAS
  // ==========================================

  /// Obtiene el saldo disponible en cada cuenta, agrupando por moneda.
  Future<Map<String, double>> getBalancesByCurrency() async {
    final db = await database;
    
    // Consultamos la suma de ingresos y egresos por cuenta
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT a.currency, t.type, SUM(t.amount) as total
      FROM transactions t
      INNER JOIN accounts a ON t.account_id = a.id
      GROUP BY a.currency, t.type
    ''');

    Map<String, double> balances = {};
    for (var row in maps) {
      final currency = row['currency'] as String;
      final type = row['type'] as String;
      final total = (row['total'] as num).toDouble();

      final current = balances[currency] ?? 0.0;
      if (type == 'income') {
        balances[currency] = current + total;
      } else {
        balances[currency] = current - total;
      }
    }
    return balances;
  }

  /// Obtiene el saldo disponible por cada cuenta individual.
  Future<Map<int, double>> getBalancesByAccountId() async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT t.account_id, t.type, SUM(t.amount) as total
      FROM transactions t
      GROUP BY t.account_id, t.type
    ''');

    Map<int, double> balances = {};
    for (var row in maps) {
      final accId = row['account_id'] as int;
      final type = row['type'] as String;
      final total = (row['total'] as num).toDouble();

      final current = balances[accId] ?? 0.0;
      if (type == 'income') {
        balances[accId] = current + total;
      } else {
        balances[accId] = current - total;
      }
    }
    return balances;
  }

  /// Obtiene los ingresos y egresos acumulados de un mes específico agrupados por moneda.
  Future<Map<String, Map<String, double>>> getMonthlySummary(String monthFilter) async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT a.currency, t.type, SUM(t.amount) as total
      FROM transactions t
      INNER JOIN accounts a ON t.account_id = a.id
      WHERE t.date LIKE ?
      GROUP BY a.currency, t.type
    ''', ['$monthFilter%']);

    // Estructura: { "₲": { "income": 8000000, "expense": 5101000 }, "$": { ... } }
    Map<String, Map<String, double>> summary = {};
    for (var row in maps) {
      final currency = row['currency'] as String;
      final type = row['type'] as String;
      final total = (row['total'] as num).toDouble();

      if (!summary.containsKey(currency)) {
        summary[currency] = {'income': 0.0, 'expense': 0.0};
      }
      summary[currency]![type] = total;
    }
    return summary;
  }

  /// Obtiene los gastos del mes específico, agrupados por categoría y moneda, para gráficos.
  Future<List<Map<String, dynamic>>> getExpenseDistributionByCategory(String monthFilter, String currency) async {
    final db = await database;

    return await db.rawQuery('''
      SELECT c.name as category_name, c.color as category_color, c.icon as category_icon,
             SUM(t.amount) as total, COUNT(t.id) as transaction_count
      FROM transactions t
      INNER JOIN categories c ON t.category_id = c.id
      INNER JOIN accounts a ON t.account_id = a.id
      WHERE t.date LIKE ? AND a.currency = ? AND t.type = 'expense'
      GROUP BY c.id
      ORDER BY total DESC
    ''', ['$monthFilter%', currency]);
  }

  /// Obtiene la evolución diaria de ingresos/gastos en el mes actual para un gráfico de línea.
  Future<List<Map<String, dynamic>>> getDailyTransactionEvolution(String monthFilter, String currency) async {
    final db = await database;

    return await db.rawQuery('''
      SELECT SUBSTR(t.date, 9, 2) as day, t.type, SUM(t.amount) as total
      FROM transactions t
      INNER JOIN accounts a ON t.account_id = a.id
      WHERE t.date LIKE ? AND a.currency = ?
      GROUP BY day, t.type
      ORDER BY day ASC
    ''', ['$monthFilter%', currency]);
  }

  // ==========================================
  // MÉTODOS DE SINCRONIZACIÓN
  // ==========================================

  /// Obtiene todas las transacciones que no han sido sincronizadas aún con Google Drive.
  Future<List<TransactionModel>> getUnsyncedTransactions() async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT t.*, 
             a.name as account_name, a.currency as account_currency,
             c.name as category_name, c.icon as category_icon, c.color as category_color,
             s.name as subcategory_name
      FROM transactions t
      INNER JOIN accounts a ON t.account_id = a.id
      INNER JOIN categories c ON t.category_id = c.id
      LEFT JOIN subcategories s ON t.subcategory_id = s.id
      WHERE t.sync_status = 0
    ''');
    
    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }

  /// Marca una lista de transacciones como sincronizadas en la base de datos local.
  Future<void> markAsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    
    final nowIso = DateTime.now().toIso8601String();
    for (var id in ids) {
      batch.update(
        'transactions',
        {
          'sync_status': 1,
          'sync_date': nowIso,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Limpia y recrea todos los datos para una restauración completa desde respaldo.
  Future<void> restoreDatabaseBackup(
    List<Map<String, dynamic>> accounts,
    List<Map<String, dynamic>> transactions,
    List<Map<String, dynamic>> categories,
    List<Map<String, dynamic>> subcategories,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Limpiar tablas existentes en orden de dependencia
      await txn.delete('transactions');
      await txn.delete('subcategories');
      await txn.delete('categories');
      await txn.delete('accounts');

      // 2. Restaurar Cuentas
      for (var acc in accounts) {
        await txn.insert('accounts', acc);
      }

      // 3. Restaurar Categorías
      for (var cat in categories) {
        await txn.insert('categories', {
          'id': cat['id'],
          'name': cat['name'],
          'icon': cat['icon'],
          'color': cat['color'],
          'type': cat['type'],
        });
      }

      // 4. Restaurar Subcategorías
      for (var sub in subcategories) {
        await txn.insert('subcategories', sub);
      }

      // 5. Restaurar Transacciones
      for (var trans in transactions) {
        await txn.insert('transactions', trans);
      }
    });
  }

  // ==========================================
  // OPERACIONES DE AGENDA DE MOVIMIENTOS
  // ==========================================

  Future<List<ScheduledTransaction>> getScheduledTransactions({bool onlyActive = true}) async {
    final db = await database;
    final where = onlyActive ? 'is_active = 1' : null;
    final List<Map<String, dynamic>> maps = await db.query(
      'scheduled_transactions',
      where: where,
      orderBy: 'next_date ASC',
    );
    return List.generate(maps.length, (i) {
      return ScheduledTransaction.fromMap(maps[i]);
    });
  }

  Future<int> insertScheduledTransaction(ScheduledTransaction st) async {
    final db = await database;
    return await db.insert('scheduled_transactions', st.toMap());
  }

  Future<int> updateScheduledTransaction(ScheduledTransaction st) async {
    final db = await database;
    return await db.update(
      'scheduled_transactions',
      st.toMap(),
      where: 'id = ?',
      whereArgs: [st.id],
    );
  }

  // ==========================================
  // OPERACIONES DE PRESUPUESTOS (BUDGETS)
  // ==========================================

  Future<List<Budget>> getBudgets({bool onlyActive = true}) async {
    final db = await database;
    final where = onlyActive ? 'is_active = 1' : null;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: where,
    );
    return List.generate(maps.length, (i) {
      return Budget.fromMap(maps[i]);
    });
  }

  Future<int> insertBudget(Budget budget) async {
    final db = await database;
    return await db.insert('budgets', budget.toMap());
  }

  Future<int> updateBudget(Budget budget) async {
    final db = await database;
    return await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<int> deleteBudget(int id) async {
    final db = await database;
    return await db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Calcula lo gastado en el mes actual para un presupuesto dado.
  Future<double> calculateSpentForBudget(Budget budget, DateTime month) async {
    final db = await database;
    String startDate = "${month.year}-${month.month.toString().padLeft(2, '0')}-01";
    
    // Cálculo simplificado del fin de mes
    int nextMonth = month.month + 1;
    int nextYear = month.year;
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear++;
    }
    String endDate = "$nextYear-${nextMonth.toString().padLeft(2, '0')}-01";

    // Unir transacciones con cuentas para verificar la moneda
    String query = '''
      SELECT SUM(t.amount) as total
      FROM transactions t
      JOIN accounts a ON t.account_id = a.id
      WHERE t.type = 'expense'
      AND a.currency = ?
      AND t.date >= ? AND t.date < ?
    ''';
    List<dynamic> args = [budget.currency, startDate, endDate];

    if (budget.accountId != null) {
      query += ' AND t.account_id = ?';
      args.add(budget.accountId);
    }
    if (budget.categoryId != null) {
      query += ' AND t.category_id = ?';
      args.add(budget.categoryId);
    }
    if (budget.subcategoryId != null) {
      query += ' AND t.subcategory_id = ?';
      args.add(budget.subcategoryId);
    }

    final result = await db.rawQuery(query, args);
    if (result.isNotEmpty && result.first['total'] != null) {
      return result.first['total'] as double;
    }
    return 0.0;
  }

  /// Devuelve el promedio de gastos por categoría en los últimos N meses (por defecto 3).
  Future<Map<int, double>> getHistoricalAverages({int monthsBack = 3}) async {
    final db = await database;
    
    DateTime now = DateTime.now();
    DateTime pastDate = DateTime(now.year, now.month - monthsBack, 1);
    String pastDateStr = "${pastDate.year}-${pastDate.month.toString().padLeft(2, '0')}-01";

    String query = '''
      SELECT category_id, SUM(amount) as total
      FROM transactions
      WHERE type = 'expense'
      AND date >= ?
      GROUP BY category_id
    ''';

    final result = await db.rawQuery(query, [pastDateStr]);
    Map<int, double> averages = {};
    for (var row in result) {
      int catId = row['category_id'] as int;
      double total = row['total'] as double;
      averages[catId] = total / monthsBack;
    }
    return averages;
  }
}
