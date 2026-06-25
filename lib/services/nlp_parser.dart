import '../models/account.dart';
import '../models/category.dart';
import '../models/subcategory.dart';
import '../database/db_helper.dart';

/// Estructura de datos que contiene el resultado del análisis de texto por voz.
class ParsedResult {
  final double? amount;
  final String? currency;
  final String type; // 'expense' (defecto) o 'income'
  final DateTime date;
  final String description;
  final Account? account;
  final Category? category;
  final Subcategory? subcategory;
  final bool isComplete; // Indica si se extrajo suficiente información (monto mínimo)

  ParsedResult({
    this.amount,
    this.currency,
    required this.type,
    required this.date,
    required this.description,
    this.account,
    this.category,
    this.subcategory,
    this.isComplete = false,
  });

  @override
  String toString() {
    return 'ParsedResult(amount: $amount, currency: $currency, type: $type, date: $date, description: "$description", account: ${account?.name}, category: ${category?.name}, subcategory: ${subcategory?.name}, isComplete: $isComplete)';
  }
}

/// Clase encargada de parsear frases en español para extraer campos financieros.
class NLPParser {
  final DBHelper _dbHelper = DBHelper();

  /// Quita acentos y pasa a minúsculas para facilitar comparaciones de texto.
  String _normalize(String text) {
    var withOutAccents = text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
    return withOutAccents.trim();
  }

  /// Analiza una cadena de texto hablada y deduce los campos de la transacción.
  Future<ParsedResult> parsePhrase(String phrase) async {
    final String normPhrase = _normalize(phrase);
    if (normPhrase.isEmpty) {
      return ParsedResult(
        type: 'expense',
        date: DateTime.now(),
        description: '',
        isComplete: false,
      );
    }

    // 1. Extraer Monto (buscar números, omitiendo años como 2026)
    double? amount;
    // Buscamos números enteros o decimales sencillos
    final RegExp amountRegExp = RegExp(r'\b\d+(?:[\.,]\d+)?\b');
    final Iterable<Match> matches = amountRegExp.allMatches(normPhrase);
    
    for (var match in matches) {
      final String rawNumber = match.group(0)!.replaceAll(',', '.');
      final double? parsedVal = double.tryParse(rawNumber);
      if (parsedVal != null && parsedVal > 0) {
        // Si el número coincide con el rango común de años (ej. entre 1900 y 2100)
        // y no tiene decimales, lo descartamos asumiendo que es una referencia temporal
        final isLikelyYear = parsedVal == parsedVal.toInt().toDouble() && 
                             parsedVal >= 1900 && 
                             parsedVal <= 2100;
        if (isLikelyYear) continue;

        amount = parsedVal;
        break;
      }
    }

    // 2. Extraer Moneda
    String? currency;
    if (normPhrase.contains('dolar') || normPhrase.contains('usd') || normPhrase.contains('\$')) {
      currency = '\$';
    } else if (normPhrase.contains('guarani') || normPhrase.contains('gs') || normPhrase.contains('₲')) {
      currency = '₲';
    } else if (normPhrase.contains('euro') || normPhrase.contains('eur') || normPhrase.contains('€')) {
      currency = '€';
    }

    // 3. Determinar Tipo de Transacción (Ingreso vs Gasto)
    String type = 'expense';
    final List<String> incomeKeywords = [
      'ingreso', 'gane', 'ganar', 'recibi', 'salario', 'sueldo', 'cobro', 'cobre', 'premio', 'venta'
    ];
    final List<String> expenseKeywords = [
      'gaste', 'gasto', 'compre', 'compra', 'pague', 'pago', 'factura', 'egreso', 'deuda'
    ];

    int incomeScore = 0;
    int expenseScore = 0;

    for (var word in incomeKeywords) {
      if (normPhrase.contains(word)) incomeScore++;
    }
    for (var word in expenseKeywords) {
      if (normPhrase.contains(word)) expenseScore++;
    }

    if (incomeScore > expenseScore) {
      type = 'income';
    }

    // 4. Determinar Fecha (hoy, ayer, anteayer, etc.)
    DateTime date = DateTime.now();
    if (normPhrase.contains('anteayer')) {
      date = DateTime.now().subtract(const Duration(days: 2));
    } else if (normPhrase.contains('ayer')) {
      date = DateTime.now().subtract(const Duration(days: 1));
    }

    // 5. Relacionar con Cuentas de la DB
    final List<Account> accounts = await _dbHelper.getAllAccounts();
    Account? matchedAccount;
    for (var acc in accounts) {
      final String normAccName = _normalize(acc.name);
      // Coincidencia exacta o parcial del nombre de la cuenta
      if (normPhrase.contains(normAccName) || normAccName.contains(normPhrase)) {
        matchedAccount = acc;
        break;
      }
    }
    // Si no coincide y se detectó una moneda, buscar cuenta activa de esa moneda
    if (matchedAccount == null && currency != null) {
      for (var acc in accounts) {
        if (acc.currency == currency) {
          matchedAccount = acc;
          break;
        }
      }
    }
    // Si sigue siendo nula, usar la primera cuenta disponible por defecto
    if (matchedAccount == null && accounts.isNotEmpty) {
      matchedAccount = accounts.first;
    }

    // 6. Relacionar con Categorías y Subcategorías
    final List<Category> categories = await _dbHelper.getCategoriesByType(type);
    Category? matchedCategory;
    Subcategory? matchedSubcategory;

    // Buscar coincidencia en categorías primero
    for (var cat in categories) {
      final String normCatName = _normalize(cat.name);
      if (normPhrase.contains(normCatName)) {
        matchedCategory = cat;
        break;
      }
    }

    // Buscar coincidencia en subcategorías
    for (var cat in categories) {
      final List<Subcategory> subcats = await _dbHelper.getSubcategoriesByCategory(cat.id!);
      for (var sub in subcats) {
        final String normSubName = _normalize(sub.name);
        if (normPhrase.contains(normSubName)) {
          matchedSubcategory = sub;
          matchedCategory = cat; // La subcategoría arrastra a su categoría padre
          break;
        }
      }
      if (matchedSubcategory != null) break;
    }

    // Si no coincidió ninguna categoría, buscar sinónimos comunes
    if (matchedCategory == null) {
      final Map<String, List<String>> synonyms = {
        'hogar': ['luz', 'agua', 'energia', 'internet', 'alquiler', 'casa', 'limpieza'],
        'alimentacion': ['comida', 'almuerzo', 'cena', 'desayuno', 'supermercado', 'super', 'restaurante', 'mcdonald', 'burger'],
        'transporte': ['nafta', 'combustible', 'colectivo', 'bus', 'pasaje', 'uber', 'bolt', 'taller', 'auto'],
        'salidasyocio': ['cine', 'netflix', 'cerveza', 'juego', 'viaje', 'ocio', 'fiesta', 'joda', 'regalo'],
        'salud': ['farmacia', 'remedio', 'dentista', 'doctor', 'medico', 'clinica'],
      };

      String? matchedKey;
      synonyms.forEach((key, list) {
        for (var syn in list) {
          if (normPhrase.contains(syn)) {
            matchedKey = key;
            break;
          }
        }
      });

      if (matchedKey != null) {
        for (var cat in categories) {
          final normName = _normalize(cat.name);
          if (normName.contains(matchedKey!) || matchedKey!.contains(normName)) {
            matchedCategory = cat;
            break;
          }
        }
      }
    }

    // 7. Limpiar la Descripción
    // La descripción será la frase original menos las palabras de comandos como montos, monedas o fechas
    String description = phrase;
    // Opcional: Recortar frase si el usuario describió algo puntual, o simplemente usar la frase completa
    if (description.length > 50) {
      description = '${description.substring(0, 47)}...';
    }

    // Si no se encuentra moneda de la frase pero se seleccionó una cuenta, tomamos la moneda de la cuenta
    final finalCurrency = currency ?? matchedAccount?.currency;

    return ParsedResult(
      amount: amount,
      currency: finalCurrency,
      type: type,
      date: date,
      description: description,
      account: matchedAccount,
      category: matchedCategory,
      subcategory: matchedSubcategory,
      isComplete: amount != null && amount > 0, // Se considera completo si tenemos monto
    );
  }
}
