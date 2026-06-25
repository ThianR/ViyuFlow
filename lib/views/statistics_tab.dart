import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../theme.dart';


/// Pestaña de Estadísticas y Análisis Financiero de ViyuFlow.
/// Ofrece gráficos circulares de gastos y gráficos de barras comparativos mensuales.
class StatisticsTab extends StatefulWidget {
  const StatisticsTab({super.key});

  @override
  State<StatisticsTab> createState() => StatisticsTabState();
}

class StatisticsTabState extends State<StatisticsTab> {
  final DBHelper _dbHelper = DBHelper();
  
  bool _isLoading = true;
  String _activeMonth = '';
  String _activeCurrency = '₲';
  String _statsType = 'expense'; // 'expense' (Gastos) o 'income' (Ingresos)

  // Datos cargados para las estadísticas
  List<Map<String, dynamic>> _categoryData = [];
  Map<String, Map<String, double>> _monthlySummary = {};
  List<String> _availableCurrencies = ['₲'];

  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _activeMonth = DateFormat('yyyy-MM').format(DateTime.now());
    reloadStatistics();
  }

  /// Recarga todos los datos estadísticos y resúmenes de base de datos.
  Future<void> reloadStatistics() async {
    setState(() => _isLoading = true);

    try {
      // 1. Obtener monedas disponibles y balance
      final balances = await _dbHelper.getBalancesByCurrency();
      if (balances.isNotEmpty) {
        _availableCurrencies = balances.keys.toList();
        if (!_availableCurrencies.contains(_activeCurrency)) {
          _activeCurrency = _availableCurrencies.first;
        }
      }

      // 2. Obtener resumen mensual agregador por moneda
      _monthlySummary = await _dbHelper.getMonthlySummary(_activeMonth);

      // 3. Obtener distribución por categorías para el tipo activo
      final dist = await _dbHelper.getExpenseDistributionByCategory(_activeMonth, _activeCurrency);
      
      // Si el tipo activo es de ingresos, consultamos directamente
      if (_statsType == 'income') {
        final db = await _dbHelper.database;
        final rawIncomes = await db.rawQuery('''
          SELECT c.name as category_name, c.color as category_color, c.icon as category_icon,
                 SUM(t.amount) as total, COUNT(t.id) as transaction_count
          FROM transactions t
          INNER JOIN categories c ON t.category_id = c.id
          INNER JOIN accounts a ON t.account_id = a.id
          WHERE t.date LIKE ? AND a.currency = ? AND t.type = 'income'
          GROUP BY c.id
          ORDER BY total DESC
        ''', ['$_activeMonth%', _activeCurrency]);
        _categoryData = rawIncomes;
      } else {
        _categoryData = dist;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error al recargar estadísticas: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Retorna el sumatorio de montos de la categoría activa.
  double _calculateTotalSum() {
    double sum = 0.0;
    for (var item in _categoryData) {
      sum += (item['total'] as num).toDouble();
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final double totalSum = _calculateTotalSum();
    final monthLabel = DateFormat("MMMM yyyy", "es_ES").format(DateTime.parse('$_activeMonth-01')).toUpperCase();

    // Sumarios de la tarjeta superior
    final currentSummary = _monthlySummary[_activeCurrency] ?? {'income': 0.0, 'expense': 0.0};
    final double netBalance = currentSummary['income']! - currentSummary['expense']!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabecera de Mes y Selector de Tipo de Moneda
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthLabel,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (_availableCurrencies.length > 1)
                DropdownButton<String>(
                  dropdownColor: AppColors.cardBackground,
                  value: _activeCurrency,
                  items: _availableCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _activeCurrency = val;
                      });
                      reloadStatistics();
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Tarjeta Balance General del Mes (Captura 4)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                const Text('Balance general', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${netBalance >= 0 ? "+" : ""}${NumberFormat.decimalPattern('es_ES').format(netBalance)} $_activeCurrency',
                      style: TextStyle(
                        color: netBalance >= 0 ? AppColors.income : AppColors.expense,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      netBalance >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      color: netBalance >= 0 ? AppColors.income : AppColors.expense,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Selectores de Categoría: GASTOS / INGRESOS (Botones encapsulados)
          Row(
            children: [
              _buildTypeSelector('expense', 'GASTOS', AppColors.expense),
              const SizedBox(width: 12),
              _buildTypeSelector('income', 'INGRESOS', AppColors.income),
            ],
          ),
          const SizedBox(height: 24),

          // 4. Gráfico de Torta / Torta de Categorías (Captura 3)
          if (_categoryData.isNotEmpty) ...[
            Center(
              child: SizedBox(
                height: 180,
                width: 180,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 4,
                    centerSpaceRadius: 55,
                    sections: _getPieSections(totalSum),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 5. Leyenda y desglose del porcentaje de categorías (Captura 3)
            const Text('Resumen por categoría', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _categoryData.length,
              itemBuilder: (context, index) {
                final item = _categoryData[index];
                final double total = (item['total'] as num).toDouble();
                final double pct = totalSum > 0 ? (total / totalSum) * 100 : 0.0;
                
                final int colorHex = int.tryParse(item['category_color'] ?? '0xFF9E9E9E') ?? 0xFF9E9E9E;
                final IconData catIcon = _getIconData(item['category_icon'] ?? 'shopping_bag');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Color(colorHex).withValues(alpha: 0.12),
                        child: Icon(catIcon, color: Color(colorHex), size: 18),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['category_name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('${item['transaction_count']} transacción', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${NumberFormat.decimalPattern('es_ES').format(total)} $_activeCurrency',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: Text('No hay datos en este período para graficar.', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // 6. Gráfico de Comparación Mensual (Gráfico de barras de captura 4)
          const Text('Gráfico de comparación', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            height: 180,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: totalSum > 0 ? totalSum * 1.2 : 6000000,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // Barra limpia sin decimales laterales
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        const months = ['Nov', 'Dic', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun'];
                        if (val.toInt() >= 0 && val.toInt() < months.length) {
                          return Text(months[val.toInt()], style: const TextStyle(color: Colors.grey, fontSize: 10));
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _buildBarGroup(0, 0),
                  _buildBarGroup(1, 0),
                  _buildBarGroup(2, 0),
                  _buildBarGroup(3, 0),
                  _buildBarGroup(4, 0),
                  _buildBarGroup(5, 0),
                  _buildBarGroup(6, 0),
                  // En junio (último mes) pintamos el valor real acumulado del total
                  _buildBarGroup(7, totalSum),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Construye un grupo de barras individual para el gráfico de comparación mensual.
  BarChartGroupData _buildBarGroup(int x, double val) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: val,
          color: _statsType == 'expense' ? AppColors.expense : AppColors.income,
          width: 14,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 6000000,
            color: Colors.white.withValues(alpha: 0.03),
          ),
        ),
      ],
    );
  }

  /// Crea las secciones del gráfico circular con porcentajes interactivos.
  List<PieChartSectionData> _getPieSections(double totalSum) {
    if (totalSum <= 0) return [];

    return List.generate(_categoryData.length, (i) {
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 30.0 : 20.0;
      
      final item = _categoryData[i];
      final double total = (item['total'] as num).toDouble();
      final double pct = (total / totalSum) * 100;
      
      final int colorHex = int.tryParse(item['category_color'] ?? '0xFF9E9E9E') ?? 0xFF9E9E9E;

      return PieChartSectionData(
        color: Color(colorHex),
        value: total,
        title: isTouched ? '${pct.toStringAsFixed(0)}%' : '',
        radius: radius,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }

  /// Helper de botón de selección de tipo de estadística (Gasto/Ingreso).
  Widget _buildTypeSelector(String type, String label, Color activeColor) {
    final isSelected = _statsType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _statsType = type;
          });
          reloadStatistics();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.15) : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : Colors.grey.shade800,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? activeColor : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  /// Helper de resolución de iconos.
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
}
