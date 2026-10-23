#ifndef REHABREP_ANGLE_H
#define REHABREP_ANGLE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    float x;
    float y;
    float confidence;
} KeyPoint2D;

/**
 * Calculates joint angle formed by three points: A -> B -> C.
 * For Knee: Hip (A) -> Knee (B) -> Ankle (C)
 * For Shoulder: Hip (A) -> Shoulder (B) -> Elbow (C)
 *
 * @param a Point A
 * @param b Point B (vertex joint)
 * @param c Point C
 * @return Joint angle in degrees [0.0f, 180.0f]
 */
float calculate_joint_angle(KeyPoint2D a, KeyPoint2D b, KeyPoint2D c);

/**
 * Applies Exponential Moving Average (EMA) smoothing to prevent raw frame jitter.
 *
 * @param current_raw The newly detected raw angle
 * @param previous_smoothed The previously smoothed angle
 * @param alpha Smoothing factor (0.0 to 1.0). Default ~0.35
 * @return Smoothed angle in degrees
 */
float smooth_angle_ema(float current_raw, float previous_smoothed, float alpha);

#ifdef __cplusplus
}
#endif

#endif // REHABREP_ANGLE_H
