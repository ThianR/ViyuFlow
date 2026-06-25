import 'package:flutter/material.dart';
import '../services/speech_service.dart';
import '../services/nlp_parser.dart';
import '../views/add_transaction_screen.dart';
import '../theme.dart';

/// Un modal tipo diálogo que controla el micrófono y guía al usuario para registrar
/// transacciones mediante comandos por voz, mostrando la transcripción en tiempo real.
class VoiceInputDialog extends StatefulWidget {
  const VoiceInputDialog({super.key});

  @override
  State<VoiceInputDialog> createState() => _VoiceInputDialogState();
}

class _VoiceInputDialogState extends State<VoiceInputDialog> with SingleTickerProviderStateMixin {
  final SpeechService _speechService = SpeechService();
  final NLPParser _nlpParser = NLPParser();

  String _transcribedText = 'Pulsa el micrófono y di tu gasto...';
  bool _isListening = false;
  bool _hasError = false;

  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Animación de pulsación para el icono del micrófono mientras graba
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Iniciar la escucha de forma automática al abrir el diálogo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _speechService.stopListening();
    super.dispose();
  }

  /// Inicia el servicio de reconocimiento de voz.
  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
      _hasError = false;
      _transcribedText = 'Escuchando...';
    });

    try {
      await _speechService.startListening(
        onResult: (text) {
          setState(() {
            _transcribedText = text;
          });
        },
        onListeningComplete: () {
          _processVoiceText();
        },
      );
    } catch (e) {
      setState(() {
        _isListening = false;
        _hasError = true;
        _transcribedText = 'Error al activar el micrófono.';
      });
    }
  }

  /// Detiene el micrófono manualmente.
  Future<void> _stopListening() async {
    await _speechService.stopListening();
    _processVoiceText();
  }

  /// Procesa la cadena transcrita mediante el parser y navega al formulario.
  Future<void> _processVoiceText() async {
    if (!mounted) return;
    setState(() {
      _isListening = false;
    });

    final String finalPhrase = _transcribedText.trim();
    if (finalPhrase.isEmpty ||
        finalPhrase == 'Escuchando...' ||
        finalPhrase == 'Pulsa el micrófono y di tu gasto...') {
      setState(() {
        _transcribedText = 'No se escuchó nada. Inténtalo de nuevo.';
      });
      return;
    }

    // Mostrar estado de procesamiento
    setState(() {
      _transcribedText = 'Procesando: "$finalPhrase"...';
    });

    // Parsear el texto usando el analizador local
    final parsedResult = await _nlpParser.parsePhrase(finalPhrase);

    if (!mounted) return;
    
    // Cerrar el diálogo flotante
    Navigator.pop(context);

    // Abrir la pantalla de transacción con el resultado del análisis
    final bool? refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          voiceResult: parsedResult,
        ),
      ),
    );

    // Si se insertó con éxito, podemos propagar la recarga al feed
    if (refreshed == true && Navigator.canPop(context)) {
      // Si la pantalla de navegación está abierta en la pila anterior
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Color(0xFF1E1E28),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade800, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fila de cabecera
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.mic, color: AppColors.voiceAccent, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Transacciones de voz',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tarjeta de texto transcrito en tiempo real
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 100),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _transcribedText,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // Botón de micrófono animado
            ScaleTransition(
              scale: _isListening ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
              child: Material(
                color: _isListening ? AppColors.voiceAccent : Colors.grey.shade800,
                shape: const CircleBorder(),
                elevation: 6,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _isListening ? _stopListening : _startListening,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Icon(
                      _isListening ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Texto de instrucción secundaria
            Text(
              _isListening 
                  ? 'Di el monto, cuenta y gasto (ej. "Ayer compré comida por 50000 guaraníes")\no presiona el botón para detener.' 
                  : 'Presiona el micrófono para hablar.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
