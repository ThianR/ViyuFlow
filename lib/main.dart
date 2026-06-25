import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme.dart';
import 'views/splash_screen.dart';

void main() async {
  // Garantizar que la vinculación del framework de Flutter esté lista antes de inicializar servicios
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar la configuración de idioma local (Español) para el formateo de fechas
  await initializeDateFormatting('es_ES', null);

  runApp(const ViyuFlowApp());
}

/// Punto de entrada del widget raíz de la aplicación ViyuFlow.
class ViyuFlowApp extends StatelessWidget {
  const ViyuFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ViyuFlow',
      debugShowCheckedModeBanner: false,
      
      // Aplicar nuestro tema oscuro premium configurado
      theme: buildThemeData(context),
      
      // Pantalla de inicio con logo
      home: const SplashScreen(),
    );
  }
}
