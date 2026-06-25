import 'package:flutter/foundation.dart' show debugPrint;
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Servicio encargado de controlar el micrófono y la transcripción de voz a texto.
class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  factory SpeechService() => _instance;

  SpeechService._internal();

  /// Retorna si el micrófono está escuchando activamente en este momento.
  bool get isListening => _speech.isListening;

  /// Inicializa el motor de reconocimiento de voz.
  /// Solicita los permisos del micrófono si es necesario.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onError: (val) => debugPrint('Error en Speech: $val'),
        onStatus: (val) => debugPrint('Estado de Speech: $val'),
      );
    } catch (e) {
      debugPrint('Excepción al inicializar SpeechToText: $e');
      _isInitialized = false;
    }

    return _isInitialized;
  }

  /// Empieza a escuchar el micrófono y transcribir el audio a texto.
  /// Llama al callback [onResult] cada vez que detecta nuevas palabras.
  Future<void> startListening({
    required Function(String text) onResult,
    required Function() onListeningComplete,
  }) async {
    final hasSpeech = await initialize();
    if (!hasSpeech) {
      debugPrint('El reconocimiento de voz no está disponible o no tiene permisos.');
      return;
    }

    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: 'es_ES',
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 4),
      ),
      onResult: (result) {
        onResult(result.recognizedWords);
      },
    );

    // Esperar a que deje de escuchar y disparar el callback de finalización
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 500));
      return _speech.isListening;
    }).then((_) {
      onListeningComplete();
    });
  }

  /// Detiene la escucha de audio inmediatamente.
  Future<void> stopListening() async {
    if (_isInitialized && _speech.isListening) {
      await _speech.stop();
    }
  }
}
