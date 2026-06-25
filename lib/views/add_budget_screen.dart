import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/budget.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/subcategory.dart';
import '../theme.dart';
import 'auto_budget_dialog.dart';

class AddBudgetScreen extends StatefulWidget {
  final Budget? budget;
  const AddBudgetScreen({super.key, this.budget});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final DBHelper _dbHelper = DBHelper();
  final TextEditingController _amountCtrl = TextEditingController();

  double _amount = 0.0;
  String _currency = '₲';
  Account? _selectedAccount;
  Category? _selectedCategory;
  Subcategory? _selectedSubcategory;
  
  List<Account> _accounts = [];
  List<Category> _categories = [];
  List<Subcategory> _subcategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.budget != null) {
      _amount = widget.budget!.amount;
      _currency = widget.budget!.currency;
      _amountCtrl.text = NumberFormat.decimalPattern('es_ES').format(_amount);
    }
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _categories = await _dbHelper.getCategoriesByType('expense');
    _accounts = await _dbHelper.getAllAccounts();
    
    if (widget.budget != null) {
      if (widget.budget!.accountId != null) {
        _selectedAccount = _accounts.firstWhere((a) => a.id == widget.budget!.accountId, orElse: () => _accounts.first);
      }
      if (widget.budget!.categoryId != null) {
        _selectedCategory = _categories.firstWhere((c) => c.id == widget.budget!.categoryId, orElse: () => _categories.first);
        _subcategories = await _dbHelper.getSubcategoriesByCategory(_selectedCategory!.id!);
        if (widget.budget!.subcategoryId != null) {
          _selectedSubcategory = _subcategories.firstWhere((s) => s.id == widget.budget!.subcategoryId, orElse: () => _subcategories.first);
        }
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _reloadSubcategories(Category? cat) async {
    if (cat == null) {
      setState(() {
        _selectedCategory = null;
        _subcategories = [];
        _selectedSubcategory = null;
      });
      return;
    }
    final subs = await _dbHelper.getSubcategoriesByCategory(cat.id!);
    setState(() {
      _selectedCategory = cat;
      _subcategories = subs;
      _selectedSubcategory = null;
    });
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un monto válido')));
      return;
    }

    final b = Budget(
      id: widget.budget?.id,
      amount: _amount,
      currency: _currency,
      accountId: _selectedAccount?.id,
      categoryId: _selectedCategory?.id,
      subcategoryId: _selectedSubcategory?.id,
    );

    if (widget.budget == null) {
      await _dbHelper.insertBudget(b);
    } else {
      await _dbHelper.updateBudget(b);
    }
    Navigator.pop(context, true);
  }

  Future<void> _showAutoGenerate() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const AutoBudgetDialog(),
    );
    if (result == true) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.budget == null ? 'Nuevo Presupuesto' : 'Editar Presupuesto'),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.primary),
            onPressed: _saveBudget,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.budget == null)
              ElevatedButton.icon(
                onPressed: _showAutoGenerate,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Autogenerar Presupuestos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  foregroundColor: AppColors.primary,
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                DropdownButton<String>(
                  dropdownColor: AppColors.cardBackground,
                  value: _currency,
                  items: const [
                    DropdownMenuItem(value: '₲', child: Text('₲', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'U\$', child: Text('U\$', style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (v) => setState(() => _currency = v!),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(labelText: 'Monto Límite'),
                    onChanged: (value) {
                      String numericString = value.replaceAll(RegExp(r'[^0-9]'), '');
                      if (numericString.isNotEmpty) {
                        final number = int.parse(numericString);
                        final formatted = NumberFormat.decimalPattern('es_ES').format(number);
                        _amountCtrl.value = TextEditingValue(
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
                      _amount = double.parse(clean);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
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
            DropdownButtonFormField<Category?>(
              dropdownColor: AppColors.cardBackground,
              initialValue: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Categoría (Opcional)'),
              items: [
                const DropdownMenuItem<Category?>(
                  value: null,
                  child: Text('(Global - Todas las categorías)', style: TextStyle(color: Colors.white54)),
                ),
                ..._categories.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c.name, style: const TextStyle(color: Colors.white)),
                )),
              ],
              onChanged: (c) => _reloadSubcategories(c),
            ),
            if (_selectedCategory != null && _subcategories.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<Subcategory?>(
                dropdownColor: AppColors.cardBackground,
                initialValue: _selectedSubcategory,
                decoration: const InputDecoration(labelText: 'Subcategoría (Opcional)'),
                items: [
                  const DropdownMenuItem<Subcategory?>(
                    value: null,
                    child: Text('(Todas las subcategorías)', style: TextStyle(color: Colors.white54)),
                  ),
                  ..._subcategories.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.name, style: const TextStyle(color: Colors.white)),
                  )),
                ],
                onChanged: (s) => setState(() => _selectedSubcategory = s),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Nota: Si dejas la categoría como Global, este presupuesto aplicará al total general de gastos en el mes.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            )
          ],
        ),
      ),
    );
  }
}
