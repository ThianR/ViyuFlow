import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/subcategory.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../services/nlp_parser.dart';
import '../theme.dart';
import '../widgets/custom_keypad.dart';

/// Pantalla para registrar una nueva transacción (ingreso o gasto) o editar una existente.
/// También soporta la carga inicial desde la interpretación de comandos por voz.
class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? existingTransaction;
  final ParsedResult? voiceResult;
  final int? preselectedAccountId;

  const AddTransactionScreen({
    super.key,
    this.existingTransaction,
    this.voiceResult,
    this.preselectedAccountId,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final DBHelper _dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();

  // Estados de los campos
  String _transactionType = 'expense'; // 'expense' o 'income'
  double _amount = 0.0;
  String _expression = '0';
  String _description = '';
  DateTime _selectedDate = DateTime.now();

  Account? _selectedAccount;
  Category? _selectedCategory;
  Subcategory? _selectedSubcategory;

  // Catálogos cargados de la base de datos
  List<Account> _accounts = [];
  List<Category> _categories = [];
  List<Subcategory> _subcategories = [];

  bool _isLoading = true;
  bool _showKeypad = true;

  
  String? _budgetMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  /// Carga los catálogos y precarga datos si viene de edición o comando de voz.
  Future<void> _loadInitialData() async {
    try {
      _accounts = await _dbHelper.getAllAccounts();
      
      // Aplicar tipo inicial
      if (widget.existingTransaction != null) {
        _transactionType = widget.existingTransaction!.type;
      } else if (widget.voiceResult != null) {
        _transactionType = widget.voiceResult!.type;
      }

      _categories = await _dbHelper.getCategoriesByType(_transactionType);

      // Precargar si es EDICIÓN
      if (widget.existingTransaction != null) {
        final t = widget.existingTransaction!;
        _amount = t.amount;
        _expression = _amount.toStringAsFixed(0).replaceAll('.0', '');
        _description = t.description;
        _selectedDate = t.date;
        _selectedAccount = _accounts.firstWhere((a) => a.id == t.accountId, orElse: () => _accounts.first);
        _selectedCategory = _categories.firstWhere((c) => c.id == t.categoryId, orElse: () => _categories.first);
        if (t.subcategoryId != null) {
          _subcategories = await _dbHelper.getSubcategoriesByCategory(_selectedCategory!.id!);
          _selectedSubcategory = _subcategories.firstWhere((s) => s.id == t.subcategoryId, orElse: () => _subcategories.first);
        }
      } 
      // Precargar si es RESULTADO DE VOZ
      else if (widget.voiceResult != null) {
        final r = widget.voiceResult!;
        _amount = r.amount ?? 0.0;
        _expression = _amount > 0 ? _amount.toStringAsFixed(0).replaceAll('.0', '') : '0';
        _description = r.description;
        _selectedDate = r.date;
        
        // Mapear cuenta de voz
        if (r.account != null) {
          _selectedAccount = _accounts.firstWhere((a) => a.id == r.account!.id, orElse: () => _accounts.first);
        }
        // Mapear categoría de voz
        if (r.category != null) {
          _selectedCategory = _categories.firstWhere((c) => c.id == r.category!.id, orElse: () => _categories.first);
        }
        // Mapear subcategoría de voz
        if (r.subcategory != null && _selectedCategory != null) {
          _subcategories = await _dbHelper.getSubcategoriesByCategory(_selectedCategory!.id!);
          _selectedSubcategory = _subcategories.firstWhere((s) => s.id == r.subcategory!.id, orElse: () => _subcategories.first);
        }
      }

      // Si no hay selecciones previas, aplicar preselección o cuenta por defecto
      if (_selectedAccount == null && _accounts.isNotEmpty) {
        if (widget.preselectedAccountId != null) {
          _selectedAccount = _accounts.firstWhere((a) => a.id == widget.preselectedAccountId, orElse: () => _accounts.first);
        } else {
          _selectedAccount = _accounts.firstWhere((a) => a.isDefault, orElse: () => _accounts.first);
        }
      }
      if (_selectedCategory == null && _categories.isNotEmpty) {
        _selectedCategory = _categories.first;
        _subcategories = await _dbHelper.getSubcategoriesByCategory(_selectedCategory!.id!);
        if (_subcategories.isNotEmpty) {
          _selectedSubcategory = _subcategories.first;
        }
      }
      
      await _checkBudget();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error al cargar datos en formulario: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Cambia el tipo de movimiento (ingreso/egreso) y recarga las categorías asociadas.
  Future<void> _changeTransactionType(String type) async {
    setState(() {
      _transactionType = type;
      _isLoading = true;
    });

    _categories = await _dbHelper.getCategoriesByType(type);
    if (_categories.isNotEmpty) {
      _selectedCategory = _categories.first;
      _subcategories = await _dbHelper.getSubcategoriesByCategory(_selectedCategory!.id!);
      _selectedSubcategory = _subcategories.isNotEmpty ? _subcategories.first : null;
    } else {
      _selectedCategory = null;
      _selectedSubcategory = null;
      _subcategories = [];
    }

    await _checkBudget();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _checkBudget() async {
    if (_selectedCategory == null || _selectedAccount == null || _transactionType != 'expense') {
      setState(() => _budgetMessage = null);
      return;
    }

    final budgets = await _dbHelper.getBudgets();
    Budget? activeBudget;
    
    for (var b in budgets) {
      if (b.currency == _selectedAccount!.currency) {
        if (b.categoryId == _selectedCategory!.id) {
          activeBudget = b;
          break;
        }
      }
    }

    if (activeBudget == null) {
      setState(() => _budgetMessage = null);
      return;
    }

    double spent = await _dbHelper.calculateSpentForBudget(activeBudget, DateTime.now());
    double remaining = activeBudget.amount - spent;
    
    setState(() {
      final formatted = NumberFormat.decimalPattern('es_ES').format(remaining);
      _budgetMessage = 'Presupuesto restante: $formatted ${activeBudget!.currency}';
    });
  }

  /// Al cambiar la categoría principal, carga y actualiza las subcategorías correspondientes.
  Future<void> _onCategoryChanged(Category? newCategory) async {
    if (newCategory == null) return;
    setState(() {
      _selectedCategory = newCategory;
      _subcategories = [];
      _selectedSubcategory = null;
    });

    final subcats = await _dbHelper.getSubcategoriesByCategory(newCategory.id!);
    setState(() {
      _subcategories = subcats;
      if (subcats.isNotEmpty) {
        _selectedSubcategory = subcats.first;
      }
    });
  }

  /// Abre un DatePicker para seleccionar la fecha de la transacción.
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.cardBackground,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Valida los datos y guarda la transacción en SQLite (inserción o actualización).
  Future<void> _saveTransaction() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa un monto válido mayor a 0.'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    if (_selectedAccount == null || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona una cuenta y categoría.'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    // Si es edición, conservamos el ID original
    final transaction = TransactionModel(
      id: widget.existingTransaction?.id,
      accountId: _selectedAccount!.id!,
      categoryId: _selectedCategory!.id!,
      subcategoryId: _selectedSubcategory?.id,
      amount: _amount,
      description: _description.trim(),
      date: _selectedDate,
      type: _transactionType,
      syncStatus: false, // Se marca como pendiente de sincronizar
    );

    try {
      if (widget.existingTransaction == null) {
        await _dbHelper.insertTransaction(transaction);
      } else {
        await _dbHelper.updateTransaction(transaction);
      }

      Navigator.pop(context, true); // Devuelve 'true' para refrescar el feed
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  /// Formatea el monto para quitar el .0 si es entero, y añade separador de miles
  String _formatAmount(double amt) {
    if (amt == amt.truncateToDouble()) {
      return NumberFormat.decimalPattern('es_ES').format(amt.toInt());
    } else {
      return NumberFormat.decimalPattern('es_ES').format(amt);
    }
  }

  /// Formatea la expresión matemática, añadiendo separador de miles a todos los números
  String _formatExpression(String expr) {
    if (expr == '0') return '0';
    return expr.replaceAllMapped(RegExp(r'\d+(?:\.\d+)?'), (match) {
      final double? number = double.tryParse(match.group(0)!);
      if (number == null) return match.group(0)!;
      if (number == number.truncateToDouble()) {
        return NumberFormat.decimalPattern('es_ES').format(number.toInt());
      } else {
        return NumberFormat.decimalPattern('es_ES').format(number);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final String currencySymbol = _selectedAccount?.currency ?? '₲';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingTransaction == null ? 'Nueva Transacción' : 'Editar Transacción'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveTransaction,
          ),
        ],
      ),
      body: Column(
        children: [
          // Sección superior scrollable del formulario
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Selector de Tipo (Gasto / Ingreso)
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _changeTransactionType('expense'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _transactionType == 'expense'
                                    ? AppColors.expense.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: _transactionType == 'expense' ? AppColors.expense : Colors.grey.shade800,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                              ),
                              child: Text(
                                'GASTO',
                                style: TextStyle(
                                  color: _transactionType == 'expense' ? AppColors.expense : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _changeTransactionType('income'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _transactionType == 'income'
                                    ? AppColors.income.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: _transactionType == 'income' ? AppColors.income : Colors.grey.shade800,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              child: Text(
                                'INGRESO',
                                style: TextStyle(
                                  color: _transactionType == 'income' ? AppColors.income : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 2. Visualización del Monto y Calculadora
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showKeypad = true;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _showKeypad ? AppColors.primary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Expresión: ${_formatExpression(_expression)}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatAmount(_amount)} $currencySymbol',
                              style: TextStyle(
                                color: _transactionType == 'expense' ? AppColors.expense : AppColors.income,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. Selector de Cuenta
                    const Text('Cuenta', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Account>(
                          value: _selectedAccount,
                          dropdownColor: AppColors.cardBackground,
                          isExpanded: true,
                          hint: const Text('Seleccionar cuenta'),
                          items: _accounts.map((acc) {
                            final int colorVal = int.tryParse(acc.color) ?? 0xFF0F52BA;
                            return DropdownMenuItem<Account>(
                              value: acc,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 8,
                                    backgroundColor: Color(colorVal),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(acc.name),
                                  const Spacer(),
                                  Text(acc.currency, style: const TextStyle(color: AppColors.textSecondary)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (acc) async {
                            setState(() {
                              _selectedAccount = acc;
                            });
                            await _checkBudget();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Selector de Categoría
                    const Text('Categoría', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Category>(
                          value: _selectedCategory,
                          dropdownColor: AppColors.cardBackground,
                          isExpanded: true,
                          hint: const Text('Seleccionar categoría'),
                          items: _categories.map((cat) {
                            final int colorVal = int.tryParse(cat.color) ?? 0xFF9E9E9E;
                            return DropdownMenuItem<Category>(
                              value: cat,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Color(colorVal).withValues(alpha: 0.2),
                                    child: Icon(
                                      _getIconData(cat.icon),
                                      size: 14,
                                      color: Color(colorVal),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(cat.name),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: _onCategoryChanged,
                        ),
                      ),
                    ),
                    if (_budgetMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 12),
                        child: Text(_budgetMessage!, style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(height: 16),

                    // 5. Selector de Subcategoría (Solo si hay disponibles)
                    if (_subcategories.isNotEmpty) ...[
                      const Text('Subcategoría', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Subcategory>(
                            value: _selectedSubcategory,
                            dropdownColor: AppColors.cardBackground,
                            isExpanded: true,
                            hint: const Text('Ninguna subcategoría'),
                            items: _subcategories.map((sub) {
                              return DropdownMenuItem<Subcategory>(
                                value: sub,
                                child: Text(sub.name),
                              );
                            }).toList(),
                            onChanged: (sub) {
                              setState(() {
                                _selectedSubcategory = sub;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 6. Selector de Fecha y Notas
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Fecha', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _selectDate(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardBackground,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('dd MMM, yyyy').format(_selectedDate),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 7. Campo de Nota/Descripción
                    const Text('Descripción', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _description,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Agregar un detalle (ej. Compras semanales)',
                      ),
                      onChanged: (val) {
                        setState(() {
                          _description = val;
                        });
                      },
                      onTap: () {
                        // Ocultar el teclado de la calculadora cuando el usuario escribe texto
                        setState(() {
                          _showKeypad = false;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // Teclado numérico in-app (se muestra en la mitad inferior de forma fija si está activo)
          if (_showKeypad)
            CustomKeypad(
              initialValue: _expression,
              onValueChanged: (exp, val) {
                setState(() {
                  _expression = exp.isEmpty ? '0' : exp;
                  _amount = double.tryParse(val) ?? 0.0;
                });
              },
              onSubmitted: _saveTransaction,
            ),
        ],
      ),
    );
  }

  /// Retorna el icono del sistema Material Icons a partir del string guardado.
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'home': return Icons.home;
      case 'restaurant': return Icons.restaurant;
      case 'directions_car': return Icons.directions_car;
      case 'medical_services': return Icons.medical_services;
      case 'sports_esports': return Icons.sports_esports;
      case 'school': return Icons.school;
      case 'payments': return Icons.payments;
      case 'account_balance_wallet': return Icons.account_balance_wallet;
      case 'flight': return Icons.flight;
      case 'local_grocery_store': return Icons.local_grocery_store;
      case 'pets': return Icons.pets;
      case 'fitness_center': return Icons.fitness_center;
      case 'checkroom': return Icons.checkroom;
      case 'local_gas_station': return Icons.local_gas_station;
      case 'phone_iphone': return Icons.phone_iphone;
      case 'theaters': return Icons.theaters;
      case 'wifi': return Icons.wifi;
      case 'water_drop': return Icons.water_drop;
      case 'bolt': return Icons.bolt;
      case 'tv': return Icons.tv;
      case 'train': return Icons.train;
      case 'pedal_bike': return Icons.pedal_bike;
      case 'local_cafe': return Icons.local_cafe;
      case 'fastfood': return Icons.fastfood;
      case 'work': return Icons.work;
      case 'laptop_mac': return Icons.laptop_mac;
      case 'menu_book': return Icons.menu_book;
      case 'savings': return Icons.savings;
      case 'credit_card': return Icons.credit_card;
      case 'shopping_bag':
      default:
        return Icons.shopping_bag;
    }
  }
}
