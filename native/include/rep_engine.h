#ifndef REHABREP_REP_ENGINE_H
#define REHABREP_REP_ENGINE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    REP_STATE_REST = 0,
    REP_STATE_MOVING,
    REP_STATE_PEAK,
    REP_STATE_RETURNING,
    REP_STATE_REP_COMPLETE
} RepStateMachineState;

typedef enum {
    VERDICT_UNKNOWN = 0,
    VERDICT_CORRECT,
    VERDICT_TOO_SHALLOW,
    VERDICT_OVERSHOOT,
    VERDICT_TOO_FAST,
    VERDICT_LOW_MUSCLE_ENGAGEMENT
} RepVerdictCode;

typedef struct {
    int rep_number;
    float peak_angle;
    float duration_seconds;
    RepVerdictCode verdict;
    float emg_activation_pct;
} CompletedRepResult;

typedef struct {
    // Configuration
    float min_prescribed_angle;
    float max_prescribed_angle;
    float hysteresis_degrees;
    float min_rep_duration_sec;
    float max_rep_duration_sec;

    // Internal State
    RepStateMachineState current_state;
    int completed_reps;
    int correct_reps;
    float peak_angle_reached;
    double movement_start_timestamp;
    float last_smoothed_angle;
    bool is_extending;
} RepEngineContext;

/**
 * Initializes RepEngine context with clinical parameters.
 */
void rep_engine_init(RepEngineContext* ctx, float min_angle, float max_angle);

/**
 * Updates repetition engine state machine with newly smoothed angle frame.
 *
 * @param ctx Engine context
 * @param smoothed_angle Current smoothed angle in degrees
 * @param timestamp_seconds Monotonic timestamp in seconds
 * @param current_emg_pct Normalized muscle engagement (0-100)
 * @param out_result Populated with rep data when a repetition completes
 * @return 1 if a repetition just completed on this frame, 0 otherwise
 */
int rep_engine_update(
    RepEngineContext* ctx,
    float smoothed_angle,
    double timestamp_seconds,
    float current_emg_pct,
    CompletedRepResult* out_result
);

#ifdef __cplusplus
}
#endif

#endif // REHABREP_REP_ENGINE_H
