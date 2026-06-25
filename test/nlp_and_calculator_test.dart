import 'package:flutter_test/flutter_test.dart';
import 'package:viyuflow/widgets/custom_keypad.dart';

void main() {
  group('Pruebas de la Calculadora (CustomKeypad)', () {
    test('Suma simple', () {
      final result = CustomKeypad.evaluateExpression('10+20');
      expect(result, equals('30'));
    });

    test('Resta simple', () {
      final result = CustomKeypad.evaluateExpression('50-15');
      expect(result, equals('35'));
    });

    test('Multiplicación simple', () {
      final result = CustomKeypad.evaluateExpression('10*5');
      expect(result, equals('50'));
    });

    test('División simple', () {
      final result = CustomKeypad.evaluateExpression('100/4');
      expect(result, equals('25'));
    });

    test('Prioridad de operadores (Multiplicación antes de suma)', () {
      final result = CustomKeypad.evaluateExpression('10+5*2');
      expect(result, equals('20')); // 10 + (5*2) = 20
    });

    test('Prioridad de operadores (División antes de resta)', () {
      final result = CustomKeypad.evaluateExpression('20-10/2');
      expect(result, equals('15')); // 20 - (10/2) = 15
    });

    test('Uso de decimales', () {
      final result = CustomKeypad.evaluateExpression('10.5+4.5');
      expect(result, equals('15'));
    });

    test('Resultado con decimales reales', () {
      final result = CustomKeypad.evaluateExpression('10/3');
      expect(result, equals('3.33'));
    });

    test('Soporte de signo negativo inicial', () {
      final result = CustomKeypad.evaluateExpression('-10+5');
      expect(result, equals('-5'));
    });

    test('División por cero devuelve Error', () {
      final result = CustomKeypad.evaluateExpression('10/0');
      expect(result, equals('Error'));
    });
  });

  group('Pruebas del Parser de Expresiones Regulares del NLP', () {
    // Definimos el mismo patrón Regex usado en nlp_parser.dart para pruebas puras
    final RegExp amountRegExp = RegExp(r'\b\d+(?:[\.,]\d+)?\b');

    double? parseAmount(String phrase) {
      final normPhrase = phrase.toLowerCase().trim();
      final Iterable<Match> matches = amountRegExp.allMatches(normPhrase);
      for (var match in matches) {
        final String rawNumber = match.group(0)!.replaceAll(',', '.');
        final double? parsedVal = double.tryParse(rawNumber);
        if (parsedVal != null && parsedVal > 0) {
          // Excluir números sospechosos de ser años
          final isLikelyYear = parsedVal == parsedVal.toInt().toDouble() && 
                               parsedVal >= 1900 && 
                               parsedVal <= 2100;
          if (isLikelyYear) continue;

          return parsedVal;
        }
      }
      return null;
    }

    test('Extrae montos enteros simples', () {
      expect(parseAmount('Gasté 150000 guaraníes en súper'), equals(150000.0));
      expect(parseAmount('Ayer compré comida a 5 dólares'), equals(5.0));
    });

    test('Extrae montos con decimales y coma', () {
      expect(parseAmount('Pagué 10,50 dólares'), equals(10.50));
      expect(parseAmount('Ingreso de 450.75 dólares'), equals(450.75));
    });

    test('Ignora los años del texto como montos', () {
      // Debería omitir 2026 y capturar 3500
      expect(parseAmount('En el año 2026 gasté 3500 guaraníes'), equals(3500.0));
      // Debería omitir 1999 y capturar 150
      expect(parseAmount('Desde 1999 mi sueldo subió 150 dólares'), equals(150.0));
    });
  });
}
