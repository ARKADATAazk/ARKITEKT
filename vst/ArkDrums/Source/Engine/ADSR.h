/*
  ==============================================================================

    ADSR.h
    ArkDrums - Professional Drum Sampler
    ADSR Envelope Generator

    Simple, efficient ADSR for per-voice amplitude envelopes.

  ==============================================================================
*/

#pragma once

#include <cmath>
#include "../Utils/Constants.h"

namespace ArkDrums {

class ADSR {
public:
    enum Stage {
        IDLE,
        ATTACK,
        DECAY,
        SUSTAIN,
        RELEASE
    };

    ADSR()
        : stage_(IDLE)
        , current_level_(0.0f)
        , sample_rate_(DEFAULT_SAMPLE_RATE)
        , attack_samples_(0.0f)
        , decay_samples_(0.0f)
        , sustain_level_(0.0f)
        , release_samples_(0.0f)
        , samples_in_stage_(0)
    {
        setParameters(DEFAULT_ATTACK, DEFAULT_DECAY, DEFAULT_SUSTAIN, DEFAULT_RELEASE);
    }

    // ========================================================================
    // CONFIGURATION
    // ========================================================================

    void setSampleRate(double sampleRate) {
        sample_rate_ = sampleRate;
        updateCoefficients();
    }

    void setParameters(float attack_sec, float decay_sec, float sustain_level, float release_sec) {
        attack_sec_ = attack_sec;
        decay_sec_ = decay_sec;
        sustain_level_ = sustain_level;
        release_sec_ = release_sec;
        updateCoefficients();
    }

    void setAttack(float attack_sec) {
        attack_sec_ = attack_sec;
        attack_samples_ = attack_sec * static_cast<float>(sample_rate_);
    }

    void setDecay(float decay_sec) {
        decay_sec_ = decay_sec;
        decay_samples_ = decay_sec * static_cast<float>(sample_rate_);
    }

    void setSustain(float sustain_level) {
        sustain_level_ = sustain_level;
    }

    void setRelease(float release_sec) {
        release_sec_ = release_sec;
        release_samples_ = release_sec * static_cast<float>(sample_rate_);
    }

    // ========================================================================
    // CONTROL
    // ========================================================================

    void noteOn() {
        stage_ = ATTACK;
        samples_in_stage_ = 0;
        // Don't reset current_level_ to allow re-triggering (important for drums)
    }

    void noteOff() {
        stage_ = RELEASE;
        samples_in_stage_ = 0;
        // For drums, we often want immediate release, so capture current level
        release_start_level_ = current_level_;
    }

    void reset() {
        stage_ = IDLE;
        current_level_ = 0.0f;
        samples_in_stage_ = 0;
    }

    // ========================================================================
    // PROCESSING
    // ========================================================================

    /// Process one sample, return envelope level (0.0 - 1.0)
    float process() {
        switch (stage_) {
            case IDLE:
                current_level_ = 0.0f;
                break;

            case ATTACK:
                if (attack_samples_ > 0) {
                    current_level_ = static_cast<float>(samples_in_stage_) / attack_samples_;
                    if (current_level_ >= 1.0f) {
                        current_level_ = 1.0f;
                        stage_ = DECAY;
                        samples_in_stage_ = 0;
                    }
                } else {
                    // Instant attack
                    current_level_ = 1.0f;
                    stage_ = DECAY;
                    samples_in_stage_ = 0;
                }
                break;

            case DECAY:
                if (decay_samples_ > 0) {
                    float decay_progress = static_cast<float>(samples_in_stage_) / decay_samples_;
                    current_level_ = 1.0f - (decay_progress * (1.0f - sustain_level_));

                    if (decay_progress >= 1.0f) {
                        current_level_ = sustain_level_;
                        stage_ = SUSTAIN;
                        samples_in_stage_ = 0;
                    }
                } else {
                    // Instant decay
                    current_level_ = sustain_level_;
                    stage_ = SUSTAIN;
                    samples_in_stage_ = 0;
                }
                break;

            case SUSTAIN:
                current_level_ = sustain_level_;

                // For one-shot drums (sustain = 0), immediately go to release
                if (sustain_level_ == 0.0f) {
                    stage_ = RELEASE;
                    samples_in_stage_ = 0;
                    release_start_level_ = 0.0f;
                }
                break;

            case RELEASE:
                if (release_samples_ > 0) {
                    float release_progress = static_cast<float>(samples_in_stage_) / release_samples_;
                    current_level_ = release_start_level_ * (1.0f - release_progress);

                    if (release_progress >= 1.0f) {
                        current_level_ = 0.0f;
                        stage_ = IDLE;
                    }
                } else {
                    // Instant release
                    current_level_ = 0.0f;
                    stage_ = IDLE;
                }
                break;
        }

        ++samples_in_stage_;
        return current_level_;
    }

    // ========================================================================
    // QUERY
    // ========================================================================

    bool isActive() const {
        return stage_ != IDLE;
    }

    Stage getStage() const {
        return stage_;
    }

    float getCurrentLevel() const {
        return current_level_;
    }

private:
    void updateCoefficients() {
        attack_samples_ = attack_sec_ * static_cast<float>(sample_rate_);
        decay_samples_ = decay_sec_ * static_cast<float>(sample_rate_);
        release_samples_ = release_sec_ * static_cast<float>(sample_rate_);
    }

    // Stage
    Stage stage_;
    float current_level_;
    int samples_in_stage_;

    // Configuration
    double sample_rate_;
    float attack_sec_;
    float decay_sec_;
    float sustain_level_;
    float release_sec_;

    // Computed coefficients
    float attack_samples_;
    float decay_samples_;
    float release_samples_;
    float release_start_level_;  // Level when release started
};

} // namespace ArkDrums
