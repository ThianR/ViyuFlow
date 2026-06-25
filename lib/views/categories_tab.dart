import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/category.dart';
import '../models/subcategory.dart';
import '../theme.dart';

/// Pestaña de administración de categorías y subcategorías.
/// Permite visualizar, añadir y eliminar categorías e inicializar subcategorías.
class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key});

  @override
  State<CategoriesTab> createState() => CategoriesTabState();
}

class CategoriesTabState extends State<CategoriesTab> {
  final DBHelper _dbHelper = DBHelper();
  
  String _activeTab = 'expense'; // 'expense' (Gastos) o 'income' (Ingresos)
  List<Category> _categories = [];
  bool _isLoading = true;
  
  // Mapa para controlar qué categorías están expandidas mostrando sus subcategorías
  final Map<int, bool> _expandedCategories = {};
  // Mapa de subcategorías cargadas por categoría ID
  final Map<int, List<Subcategory>> _subcategoriesMap = {};

  @override
  void initState() {
    super.initState();
    reloadCategories();
  }

  /// Carga las categorías asociadas al tipo activo.
  Future<void> reloadCategories() async {
    setState(() => _isLoading = true);

    try {
      final cats = await _dbHelper.getCategoriesByType(_activeTab);
      
      // Limpiar y precargar subcategorías para las que estén expandidas
      for (var cat in cats) {
        if (_expandedCategories[cat.id!] == true) {
          final subcats = await _dbHelper.getSubcategoriesByCategory(cat.id!);
          _subcategoriesMap[cat.id!] = subcats;
        }
      }

      setState(() {
        _categories = cats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error al recargar categorías: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Alterna la expansión de una categoría para ver y editar sus subcategorías.
  Future<void> _toggleCategoryExpansion(int categoryId) async {
    final isExpanded = _expandedCategories[categoryId] ?? false;
    
    if (!isExpanded) {
      // Cargar subcategorías antes de expandir
      final subcats = await _dbHelper.getSubcategoriesByCategory(categoryId);
      setState(() {
        _subcategoriesMap[categoryId] = subcats;
        _expandedCategories[categoryId] = true;
      });
    } else {
      setState(() {
        _expandedCategories[categoryId] = false;
      });
    }
  }

  /// Crea una nueva categoría mediante un cuadro de diálogo interactivo.
  Future<void> _createNewCategory() async {
    final TextEditingController nameController = TextEditingController();
    String iconName = 'shopping_bag';
    String colorHex = '0xFFFF5252';

    final List<Map<String, dynamic>> icons = [
      {'name': 'shopping_bag', 'icon': Icons.shopping_bag},
      {'name': 'home', 'icon': Icons.home},
      {'name': 'restaurant', 'icon': Icons.restaurant},
      {'name': 'directions_car', 'icon': Icons.directions_car},
      {'name': 'medical_services', 'icon': Icons.medical_services},
      {'name': 'sports_esports', 'icon': Icons.sports_esports},
      {'name': 'school', 'icon': Icons.school},
      {'name': 'payments', 'icon': Icons.payments},
      {'name': 'flight', 'icon': Icons.flight},
      {'name': 'local_grocery_store', 'icon': Icons.local_grocery_store},
      {'name': 'pets', 'icon': Icons.pets},
      {'name': 'fitness_center', 'icon': Icons.fitness_center},
      {'name': 'checkroom', 'icon': Icons.checkroom},
      {'name': 'local_gas_station', 'icon': Icons.local_gas_station},
      {'name': 'phone_iphone', 'icon': Icons.phone_iphone},
      {'name': 'theaters', 'icon': Icons.theaters},
      {'name': 'wifi', 'icon': Icons.wifi},
      {'name': 'water_drop', 'icon': Icons.water_drop},
      {'name': 'bolt', 'icon': Icons.bolt},
      {'name': 'tv', 'icon': Icons.tv},
      {'name': 'train', 'icon': Icons.train},
      {'name': 'pedal_bike', 'icon': Icons.pedal_bike},
      {'name': 'local_cafe', 'icon': Icons.local_cafe},
      {'name': 'fastfood', 'icon': Icons.fastfood},
      {'name': 'work', 'icon': Icons.work},
      {'name': 'laptop_mac', 'icon': Icons.laptop_mac},
      {'name': 'menu_book', 'icon': Icons.menu_book},
      {'name': 'savings', 'icon': Icons.savings},
      {'name': 'credit_card', 'icon': Icons.credit_card},
    ];

    final List<String> colors = [
      '0xFFFF5252', // Rojo
      '0xFFFF9800', // Naranja
      '0xFF29B6F6', // Azul cian
      '0xFF00E676', // Verde
      '0xFFE040FB', // Púrpura
      '0xFF673AB7', // Violeta profundo
      '0xFF00B0FF', // Azul claro
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              title: const Text('Nueva Categoría', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(hintText: 'Nombre de categoría'),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Icono:', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(height: 8),
                    // Rejilla de iconos
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: icons.map((item) {
                        final isSelected = iconName == item['name'];
                        return GestureDetector(
                          onTap: () => setDialogState(() => iconName = item['name'] as String),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: isSelected ? AppColors.primary : Colors.white10,
                            child: Icon(item['icon'] as IconData, size: 18, color: isSelected ? Colors.white : Colors.grey),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Color:', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(height: 8),
                    // Rejilla de colores
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: colors.map((colHex) {
                        final isSelected = colorHex == colHex;
                        final colorVal = int.parse(colHex);
                        return GestureDetector(
                          onTap: () => setDialogState(() => colorHex = colHex),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Color(colorVal),
                            child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.pop(context)),
                TextButton(
                  child: const Text('Crear', style: TextStyle(color: AppColors.income)),
                  onPressed: () async {
                    if (nameController.text.trim().isNotEmpty) {
                      final newCat = Category(
                        name: nameController.text.trim(),
                        icon: iconName,
                        color: colorHex,
                        type: _activeTab,
                      );
                      await _dbHelper.insertCategory(newCat);
                      Navigator.pop(context);
                      reloadCategories();
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

  /// Crea una nueva subcategoría dentro de una categoría específica.
  Future<void> _createNewSubcategory(int categoryId) async {
    final TextEditingController nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Nueva Subcategoría', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'Nombre (ej. Energía Eléctrica)'),
          ),
          actions: [
            TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.pop(context)),
            TextButton(
              child: const Text('Agregar', style: TextStyle(color: AppColors.income)),
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  final newSub = Subcategory(
                    categoryId: categoryId,
                    name: nameController.text.trim(),
                  );
                  await _dbHelper.insertSubcategory(newSub);
                  
                  // Forzar recarga de la sublista correspondiente
                  final subcats = await _dbHelper.getSubcategoriesByCategory(categoryId);
                  setState(() {
                    _subcategoriesMap[categoryId] = subcats;
                  });

                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Borra una subcategoría de la lista.
  Future<void> _deleteSubcategory(int categoryId, int subcatId) async {
    await _dbHelper.deleteSubcategory(subcatId);
    final subcats = await _dbHelper.getSubcategoriesByCategory(categoryId);
    setState(() {
      _subcategoriesMap[categoryId] = subcats;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // 1. Cabecera con selector de Pestañas: GASTOS / INGRESOS (Diseño captura 5)
          Container(
            color: AppColors.background,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _activeTab = 'expense';
                      });
                      reloadCategories();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _activeTab == 'expense' ? AppColors.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'GASTOS',
                        style: TextStyle(
                          color: _activeTab == 'expense' ? AppColors.textPrimary : AppColors.textSecondary,
                          fontWeight: _activeTab == 'expense' ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _activeTab = 'income';
                      });
                      reloadCategories();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _activeTab == 'income' ? AppColors.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'INGRESOS',
                        style: TextStyle(
                          color: _activeTab == 'income' ? AppColors.textPrimary : AppColors.textSecondary,
                          fontWeight: _activeTab == 'income' ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Lista de Categorías
          Expanded(
            child: _categories.isEmpty
                ? const Center(
                    child: Text('No hay categorías creadas.', style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isExpanded = _expandedCategories[cat.id!] ?? false;
                      final subcats = _subcategoriesMap[cat.id!] ?? [];
                      
                      final int colorHex = int.tryParse(cat.color) ?? 0xFF9E9E9E;
                      final IconData catIcon = _getIconData(cat.icon);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Color(colorHex).withOpacity(0.12),
                                child: Icon(catIcon, color: Color(colorHex), size: 20),
                              ),
                              title: Text(
                                cat.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              trailing: Icon(
                                isExpanded ? Icons.expand_less : Icons.expand_more,
                                color: Colors.grey,
                              ),
                              onTap: () => _toggleCategoryExpansion(cat.id!),
                              onLongPress: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: AppColors.cardBackground,
                                    title: const Text('¿Eliminar categoría?'),
                                    content: Text('Esto eliminará la categoría "${cat.name}" y todas sus subcategorías asociadas.'),
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
                                  await _dbHelper.deleteCategory(cat.id!);
                                  reloadCategories();
                                }
                              },
                            ),
                            
                            // Lista de Subcategorías asociadas (desplegada)
                            if (isExpanded) ...[
                              const Divider(height: 1, color: Colors.white12),
                              // Sublista
                              Padding(
                                padding: const EdgeInsets.only(left: 48.0, right: 16.0, top: 4, bottom: 8),
                                child: Column(
                                  children: [
                                    if (subcats.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8.0),
                                        child: Text(
                                          'Sin subcategorías creadas.',
                                          style: TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                      )
                                    else
                                      ...subcats.map((sub) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(sub.name, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.grey),
                                                onPressed: () => _deleteSubcategory(cat.id!, sub.id!),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    
                                    // Botón agregar subcategoría
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                                        label: const Text('Agregar subcategoría', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                                        onPressed: () => _createNewSubcategory(cat.id!),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      
      // Botón flotante para agregar una categoría completa (diseño captura 5)
      floatingActionButton: FloatingActionButton(
        heroTag: 'categories_fab',
        mini: true,
        backgroundColor: AppColors.primary,
        onPressed: _createNewCategory,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Helper de resolución de iconos.
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
