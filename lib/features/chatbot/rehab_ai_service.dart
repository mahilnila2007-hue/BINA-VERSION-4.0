import 'dart:async';
import '../../domain/models/prescription.dart';

/// ReHab AI Assistant Service.
/// Provides friendly, clear rehabilitation guidance and answers
/// patient questions while strictly adhering to healthcare safety guardrails.
class ReHabAiService {
  static const String safetyWarningPrescription =
      'Your exercise plan was set by your physiotherapist, Dr. Priya. Please check with them before changing your repetitions or range of motion.';

  static const String safetyWarningDiagnosis =
      'I am an exercise and rehabilitation assistant, not a doctor. I cannot diagnose pain or symptoms. If you experience sharp pain or dizziness, please rest immediately and consult Dr. Priya.';

  /// Responds to patient queries with contextual knowledge of their current prescription.
  Future<String> askQuestion({
    required String query,
    required Prescription? currentPrescription,
    required double currentAdherence,
  }) async {
    // Simulated realistic AI response latency
    await Future.delayed(const Duration(milliseconds: 500));

    final cleanQuery = query.toLowerCase().trim();

    // Guardrail 1: Changing or increasing prescription (Section 23)
    if (cleanQuery.contains('increase') ||
        cleanQuery.contains('more reps') ||
        cleanQuery.contains('change prescription') ||
        cleanQuery.contains('add sets') ||
        cleanQuery.contains('can i do more')) {
      return safetyWarningPrescription;
    }

    // Guardrail 2: Medical diagnosis / pain diagnosis
    if (cleanQuery.contains('pain') ||
        cleanQuery.contains('hurt') ||
        cleanQuery.contains('diagnose') ||
        cleanQuery.contains('swollen') ||
        cleanQuery.contains('injury')) {
      return '$safetyWarningDiagnosis\n\nFor mild muscular tiredness, rest between sets. If it hurts, stop the exercise.';
    }

    // Question 1: How should I position the camera? (Section 22)
    if (cleanQuery.contains('camera') ||
        cleanQuery.contains('position') ||
        cleanQuery.contains('where to place') ||
        cleanQuery.contains('phone')) {
      return 'Place your phone about 6 to 8 feet away on a stable table or shelf at waist height.\n\n'
          'For your ${currentPrescription?.exerciseName ?? "Knee Extension"}, position the camera at your side so your hip, knee, and ankle are all visible.';
    }

    // Question 2: What does knee extension mean? (Section 22)
    if (cleanQuery.contains('knee extension') ||
        cleanQuery.contains('what does') ||
        cleanQuery.contains('what is')) {
      return 'Knee extension means sitting upright on a firm chair and straightening your leg out in front of you.\n\n'
          'Your target is to gently reach between ${currentPrescription?.minAngle.toInt() ?? 80}° and ${currentPrescription?.maxAngle.toInt() ?? 160}° without locking the joint forcefully.';
    }

    // Question 3: Why am I getting "bend more"? (Section 22)
    if (cleanQuery.contains('bend more') ||
        cleanQuery.contains('bend a little more') ||
        cleanQuery.contains('shallow')) {
      return 'When ReHabRep says "Bend a little more", it means your leg did not quite reach the prescribed movement depth (${currentPrescription?.maxAngle.toInt() ?? 160}°).\n\n'
          'Try extending a little further upward at the top of the repetition while keeping your thighs supported on the chair.';
    }

    // Question 4: How many exercises do I have today? (Section 22)
    if (cleanQuery.contains('how many') ||
        cleanQuery.contains('today') ||
        cleanQuery.contains('plan') ||
        cleanQuery.contains('routine')) {
      return 'Today your prescribed exercise is ${currentPrescription?.exerciseName ?? "Seated Knee Extension"} for ${currentPrescription?.sets ?? 3} sets of ${currentPrescription?.reps ?? 10} repetitions (${currentPrescription?.schedule ?? "Daily"}).';
    }

    // Question 5: What does 80% adherence mean? (Section 22)
    if (cleanQuery.contains('adherence') ||
        cleanQuery.contains('80%') ||
        cleanQuery.contains('percentage') ||
        cleanQuery.contains('accuracy')) {
      return 'Your adherence score (${currentAdherence.toStringAsFixed(0)}%) reflects how closely your movements matched Dr. Priya\'s prescribed range of motion.\n\n'
          '80% or higher is considered excellent rehabilitation form!';
    }

    // Default friendly educational response
    return 'I am ReHab AI, your exercise companion. You can ask me how to position your camera, how your repetitions are counted, or what your exercise range means.\n\n'
        'Remember that your exercise plan is managed by your physiotherapist, Dr. Priya.';
  }
}
