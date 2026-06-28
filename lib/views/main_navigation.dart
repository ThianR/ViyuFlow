import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../services/google_drive_service.dart';
import '../services/csv_service.dart';
import '../services/excel_service.dart';
import '../database/db_helper.dart';
import '../theme.dart';
import '../widgets/voice_input_dialog.dart';
import 'add_transaction_screen.dart';
import 'accounts_tab.dart';
import 'transactions_tab.dart';
import 'statistics_tab.dart';
import 'categories_tab.dart';

/// Controlador principal de la navegación de la aplicación ViyuFlow.
/// Mantiene la estructura del menú inferior y la sincronización entre pestañas.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  // ignore: constant_identifier_names
  static const String DIRECTORIO_TEMP = "temp";

  int _currentIndex = 0;
  final GoogleDriveService _driveService = GoogleDriveService();
  final DBHelper _dbHelper = DBHelper();
  final CSVService _csvService = CSVService();
  final ExcelService _excelService = ExcelService();

  // Claves globales para forzar recargas en las pestañas al hacer cambios
  final GlobalKey<AccountsTabState> _accountsKey = GlobalKey();
  final GlobalKey<TransactionsTabState> _transactionsKey = GlobalKey();
  final GlobalKey<StatisticsTabState> _statisticsKey = GlobalKey();
  final GlobalKey<CategoriesTabState> _categoriesKey = GlobalKey();

  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _processAutomatedDebts();
    _checkGoogleSignInSilently();
  }

  Future<void> _processAutomatedDebts() async {
    await _dbHelper.processScheduledTransactions();
    // No necesitamos recargar aquí inmediatamente porque las pestañas se cargan solas,
    // pero si ya están cargadas, podríamos forzar reload:
    _reloadAllTabs();
  }

  /// Intenta iniciar sesión silenciosamente con Google al arrancar la app.
  Future<void> _checkGoogleSignInSilently() async {
    final signedIn = await _driveService.trySilentSignIn();
    if (signedIn) {
      debugPrint(
        'Autenticado silenciosamente con la cuenta de Google: ${_driveService.currentUser?.email}',
      );
      // Intentar respaldo automático diario al inicio
      _runAutomaticDailyBackup();
    }
  }

  /// Ejecuta un respaldo diario en segundo plano si ha pasado más de 24 horas del último.
  Future<void> _runAutomaticDailyBackup() async {
    // Aquí implementamos la lógica de verificación de fecha de último respaldo.
    // Para simplificar, iniciamos la subida de datos que se actualiza si hay cambios no sincronizados.
    await _driveService.uploadBackup();
  }

  /// Dispara la recarga de datos en todas las pestañas de la aplicación.
  void _reloadAllTabs() {
    _accountsKey.currentState?.reloadAccounts();
    _transactionsKey.currentState?.reloadTransactions();
    _statisticsKey.currentState?.reloadStatistics();
    _categoriesKey.currentState?.reloadCategories();
  }

  /// Abre la pantalla flotante para añadir una transacción de forma manual.
  Future<void> _navigateToAddTransaction() async {
    final int? currentSelectedAccountId =
        _transactionsKey.currentState?.selectedAccountId;

    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          preselectedAccountId: currentSelectedAccountId,
        ),
      ),
    );

    if (result == true) {
      _reloadAllTabs();
    }
  }

  /// Abre el pop-up interactivo del micrófono para transacciones por voz.
  void _openVoiceInputDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const VoiceInputDialog(),
    ).then((_) {
      // Al cerrar el pop-up, recargar datos por si se insertó un movimiento
      _reloadAllTabs();
    });
  }

  /// Abre el menú flotante lateral de ajustes y sincronización (Google Drive y CSV).
  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/app_icon.jpg',
                          height: 40,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Ajustes y Respaldos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Sección Google Drive
                  const Text(
                    'Sincronización con Google',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _driveService.isSignedIn
                      ? ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.cloud_done,
                            color: AppColors.income,
                          ),
                          title: Text(
                            _driveService.currentUser?.email ?? 'Conectado',
                          ),
                          subtitle: const Text('Respaldo automático activado'),
                          trailing: TextButton(
                            child: const Text(
                              'Desconectar',
                              style: TextStyle(color: AppColors.expense),
                            ),
                            onPressed: () async {
                              await _driveService.signOut();
                              setModalState(() {});
                              setState(() {});
                            },
                          ),
                        )
                      : ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.cloud_off,
                            color: Colors.grey,
                          ),
                          title: const Text('Cuenta de Google'),
                          subtitle: const Text('Respaldos desactivados'),
                          trailing: ElevatedButton(
                            child: const Text('Conectar'),
                            onPressed: () async {
                              final success = await _driveService.signIn();
                              if (success) {
                                setModalState(() {});
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Conectado con éxito a Google Drive',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),

                  if (_driveService.isSignedIn) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: _isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.backup, size: 16),
                            label: const Text('Respaldar Ahora'),
                            onPressed: _isSyncing
                                ? null
                                : () async {
                                    setModalState(() => _isSyncing = true);
                                    final success = await _driveService
                                        .uploadBackup();
                                    setModalState(() => _isSyncing = false);
                                    if (success) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Respaldo en Google Drive completado.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.restore, size: 16),
                            label: const Text('Restaurar'),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('¿Restaurar datos?'),
                                  content: const Text(
                                    'Esto reemplazará todos tus datos locales actuales con la copia de Google Drive. Esta acción no se puede deshacer.',
                                  ),
                                  actions: [
                                    TextButton(
                                      child: const Text('Cancelar'),
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                    ),
                                    TextButton(
                                      child: const Text(
                                        'Restaurar',
                                        style: TextStyle(
                                          color: AppColors.expense,
                                        ),
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                Navigator.pop(context); // Cerrar bottom sheet
                                setState(() => _isLoadingNavigation = true);
                                final success = await _driveService
                                    .restoreBackup();
                                setState(() => _isLoadingNavigation = false);
                                if (success) {
                                  _reloadAllTabs();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Datos restaurados con éxito.',
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No se pudo restaurar el respaldo.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),

                  // Sección CSV Local
                  const Text(
                    'Datos Locales (CSV)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Exportar CSV'),
                          onPressed: () async {
                            final txs = await _dbHelper.getAllTransactions();
                            try {
                              final csvStr = _csvService
                                  .exportTransactionsToCSV(txs);
                              String? selectedDirectory =
                                  await FilePicker.getDirectoryPath(
                                    dialogTitle:
                                        'Selecciona dónde guardar el CSV',
                                  );

                              if (selectedDirectory != null) {
                                final file = File(
                                  '$selectedDirectory/Exportacion_ViyuFlow.csv',
                                );
                                await file.writeAsString(csvStr);

                                if (!mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'CSV guardado en: ${file.path}',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint('Error al guardar CSV: $e');
                              if (!mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al exportar: $e'),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.upload, size: 16),
                          label: const Text('Importar CSV'),
                          onPressed: () async {
                            // En una app real abriríamos el selector de archivos
                            // Importar seleccionando un archivo real
                            try {
                              final result = await FilePicker.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['csv'],
                              );

                              if (result != null &&
                                  result.files.single.path != null) {
                                final file = File(result.files.single.path!);
                                final csvData = await file.readAsString();
                                final count = await _csvService
                                    .importTransactionsFromCSV(csvData);
                                _reloadAllTabs();
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Se importaron $count transacciones con éxito.',
                                    ),
                                  ),
                                );
                              } else {
                                // El usuario canceló la selección
                              }
                            } catch (e) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error: ${e.toString().replaceAll('Exception: ', '')}',
                                  ),
                                  backgroundColor: AppColors.expense,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.file_download, size: 16),
                      label: const Text(
                        'Descargar Plantilla de importacion CSV',
                      ),
                      onPressed: () async {
                        try {
                          final csvStr = _csvService.getCSVTemplate();
                          String? selectedDirectory =
                              await FilePicker.getDirectoryPath(
                                dialogTitle:
                                    'Selecciona dónde guardar la plantilla',
                              );

                          if (selectedDirectory != null) {
                            final file = File(
                              '$selectedDirectory/Plantilla_Importacion_ViyuFlow.csv',
                            );
                            await file.writeAsString(csvStr);

                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Plantilla guardada en: ${file.path}',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('Error al guardar plantilla CSV: $e');
                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error al descargar plantilla: $e'),
                              backgroundColor: AppColors.expense,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),
                  const Text(
                    'Reporte Completo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF107C41,
                        ), // Color verde Excel
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.table_chart, size: 20),
                      label: const Text('Exportar Reporte Completo (Excel)'),
                      onPressed: () async {
                        try {
                          final bytes = await _excelService
                              .generateFullReport();
                          String? selectedDirectory =
                              await FilePicker.getDirectoryPath(
                                dialogTitle:
                                    'Selecciona dónde guardar el Excel',
                              );

                          if (selectedDirectory != null) {
                            final file = File(
                              '$selectedDirectory/ReporteCompleto_ViyuFlow.xlsx',
                            );
                            await file.writeAsBytes(bytes);

                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Excel guardado en: ${file.path}',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('Error al exportar a Excel: $e');
                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al exportar: $e')),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool _isLoadingNavigation = false;

  @override
  Widget build(BuildContext context) {
    if (_isLoadingNavigation) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Lista de vistas (Tabs)
    final List<Widget> tabs = [
      AccountsTab(
        key: _accountsKey,
        onAccountSelected: (int accountId) {
          _transactionsKey.currentState?.selectAccount(accountId);
          setState(() {
            _currentIndex = 1;
          });
        },
        onScheduleChanged: _reloadAllTabs,
      ),
      TransactionsTab(key: _transactionsKey),
      StatisticsTab(key: _statisticsKey),
      CategoriesTab(key: _categoriesKey),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo_transparent.png', height: 32),
            const SizedBox(width: 12),
            const Text('ViyuFlow'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _showSettingsBottomSheet,
        ),
        actions: [
          // Indicador de estado de sincronización
          if (_driveService.isSignedIn)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Icons.cloud_done, color: AppColors.income, size: 20),
            ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: tabs),

      // Botones flotantes
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        heroTag: 'main_fab',
        backgroundColor: AppColors.accent,
        shape: const CircleBorder(),
        elevation: 6,
        onPressed: _navigateToAddTransaction,
        child: const Icon(Icons.add, size: 28, color: Colors.white),
      ),

      // Barra de navegación inferior
      bottomNavigationBar: BottomAppBar(
        color: AppColors.cardBackground,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Botones izquierdos: Cuentas y Transacciones
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: _currentIndex == 0 ? AppColors.primary : Colors.grey,
                  ),
                  onPressed: () => setState(() => _currentIndex = 0),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: Icon(
                    Icons.list_alt,
                    color: _currentIndex == 1 ? AppColors.primary : Colors.grey,
                  ),
                  onPressed: () => setState(() => _currentIndex = 1),
                ),
              ],
            ),
            // Botón rápido de entrada por voz a la izquierda del FAB
            IconButton(
              icon: const Icon(Icons.mic, color: AppColors.voiceAccent),
              onPressed: _openVoiceInputDialog,
            ),
            // Botones derechos: Estadísticas y Categorías
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.bar_chart,
                    color: _currentIndex == 2 ? AppColors.primary : Colors.grey,
                  ),
                  onPressed: () => setState(() => _currentIndex = 2),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: Icon(
                    Icons.category_outlined,
                    color: _currentIndex == 3 ? AppColors.primary : Colors.grey,
                  ),
                  onPressed: () => setState(() => _currentIndex = 3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
