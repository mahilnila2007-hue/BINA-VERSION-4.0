#include "../include/angle.h"
#include <cmath>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

float calculate_joint_angle(KeyPoint2D a, KeyPoint2D b, KeyPoint2D c) {
    // Vector BA: from B to A
    float v1_x = a.x - b.x;
    float v1_y = a.y - b.y;

    // Vector BC: from B to C
    float v2_x = c.x - b.x;
    float v2_y = c.y - b.y;

    // Dot product: v1 . v2
    float dot_product = (v1_x * v2_x) + (v1_y * v2_y);

    // Magnitudes
    float mag1 = std::sqrt((v1_x * v1_x) + (v1_y * v1_y));
    float mag2 = std::sqrt((v2_x * v2_x) + (v2_y * v2_y));

    if (mag1 < 1e-5f || mag2 < 1e-5f) {
        return 0.0f;
    }

    // Cosine of angle
    float cosine = dot_product / (mag1 * mag2);

    // Clamp cosine within [-1.0, 1.0] to prevent NaN
    if (cosine > 1.0f) cosine = 1.0f;
    if (cosine < -1.0f) cosine = -1.0f;

    // Angle in radians then convert to degrees
    float radians = std::acos(cosine);
    float degrees = radians * (180.0f / static_cast<float>(M_PI));

    return degrees;
}

float smooth_angle_ema(float current_raw, float previous_smoothed, float alpha) {
    if (previous_smoothed <= 0.0f) {
        return current_raw; // First reading
    }
    return (alpha * current_raw) + ((1.0f - alpha) * previous_smoothed);
}
