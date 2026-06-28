class CurrencyUtils {
  static const List<Map<String, String>> availableCurrencies = [
    {'symbol': '₲', 'name': 'Guaraníes (₲)'},
    {'symbol': '\$', 'name': 'Dólares (\$)'},
    {'symbol': '€', 'name': 'Euros (€)'},
    {'symbol': 'ARS', 'name': 'Pesos Argentinos (ARS)'},
    {'symbol': 'MXN', 'name': 'Pesos Mexicanos (MXN)'},
    {'symbol': 'COP', 'name': 'Pesos Colombianos (COP)'},
    {'symbol': 'CLP', 'name': 'Pesos Chilenos (CLP)'},
    {'symbol': 'UYU', 'name': 'Pesos Uruguayos (UYU)'},
    {'symbol': 'S/', 'name': 'Soles Peruanos (S/)'},
    {'symbol': 'Bs', 'name': 'Bolivianos (Bs)'},
    {'symbol': 'RD\$', 'name': 'Pesos Dominicanos (RD\$)'},
    {'symbol': '₡', 'name': 'Colones (CRC)'},
    {'symbol': 'Q', 'name': 'Quetzales (GTQ)'},
    {'symbol': 'L', 'name': 'Lempiras (HNL)'},
    {'symbol': 'C\$', 'name': 'Córdobas (NIO)'},
    {'symbol': 'Bs.S', 'name': 'Bolívares (VES)'},
  ];

  static String getCurrencyName(String symbol) {
    final currency = availableCurrencies.firstWhere(
      (c) => c['symbol'] == symbol,
      orElse: () => {'symbol': symbol, 'name': symbol},
    );
    return currency['name']!;
  }
}
