#include "../include/rep_engine.h"
#include <algorithm>

void rep_engine_init(RepEngineContext* ctx, float min_angle, float max_angle) {
    if (!ctx) return;
    ctx->min_prescribed_angle = min_angle;
    ctx->max_prescribed_angle = max_angle;
    ctx->hysteresis_degrees = 4.0f;
    ctx->min_rep_duration_sec = 1.2f;
    ctx->max_rep_duration_sec = 8.0f;

    ctx->current_state = REP_STATE_REST;
    ctx->completed_reps = 0;
    ctx->correct_reps = 0;
    ctx->peak_angle_reached = min_angle;
    ctx->movement_start_timestamp = 0.0;
    ctx->last_smoothed_angle = min_angle;
    ctx->is_extending = false;
}

int rep_engine_update(
    RepEngineContext* ctx,
    float smoothed_angle,
    double timestamp_seconds,
    float current_emg_pct,
    CompletedRepResult* out_result
) {
    if (!ctx) return 0;

    int rep_completed = 0;
    float start_threshold = ctx->min_prescribed_angle + ctx->hysteresis_degrees;
    float return_threshold = ctx->min_prescribed_angle + (ctx->hysteresis_degrees * 1.5f);

    switch (ctx->current_state) {
        case REP_STATE_REST:
            // Trigger movement when angle crosses hysteresis threshold away from rest
            if (smoothed_angle > start_threshold) {
                ctx->current_state = REP_STATE_MOVING;
                ctx->movement_start_timestamp = timestamp_seconds;
                ctx->peak_angle_reached = smoothed_angle;
                ctx->is_extending = true;
            }
            break;

        case REP_STATE_MOVING:
            if (smoothed_angle > ctx->peak_angle_reached) {
                ctx->peak_angle_reached = smoothed_angle;
            }

            // If angle starts decreasing significantly, we have passed the peak
            if (smoothed_angle < (ctx->peak_angle_reached - ctx->hysteresis_degrees)) {
                ctx->current_state = REP_STATE_RETURNING;
                ctx->is_extending = false;
            }
            break;

        case REP_STATE_RETURNING:
            // Return back toward rest position
            if (smoothed_angle <= return_threshold) {
                // REP COMPLETE
                ctx->completed_reps++;
                float rep_duration = static_cast<float>(timestamp_seconds - ctx->movement_start_timestamp);

                // Form Evaluation Logic
                RepVerdictCode verdict = VERDICT_CORRECT;

                if (rep_duration < ctx->min_rep_duration_sec) {
                    verdict = VERDICT_TOO_FAST;
                } else if (ctx->peak_angle_reached < (ctx->min_prescribed_angle + (ctx->max_prescribed_angle - ctx->min_prescribed_angle) * 0.65f)) {
                    verdict = VERDICT_TOO_SHALLOW;
                } else if (ctx->peak_angle_reached > (ctx->max_prescribed_angle + 6.0f)) {
                    verdict = VERDICT_OVERSHOOT;
                } else if (current_emg_pct > 0.0f && current_emg_pct < 28.0f) {
                    verdict = VERDICT_LOW_MUSCLE_ENGAGEMENT;
                } else {
                    verdict = VERDICT_CORRECT;
                    ctx->correct_reps++;
                }

                if (out_result) {
                    out_result->rep_number = ctx->completed_reps;
                    out_result->peak_angle = ctx->peak_angle_reached;
                    out_result->duration_seconds = rep_duration;
                    out_result->verdict = verdict;
                    out_result->emg_activation_pct = current_emg_pct;
                }

                rep_completed = 1;
                ctx->current_state = REP_STATE_REST;
                ctx->peak_angle_reached = ctx->min_prescribed_angle;
            }
            break;

        default:
            ctx->current_state = REP_STATE_REST;
            break;
    }

    ctx->last_smoothed_angle = smoothed_angle;
    return rep_completed;
}
