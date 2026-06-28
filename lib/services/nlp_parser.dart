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
  static const Map<String, int> _numberWords = {
    'cero': 0, 'un': 1, 'uno': 1, 'una': 1, 'dos': 2, 'tres': 3, 'cuatro': 4,
    'cinco': 5, 'seis': 6, 'siete': 7, 'ocho': 8, 'nueve': 9, 'diez': 10,
    'once': 11, 'doce': 12, 'trece': 13, 'catorce': 14, 'quince': 15,
    'dieciseis': 16, 'diecisiete': 17, 'dieciocho': 18, 'diecinueve': 19,
    'veinte': 20, 'veintiun': 21, 'veintiuno': 21, 'veintiuna': 21,
    'veintidos': 22, 'veintitres': 23, 'veinticuatro': 24, 'veinticinco': 25,
    'veintiseis': 26, 'veintisiete': 27, 'veintiocho': 28, 'veintinueve': 29,
    'treinta': 30, 'cuarenta': 40, 'cincuenta': 50, 'sesenta': 60,
    'setenta': 70, 'ochenta': 80, 'noventa': 90, 'cien': 100, 'ciento': 100,
    'doscientos': 200, 'doscientas': 200, 'trescientos': 300, 'trescientas': 300,
    'cuatrocientos': 400, 'cuatrocientas': 400, 'quinientos': 500, 'quinientas': 500,
    'seiscientos': 600, 'seiscientas': 600, 'setecientos': 700, 'setecientas': 700,
    'ochocientos': 800, 'ochocientas': 800, 'novecientos': 900, 'novecientas': 900,
  };

  /// Convierte números escritos en texto (ej. "dos mil") a formato numérico (ej. "2000").
  String _replaceTextNumbers(String phrase) {
    List<String> words = phrase.split(RegExp(r'\s+'));
    List<String> resultWords = [];
    
    int currentVal = 0;
    int totalVal = 0;
    bool isBuildingNumber = false;

    void commitNumber() {
      if (isBuildingNumber) {
        int finalNumber = totalVal + currentVal;
        resultWords.add(finalNumber.toString());
        currentVal = 0;
        totalVal = 0;
        isBuildingNumber = false;
      }
    }

    for (int i = 0; i < words.length; i++) {
      String rawWord = words[i];
      String word = _normalize(rawWord.replaceAll(RegExp(r'[^\w\s]'), ''));

      if (_numberWords.containsKey(word)) {
        isBuildingNumber = true;
        currentVal += _numberWords[word]!;
      } else if (word == 'mil') {
        isBuildingNumber = true;
        if (currentVal == 0) currentVal = 1;
        totalVal += currentVal * 1000;
        currentVal = 0;
      } else if (word == 'millon' || word == 'millones') {
        isBuildingNumber = true;
        if (currentVal == 0) currentVal = 1;
        totalVal += currentVal * 1000000;
        currentVal = 0;
      } else if (word == 'y' && isBuildingNumber && i + 1 < words.length && _numberWords.containsKey(_normalize(words[i+1].replaceAll(RegExp(r'[^\w\s]'), '')))) {
        // Ignorar la 'y' que une decenas y unidades (ej. "treinta y cinco")
      } else {
        commitNumber();
        resultWords.add(rawWord);
      }
    }
    commitNumber();

    return resultWords.join(' ');
  }

  /// Evalúa una expresión matemática simple (sumas y restas) contenida en un string.
  double? _evaluateMath(String expr) {
    final RegExp tokenRegExp = RegExp(r'(\d+(?:[\.,]\d+)?|[\+\-])');
    final Iterable<Match> tokens = tokenRegExp.allMatches(expr);
    
    double result = 0;
    String currentOp = '+';
    
    for (var match in tokens) {
      String token = match.group(0)!;
      if (token == '+' || token == '-') {
        currentOp = token;
      } else {
        double val = double.parse(token.replaceAll(',', '.'));
        if (currentOp == '+') {
          result += val;
        } else if (currentOp == '-') {
          result -= val;
        }
      }
    }
    return result;
  }

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
    final String phraseWithNumbers = _replaceTextNumbers(phrase);
    final String normPhrase = _normalize(phraseWithNumbers)
        .replaceAll(RegExp(r'\bmas\b', caseSensitive: false), '+')
        .replaceAll(RegExp(r'\bmenos\b', caseSensitive: false), '-');

    if (normPhrase.isEmpty) {
      return ParsedResult(
        type: 'expense',
        date: DateTime.now(),
        description: '',
        isComplete: false,
      );
    }

    // 1. Extraer Monto (buscar números u operaciones matemáticas simples, omitiendo años solos como 2026)
    double? amount;
    final RegExp mathRegExp = RegExp(r'\b\d+(?:[\.,]\d+)?(?:\s*[\+\-]\s*\d+(?:[\.,]\d+)?)*\b');
    final Iterable<Match> matches = mathRegExp.allMatches(normPhrase);
    
    for (var match in matches) {
      final String expr = match.group(0)!;
      final double parsedVal = _evaluateMath(expr) ?? 0;
      
      if (parsedVal > 0) {
        // Si es un número solo (sin operadores) y coincide con el rango común de años (ej. entre 1900 y 2100)
        if (!expr.contains('+') && !expr.contains('-')) {
          final isLikelyYear = parsedVal == parsedVal.toInt().toDouble() && 
                               parsedVal >= 1900 && 
                               parsedVal <= 2100;
          if (isLikelyYear) continue;
        }

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
