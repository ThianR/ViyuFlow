# ViyuFlow

**ViyuFlow** es una aplicación móvil moderna, rápida y completamente privada para la gestión de finanzas personales. Diseñada para mantener el control de tus ingresos, gastos, presupuestos y cuentas bancarias, con un enfoque principal en la usabilidad y la privacidad local de tus datos.

## Descarga el APK
[Descargar ViyuFlow (Google Drive)](https://drive.google.com/drive/folders/1cjnwGumkkepkRA9MzVX7vrGpKjXbPaAM?usp=drive_link)

## Características Principales

### 1. Gestión Multi-Cuenta y Multimoneda
- Crea diferentes cuentas (Billeteras virtuales, Efectivo, Bancos, Tarjetas de crédito).
- Personaliza cada cuenta con colores, gradientes y nombres.
- **Multimoneda Localizada:** Soporta nativamente todas las divisas de habla hispana (Pesos Argentinos, Mexicanos, Colombianos, Soles, etc.), además del Guaraní (₲), Dólar ($) y Euro (€).
- **Consolidación:** Visualiza el saldo total consolidado filtrado automáticamente por cada tipo de moneda.

### 2. Ingresos y Gastos Eficientes
- Registra movimientos detallados indicando categoría, subcategoría, cuenta, fecha y descripción.
- Interfaz rápida e intuitiva para anotar gastos al instante.
- **Categorización visual:** Identifica tus gastos por íconos y colores. Puedes crear, editar o eliminar categorías a tu gusto.

### 3. Registro por Voz (Speech-to-Text)
- **Agrega transacciones hablando:** Un sistema de reconocimiento de voz inteligente te permite dictar tus transacciones (ej: *"Gasto de comida 50 mil guaraníes"* o *"Ingreso de sueldo 2 millones en el banco"*) y la app completará el formulario por ti.

### 4. Transacciones Programadas y Recurrentes
- Crea recordatorios para **pagos de deudas** o **ingresos recurrentes** (sueldos, alquileres).
- La aplicación **procesa y cobra automáticamente** estas transacciones cuando llega su fecha programada.
- Cálculo de "montos pendientes" directamente en tu panel de transacciones diarias.

### 5. Privacidad Total (Offline-First)
- ViyuFlow funciona de manera 100% *offline*.
- Todos tus datos financieros se almacenan localmente en tu dispositivo a través de **SQLite**, sin pasar por servidores de terceros.
- Tus datos son tuyos y nadie más tiene acceso a ellos.

### 6. Respaldos en Google Drive
- Inicia sesión de forma segura y directa con tu cuenta de Google.
- Realiza **copias de seguridad (Backups) automatizados y manuales** directamente a tu espacio privado de Google Drive.
- Restaura tus datos sin fricciones si cambias de teléfono.

### 7. Exportación, Importación y Reportes (Excel/CSV)
- **CSV:** Importa o exporta datos localmente mediante plantillas CSV para mover tu información fácilmente.
- **Reportes en Excel (.xlsx):** Genera y descarga un reporte completo y formateado a Excel de toda tu vida financiera con un solo clic.

### 8. Estadísticas y Presupuestos
- **Gráficos interactivos:** Analiza tu distribución de gastos mediante gráficos de barras, pastel y líneas de evolución temporal usando la librería `fl_chart`.
- **Evolución del Balance:** Observa visualmente cómo tu patrimonio sube o baja en los últimos 7 días, 30 días o un año.
- **Presupuestos:** Establece límites de gastos mensuales para controlar mejor en qué áreas estás gastando de más.

### 9. Diseño Moderno e Interfaz Atractiva
- Diseñada desde cero con una paleta de colores moderna orientada a un **Modo Oscuro** (Dark Mode).
- Efectos visuales fluidos, tarjetas flotantes, gradientes estilizados y botones flotantes para una experiencia *premium*.

---

## Tecnologías y Arquitectura

- **Framework:** Flutter (Android & iOS).
- **Lenguaje:** Dart.
- **Base de Datos:** SQLite (`sqflite`).
- **Autenticación y Nube:** `google_sign_in` / `googleapis` (Integración con Google Drive API).
- **Reportes:** `syncfusion_flutter_xlsio` (Excel), `csv` (CSV).
- **UI & Gráficos:** `fl_chart`, `cupertino_icons`.
- **Reconocimiento de Voz:** `speech_to_text`.

## Requisitos Mínimos

Para garantizar un rendimiento fluido y compatibilidad con todas las funcionalidades (incluyendo el reconocimiento de voz y exportación de archivos), ViyuFlow requiere:

- **Android:** Versión 5.0 (Lollipop) - API Nivel 21 o superior.
- **iOS:** iOS 12.0 o superior.
- **Conexión a Internet:** Solo requerida temporalmente para la sincronización y respaldos con Google Drive.
- **Micrófono:** Permiso requerido para utilizar la función de registro por voz.

## Instalación (Desarrollo)

1. Asegúrate de tener **Flutter (SDK ^3.11.5)** instalado.
2. Clona este repositorio.
3. Ejecuta en la terminal:
   ```bash
   flutter pub get
   ```
4. Conecta tu emulador o dispositivo móvil y corre el proyecto:
   ```bash
   flutter run
   ```

*NOTA: Para compilar las funciones de Google Drive, necesitarás incluir los archivos de configuración (`google-services.json` / `Info.plist`) en tu entorno local obtenidos desde Firebase/Google Cloud Console.*
