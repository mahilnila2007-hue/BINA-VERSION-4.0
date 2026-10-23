import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-Speech coaching service with deterministic cooldowns.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  FlutterTts? _flutterTts;
  bool _initialized = false;
  bool _isEnabled = true;
  DateTime _lastSpokenTime = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastSpokenText = '';
  static const Duration cooldown = Duration(seconds: 3);

  bool get isEnabled => _isEnabled;
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) stop();
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      _flutterTts = FlutterTts();
      await _flutterTts?.setLanguage('en-US');
      await _flutterTts?.setSpeechRate(0.48); // Slightly slower for elderly clarity
      await _flutterTts?.setVolume(1.0);
      await _flutterTts?.setPitch(1.0);
      _initialized = true;
    } catch (e) {
      debugPrint('TTS initialization warning: $e');
    }
  }

  /// Speaks message if cooldown window has passed or text differs significantly.
  Future<void> speak(String text, {bool force = false}) async {
    if (!_isEnabled || text.isEmpty) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastSpokenTime);

    if (!force && elapsed < cooldown && _lastSpokenText == text) {
      return; // Respect cooldown to prevent overwhelming elderly users
    }

    _lastSpokenTime = now;
    _lastSpokenText = text;

    try {
      if (!_initialized) await init();
      await _flutterTts?.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts?.stop();
    } catch (_) {}
  }
}
