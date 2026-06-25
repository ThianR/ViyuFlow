import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../database/db_helper.dart';
import '../models/account.dart';

import '../models/transaction.dart';

/// Cliente HTTP personalizado que inyecta la cabecera de autenticación OAuth de Google
/// en las peticiones HTTP que realiza el cliente de la API de Google Drive.
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

/// Servicio que interactúa con Google Drive para crear y restaurar copias de seguridad de ViyuFlow.
class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  final DBHelper _dbHelper = DBHelper();

  // Configuración de inicio de sesión de Google con los scopes necesarios para Drive
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope, // Acceso exclusivo a la carpeta oculta de datos de la app
      drive.DriveApi.driveFileScope,    // Opcional: acceso a los archivos creados por esta app
    ],
  );

  GoogleSignInAccount? _currentUser;

  factory GoogleDriveService() => _instance;

  GoogleDriveService._internal();

  /// Retorna si el usuario está actualmente autenticado con su cuenta de Google.
  bool get isSignedIn => _currentUser != null;

  /// Obtiene los datos del usuario actual autenticado.
  GoogleSignInAccount? get currentUser => _currentUser;

  /// Inicializa la sesión de Google intentando un inicio silencioso si el usuario ya se había conectado antes.
  Future<bool> trySilentSignIn() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      return _currentUser != null;
    } catch (e) {
      debugPrint('Error en inicio de sesión silencioso de Google: $e');
      return false;
    }
  }

  /// Inicia el flujo visual de autenticación de Google.
  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser != null;
    } catch (e) {
      debugPrint('Error al iniciar sesión con Google: $e');
      return false;
    }
  }

  /// Cierra la sesión activa de Google.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
    } catch (e) {
      debugPrint('Error al cerrar sesión de Google: $e');
    }
  }

  /// Crea un cliente de la API de Google Drive utilizando el token de acceso del usuario autenticado.
  Future<drive.DriveApi?> _getDriveApi() async {
    if (_currentUser == null) {
      final success = await trySilentSignIn();
      if (!success) return null;
    }

    try {
      final authHeaders = await _currentUser!.authHeaders;
      final client = GoogleAuthClient(authHeaders);
      return drive.DriveApi(client);
    } catch (e) {
      debugPrint('Error al inicializar el cliente de la API de Drive: $e');
      return null;
    }
  }

  // ==========================================
  // EXPORTACIÓN Y SUBIDA DE RESPALDO
  // ==========================================

  /// Compila la base de datos local a un formato JSON y la sube a Google Drive.
  /// Si el respaldo es exitoso, marca las transacciones locales como sincronizadas.
  Future<bool> uploadBackup() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      debugPrint('No se pudo subir el respaldo: El usuario no está autenticado.');
      return false;
    }

    try {
      // 1. Obtener todos los datos de la base de datos local
      final List<Account> accounts = await _dbHelper.getAllAccounts();
      
      // Consultamos las categorías directamente sin filtros de tipo
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> catMaps = await db.query('categories');
      final List<Map<String, dynamic>> subMaps = await db.query('subcategories');
      final List<TransactionModel> transactions = await _dbHelper.getAllTransactions();

      // Mapear los modelos a datos planos JSON
      final List<Map<String, dynamic>> accountsJson = accounts.map((a) => a.toMap()).toList();
      final List<Map<String, dynamic>> transactionsJson = transactions.map((t) => t.toMap()).toList();
      final List<Map<String, dynamic>> categoriesJson = catMaps;
      final List<Map<String, dynamic>> subcategoriesJson = subMaps;

      // Estructura completa de respaldo
      final Map<String, dynamic> backupPayload = {
        'app': 'ViyuFlow',
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'accounts': accountsJson,
        'categories': categoriesJson,
        'subcategories': subcategoriesJson,
        'transactions': transactionsJson,
      };

      final String backupContent = jsonEncode(backupPayload);
      final List<int> contentBytes = utf8.encode(backupContent);
      final Stream<List<int>> mediaStream = Stream.value(contentBytes);
      final media = drive.Media(mediaStream, contentBytes.length);

      // 2. Buscar si ya existe un respaldo anterior en la carpeta de datos de la app
      final String fileName = 'viyuflow_backup.json';
      final drive.FileList fileList = await driveApi.files.list(
        q: "name = '$fileName' and 'appDataFolder' in parents",
        spaces: 'appDataFolder',
      );

      drive.File fileMetadata = drive.File();
      fileMetadata.name = fileName;

      drive.File responseFile;
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // Actualizar el archivo existente
        final existingFileId = fileList.files!.first.id!;
        responseFile = await driveApi.files.update(
          fileMetadata,
          existingFileId,
          uploadMedia: media,
        );
        debugPrint('Respaldo en Google Drive actualizado con éxito (ID: ${responseFile.id}).');
      } else {
        // Crear un nuevo archivo en la carpeta appDataFolder
        fileMetadata.parents = ['appDataFolder'];
        responseFile = await driveApi.files.create(
          fileMetadata,
          uploadMedia: media,
        );
        debugPrint('Nuevo respaldo en Google Drive creado con éxito (ID: ${responseFile.id}).');
      }

      // 3. Marcar las transacciones locales como sincronizadas tras el éxito de subida
      final List<int> transactionIds = transactions
          .where((t) => !t.syncStatus)
          .map((t) => t.id!)
          .toList();
      
      if (transactionIds.isNotEmpty) {
        await _dbHelper.markAsSynced(transactionIds);
      }

      return responseFile.id != null;
    } catch (e) {
      debugPrint('Excepción durante la subida del respaldo a Google Drive: $e');
      return false;
    }
  }

  // ==========================================
  // DESCARGA Y RESTAURACIÓN DE RESPALDO
  // ==========================================

  /// Descarga el archivo de respaldo desde Google Drive y restaura la base de datos SQLite local.
  Future<bool> restoreBackup() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      debugPrint('No se pudo restaurar: El usuario no está autenticado.');
      return false;
    }

    try {
      // 1. Buscar el archivo de respaldo en Google Drive
      final String fileName = 'viyuflow_backup.json';
      final drive.FileList fileList = await driveApi.files.list(
        q: "name = '$fileName' and 'appDataFolder' in parents",
        spaces: 'appDataFolder',
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        debugPrint('No se encontró ningún archivo de respaldo de ViyuFlow en Google Drive.');
        return false;
      }

      final fileId = fileList.files!.first.id!;

      // 2. Descargar el contenido del archivo
      final drive.Media media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      // Leer el stream del archivo descargado
      final List<int> bytes = [];
      await for (var chunk in media.stream) {
        bytes.addAll(chunk);
      }

      final String jsonContent = utf8.decode(bytes);
      final Map<String, dynamic> backupData = jsonDecode(jsonContent);

      // Validar firma del archivo
      if (backupData['app'] != 'ViyuFlow') {
        debugPrint('El archivo descargado no pertenece a esta aplicación.');
        return false;
      }

      // 3. Extraer listas tipadas para reconstruir las tablas
      final List<dynamic> accountsRaw = backupData['accounts'] as List<dynamic>;
      final List<dynamic> transactionsRaw = backupData['transactions'] as List<dynamic>;
      final List<dynamic> categoriesRaw = backupData['categories'] as List<dynamic>;
      final List<dynamic> subcategoriesRaw = backupData['subcategories'] as List<dynamic>;

      final List<Map<String, dynamic>> accounts = accountsRaw.cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> transactions = transactionsRaw.cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> categories = categoriesRaw.cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> subcategories = subcategoriesRaw.cast<Map<String, dynamic>>();

      // 4. Escribir de forma atómica en SQLite
      await _dbHelper.restoreDatabaseBackup(accounts, transactions, categories, subcategories);
      debugPrint('Base de datos restaurada con éxito desde Google Drive.');

      return true;
    } catch (e) {
      debugPrint('Excepción durante la descarga y restauración de respaldo desde Google Drive: $e');
      return false;
    }
  }
}
