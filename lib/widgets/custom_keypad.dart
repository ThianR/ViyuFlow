import 'package:flutter/material.dart';
import '../theme.dart';

/// Un widget de teclado numérico personalizado con soporte de calculadora básica.
/// Permite ingresar dígitos, puntos decimales y operadores aritméticos simples.
class CustomKeypad extends StatefulWidget {
  final String initialValue;
  final Function(String expression, String calculatedValue) onValueChanged;
  final VoidCallback onSubmitted;

  const CustomKeypad({
    super.key,
    required this.initialValue,
    required this.onValueChanged,
    required this.onSubmitted,
  });

  /// Evalúa una expresión matemática simple sin paréntesis de izquierda a derecha.
  /// Implementa prioridad de multiplicación y división antes de suma y resta.
  static String evaluateExpression(String exp) {
    if (exp.isEmpty) return '0';

    try {
      // 1. Extraer tokens (números y operadores) de la expresión
      final List<String> tokens = [];
      String currentNumber = '';
      
      for (int i = 0; i < exp.length; i++) {
        final char = exp[i];
        if (RegExp(r'[0-9\.]').hasMatch(char)) {
          currentNumber += char;
        } else {
          // Es un operador
          if (currentNumber.isNotEmpty) {
            tokens.add(currentNumber);
            currentNumber = '';
          }
          // Manejo de signo negativo inicial o tras otro operador
          if (char == '-' && (tokens.isEmpty || RegExp(r'[\+\-\*/]').hasMatch(tokens.last))) {
            currentNumber = '-';
          } else {
            tokens.add(char);
          }
        }
      }
      if (currentNumber.isNotEmpty) {
        tokens.add(currentNumber);
      }

      if (tokens.isEmpty) return '0';
      if (tokens.length == 1) {
        final numVal = double.tryParse(tokens.first);
        return numVal != null ? formatNumber(numVal) : '0';
      }

      // 2. Procesar multiplicación (*) y división (/)
      final List<String> intermediateTokens = [];
      int idx = 0;
      while (idx < tokens.length) {
        final token = tokens[idx];
        if (token == '*' || token == '/') {
          final double left = double.parse(intermediateTokens.removeLast());
          final double right = double.parse(tokens[idx + 1]);
          double result = 0;
          if (token == '*') {
            result = left * right;
          } else {
            if (right == 0) return 'Error'; // Evitar división por cero
            result = left / right;
          }
          intermediateTokens.add(result.toString());
          idx += 2;
        } else {
          intermediateTokens.add(token);
          idx++;
        }
      }

      // 3. Procesar suma (+) y resta (-)
      double finalResult = double.parse(intermediateTokens.first);
      idx = 1;
      while (idx < intermediateTokens.length) {
        final op = intermediateTokens[idx];
        final double right = double.parse(intermediateTokens[idx + 1]);
        if (op == '+') {
          finalResult += right;
        } else if (op == '-') {
          finalResult -= right;
        }
        idx += 2;
      }

      return formatNumber(finalResult);
    } catch (e) {
      // En caso de expresión inválida a mitad de digitación, retornar el último número válido
      return '0';
    }
  }

  /// Da formato al número omitiendo decimales innecesarios (ej: 1000.0 -> 1000).
  static String formatNumber(double numVal) {
    if (numVal == numVal.toInt().toDouble()) {
      return numVal.toInt().toString();
    }
    return numVal.toStringAsFixed(2);
  }

  @override
  State<CustomKeypad> createState() => _CustomKeypadState();
}

class _CustomKeypadState extends State<CustomKeypad> {
  String _expression = '';
  String _calculatedValue = '0';

  @override
  void initState() {
    super.initState();
    // Si hay un valor inicial numérico válido, lo usamos de inicio
    if (widget.initialValue.isNotEmpty && widget.initialValue != '0') {
      _expression = widget.initialValue;
      _calculatedValue = widget.initialValue;
    }
  }

  /// Maneja la pulsación de cualquier tecla en el teclado personalizado.
  void _onKeyPress(String value) {
    setState(() {
      if (value == 'AC') {
        // Limpiar todo
        _expression = '';
        _calculatedValue = '0';
      } else if (value == '⌫') {
        // Borrar el último caracter de la expresión
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
        _updateCalculatedValue();
      } else if (value == '=') {
        // Evaluar la expresión matemática y dejar solo el resultado final en pantalla
        _updateCalculatedValue(forceFinal: true);
        _expression = _calculatedValue;
      } else if (value == 'OK') {
        // Evaluar antes de enviar y disparar submit
        _updateCalculatedValue(forceFinal: true);
        widget.onSubmitted();
      } else {
        // Evitar múltiples operadores juntos
        final List<String> operators = ['+', '-', '*', '/'];
        if (_expression.isNotEmpty) {
          final lastChar = _expression[_expression.length - 1];
          if (operators.contains(lastChar) && operators.contains(value)) {
            // Reemplazar el último operador por el nuevo
            _expression = _expression.substring(0, _expression.length - 1) + value;
            widget.onValueChanged(_expression, _calculatedValue);
            return;
          }
        } else {
          // No permitir empezar con operadores excepto menos (-)
          if (operators.contains(value) && value != '-') return;
        }

        // Agregar dígito u operador a la expresión
        _expression += value;
        _updateCalculatedValue();
      }
      widget.onValueChanged(_expression, _calculatedValue);
    });
  }

  /// Actualiza el cálculo dinámico del valor basándose en la expresión actual.
  void _updateCalculatedValue({bool forceFinal = false}) {
    if (_expression.isEmpty) {
      _calculatedValue = '0';
      return;
    }

    // Si la expresión termina en un operador y no estamos forzando la evaluación final,
    // quitamos temporalmente el operador final para calcular el valor parcial
    final List<String> operators = ['+', '-', '*', '/'];
    String expToEvaluate = _expression;
    if (expToEvaluate.isNotEmpty) {
      final lastChar = expToEvaluate[expToEvaluate.length - 1];
      if (operators.contains(lastChar)) {
        if (forceFinal) {
          expToEvaluate = expToEvaluate.substring(0, expToEvaluate.length - 1);
        } else {
          // Para cálculo dinámico temporal, omitimos el último operador
          final tempExp = expToEvaluate.substring(0, expToEvaluate.length - 1);
          _calculatedValue = CustomKeypad.evaluateExpression(tempExp);
          return;
        }
      }
    }

    _calculatedValue = CustomKeypad.evaluateExpression(expToEvaluate);
  }

  /// Construye un botón individual del teclado virtual.
  Widget _buildKeyButton(String label, {Color? textColor, Color? buttonColor}) {
    final defaultBg = const Color(0xFF1E1E26);
    final isOperator = ['+', '-', '*', '/', '='].contains(label);
    final isAction = ['AC', '⌫', 'OK'].contains(label);

    final bg = buttonColor ?? (isOperator 
        ? AppColors.primary.withOpacity(0.2) 
        : isAction 
            ? (label == 'OK' ? AppColors.income.withOpacity(0.2) : Colors.red.withOpacity(0.1))
            : defaultBg);

    final textCol = textColor ?? (isOperator 
        ? AppColors.primary 
        : isAction 
            ? (label == 'OK' ? AppColors.income : AppColors.expense) 
            : AppColors.textPrimary);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _onKeyPress(label),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 58,
              alignment: Alignment.center,
              child: label == '⌫' 
                ? Icon(Icons.backspace_outlined, color: textCol, size: 22)
                : label == 'OK'
                  ? Icon(Icons.check_circle_outline, color: textCol, size: 24)
                  : Text(
                      label,
                      style: TextStyle(
                        color: textCol,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila 1: AC, /, *, ⌫
          Row(
            children: [
              _buildKeyButton('AC'),
              _buildKeyButton('/'),
              _buildKeyButton('*'),
              _buildKeyButton('⌫'),
            ],
          ),
          // Fila 2: 7, 8, 9, -
          Row(
            children: [
              _buildKeyButton('7'),
              _buildKeyButton('8'),
              _buildKeyButton('9'),
              _buildKeyButton('-'),
            ],
          ),
          // Fila 3: 4, 5, 6, +
          Row(
            children: [
              _buildKeyButton('4'),
              _buildKeyButton('5'),
              _buildKeyButton('6'),
              _buildKeyButton('+'),
            ],
          ),
          // Fila 4: 1, 2, 3, =
          Row(
            children: [
              _buildKeyButton('1'),
              _buildKeyButton('2'),
              _buildKeyButton('3'),
              _buildKeyButton('='),
            ],
          ),
          // Fila 5: ., 0, 000, OK
          Row(
            children: [
              _buildKeyButton('.'),
              _buildKeyButton('0'),
              _buildKeyButton('000'),
              _buildKeyButton('OK', buttonColor: AppColors.primary, textColor: Colors.white),
            ],
          ),
        ],
      ),
    );
  }
}
