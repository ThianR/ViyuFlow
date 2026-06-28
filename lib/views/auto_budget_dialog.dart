import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../theme.dart';
import '../utils/currency_utils.dart';

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
  String _budgetType = 'both';
  
  Account? _selectedAccount;
  List<Account> _accounts = [];
  bool _isLoadingAccounts = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await _dbHelper.getAllAccounts();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _isLoadingAccounts = false;
      });
    }
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_income <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingreso inválido')));
      return;
    }

    setState(() => _isGenerating = true);

    double totalBudgetPool = _income * (_percent / 100);
    
    if (_budgetType == 'both' || _budgetType == 'categories') {
      // Obtener promedios históricos de los últimos N meses
      final averages = await _dbHelper.getHistoricalAverages(monthsBack: _months);
      
      if (averages.isEmpty) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay datos históricos suficientes para autogenerar por categorías.')));
          setState(() => _isGenerating = false);
        }
        return;
      }

      double totalHistoricalAvg = 0;
      averages.forEach((key, val) => totalHistoricalAvg += val);

      for (var entry in averages.entries) {
        int catId = entry.key;
        double catAvg = entry.value;

        double catBudget = (catAvg / totalHistoricalAvg) * totalBudgetPool;

        final b = Budget(
          amount: catBudget,
          currency: _currency,
          accountId: _selectedAccount?.id,
          categoryId: catId,
        );
        await _dbHelper.insertBudget(b);
      }
    }

    if (_budgetType == 'both' || _budgetType == 'global') {
      final global = Budget(
        amount: totalBudgetPool,
        currency: _currency,
        accountId: _selectedAccount?.id,
      );
      await _dbHelper.insertBudget(global);
    }

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
              const Text(
                'La app calculará los presupuestos basados en tus ingresos esperados y gastos históricos.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                dropdownColor: AppColors.cardBackground,
                initialValue: _budgetType,
                decoration: const InputDecoration(labelText: 'Tipo de Presupuesto'),
                items: const [
                  DropdownMenuItem(value: 'both', child: Text('Global y por Categorías', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'global', child: Text('Solo Global', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'categories', child: Text('Solo por Categorías', style: TextStyle(color: Colors.white))),
                ],
                onChanged: (v) => setState(() => _budgetType = v!), // trigger rebuild para ocultar Meses a analizar
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                dropdownColor: AppColors.cardBackground,
                initialValue: _currency,
                decoration: const InputDecoration(labelText: 'Moneda'),
                items: CurrencyUtils.availableCurrencies.map((c) {
                  return DropdownMenuItem(value: c['symbol'], child: Text(c['name']!, style: const TextStyle(color: Colors.white)));
                }).toList(),
                onChanged: (v) => setState(() => _currency = v!),
              ),
              const SizedBox(height: 16),
              if (_isLoadingAccounts)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<Account?>(
                  dropdownColor: AppColors.cardBackground,
                  initialValue: _selectedAccount,
                  decoration: const InputDecoration(labelText: 'Cuenta (Opcional)'),
                  items: [
                    const DropdownMenuItem<Account?>(
                      value: null,
                      child: Text('(General - Todas las cuentas)', style: TextStyle(color: Colors.white54)),
                    ),
                    ..._accounts.map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(a.name, style: const TextStyle(color: Colors.white)),
                    )),
                  ],
                  onChanged: (a) => setState(() => _selectedAccount = a),
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
              if (_budgetType != 'global') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  dropdownColor: AppColors.cardBackground,
                  initialValue: _months,
                  decoration: const InputDecoration(labelText: 'Meses a analizar'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Último mes', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 3, child: Text('Últimos 3 meses', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 6, child: Text('Últimos 6 meses', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 12, child: Text('Último año', style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (v) => setState(() => _months = v!),
                ),
              ],
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
