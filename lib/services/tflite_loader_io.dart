import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'tflite_loader_stub.dart';

PoseModelRunner getPoseModelRunner() => PoseModelRunnerIo();

class PoseModelRunnerIo implements PoseModelRunner {
  Interpreter? _interpreter;

  @override
  Future<bool> load(String assetPath) async {
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(assetPath, options: options);
      return true;
    } catch (e) {
      try {
        _interpreter = await Interpreter.fromAsset(assetPath);
        return true;
      } catch (e2) {
        debugPrint('PoseModelRunnerIo: Could not load $assetPath ($e2)');
        return false;
      }
    }
  }

  @override
  void run(dynamic input, dynamic output) {
    if (_interpreter != null) {
      _interpreter!.run(input, output);
    }
  }

  @override
  void close() {
    try {
      _interpreter?.close();
    } catch (_) {}
    _interpreter = null;
  }
}
