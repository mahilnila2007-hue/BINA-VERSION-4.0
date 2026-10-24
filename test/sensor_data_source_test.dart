import 'package:flutter_test/flutter_test.dart';
import 'package:rehabrep/domain/models/sensor_reading.dart';
import 'package:rehabrep/services/exercise_analysis_engine.dart';
import 'package:rehabrep/services/sensor_data_source.dart';

void main() {
  group('SensorDataSource & DemoSensorDataSource Comprehensive Tests', () {
    test('1. Initial Demo State: values show realistic initial physiological baseline', () {
      final dataSource = DemoSensorDataSource(
        updateInterval: const Duration(milliseconds: 50),
      );

      final initialReading = dataSource.currentReading;
      expect(initialReading.heartRate, equals(72));
      expect(initialReading.spo2, equals(98));
      expect(initialReading.emgActivationPct, equals(42.0));
      expect(initialReading.isConnected, isTrue);
      expect(initialReading.temperature, inInclusiveRange(36.3, 37.2));
      expect(dataSource.mode, equals(SensorMode.demo));

      dataSource.dispose();
    });

    test('2. Continuous Loop: generates streaming readings within 100-250ms update cycle', () async {
      final dataSource = DemoSensorDataSource(
        updateInterval: const Duration(milliseconds: 20),
      );

      final receivedReadings = <SensorReading>[];
      final subscription = dataSource.readingStream.listen((reading) {
        receivedReadings.add(reading);
      });

      // Wait 120ms to collect several samples
      await Future.delayed(const Duration(milliseconds: 120));
      await subscription.cancel();
      dataSource.dispose();

      expect(receivedReadings.length, greaterThanOrEqualTo(3));
      for (final r in receivedReadings) {
        expect(r.heartRate, inInclusiveRange(60, 100));
        expect(r.spo2, inInclusiveRange(96, 99));
        expect(r.emgActivationPct, inInclusiveRange(5.0, 95.0));
        expect(r.isConnected, isTrue);
      }
    });

    test('3. Heart Rate Validation: strictly bounded in 60-100 BPM across cycles', () async {
      final dataSource = DemoSensorDataSource(
        updateInterval: const Duration(milliseconds: 10),
      );

      final hrValues = <int>[];
      final sub = dataSource.readingStream.listen((r) => hrValues.add(r.heartRate));

      await Future.delayed(const Duration(milliseconds: 250));
      await sub.cancel();
      dataSource.dispose();

      expect(hrValues.length, greaterThan(10));
      for (final hr in hrValues) {
        expect(hr, greaterThanOrEqualTo(60));
        expect(hr, lessThanOrEqualTo(100));
      }

      // Verify that values change smoothly and are not all identical static values
      final distinctHrs = hrValues.toSet();
      expect(distinctHrs.length, greaterThan(1));
    });

    test('4. SpO2 Validation: strictly bounded in 96-99%, never 70, 80, or 110%', () async {
      final dataSource = DemoSensorDataSource(
        updateInterval: const Duration(milliseconds: 10),
      );

      final spo2Values = <int>[];
      final sub = dataSource.readingStream.listen((r) => spo2Values.add(r.spo2));

      await Future.delayed(const Duration(milliseconds: 250));
      await sub.cancel();
      dataSource.dispose();

      expect(spo2Values.length, greaterThan(10));
      for (final spo2 in spo2Values) {
        expect(spo2, inInclusiveRange(96, 99));
        expect(spo2, isNot(equals(70)));
        expect(spo2, isNot(equals(80)));
        expect(spo2, isNot(equals(110)));
      }
    });

    test('5. Exercise-Responsive EMG: transitions between Rest, Movement, and Contraction', () async {
      final dataSource = DemoSensorDataSource(
        updateInterval: const Duration(milliseconds: 15),
      );

      // 1. Resting phase
      dataSource.updateExerciseState(
        phase: RepCyclePhase.resting,
        currentAngle: 10.0,
        isContracting: false,
      );
      await Future.delayed(const Duration(milliseconds: 120));
      final restReading = dataSource.currentReading;
      expect(restReading.emgActivationPct, inInclusiveRange(5.0, 25.0));

      // 2. Movement phase
      dataSource.updateExerciseState(
        phase: RepCyclePhase.movingOut,
        currentAngle: 45.0,
        isContracting: false,
      );
      await Future.delayed(const Duration(milliseconds: 120));
      final moveReading = dataSource.currentReading;
      expect(moveReading.emgActivationPct, inInclusiveRange(20.0, 55.0));

      // 3. Contraction / Active Target phase
      dataSource.updateExerciseState(
        phase: RepCyclePhase.inTargetZone,
        currentAngle: 90.0,
        isContracting: true,
      );
      await Future.delayed(const Duration(milliseconds: 160));
      final contractReading = dataSource.currentReading;
      expect(contractReading.emgActivationPct, inInclusiveRange(50.0, 88.0));
      expect(contractReading.heartRate, inInclusiveRange(75, 100));

      // 4. Returning to rest
      dataSource.updateExerciseState(
        phase: RepCyclePhase.returning,
        currentAngle: 20.0,
        isContracting: false,
      );
      await Future.delayed(const Duration(milliseconds: 150));
      final relaxedReading = dataSource.currentReading;
      expect(relaxedReading.emgActivationPct, lessThan(contractReading.emgActivationPct));

      dataSource.dispose();
    });

    test('6. Temperature Validation: stays strictly in 36.3 - 37.2 range', () async {
      final dataSource = DemoSensorDataSource(
        updateInterval: const Duration(milliseconds: 10),
      );

      final tempValues = <double>[];
      final sub = dataSource.readingStream.listen((r) => tempValues.add(r.temperature));

      await Future.delayed(const Duration(milliseconds: 150));
      await sub.cancel();
      dataSource.dispose();

      for (final temp in tempValues) {
        expect(temp, inInclusiveRange(36.3, 37.2));
      }
    });

    test('7. RealSensorDataSource: starts disconnected and ingests hardware packets cleanly', () async {
      final realSource = RealSensorDataSource();
      expect(realSource.mode, equals(SensorMode.realTime));
      expect(realSource.isHardwareConnected, isFalse);
      expect(realSource.currentReading.isConnected, isFalse);

      final received = <SensorReading>[];
      final sub = realSource.readingStream.listen((r) => received.add(r));

      // Ingest live ESP32 packet
      realSource.ingestHardwarePacket(
        heartRate: 76,
        spo2: 99,
        emgActivationPct: 48.5,
        emgRaw: 485.0,
        temperature: 36.8,
        kneeAngle: 85.0,
      );

      await Future.delayed(const Duration(milliseconds: 10));

      expect(realSource.isHardwareConnected, isTrue);
      expect(realSource.currentReading.isConnected, isTrue);
      expect(realSource.currentReading.heartRate, equals(76));
      expect(realSource.currentReading.spo2, equals(99));
      expect(realSource.currentReading.emgActivationPct, equals(48.5));
      expect(received.length, equals(1));

      // Disconnect
      realSource.markDisconnected();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(realSource.isHardwareConnected, isFalse);
      expect(realSource.currentReading.isConnected, isFalse);
      expect(received.length, equals(2));

      await sub.cancel();
      realSource.dispose();
    });
  });
}
