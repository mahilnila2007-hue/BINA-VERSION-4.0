import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/exercise_presets.dart';
import '../../core/theme/color_palette.dart';
import '../../core/theme/typography.dart';
import '../../domain/models/prescription.dart';
import '../auth/auth_provider.dart';

/// Modal dialog allowing therapist to prescribe or adjust exercise ROM and sets/reps.
class PrescriptionBuilderDialog extends ConsumerStatefulWidget {
  final Prescription? initialPrescription;

  const PrescriptionBuilderDialog({super.key, this.initialPrescription});

  @override
  ConsumerState<PrescriptionBuilderDialog> createState() => _PrescriptionBuilderDialogState();
}

class _PrescriptionBuilderDialogState extends ConsumerState<PrescriptionBuilderDialog> {
  late String _selectedExerciseId;
  late double _minAngle;
  late double _maxAngle;
  late int _sets;
  late int _reps;
  late String _schedule;

  @override
  void initState() {
    super.initState();
    final p = widget.initialPrescription ?? ExercisePresets.kneeExtensionPrescription;
    _selectedExerciseId = p.exerciseId;
    _minAngle = p.minAngle;
    _maxAngle = p.maxAngle;
    _sets = p.sets;
    _reps = p.reps;
    _schedule = p.schedule;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: AppColors.surfaceLight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.assignment_add, color: AppColors.primary, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Prescribe Protocol',
                        style: AppTypography.headingMedium().copyWith(fontSize: 22),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 26),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Exercise Type Selector
              Text('Exercise Type', style: AppTypography.clinicalCaption()),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: ExercisePresets.kneeExtensionId,
                    label: Text('Knee Extension'),
                    icon: Icon(Icons.airline_seat_recline_normal_rounded),
                  ),
                  ButtonSegment(
                    value: ExercisePresets.shoulderAbductionId,
                    label: Text('Shoulder Abduction'),
                    icon: Icon(Icons.accessibility_new_rounded),
                  ),
                ],
                selected: {_selectedExerciseId},
                onSelectionChanged: (set) {
                  setState(() {
                    _selectedExerciseId = set.first;
                    if (_selectedExerciseId == ExercisePresets.kneeExtensionId) {
                      _minAngle = 80.0;
                      _maxAngle = 160.0;
                    } else {
                      _minAngle = 20.0;
                      _maxAngle = 110.0;
                    }
                  });
                },
              ),
              const SizedBox(height: 24),

              // Permitted Joint Angle Range (ROM)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Permitted Range of Motion (ROM)', style: AppTypography.clinicalCaption()),
                  Text(
                    '${_minAngle.toInt()}° — ${_maxAngle.toInt()}°',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              RangeSlider(
                values: RangeValues(_minAngle, _maxAngle),
                min: 0,
                max: 180,
                divisions: 36,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.cardBorderLight,
                labels: RangeLabels('${_minAngle.toInt()}°', '${_maxAngle.toInt()}°'),
                onChanged: (values) {
                  setState(() {
                    _minAngle = values.start;
                    _maxAngle = values.end;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Sets & Reps
              Row(
                children: [
                  // Sets
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sets', style: AppTypography.clinicalCaption()),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.cardBorderLight),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _sets,
                              isExpanded: true,
                              items: [1, 2, 3, 4, 5]
                                  .map((s) => DropdownMenuItem(value: s, child: Text('$s sets')))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _sets = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Reps
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reps per set', style: AppTypography.clinicalCaption()),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.cardBorderLight),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _reps,
                              isExpanded: true,
                              items: [5, 8, 10, 12, 15, 20]
                                  .map((r) => DropdownMenuItem(value: r, child: Text('$r reps')))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _reps = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Schedule
              Text('Schedule', style: AppTypography.clinicalCaption()),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.cardBorderLight),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _schedule,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'Daily - Morning & Evening', child: Text('Daily - Morning & Evening')),
                      DropdownMenuItem(value: 'Daily - Morning', child: Text('Daily - Morning')),
                      DropdownMenuItem(value: 'Daily - Afternoon', child: Text('Daily - Afternoon')),
                      DropdownMenuItem(value: '3x Weekly - Mon / Wed / Fri', child: Text('3x Weekly - Mon / Wed / Fri')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _schedule = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              ElevatedButton.icon(
                onPressed: () {
                  final isKnee = _selectedExerciseId == ExercisePresets.kneeExtensionId;
                  final newRx = Prescription(
                    id: 'rx_${DateTime.now().millisecondsSinceEpoch}',
                    patientId: AppConstants.defaultPatientId,
                    exerciseId: _selectedExerciseId,
                    exerciseName: isKnee ? 'Seated Knee Extension' : 'Shoulder Abduction',
                    minAngle: _minAngle,
                    maxAngle: _maxAngle,
                    sets: _sets,
                    reps: _reps,
                    schedule: _schedule,
                    cameraInstructions: isKnee
                        ? 'Place phone 6–8 feet away at side angle. Sit on a firm chair with hip, knee, and ankle clearly visible.'
                        : 'Place phone 6–8 feet away facing you. Stand or sit upright with torso, shoulder, and elbow clearly visible.',
                    targetJointName: isKnee ? 'Knee (Hip → Knee → Ankle)' : 'Shoulder (Hip → Shoulder → Elbow)',
                  );

                  ref.read(prescriptionRepositoryProvider).savePrescription(newRx);
                  ref.read(currentPrescriptionProvider.notifier).setPrescription(newRx);

                  Navigator.of(context).pop(newRx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Prescription updated: ${newRx.exerciseName} (${newRx.sets}×${newRx.reps})'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('SAVE PRESCRIPTION'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(64),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
