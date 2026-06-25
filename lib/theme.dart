import 'package:flutter/material.dart';

/// Clase que contiene todas las constantes de color utilizadas en la aplicación
/// para mantener la consistencia del diseño premium oscuro.
class AppColors {
  // Colores base del tema oscuro
  static const Color background = Color(0xFF0F0F12);
  static const Color cardBackground = Color(0xFF18181F);
  static const Color primary = Color(0xFF0F52BA); // Azul zafiro premium
  static const Color accent = Color(0xFFFFA502);  // Naranja vibrante para añadir
  static const Color voiceAccent = Color(0xFF29B6F6); // Azul cian para la voz

  // Colores de estado financiero
  static const Color income = Color(0xFF00E676);  // Verde esmeralda para ingresos
  static const Color expense = Color(0xFFFF5252); // Rojo coral para egresos

  // Colores de texto
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textHint = Color(0xFF5A5A5F);

  // Paleta de degradados para tarjetas de cuentas
  static const List<Color> gradientBlue = [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF6FB1FC)];
  static const List<Color> gradientPurple = [Color(0xFF800080), Color(0xFF9400D3), Color(0xFFBA55D3)];
  static const List<Color> gradientGreen = [Color(0xFF11998e), Color(0xFF38ef7d)];
  static const List<Color> gradientOrange = [Color(0xFFf12711), Color(0xFFf5af19)];
}

/// Definición del ThemeData oscuro premium para ViyuFlow
ThemeData buildThemeData(BuildContext context) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primary,
    
    // Configuración de la barra de navegación superior (AppBar)
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),

    // Configuración de tarjetas (CardThemeData)
    cardTheme: CardThemeData(
      color: AppColors.cardBackground,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    // Configuración de botones y entradas de texto
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardBackground,
      hintStyle: const TextStyle(color: AppColors.textHint),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),

    // Esquema de colores del sistema
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.cardBackground,
      error: AppColors.expense,
    ),
  );
}
