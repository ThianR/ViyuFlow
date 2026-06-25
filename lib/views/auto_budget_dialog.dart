import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/budget.dart';
import '../theme.dart';

class AutoBudgetDialog extends StatefulWidget {
  const AutoBudgetDialog({super.key});

  @override
  State<AutoBudgetDialog> createState() => _AutoBudgetDialogState();
}

class _AutoBudgetDialogState extends State<AutoBudgetDialog> {
  final DBHelper _dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _incomeCtrl = TextEditingController();
  double _income = 0.0;
  double _percent = 70.0;
  int _months = 3;
  String _currency = '₲';
  
  bool _isGenerating = false;

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_income <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingreso inválido')));
      return;
    }

    setState(() => _isGenerating = true);

    double totalBudgetPool = _income * (_percent / 100);
    
    // Obtener promedios históricos de los últimos N meses
    final averages = await _dbHelper.getHistoricalAverages(monthsBack: _months);
    
    if (averages.isEmpty) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay datos históricos suficientes para autogenerar.')));
        Navigator.pop(context);
      }
      return;
    }

    double totalHistoricalAvg = 0;
    averages.forEach((key, val) => totalHistoricalAvg += val);

    // Si los históricos superan el límite de budgetPool, se escalan para abajo,
    // o se asigna proporcionalmente. 
    // Opción recomendada: distribuir el pool proporcionalmente.
    for (var entry in averages.entries) {
      int catId = entry.key;
      double catAvg = entry.value;

      double catBudget = (catAvg / totalHistoricalAvg) * totalBudgetPool;

      // Crear presupuesto
      final b = Budget(
        amount: catBudget,
        currency: _currency,
        categoryId: catId,
      );
      await _dbHelper.insertBudget(b);
    }

    // Opcional: Crear presupuesto global con el monto total
    final global = Budget(
      amount: totalBudgetPool,
      currency: _currency,
    );
    await _dbHelper.insertBudget(global);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Presupuestos generados exitosamente')));
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      title: const Text('Autogenerar Presupuestos', style: TextStyle(color: Colors.white)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'La app calculará un presupuesto global y por categorías basado en tus gastos de los últimos meses.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                dropdownColor: AppColors.cardBackground,
                value: _currency,
                decoration: const InputDecoration(labelText: 'Moneda'),
                items: const [
                  DropdownMenuItem(value: '₲', child: Text('Guaraníes (₲)', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'U\$', child: Text('Dólares (U\$)', style: TextStyle(color: Colors.white))),
                ],
                onChanged: (v) => setState(() => _currency = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _incomeCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Ingreso mensual esperado'),
                onChanged: (value) {
                  String numericString = value.replaceAll(RegExp(r'[^0-9]'), '');
                  if (numericString.isNotEmpty) {
                    final number = int.parse(numericString);
                    final formatted = NumberFormat.decimalPattern('es_ES').format(number);
                    _incomeCtrl.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(offset: formatted.length),
                    );
                  }
                },
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  String clean = v.replaceAll(RegExp(r'[^0-9]'), '');
                  if (double.tryParse(clean) == null) return 'Inválido';
                  return null;
                },
                onSaved: (v) {
                  String clean = v!.replaceAll(RegExp(r'[^0-9]'), '');
                  _income = double.parse(clean);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text('Destinar a gastos:', style: TextStyle(color: Colors.white70)),
                  ),
                  Text('${_percent.toInt()}%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _percent,
                min: 10,
                max: 100,
                divisions: 90,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _percent = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                dropdownColor: AppColors.cardBackground,
                value: _months,
                decoration: const InputDecoration(labelText: 'Meses a analizar'),
                items: [
                  DropdownMenuItem(value: 1, child: Text('Último mes', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 3, child: Text('Últimos 3 meses', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 6, child: Text('Últimos 6 meses', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 12, child: Text('Último año', style: TextStyle(color: Colors.white))),
                ],
                onChanged: (v) => setState(() => _months = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _isGenerating ? null : _generate,
          child: _isGenerating 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Generar'),
        ),
      ],
    );
  }
}
