import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/scheduled_transaction.dart';
import '../theme.dart';
import 'add_scheduled_screen.dart';

import 'package:intl/intl.dart';

class ScheduledScreen extends StatefulWidget {
  const ScheduledScreen({super.key});

  @override
  State<ScheduledScreen> createState() => _ScheduledScreenState();
}

class _ScheduledScreenState extends State<ScheduledScreen> {
  final DBHelper _dbHelper = DBHelper();
  List<ScheduledTransaction> _scheduledList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _scheduledList = await _dbHelper.getScheduledTransactions(onlyActive: true);
    setState(() => _isLoading = false);
  }

  Future<void> _navigateToAdd() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddScheduledScreen()),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _markAsPaid(ScheduledTransaction st) async {
    setState(() => _isLoading = true);
    try {
      await _dbHelper.applyScheduledTransaction(st);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${st.description} confirmada y registrada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar: $e')),
      );
    }
    _loadData();
  }

  Future<void> _deleteItem(ScheduledTransaction st) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Eliminar', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de eliminar esta agenda?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );

    if (confirm == true && st.id != null) {
      await _dbHelper.deleteScheduledTransaction(st.id!);
      _loadData();
    }
  }

  Future<void> _editItem(ScheduledTransaction st) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddScheduledScreen(transaction: st)),
    );
    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda de Movimientos'),
        backgroundColor: AppColors.background,
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _scheduledList.isEmpty
              ? const Center(
                  child: Text('No hay movimientos programados',
                      style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _scheduledList.length,
                  itemBuilder: (context, index) {
                    final item = _scheduledList[index];
                    return Card(
                      color: AppColors.cardBackground,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () => _editItem(item),
                        onLongPress: () => _deleteItem(item),
                        leading: CircleAvatar(
                          backgroundColor: item.type == 'income'
                              ? AppColors.income.withOpacity(0.2)
                              : AppColors.expense.withOpacity(0.2),
                          child: Icon(
                            item.type == 'income'
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: item.type == 'income'
                                ? AppColors.income
                                : AppColors.expense,
                          ),
                        ),
                        title: Text(item.description,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Vence: ${item.nextDate.day}/${item.nextDate.month}/${item.nextDate.year} - ${item.frequency}',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${NumberFormat.decimalPattern('es_ES').format(item.amount)} ₲',
                              style: TextStyle(
                                color: item.type == 'income'
                                    ? AppColors.income
                                    : AppColors.expense,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (item.autoApply)
                              const Text('Automático',
                                  style: TextStyle(
                                      color: AppColors.primary, fontSize: 10))
                            else
                              InkWell(
                                onTap: () => _markAsPaid(item),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.primary),
                                  ),
                                  child: const Text('Confirmar', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
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
