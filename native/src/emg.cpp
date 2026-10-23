#include "../include/emg.h"
#include <cmath>

float calculate_emg_rms(const float* samples, int count) {
    if (!samples || count <= 0) return 0.0f;

    float sum_squares = 0.0f;
    for (int i = 0; i < count; ++i) {
        sum_squares += (samples[i] * samples[i]);
    }

    return std::sqrt(sum_squares / static_cast<float>(count));
}

float normalize_emg_activation(float current_rms, float mvc_rms) {
    if (mvc_rms <= 1e-4f) return 0.0f;

    float pct = (current_rms / mvc_rms) * 100.0f;
    if (pct < 0.0f) pct = 0.0f;
    if (pct > 100.0f) pct = 100.0f;

    return pct;
}
