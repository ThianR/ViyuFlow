import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import '../theme.dart';
import 'add_transaction_screen.dart';

/// Pestaña que lista de manera cronológica y por mes los ingresos y egresos registrados.
/// Permite filtrar, editar y eliminar transacciones individuales.
class TransactionsTab extends StatefulWidget {
  const TransactionsTab({super.key});

  @override
  State<TransactionsTab> createState() => TransactionsTabState();
}

class TransactionsTabState extends State<TransactionsTab> {
  final DBHelper _dbHelper = DBHelper();
  
  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _transactions = [];
  List<Account> _accounts = [];
  bool _isLoading = true;
  
  // Filtros de fecha (Mes/Año activo)
  late DateTime _activeMonth;
  late List<DateTime> _monthTabs;

  // Filtros de cuenta
  int? _selectedAccountId;
  String? _selectedConsolidatedCurrency;

  int? get selectedAccountId => _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _activeMonth = DateTime.now();
    _generateMonthTabs();
    reloadTransactions();
  }

  /// Genera las pestañas de meses alrededor del mes actual (anterior, actual, siguiente).
  void _generateMonthTabs() {
    final now = DateTime.now();
    _monthTabs = [
      DateTime(now.year, now.month - 1),
      DateTime(now.year, now.month),
      DateTime(now.year, now.month + 1),
    ];
  }

  /// Recarga el listado de transacciones correspondientes al mes activo.
  Future<void> reloadTransactions() async {
    setState(() => _isLoading = true);

    try {
      final monthFilter = DateFormat('yyyy-MM').format(_activeMonth);
      _accounts = await _dbHelper.getAllAccounts();
      _allTransactions = await _dbHelper.getAllTransactions(monthFilter: monthFilter);
      
      // Auto-seleccionar cuenta default si no hay selección
      if (_selectedAccountId == null && _selectedConsolidatedCurrency == null && _accounts.isNotEmpty) {
        final defaultAcc = _accounts.firstWhere((a) => a.isDefault, orElse: () => _accounts.first);
        _selectedAccountId = defaultAcc.id;
      }
      
      _applyFilters();
    } catch (e) {
      debugPrint('Error al recargar transacciones: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Permite seleccionar una cuenta específica externamente (ej. desde el Dashboard).
  void selectAccount(int accountId) {
    setState(() {
      _selectedAccountId = accountId;
      _selectedConsolidatedCurrency = null;
    });
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      if (_selectedAccountId != null) {
        _transactions = _allTransactions.where((t) => t.accountId == _selectedAccountId).toList();
      } else if (_selectedConsolidatedCurrency != null) {
        _transactions = _allTransactions.where((t) => t.accountCurrency == _selectedConsolidatedCurrency).toList();
      } else {
        _transactions = _allTransactions;
      }
      _isLoading = false;
    });
  }

  /// Calcula los montos consolidados (Ingresos y Gastos totales) del listado actual.
  Map<String, double> _calculateTotals() {
    double totalIncome = 0.0;
    double totalExpense = 0.0;
    
    for (var tx in _transactions) {
      if (tx.type == 'income') {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
      }
    }
    
    return {
      'income': totalIncome,
      'expense': totalExpense,
    };
  }

  /// Permite borrar una transacción tras confirmación del usuario.
  Future<void> _deleteTransaction(int id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('¿Eliminar movimiento?', style: TextStyle(color: Colors.white)),
        content: const Text('Esta transacción será eliminada permanentemente de tu registro local.'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.pop(context, false)),
          TextButton(
            child: const Text('Eliminar', style: TextStyle(color: AppColors.expense)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteTransaction(id);
      reloadTransactions();
    }
  }

  /// Agrupa las transacciones en base al día para pintarlas bajo separadores de fecha.
  Map<String, List<TransactionModel>> _groupTransactionsByDay() {
    Map<String, List<TransactionModel>> groups = {};
    final now = DateTime.now();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    for (var tx in _transactions) {
      String dayLabel;
      if (tx.date.year == now.year && tx.date.month == now.month && tx.date.day == now.day) {
        dayLabel = 'Hoy';
      } else if (tx.date.year == yesterday.year && tx.date.month == yesterday.month && tx.date.day == yesterday.day) {
        dayLabel = 'Ayer';
      } else {
        // Ejemplo: "19 viernes junio 2026"
        dayLabel = DateFormat("dd EEEE MMMM yyyy", "es_ES").format(tx.date);
      }

      if (!groups.containsKey(dayLabel)) {
        groups[dayLabel] = [];
      }
      groups[dayLabel]!.add(tx);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totals = _calculateTotals();
    final groupedTxs = _groupTransactionsByDay();
    String currencySymbol = '₲';
    if (_selectedAccountId != null && _accounts.isNotEmpty) {
      currencySymbol = _accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => _accounts.first).currency;
    } else if (_selectedConsolidatedCurrency != null) {
      currencySymbol = _selectedConsolidatedCurrency!;
    }

    return Column(
      children: [
        // 1. Cabecera Deslizable de Meses (Tabs)
        Container(
          height: 50,
          color: AppColors.background,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _monthTabs.map((month) {
              final isSelected = month.year == _activeMonth.year && month.month == _activeMonth.month;
              final String label = DateFormat("MMMM yyyy", "es_ES").format(month).toUpperCase();
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _activeMonth = month;
                  });
                  reloadTransactions();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // 1.5 Cabecera Deslizable de Cuentas (Filtros)
        Container(
          color: AppColors.background,
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Column(
            children: [
              // Fila de Cuentas Individuales
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    ..._accounts.map((acc) {
                      final isSelected = _selectedAccountId == acc.id;
                      return _buildAccountTab(acc.name, isSelected, () {
                        setState(() {
                          _selectedAccountId = acc.id;
                          _selectedConsolidatedCurrency = null;
                        });
                        _applyFilters();
                      });
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Fila de Consolidados por Moneda
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    ..._accounts.map((a) => a.currency).toSet().map((currency) {
                      final isSelected = _selectedConsolidatedCurrency == currency;
                      return _buildConsolidatedTab(currency, isSelected, () {
                        setState(() {
                          _selectedAccountId = null;
                          _selectedConsolidatedCurrency = currency;
                        });
                        _applyFilters();
                      });
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. Tarjetas de Resumen de Ingreso/Gasto Mensual (Diseño de captura 2)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  // Tarjeta Ingresos
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.income.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.income.withValues(alpha: 0.2), width: 1),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.income,
                            radius: 14,
                            child: Icon(Icons.arrow_upward, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Ingresos', style: TextStyle(color: Colors.grey, fontSize: 11)),
                              Text(
                                '${NumberFormat.decimalPattern('es_ES').format(totals['income']!)} $currencySymbol',
                                style: const TextStyle(color: AppColors.income, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text('${_transactions.where((t) => t.type == 'income').length} transacción', style: const TextStyle(color: Colors.grey, fontSize: 9)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Tarjeta Gastos
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.expense.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.expense.withValues(alpha: 0.2), width: 1),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.expense,
                            radius: 14,
                            child: Icon(Icons.arrow_downward, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Gastos', style: TextStyle(color: Colors.grey, fontSize: 11)),
                              Text(
                                '${NumberFormat.decimalPattern('es_ES').format(totals['expense']!)} $currencySymbol',
                                style: const TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text('${_transactions.where((t) => t.type == 'expense').length} transacciones', style: const TextStyle(color: Colors.grey, fontSize: 9)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Sección de pendientes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: AppColors.income),
                      const SizedBox(width: 6),
                      const Text('Ingresos pendientes:', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      const SizedBox(width: 4),
                      Text('0 $currencySymbol', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: AppColors.expense),
                      const SizedBox(width: 6),
                      const Text('Gastos pendientes:', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      const SizedBox(width: 4),
                      // Mock de un gasto pendiente
                      Text('1,400,000 $currencySymbol', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                ],
              )
            ],
          ),
        ),

        const Divider(height: 1, color: Colors.white12),

        // 3. Listado Agrupado
        Expanded(
          child: groupedTxs.isEmpty
              ? const Center(
                  child: Text(
                    'No hay transacciones cargadas en este mes.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  itemCount: groupedTxs.keys.length,
                  itemBuilder: (context, index) {
                    final dayLabel = groupedTxs.keys.elementAt(index);
                    final dayTxs = groupedTxs[dayLabel]!;

                    // Calcular sumatorio diario del grupo
                    double dailySum = 0.0;
                    for (var tx in dayTxs) {
                      if (tx.type == 'income') {
                        dailySum += tx.amount;
                      } else {
                        dailySum -= tx.amount;
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Separador de fecha
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dayLabel.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${dailySum > 0 ? "+" : ""}${NumberFormat.decimalPattern('es_ES').format(dailySum)} $currencySymbol',
                                style: TextStyle(
                                  color: dailySum >= 0 ? AppColors.income : AppColors.expense,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Elementos de transacciones del día
                        ...dayTxs.map((tx) {
                          final int catColorHex = int.tryParse(tx.categoryColor ?? '0xFF9E9E9E') ?? 0xFF9E9E9E;
                          final IconData catIcon = _getIconData(tx.categoryIcon ?? 'shopping_bag');

                          return Dismissible(
                            key: Key(tx.id.toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: AppColors.expense,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (direction) {
                              _dbHelper.deleteTransaction(tx.id!);
                              _transactions.remove(tx);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Movimiento eliminado.')),
                              );
                            },
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Color(catColorHex).withValues(alpha: 0.12),
                                child: Icon(catIcon, color: Color(catColorHex), size: 20),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    tx.categoryName ?? 'Sin categoría',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('HH:mm').format(tx.date),
                                    style: const TextStyle(color: AppColors.textHint, fontSize: 10),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                tx.description.isNotEmpty ? tx.description : (tx.subcategoryName ?? 'general'),
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${tx.type == 'expense' ? "-" : "+"}${NumberFormat.decimalPattern('es_ES').format(tx.amount)} $currencySymbol',
                                    style: TextStyle(
                                      color: tx.type == 'expense' ? AppColors.expense : AppColors.income,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (!tx.syncStatus) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.cloud_off, size: 12, color: AppColors.textHint),
                                  ]
                                ],
                              ),
                              onTap: () async {
                                // Navegar a edición
                                final bool? result = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddTransactionScreen(existingTransaction: tx),
                                  ),
                                );
                                if (result == true) {
                                  reloadTransactions();
                                }
                              },
                              onLongPress: () => _deleteTransaction(tx.id!),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Helper para resolver iconos de Material.
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home;
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car;
      case 'medical_services':
        return Icons.medical_services;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'school':
        return Icons.school;
      case 'payments':
        return Icons.payments;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      case 'shopping_bag':
      default:
        return Icons.shopping_bag;
    }
  }

  /// Helper para pintar una pestaña de cuenta o consolidado.
  Widget _buildAccountTab(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : Colors.white54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// Helper para pintar la pestaña de consolidado por moneda.
  Widget _buildConsolidatedTab(String currencySymbol, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white24,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              currencySymbol,
              style: TextStyle(
                color: isSelected ? AppColors.primary : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Consolidado',
              style: TextStyle(
                color: isSelected ? AppColors.primary : Colors.white54,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
