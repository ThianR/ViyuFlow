import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../theme.dart';
import 'scheduled_screen.dart';
import 'budget_screen.dart';
import 'package:intl/intl.dart';
import 'package:intl/intl.dart';

/// Pestaña de Billetera que muestra el saldo general, la lista de cuentas
/// y un gráfico de evolución temporal de los saldos.
class AccountsTab extends StatefulWidget {
  final void Function(int accountId)? onAccountSelected;

  const AccountsTab({super.key, this.onAccountSelected});

  @override
  State<AccountsTab> createState() => AccountsTabState();
}

class AccountsTabState extends State<AccountsTab> {
  final DBHelper _dbHelper = DBHelper();
  
  List<Account> _accounts = [];
  Map<String, double> _balances = {};
  Map<int, double> _accountBalances = {};
  bool _isLoading = true;
  String _selectedPeriod = '30 días'; // '7 días', '30 días', 'Último año'
  String _activeCurrency = '₲'; // Moneda de visualización activa

  @override
  void initState() {
    super.initState();
    reloadAccounts();
  }

  /// Recarga las cuentas y balances agregados desde la base de datos local.
  Future<void> reloadAccounts() async {
    setState(() => _isLoading = true);
    
    try {
      final accList = await _dbHelper.getAllAccounts();
      final balMap = await _dbHelper.getBalancesByCurrency();
      final accBalMap = await _dbHelper.getBalancesByAccountId();

      setState(() {
        _accounts = accList;
        _balances = balMap;
        _accountBalances = accBalMap;
        if (balMap.isNotEmpty && !balMap.containsKey(_activeCurrency)) {
          _activeCurrency = balMap.keys.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error al recargar cuentas: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Crea una nueva cuenta rápida con datos aleatorios de colores y nombre.
  Future<void> _createQuickAccount() async {
    final TextEditingController nameController = TextEditingController();
    String currency = '₲';
    String colorHex = '0xFF0052D4'; // Degradado azul por defecto
    bool isDefault = false;

    final Map<String, String> gradients = {
      'Azul': '0xFF0052D4',
      'Púrpura': '0xFF800080',
      'Verde': '0xFF11998E',
      'Naranja': '0xFFF12711'
    };

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              title: const Text('Nueva Cuenta', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Nombre de la cuenta (ej. Coop. Universitaria)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Moneda:', style: TextStyle(color: Colors.white)),
                      DropdownButton<String>(
                        dropdownColor: AppColors.cardBackground,
                        value: currency,
                        items: const [
                          DropdownMenuItem(value: '₲', child: Text('Guaraníes (₲)')),
                          DropdownMenuItem(value: '\$', child: Text('Dólares (\$)')),
                          DropdownMenuItem(value: '€', child: Text('Euros (€)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => currency = val);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Estilo visual:', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: gradients.entries.map((entry) {
                      final isSelected = colorHex == entry.value;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() => colorHex = entry.value);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Text(entry.key, style: const TextStyle(fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cuenta Principal', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('Será la predeterminada al registrar movimientos', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    value: isDefault,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setDialogState(() => isDefault = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: const Text('Crear', style: TextStyle(color: AppColors.income)),
                  onPressed: () async {
                    if (nameController.text.trim().isNotEmpty) {
                      final newAccount = Account(
                        name: nameController.text.trim(),
                        currency: currency,
                        color: colorHex,
                        isDefault: isDefault,
                      );
                      await _dbHelper.insertAccount(newAccount);
                      Navigator.pop(context);
                      reloadAccounts();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Muestra un menú de opciones para una cuenta existente.
  void _showAccountOptions(Account acc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text('Editar Cuenta', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _editAccount(acc);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.expense),
                title: const Text('Eliminar Cuenta', style: TextStyle(color: AppColors.expense)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteAccount(acc);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Permite modificar los detalles de una cuenta existente.
  Future<void> _editAccount(Account account) async {
    final TextEditingController nameController = TextEditingController(text: account.name);
    String currency = account.currency;
    String colorHex = account.color;
    bool isDefault = account.isDefault;

    final Map<String, String> gradients = {
      'Azul': '0xFF0052D4',
      'Púrpura': '0xFF800080',
      'Verde': '0xFF11998E',
      'Naranja': '0xFFF12711'
    };

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              title: const Text('Editar Cuenta', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Nombre de la cuenta',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Moneda:', style: TextStyle(color: Colors.white)),
                      DropdownButton<String>(
                        dropdownColor: AppColors.cardBackground,
                        value: ['₲', '\$', '€'].contains(currency) ? currency : '₲',
                        items: const [
                          DropdownMenuItem(value: '₲', child: Text('Guaraníes (₲)')),
                          DropdownMenuItem(value: '\$', child: Text('Dólares (\$)')),
                          DropdownMenuItem(value: '€', child: Text('Euros (€)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => currency = val);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Estilo visual:', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: gradients.entries.map((entry) {
                      final isSelected = colorHex == entry.value;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() => colorHex = entry.value);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Text(entry.key, style: const TextStyle(fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cuenta Principal', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('Será la predeterminada al registrar movimientos', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    value: isDefault,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setDialogState(() => isDefault = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: const Text('Guardar', style: TextStyle(color: AppColors.income)),
                  onPressed: () async {
                    if (nameController.text.trim().isNotEmpty) {
                      final updatedAccount = account.copyWith(
                        name: nameController.text.trim(),
                        currency: currency,
                        color: colorHex,
                        isDefault: isDefault,
                      );
                      await _dbHelper.updateAccount(updatedAccount);
                      Navigator.pop(context);
                      reloadAccounts();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Muestra diálogo de confirmación para eliminar una cuenta de forma lógica.
  Future<void> _confirmDeleteAccount(Account acc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('¿Eliminar cuenta?'),
        content: Text('Esto ocultará la cuenta "${acc.name}". Las transacciones ya registradas no se perderán.'),
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
      await _dbHelper.deleteAccount(acc.id!);
      reloadAccounts();
    }
  }
  List<Color> _getGradient(String colorHex) {
    switch (colorHex) {
      case '0xFF800080':
        return AppColors.gradientPurple;
      case '0xFF11998E':
        return AppColors.gradientGreen;
      case '0xFFF12711':
        return AppColors.gradientOrange;
      case '0xFF0052D4':
      default:
        return AppColors.gradientBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Buscar cuenta principal (default)
    final defaultAccount = _accounts.firstWhere(
      (acc) => acc.isDefault, 
      orElse: () => _accounts.isNotEmpty ? _accounts.first : Account(name: 'Sin Cuenta', currency: '₲', color: '0xFF0052D4')
    );
    final double mainBalance = _accountBalances[defaultAccount.id] ?? 0.0;
    final double activeBalance = _balances[_activeCurrency] ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Tarjeta Superior: Saldo de la Cuenta Principal
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0A2540), Color(0xFF0052D4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saldo de ${defaultAccount.name}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    if (defaultAccount.isDefault)
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${NumberFormat.decimalPattern('es_ES').format(mainBalance)} ${defaultAccount.currency}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.income.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_upward, color: AppColors.income, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '+${mainBalance > 0 ? NumberFormat.decimalPattern('es_ES').format(mainBalance) : "0"} ${defaultAccount.currency}',
                            style: const TextStyle(
                              color: AppColors.income,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Botón Añadir Cuenta rápido
                InkWell(
                  onTap: _createQuickAccount,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('Agregar cuenta', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Selectores de Filtro de Moneda Activa (si hay varias monedas)
          if (_balances.keys.length > 1) ...[
            const Text('Filtrar por Moneda', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: _balances.keys.map((curr) {
                final isSelected = curr == _activeCurrency;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(curr == '₲' ? 'Guaraníes (₲)' : curr == '\$' ? 'Dólares (\$)' : curr),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.cardBackground,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _activeCurrency = curr;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // 3. Carrusel Horizontal de Cuentas del Usuario
          Row(
            children: [
              const Text('Mis Cuentas', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              const Text('(Mantén presionado para editar)', style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _accounts.length,
              itemBuilder: (context, index) {
                final acc = _accounts[index];
                final grad = _getGradient(acc.color);
                
                return GestureDetector(
                  onTap: () => widget.onAccountSelected?.call(acc.id!),
                  onLongPress: () => _showAccountOptions(acc),
                  child: Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: grad,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          acc.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(Icons.wallet, color: Colors.white70, size: 20),
                            Text(
                              '${_accountBalances[acc.id!] != null ? NumberFormat.decimalPattern('es_ES').format(_accountBalances[acc.id!]) : "0"} ${acc.currency}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // 4. Selector de Período del Gráfico de Evolución
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Evolución de Saldo', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    children: ['7 días', '30 días', 'Último año'].map((p) {
                      final isSelected = p == _selectedPeriod;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: ChoiceChip(
                          label: Text(p, style: const TextStyle(fontSize: 10)),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.cardBackground,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedPeriod = p;
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 5. Gráfico de Línea de Evolución del Balance
          Container(
            height: 200,
            padding: const EdgeInsets.only(right: 20, top: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return const Text('');
                        // Formatear montos grandes en 'm' o 'k'
                        if (val >= 1000000) {
                          return Text('${(val / 1000000).toStringAsFixed(0)}m', style: const TextStyle(color: Colors.grey, fontSize: 10));
                        } else if (val >= 1000) {
                          return Text('${(val / 1000).toStringAsFixed(0)}k', style: const TextStyle(color: Colors.grey, fontSize: 10));
                        }
                        return Text(val.toStringAsFixed(0), style: const TextStyle(color: Colors.grey, fontSize: 10));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        // Pintamos marcas de días simuladas
                        switch (val.toInt()) {
                          case 1:
                            return const Text('16', style: TextStyle(color: Colors.grey, fontSize: 10));
                          case 4:
                            return const Text('18', style: TextStyle(color: Colors.grey, fontSize: 10));
                          case 7:
                            return const Text('20', style: TextStyle(color: Colors.grey, fontSize: 10));
                          case 10:
                            return const Text('22', style: TextStyle(color: Colors.grey, fontSize: 10));
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _getDummyChartSpots(activeBalance),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.orange,
                        strokeWidth: 1.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 5. Consolidación de Cuentas por Moneda
          const Text('Consolidación por Moneda', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_balances.isEmpty)
            const Text('No hay saldos registrados', style: TextStyle(color: Colors.white38)),
          ..._balances.entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary.withOpacity(0.2),
                        child: Text(entry.key, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Text('Saldo Total en ${entry.key}', style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  Text(
                    '${NumberFormat.decimalPattern('es_ES').format(entry.value)} ${entry.key}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            );
          }).toList(),

          const SizedBox(height: 24),

          // 6. Elementos Visuales Secundarios (Presupuestos, Agenda, Deudas)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BudgetScreen()),
              );
            },
            child: _buildSummaryCard('Presupuestos', 'Ver detalles', Icons.pie_chart, AppColors.income, null),
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            'Agenda de Pagos y Deudas', 
            'Gestiona tus pagos programados e ingresos recurrentes', 
            Icons.calendar_month, 
            AppColors.primary,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ScheduledScreen()),
            ).then((_) => reloadAccounts()),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// Retorna coordenadas de puntos para pintar el gráfico de balance dinámico.
  List<FlSpot> _getDummyChartSpots(double activeBalance) {
    if (activeBalance <= 0) {
      return const [
        FlSpot(0, 0),
        FlSpot(3, 0),
        FlSpot(7, 0),
        FlSpot(10, 0),
      ];
    }
    // Generamos una curva ascendente de muestra cuyo pico es el balance actual
    return [
      FlSpot(0, activeBalance * 0.4),
      FlSpot(3, activeBalance * 0.65),
      FlSpot(7, activeBalance * 0.5),
      FlSpot(10, activeBalance),
    ];
  }

  /// Helper para pintar tarjetas de resúmenes financieros adicionales.
  Widget _buildSummaryCard(String title, String subtitle, IconData icon, Color accentColor, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
