import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../domain/models/detected_pose.dart';
import '../domain/models/pose_keypoint.dart';
import 'tflite_loader.dart';

/// Vision AI Model Execution Status.
enum VisionAiStatus {
  unloaded,
  initializing,
  active,
  error,
}

/// Real-time YOLO Pose inference service.
/// Processes real camera frames using on-device TensorFlow Lite,
/// structures 17 COCO marked points, filters low-confidence detections,
/// applies temporal EMA smoothing, and projects accurately onto screen coordinates.
/// 
/// Strictly no simulated poses, fake keypoints, or random coordinates.
class YoloPoseService {
  static final YoloPoseService _instance = YoloPoseService._internal();
  factory YoloPoseService() => _instance;
  YoloPoseService._internal();

  PoseModelRunner? _runner;
  bool _isModelLoaded = false;
  bool _isProcessingFrame = false;
  VisionAiStatus _aiStatus = VisionAiStatus.unloaded;

  // Smoothing state for 17 keypoints: [x, y]
  final Map<CocoJoint, Offset> _smoothedKeypoints = {};
  final double _emaAlpha = 0.42; // Temporal smoothing factor

  // Pre-allocated reusable buffers to eliminate per-frame GC spikes
  static const int _inputSize = 192;
  List<List<List<List<int>>>>? _inputBuffer;
  List<List<List<List<double>>>>? _outputBuffer;

  // Performance Telemetry
  double _fps = 0.0;
  DateTime? _lastFrameTime;
  int _processedFrameCount = 0;

  bool get isModelLoaded => _isModelLoaded;
  VisionAiStatus get aiStatus => _aiStatus;
  double get fps => _fps;
  int get processedFrameCount => _processedFrameCount;

  /// Loads the YOLO Pose TFLite model from application assets.
  Future<bool> initializeModel() async {
    if (_isModelLoaded && _runner != null) {
      _aiStatus = VisionAiStatus.active;
      return true;
    }

    _aiStatus = VisionAiStatus.initializing;

    try {
      _runner = getPoseModelRunner();
      bool loaded = await _runner!.load('assets/models/yolov8n-pose.tflite');
      if (!loaded) {
        loaded = await _runner!.load('assets/models/pose_model.tflite');
      }

      _isModelLoaded = loaded;
      if (loaded) {
        // Pre-allocate inference tensors once
        _initBuffers();
        _aiStatus = VisionAiStatus.active;
        debugPrint('YoloPoseService: Neural network loaded successfully.');
      } else {
        _aiStatus = VisionAiStatus.error;
        debugPrint('YoloPoseService: Could not load YOLO pose model.');
      }
      return loaded;
    } catch (e) {
      debugPrint('YoloPoseService: Initialization error: $e');
      _isModelLoaded = false;
      _aiStatus = VisionAiStatus.error;
      return false;
    }
  }

  void _initBuffers() {
    _inputBuffer = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (_) => List.generate(
          _inputSize,
          (_) => [0, 0, 0],
        ),
      ),
    );

    _outputBuffer = List.generate(
      1,
      (_) => List.generate(
        1,
        (_) => List.generate(
          17,
          (_) => List.filled(3, 0.0),
        ),
      ),
    );
  }

  /// Processes a live camera frame from [CameraImage].
  /// Runs real neural network inference, extracts 17 COCO keypoints,
  /// and scales to [viewportSize].
  /// Drops frames if previous inference is still executing to maintain smooth 30+ FPS preview.
  Future<DetectedPose?> processCameraImage(
    CameraImage image,
    Size viewportSize, {
    bool isFrontCamera = true,
    int sensorOrientation = 90,
  }) async {
    if (_isProcessingFrame) return null; // Drop frame if previous is still executing
    _isProcessingFrame = true;

    try {
      if (!_isModelLoaded || _runner == null) {
        final loaded = await initializeModel();
        if (!loaded) {
          _aiStatus = VisionAiStatus.error;
          return DetectedPose.empty();
        }
      }

      if (_inputBuffer == null || _outputBuffer == null) {
        _initBuffers();
      }

      final pose = _runInference(
        image,
        viewportSize,
        isFrontCamera: isFrontCamera,
        sensorOrientation: sensorOrientation,
      );

      _updateFps();
      _aiStatus = VisionAiStatus.active;
      _processedFrameCount++;
      return pose;
    } catch (e) {
      debugPrint('Error during pose frame processing: $e');
      _aiStatus = VisionAiStatus.error;
      return DetectedPose.empty();
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Runs TFLite inference on [CameraImage] using pre-allocated buffers.
  DetectedPose _runInference(
    CameraImage image,
    Size viewportSize, {
    required bool isFrontCamera,
    required int sensorOrientation,
  }) {
    final planes = image.planes;
    if (planes.isEmpty) return DetectedPose.empty();

    final yPlane = planes[0];
    final bytes = yPlane.bytes;
    final bytesPerRow = yPlane.bytesPerRow;
    final imgW = image.width;
    final imgH = image.height;

    final input = _inputBuffer!;
    final output = _outputBuffer!;

    // Fill 1x192x192x3 input tensor from YUV420 plane 0 (luminance)
    // Respects camera sensor orientation (portrait rotation)
    for (int row = 0; row < _inputSize; row++) {
      for (int col = 0; col < _inputSize; col++) {
        int srcX;
        int srcY;

        if (sensorOrientation == 90) {
          // 90 deg clockwise (Standard Android back camera)
          srcX = ((_inputSize - 1 - row) * (imgW - 1)) ~/ _inputSize;
          srcY = (col * (imgH - 1)) ~/ _inputSize;
        } else if (sensorOrientation == 270) {
          // 270 deg (Common Android front camera)
          srcX = (row * (imgW - 1)) ~/ _inputSize;
          srcY = ((_inputSize - 1 - col) * (imgH - 1)) ~/ _inputSize;
        } else if (sensorOrientation == 180) {
          srcX = ((_inputSize - 1 - col) * (imgW - 1)) ~/ _inputSize;
          srcY = ((_inputSize - 1 - row) * (imgH - 1)) ~/ _inputSize;
        } else {
          // 0 deg
          srcX = (col * (imgW - 1)) ~/ _inputSize;
          srcY = (row * (imgH - 1)) ~/ _inputSize;
        }

        srcX = srcX.clamp(0, imgW - 1);
        srcY = srcY.clamp(0, imgH - 1);

        final offset = srcY * bytesPerRow + srcX;
        final val = (offset < bytes.length) ? bytes[offset] : 0;

        final pixel = input[0][row][col];
        pixel[0] = val;
        pixel[1] = val;
        pixel[2] = val;
      }
    }

    // Run real neural network
    _runner!.run(input, output);

    // Parse the 17 keypoints
    final rawKeypoints = output[0][0];
    final List<PoseKeypoint> detectedKeypoints = [];
    double totalConfidence = 0.0;
    int visibleCount = 0;

    double minX = double.infinity, minY = double.infinity;
    double maxX = 0.0, maxY = 0.0;

    for (int i = 0; i < 17; i++) {
      final rawY = rawKeypoints[i][0].clamp(0.0, 1.0);
      final rawX = rawKeypoints[i][1].clamp(0.0, 1.0);
      final score = rawKeypoints[i][2].clamp(0.0, 1.0);

      // Flip horizontally for front camera selfie mirror alignment
      final normX = isFrontCamera ? (1.0 - rawX) : rawX;
      final normY = rawY;

      final screenX = normX * viewportSize.width;
      final screenY = normY * viewportSize.height;

      final joint = CocoJoint.values[i];
      totalConfidence += score;
      if (score >= 0.35) visibleCount++;

      // EMA Temporal Smoothing
      final prev = _smoothedKeypoints[joint];
      final smoothedX = (prev == null)
          ? screenX
          : (_emaAlpha * screenX) + ((1.0 - _emaAlpha) * prev.dx);
      final smoothedY = (prev == null)
          ? screenY
          : (_emaAlpha * screenY) + ((1.0 - _emaAlpha) * prev.dy);
      _smoothedKeypoints[joint] = Offset(smoothedX, smoothedY);

      if (score >= 0.30) {
        minX = math.min(minX, smoothedX);
        minY = math.min(minY, smoothedY);
        maxX = math.max(maxX, smoothedX);
        maxY = math.max(maxY, smoothedY);
      }

      detectedKeypoints.add(PoseKeypoint(
        joint: joint,
        x: smoothedX,
        y: smoothedY,
        normalizedX: normX,
        normalizedY: normY,
        confidence: score,
      ));
    }

    final avgConfidence = totalConfidence / 17.0;
    // Strict person detection: require sufficient confidence and visible joints
    final isPersonDetected = avgConfidence >= 0.25 && visibleCount >= 4;

    if (!isPersonDetected) {
      return DetectedPose.empty();
    }

    final box = Rect.fromLTRB(
      (minX - 24).clamp(0.0, viewportSize.width),
      (minY - 24).clamp(0.0, viewportSize.height),
      (maxX + 24).clamp(0.0, viewportSize.width),
      (maxY + 24).clamp(0.0, viewportSize.height),
    );

    return DetectedPose(
      keypoints: detectedKeypoints,
      boundingBox: box,
      personConfidence: avgConfidence,
      isPersonDetected: true,
      measuredAngle: 0.0,
      targetJointName: '',
    );
  }

  void _updateFps() {
    final now = DateTime.now();
    if (_lastFrameTime != null) {
      final deltaMs = now.difference(_lastFrameTime!).inMilliseconds;
      if (deltaMs > 0) {
        final currentInstantFps = 1000.0 / deltaMs;
        _fps = (_fps == 0.0)
            ? currentInstantFps
            : (_fps * 0.85) + (currentInstantFps * 0.15);
      }
    }
    _lastFrameTime = now;
  }

  void dispose() {
    _runner?.close();
    _runner = null;
    _isModelLoaded = false;
    _aiStatus = VisionAiStatus.unloaded;
    _smoothedKeypoints.clear();
    _fps = 0.0;
    _lastFrameTime = null;
  }
}
