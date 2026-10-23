#ifndef REHABREP_EMG_H
#define REHABREP_EMG_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Calculates Root Mean Square (RMS) of EMG signal over a window of samples.
 *
 * @param samples Array of raw EMG ADC or microvolt values
 * @param count Number of samples in the window
 * @return RMS magnitude
 */
float calculate_emg_rms(const float* samples, int count);

/**
 * Normalizes raw EMG RMS against patient calibration / MVC (Maximum Voluntary Contraction).
 *
 * @param current_rms Current calculated RMS value
 * @param mvc_rms Calibrated MVC RMS value
 * @return Muscle engagement percentage clamped to [0.0f, 100.0f]
 */
float normalize_emg_activation(float current_rms, float mvc_rms);

#ifdef __cplusplus
}
#endif

#endif // REHABREP_EMG_H
