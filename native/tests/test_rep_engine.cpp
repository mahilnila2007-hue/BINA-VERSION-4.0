#include <iostream>
#include <cassert>
#include <cmath>
#include "../include/angle.h"
#include "../include/rep_engine.h"
#include "../include/emg.h"

void test_angle_calculation() {
    std::cout << "[Test] Joint Angle Geometry... ";
    KeyPoint2D a = {0.0f, 10.0f, 0.9f}; // Hip
    KeyPoint2D b = {0.0f, 0.0f, 0.9f};  // Knee
    KeyPoint2D c = {10.0f, 0.0f, 0.9f}; // Ankle (90 degree right angle)

    float angle = calculate_joint_angle(a, b, c);
    assert(std::fabs(angle - 90.0f) < 0.1f);

    // Straight leg 180 degrees
    KeyPoint2D c_straight = {0.0f, -10.0f, 0.9f};
    float angle_straight = calculate_joint_angle(a, b, c_straight);
    assert(std::fabs(angle_straight - 180.0f) < 0.1f);

    std::cout << "PASSED (90° and 180° verified)\n";
}

void test_angle_smoothing() {
    std::cout << "[Test] Angle EMA Smoothing... ";
    float raw = 150.0f;
    float prev = 140.0f;
    float alpha = 0.35f;

    float smoothed = smooth_angle_ema(raw, prev, alpha);
    float expected = (0.35f * 150.0f) + (0.65f * 140.0f);
    assert(std::fabs(smoothed - expected) < 0.01f);

    std::cout << "PASSED (" << smoothed << "°)\n";
}

void test_rep_state_machine() {
    std::cout << "[Test] Repetition State Machine & Range Verification... ";
    RepEngineContext ctx;
    rep_engine_init(&ctx, 80.0f, 160.0f);

    CompletedRepResult result;
    double t = 0.0;

    // Rep 1: Correct Extension (80 -> 148 -> 82) over 2.4 seconds
    int rep1 = rep_engine_update(&ctx, 80.0f, t, 50.0f, &result);
    assert(rep1 == 0);
    assert(ctx.current_state == REP_STATE_REST);

    t += 0.5;
    rep_engine_update(&ctx, 110.0f, t, 65.0f, &result);
    assert(ctx.current_state == REP_STATE_MOVING);

    t += 0.7;
    rep_engine_update(&ctx, 148.0f, t, 85.0f, &result); // Peak
    t += 0.5;
    rep_engine_update(&ctx, 130.0f, t, 60.0f, &result); // Past peak
    assert(ctx.current_state == REP_STATE_RETURNING);

    t += 0.7;
    int finished = rep_engine_update(&ctx, 84.0f, t, 30.0f, &result); // Return to rest
    assert(finished == 1);
    assert(result.rep_number == 1);
    assert(result.verdict == VERDICT_CORRECT);

    std::cout << "PASSED (Rep #1 CORRECT detected)\n";
}

void test_emg_processing() {
    std::cout << "[Test] EMG RMS & MVC Normalization... ";
    float samples[] = {10.0f, -10.0f, 10.0f, -10.0f};
    float rms = calculate_emg_rms(samples, 4);
    assert(std::fabs(rms - 10.0f) < 0.01f);

    float mvc = 20.0f;
    float activation = normalize_emg_activation(rms, mvc);
    assert(std::fabs(activation - 50.0f) < 0.01f);

    std::cout << "PASSED (50% activation verified)\n";
}

int main() {
    std::cout << "========================================\n";
    std::cout << "ReHabRep C++ Native Rep Engine Tests\n";
    std::cout << "========================================\n";

    test_angle_calculation();
    test_angle_smoothing();
    test_rep_state_machine();
    test_emg_processing();

    std::cout << "========================================\n";
    std::cout << "ALL NATIVE C++ ENGINE TESTS PASSED!\n";
    std::cout << "========================================\n";
    return 0;
}
