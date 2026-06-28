import 'package:flutter/foundation.dart' show debugPrint;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../database/db_helper.dart';

/// Servicio encargado de la exportación completa de la base de datos a un archivo Excel (XLSX).
class ExcelService {
  final DBHelper _dbHelper = DBHelper();

  /// Exporta toda la información (cuentas, categorías, transacciones, presupuestos, etc.) a un archivo Excel.
  /// Devuelve los bytes (List<int>) del archivo generado.
  Future<List<int>> generateFullReport() async {
    // 1. Inicializar el Workbook
    final xlsio.Workbook workbook = xlsio.Workbook();
    
    // El Workbook viene con una hoja por defecto, la usaremos para la primera tabla y luego crearemos más.
    final xlsio.Worksheet sheetTransactions = workbook.worksheets[0];
    sheetTransactions.name = 'Transacciones';

    final xlsio.Worksheet sheetAccounts = workbook.worksheets.addWithName('Cuentas');
    final xlsio.Worksheet sheetCategories = workbook.worksheets.addWithName('Categorias');
    final xlsio.Worksheet sheetBudgets = workbook.worksheets.addWithName('Presupuestos');
    final xlsio.Worksheet sheetScheduled = workbook.worksheets.addWithName('Trans_Programadas');

    final db = await _dbHelper.database;

    // Helper para poblar una hoja con los datos de una tabla
    Future<void> fillSheetFromTable(xlsio.Worksheet sheet, String tableName) async {
      try {
        final List<Map<String, dynamic>> records = await db.query(tableName);
        
        if (records.isEmpty) {
          sheet.getRangeByIndex(1, 1).setText('No hay datos registrados.');
          return;
        }

        // Obtener los nombres de las columnas
        final columns = records.first.keys.toList();

        // Escribir cabeceras
        for (int i = 0; i < columns.length; i++) {
          final xlsio.Range range = sheet.getRangeByIndex(1, i + 1);
          range.setText(columns[i].toUpperCase());
          range.cellStyle.bold = true;
          range.cellStyle.backColor = '#0F52BA'; // Azul zafiro
          range.cellStyle.fontColor = '#FFFFFF';
        }

        // Escribir datos
        for (int rowIndex = 0; rowIndex < records.length; rowIndex++) {
          final record = records[rowIndex];
          for (int colIndex = 0; colIndex < columns.length; colIndex++) {
            final value = record[columns[colIndex]];
            final xlsio.Range range = sheet.getRangeByIndex(rowIndex + 2, colIndex + 1);
            
            if (value == null) {
              range.setText('');
            } else if (value is num) {
              range.setNumber(value.toDouble());
            } else {
              range.setText(value.toString());
            }
          }
        }
        
        // Auto-ajustar el ancho de las columnas
        for (int i = 1; i <= columns.length; i++) {
          sheet.autoFitColumn(i);
        }
      } catch (e) {
        debugPrint('Error al leer la tabla $tableName: $e');
        sheet.getRangeByIndex(1, 1).setText('Error al obtener datos');
      }
    }

    // Llenar todas las hojas
    await fillSheetFromTable(sheetTransactions, 'transactions');
    await fillSheetFromTable(sheetAccounts, 'accounts');
    await fillSheetFromTable(sheetCategories, 'categories');
    await fillSheetFromTable(sheetBudgets, 'budgets');
    await fillSheetFromTable(sheetScheduled, 'scheduled_transactions');

    // Generar archivo en bytes
    final List<int> bytes = workbook.saveAsStream();
    
    // Liberar recursos
    workbook.dispose();

    return bytes;
  }
}
