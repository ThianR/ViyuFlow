import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/subcategory.dart';
import '../models/scheduled_transaction.dart';
import '../theme.dart';

class AddScheduledScreen extends StatefulWidget {
  final ScheduledTransaction? transaction;

  const AddScheduledScreen({super.key, this.transaction});

  @override
  State<AddScheduledScreen> createState() => _AddScheduledScreenState();
}

class _AddScheduledScreenState extends State<AddScheduledScreen> {
  final DBHelper _dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();

  String _type = 'expense';
  double _amount = 0.0;
  String _description = '';
  DateTime _nextDate = DateTime.now();
  String _frequency = 'monthly';
  bool _autoApply = false;
  int? _totalInstallments;

  Account? _selectedAccount;
  Category? _selectedCategory;
  Subcategory? _selectedSubcategory;

  List<Account> _accounts = [];
  List<Category> _categories = [];
  List<Subcategory> _subcategories = [];
  bool _isLoading = true;

  final TextEditingController _amountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _type = widget.transaction!.type;
      _amount = widget.transaction!.amount;
      _description = widget.transaction!.description;
      _nextDate = widget.transaction!.nextDate;
      _frequency = widget.transaction!.frequency;
      _autoApply = widget.transaction!.autoApply;
      _totalInstallments = widget.transaction!.totalInstallments;
      final formatted = NumberFormat.decimalPattern('es_ES').format(_amount);
      _amountCtrl.text = formatted;
    } else {
      _nextDate = DateTime.now().add(const Duration(days: 1));
    }
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _accounts = await _dbHelper.getAllAccounts();
    _categories = await _dbHelper.getCategoriesByType(_type);

    if (_accounts.isNotEmpty) {
      if (widget.transaction != null) {
        _selectedAccount = _accounts.firstWhere((a) => a.id == widget.transaction!.accountId, orElse: () => _accounts.first);
      } else {
        _selectedAccount = _accounts.firstWhere((a) => a.isDefault, orElse: () => _accounts.first);
      }
    }
    if (_categories.isNotEmpty) {
      if (widget.transaction != null) {
        _selectedCategory = _categories.firstWhere((c) => c.id == widget.transaction!.categoryId, orElse: () => _categories.first);
      } else {
        _selectedCategory = _categories.first;
      }
      _subcategories = await _dbHelper.getSubcategoriesByCategory(_selectedCategory!.id!);
      if (_subcategories.isNotEmpty) {
        if (widget.transaction != null && widget.transaction!.subcategoryId != null) {
          _selectedSubcategory = _subcategories.firstWhere((s) => s.id == widget.transaction!.subcategoryId, orElse: () => _subcategories.first);
        } else {
          _selectedSubcategory = _subcategories.first;
        }
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _reloadCategories(String newType) async {
    setState(() => _isLoading = true);
    _type = newType;
    _categories = await _dbHelper.getCategoriesByType(_type);
    if (_categories.isNotEmpty) {
      _selectedCategory = _categories.first;
      _subcategories = await _dbHelper.getSubcategoriesByCategory(_selectedCategory!.id!);
      _selectedSubcategory = _subcategories.isNotEmpty ? _subcategories.first : null;
    } else {
      _selectedCategory = null;
      _subcategories = [];
      _selectedSubcategory = null;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _onCategoryChanged(Category? newCat) async {
    if (newCat == null) return;
    setState(() => _isLoading = true);
    _selectedCategory = newCat;
    _subcategories = await _dbHelper.getSubcategoriesByCategory(newCat.id!);
    _selectedSubcategory = _subcategories.isNotEmpty ? _subcategories.first : null;
    setState(() => _isLoading = false);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _nextDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() => _nextDate = date);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_selectedAccount == null || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona cuenta y categoría')),
      );
      return;
    }

    final st = ScheduledTransaction(
      id: widget.transaction?.id,
      accountId: _selectedAccount!.id!,
      categoryId: _selectedCategory!.id!,
      subcategoryId: _selectedSubcategory?.id,
      type: _type,
      amount: _amount,
      description: _description,
      frequency: _frequency,
      nextDate: _nextDate,
      totalInstallments: _totalInstallments,
      autoApply: _autoApply,
    );

    if (widget.transaction == null) {
      await _dbHelper.insertScheduledTransaction(st);
    } else {
      await _dbHelper.updateScheduledTransaction(st);
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(widget.transaction == null ? 'Nueva Agenda' : 'Editar Agenda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.primary),
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Selector de Tipo
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _reloadCategories('expense'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _type == 'expense' ? AppColors.expense.withOpacity(0.2) : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                        ),
                        child: Text(
                          'GASTO',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _type == 'expense' ? AppColors.expense : Colors.white54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _reloadCategories('income'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _type == 'income' ? AppColors.income.withOpacity(0.2) : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(11)),
                        ),
                        child: Text(
                          'INGRESO',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _type == 'income' ? AppColors.income : Colors.white54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Monto y Descripción
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: '₲ ',
              ),
              onChanged: (value) {
                // Eliminar cualquier cosa que no sea dígito
                String numericString = value.replaceAll(RegExp(r'[^0-9]'), '');
                if (numericString.isNotEmpty) {
                  // Formatear con separadores de miles
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
                if (double.tryParse(clean) == null) return 'Monto inválido';
                return null;
              },
              onSaved: (v) {
                String clean = v!.replaceAll(RegExp(r'[^0-9]'), '');
                _amount = double.parse(clean);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _description,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Descripción / Título'),
              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              onSaved: (v) => _description = v!,
            ),
            const SizedBox(height: 24),

            // Cuenta y Categoría
            DropdownButtonFormField<Account>(
              value: _selectedAccount,
              dropdownColor: AppColors.cardBackground,
              decoration: const InputDecoration(labelText: 'Cuenta'),
              items: _accounts.map((a) => DropdownMenuItem(
                value: a,
                child: Text('${a.name} (${a.currency})', style: const TextStyle(color: Colors.white)),
              )).toList(),
              onChanged: (val) => setState(() => _selectedAccount = val),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Category>(
              value: _selectedCategory,
              dropdownColor: AppColors.cardBackground,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: _categories.map((c) {
                final int colorVal = int.tryParse(c.color) ?? 0xFF9E9E9E;
                return DropdownMenuItem(
                  value: c,
                  child: Row(
                    children: [
                      Icon(_getIconData(c.icon), color: Color(colorVal)),
                      const SizedBox(width: 8),
                      Text(c.name, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _onCategoryChanged,
            ),
            if (_subcategories.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<Subcategory>(
                value: _selectedSubcategory,
                dropdownColor: AppColors.cardBackground,
                decoration: const InputDecoration(labelText: 'Subcategoría (Opcional)'),
                items: _subcategories.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.name, style: const TextStyle(color: Colors.white)),
                )).toList(),
                onChanged: (val) => setState(() => _selectedSubcategory = val),
              ),
            ],
            const SizedBox(height: 24),

            // Fecha y Frecuencia
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Próxima fecha', style: TextStyle(color: Colors.white54)),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_nextDate), style: const TextStyle(color: Colors.white, fontSize: 16)),
              trailing: const Icon(Icons.calendar_today, color: AppColors.primary),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _frequency,
              dropdownColor: AppColors.cardBackground,
              decoration: const InputDecoration(labelText: 'Frecuencia'),
              items: const [
                DropdownMenuItem(value: 'once', child: Text('Una vez', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'daily', child: Text('Diario', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'weekly', child: Text('Semanal', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'monthly', child: Text('Mensual', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'yearly', child: Text('Anual', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (val) => setState(() => _frequency = val!),
            ),
            const SizedBox(height: 24),

            // Opciones Avanzadas
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aplicar automáticamente', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Si está activo, se cargará el movimiento solo al llegar la fecha', style: TextStyle(color: Colors.white54, fontSize: 12)),
              activeColor: AppColors.primary,
              value: _autoApply,
              onChanged: (val) => setState(() => _autoApply = val),
            ),
            if (_frequency != 'once') ...[
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _totalInstallments?.toString() ?? '',
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Cantidad de Cuotas (Opcional)',
                  hintText: 'Si dejas vacío será de forma indefinida',
                ),
                onSaved: (v) {
                  if (v != null && v.isNotEmpty) {
                    _totalInstallments = int.tryParse(v);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'fastfood':
        return Icons.fastfood;
      case 'directions_car':
        return Icons.directions_car;
      case 'medical_services':
        return Icons.medical_services;
      case 'school':
        return Icons.school;
      case 'flight':
        return Icons.flight;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'receipt_long':
        return Icons.receipt_long;
      case 'attach_money':
        return Icons.attach_money;
      case 'work':
        return Icons.work;
      case 'trending_up':
        return Icons.trending_up;
      case 'shopping_bag':
      default:
        return Icons.shopping_bag;
    }
  }
}
