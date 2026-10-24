import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Camera initialization, front/back camera selection,
/// permission handling, and live frame streaming service for real-time YOLO pose monitoring.
class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  CameraController? _controller;
  bool _isInitialized = false;
  bool _isStreaming = false;
  bool _permissionDenied = false;
  String? _errorMessage;
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;

  bool get isInitialized => _isInitialized && _controller != null;
  bool get isStreaming => _isStreaming;
  bool get permissionDenied => _permissionDenied;
  String? get errorMessage => _errorMessage;
  CameraController? get controller => _controller;
  bool get isFrontCamera =>
      _controller?.description.lensDirection == CameraLensDirection.front;
  int get sensorOrientation => _controller?.description.sensorOrientation ?? 90;
  double get aspectRatio => _controller?.value.aspectRatio ?? (16 / 9);

  /// Initializes the physical camera.
  /// Prefers front camera for self-monitoring rehabilitation experience.
  Future<bool> initialize() async {
    _permissionDenied = false;
    _errorMessage = null;

    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        // On web / slow devices, availableCameras() might need a brief retry
        await Future.delayed(const Duration(milliseconds: 300));
        _availableCameras = await availableCameras();
      }
      if (_availableCameras.isEmpty) {
        debugPrint('No physical cameras found on this system.');
        _isInitialized = false;
        _errorMessage = 'No camera device found on this system.';
        return false;
      }

      // Find front camera or use first available
      int targetIndex = 0;
      for (int i = 0; i < _availableCameras.length; i++) {
        if (_availableCameras[i].lensDirection == CameraLensDirection.front) {
          targetIndex = i;
          break;
        }
      }
      _selectedCameraIndex = targetIndex;

      return await _initializeController(_availableCameras[_selectedCameraIndex]);
    } on CameraException catch (e) {
      debugPrint('CameraService exception: ${e.code} - ${e.description}');
      if (e.code == 'CameraAccessDenied' || e.code == 'cameraPermission') {
        _permissionDenied = true;
        _errorMessage = 'Camera permission denied. Please grant camera access in settings.';
      } else {
        _errorMessage = e.description ?? e.code;
      }
      _isInitialized = false;
      return false;
    } catch (e) {
      debugPrint('CameraService initialization warning: $e');
      _isInitialized = false;
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> _initializeController(CameraDescription camera) async {
    try {
      if (_isStreaming) {
        await stopImageStream();
      }
      await _controller?.dispose();

      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: kIsWeb
            ? null
            : (defaultTargetPlatform == TargetPlatform.android
                ? ImageFormatGroup.yuv420
                : ImageFormatGroup.bgra8888),
      );

      await _controller!.initialize();
      _isInitialized = true;
      _permissionDenied = false;
      return true;
    } on CameraException catch (e) {
      debugPrint('Failed to initialize CameraController: ${e.code}');
      if (e.code == 'CameraAccessDenied' || e.code == 'cameraPermission') {
        _permissionDenied = true;
        _errorMessage = 'Camera permission was denied. Tap to retry or enable in settings.';
      } else {
        _errorMessage = e.description ?? e.code;
      }
      _isInitialized = false;
      return false;
    } catch (e) {
      debugPrint('Failed to initialize CameraController: $e');
      _isInitialized = false;
      _errorMessage = e.toString();
      return false;
    }
  }

  /// Toggle between front and back camera.
  Future<bool> switchCamera() async {
    if (_availableCameras.length < 2) return false;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    if (_isStreaming) {
      await stopImageStream();
    }
    return await _initializeController(_availableCameras[_selectedCameraIndex]);
  }

  /// Starts live frame streaming for YOLO pose inference.
  Future<void> startImageStream(Function(CameraImage image) onAvailable) async {
    if (_controller == null || !_isInitialized || _isStreaming) return;
    try {
      _isStreaming = true;
      await _controller!.startImageStream(onAvailable);
    } catch (e) {
      debugPrint('Error starting camera stream: $e');
      _isStreaming = false;
    }
  }

  /// Stops live frame streaming.
  Future<void> stopImageStream() async {
    if (_controller == null || !_isStreaming) return;
    try {
      await _controller!.stopImageStream();
    } catch (e) {
      debugPrint('Error stopping camera stream: $e');
    } finally {
      _isStreaming = false;
    }
  }

  Future<void> dispose() async {
    try {
      if (_isStreaming) {
        await _controller?.stopImageStream();
      }
      await _controller?.dispose();
    } catch (_) {}
    _isInitialized = false;
    _isStreaming = false;
    _controller = null;
  }
}
