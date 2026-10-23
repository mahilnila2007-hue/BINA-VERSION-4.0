export 'tflite_loader_stub.dart' show PoseModelRunner;
export 'tflite_loader_stub.dart'
    if (dart.library.io) 'tflite_loader_io.dart'
    show getPoseModelRunner;
