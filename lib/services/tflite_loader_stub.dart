/// Abstract contract for pose neural network runner.
abstract class PoseModelRunner {
  Future<bool> load(String assetPath);
  void run(dynamic input, dynamic output);
  void close();
}

PoseModelRunner getPoseModelRunner() => PoseModelRunnerStub();

class PoseModelRunnerStub implements PoseModelRunner {
  @override
  Future<bool> load(String assetPath) async => false;

  @override
  void run(dynamic input, dynamic output) {}

  @override
  void close() {}
}
