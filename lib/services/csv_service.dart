import 'dart:convert';
import 'package:csv/csv.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/subcategory.dart';
import '../database/db_helper.dart';

/// Servicio encargado de la exportación e importación de datos en formato CSV.
class CSVService {
  final DBHelper _dbHelper = DBHelper();

  /// Exporta una lista de transacciones a una cadena en formato CSV.
  String exportTransactionsToCSV(List<TransactionModel> transactions) {
    // Cabecera del archivo CSV
    List<List<dynamic>> rows = [
      [
        'ID',
        'Fecha',
        'Tipo',
        'Monto',
        'Moneda',
        'Cuenta',
        'Categoría',
        'Subcategoría',
        'Descripción'
      ]
    ];

    // Mapear cada transacción a una fila
    for (var t in transactions) {
      rows.add([
        t.id ?? '',
        t.date.toIso8601String(),
        t.type == 'income' ? 'Ingreso' : 'Egreso',
        t.amount,
        t.accountCurrency ?? '',
        t.accountName ?? '',
        t.categoryName ?? '',
        t.subcategoryName ?? '',
        t.description
      ]);
    }

    // Convertir a cadena CSV utilizando coma (,) como delimitador
    return const ListToCsvConverter().convert(rows);
  }

  /// Importa transacciones desde una cadena de texto en formato CSV.
  /// Lee el archivo fila por fila, resuelve o crea las cuentas/categorías necesarias
  /// e inserta las transacciones en la base de datos local SQLite.
  Future<int> importTransactionsFromCSV(String csvData) async {
    if (csvData.trim().isEmpty) return 0;

    // Convertir la cadena CSV en una lista bidimensional
    List<List<dynamic>> rows = const CsvToListConverter().convert(csvData);
    if (rows.length <= 1) return 0; // Solo cabecera o vacío

    // Validar cabeceras mínimas
    final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    
    // Obtener los índices de las columnas necesarias
    int idxDate = headers.indexOf('fecha');
    int idxType = headers.indexOf('tipo');
    int idxAmount = headers.indexOf('monto');
    int idxCurrency = headers.indexOf('moneda');
    int idxAccount = headers.indexOf('cuenta');
    int idxCategory = headers.indexOf('categoría');
    int idxSubcategory = headers.indexOf('subcategoría');
    int idxDescription = headers.indexOf('descripción');

    // Si no encuentra alguna columna fundamental, intentamos buscar sin acentos
    if (idxCategory == -1) idxCategory = headers.indexOf('categoria');
    if (idxSubcategory == -1) idxSubcategory = headers.indexOf('subcategoria');
    if (idxDescription == -1) idxDescription = headers.indexOf('descripcion');

    // Validación básica de columnas requeridas
    if (idxDate == -1 || idxType == -1 || idxAmount == -1 || idxAccount == -1 || idxCategory == -1) {
      throw Exception('El archivo CSV no tiene el formato esperado. Faltan columnas obligatorias.');
    }

    // Obtener datos actuales de la DB para mapear/evitar duplicar búsquedas repetidas
    List<Account> existingAccounts = await _dbHelper.getAllAccounts();
    List<Category> existingIncomes = await _dbHelper.getCategoriesByType('income');
    List<Category> existingExpenses = await _dbHelper.getCategoriesByType('expense');

    int importCount = 0;

    // Procesar cada fila de datos (omitir la cabecera)
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.length < 5) continue;

      try {
        final String rawDate = row[idxDate].toString();
        final DateTime date = DateTime.tryParse(rawDate) ?? DateTime.now();

        final String rawType = row[idxType].toString().trim().toLowerCase();
        final String type = (rawType == 'ingreso' || rawType == 'income') ? 'income' : 'expense';

        final double amount = double.tryParse(row[idxAmount].toString()) ?? 0.0;
        if (amount <= 0) continue; // Saltar transacciones inválidas

        final String currency = idxCurrency != -1 ? row[idxCurrency].toString().trim() : '₲';
        final String accountName = row[idxAccount].toString().trim();
        final String categoryName = row[idxCategory].toString().trim();
        final String subcategoryName = idxSubcategory != -1 ? row[idxSubcategory].toString().trim() : '';
        final String description = idxDescription != -1 ? row[idxDescription].toString().trim() : '';

        if (accountName.isEmpty || categoryName.isEmpty) continue;

        // 1. Resolver o Crear Cuenta
        Account? account = existingAccounts.firstWhere(
          (a) => a.name.toLowerCase() == accountName.toLowerCase() && a.currency == currency,
          orElse: () => Account(name: '', currency: '', color: ''),
        );

        if (account.name.isEmpty) {
          // Crear nueva cuenta con color por defecto (ej. Azul zafiro)
          final newAccount = Account(
            name: accountName,
            currency: currency,
            color: '0xFF0F52BA',
          );
          final newId = await _dbHelper.insertAccount(newAccount);
          account = newAccount.copyWith(id: newId);
          existingAccounts.add(account);
        }

        // 2. Resolver o Crear Categoría
        List<Category> targetCategoryList = type == 'income' ? existingIncomes : existingExpenses;
        Category? category = targetCategoryList.firstWhere(
          (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
          orElse: () => Category(name: '', icon: '', color: '', type: ''),
        );

        if (category.name.isEmpty) {
          // Crear nueva categoría por defecto si no existe
          final newCategory = Category(
            name: categoryName,
            icon: type == 'income' ? 'payments' : 'shopping_bag',
            color: type == 'income' ? '0xFF00E676' : '0xFFFF5252',
            type: type,
          );
          final newId = await _dbHelper.insertCategory(newCategory);
          category = newCategory.copyWith(id: newId);
          targetCategoryList.add(category);
        }

        // 3. Resolver o Crear Subcategoría (si se especificó en el CSV)
        int? subcategoryId;
        if (subcategoryName.isNotEmpty) {
          List<Subcategory> subcategories = await _dbHelper.getSubcategoriesByCategory(category.id!);
          Subcategory? subcategory = subcategories.firstWhere(
            (s) => s.name.toLowerCase() == subcategoryName.toLowerCase(),
            orElse: () => Subcategory(categoryId: -1, name: ''),
          );

          if (subcategory.name.isEmpty) {
            final newSub = Subcategory(
              categoryId: category.id!,
              name: subcategoryName,
            );
            final newSubId = await _dbHelper.insertSubcategory(newSub);
            subcategoryId = newSubId;
          } else {
            subcategoryId = subcategory.id;
          }
        }

        // 4. Crear e Insertar la Transacción en SQLite
        final newTransaction = TransactionModel(
          accountId: account.id!,
          categoryId: category.id!,
          subcategoryId: subcategoryId,
          amount: amount,
          description: description,
          date: date,
          type: type,
          syncStatus: false, // La transacción importada se marca lista para ser respaldada
        );

        await _dbHelper.insertTransaction(newTransaction);
        importCount++;
      } catch (e) {
        // En caso de error en una fila, se registra y se continúa con las demás filas
        print('Error procesando fila $i en importación: $e');
      }
    }

    return importCount;
  }
}
