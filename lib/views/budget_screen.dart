import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../theme.dart';
import 'add_budget_screen.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final DBHelper _dbHelper = DBHelper();
  List<Map<String, dynamic>> _budgetData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final budgets = await _dbHelper.getBudgets();
    final categories = await _dbHelper.getCategoriesByType('expense');
    
    DateTime now = DateTime.now();
    List<Map<String, dynamic>> temp = [];

    for (var b in budgets) {
      double spent = await _dbHelper.calculateSpentForBudget(b, now);
      Category? cat;
      if (b.categoryId != null) {
        cat = categories.firstWhere((c) => c.id == b.categoryId, orElse: () => categories.first);
      }

      temp.add({
        'budget': b,
        'spent': spent,
        'category': cat,
      });
    }

    setState(() {
      _budgetData = temp;
      _isLoading = false;
    });
  }

  Future<void> _navigateToAdd([Budget? b]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddBudgetScreen(budget: b)),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _deleteBudget(Budget b) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Eliminar', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de eliminar este presupuesto?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );

    if (confirm == true && b.id != null) {
      await _dbHelper.deleteBudget(b.id!);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presupuestos Mensuales'),
        backgroundColor: AppColors.background,
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _budgetData.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet, size: 80, color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      const Text('No hay presupuestos activos', style: TextStyle(color: Colors.white54, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _budgetData.length,
                  itemBuilder: (context, index) {
                    final item = _budgetData[index];
                    final Budget b = item['budget'];
                    final double spent = item['spent'];
                    final Category? cat = item['category'];

                    double pct = (spent / b.amount).clamp(0.0, 1.0);
                    Color barColor = AppColors.primary;
                    if (pct >= 0.9) {
                      barColor = AppColors.expense;
                    } else if (pct >= 0.7) {
                      barColor = Colors.orange;
                    }

                    return Card(
                      color: AppColors.cardBackground,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () => _navigateToAdd(b),
                        onLongPress: () => _deleteBudget(b),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: cat != null 
                                      ? Color(int.parse(cat.color.replaceFirst('#', '0xFF'))).withValues(alpha: 0.2)
                                      : AppColors.primary.withValues(alpha: 0.2),
                                    child: Icon(
                                      cat != null ? IconData(int.parse(cat.icon), fontFamily: 'MaterialIcons') : Icons.public,
                                      color: cat != null 
                                        ? Color(int.parse(cat.color.replaceFirst('#', '0xFF')))
                                        : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cat != null ? 'Presupuesto: ${cat.name}' : 'Presupuesto Global',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text(
                                          'Restante: ${NumberFormat.decimalPattern('es_ES').format(b.amount - spent)} ${b.currency}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${NumberFormat.decimalPattern('es_ES').format(spent)} ${b.currency}', style: const TextStyle(color: Colors.white)),
                                  Text('${NumberFormat.decimalPattern('es_ES').format(b.amount)} ${b.currency}', style: const TextStyle(color: Colors.white54)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: pct,
                                backgroundColor: Colors.white10,
                                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text('${(pct * 100).toStringAsFixed(1)}%', style: TextStyle(color: barColor, fontSize: 10, fontWeight: FontWeight.bold)),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _navigateToAdd,
        child: const Icon(Icons.add),
      ),
    );
  }
}
