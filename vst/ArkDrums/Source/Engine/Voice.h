/*
  ==============================================================================

    Voice.h
    ArkDrums - Professional Drum Sampler
    Voice = Active playing sample instance

    Each voice plays one sample with ADSR, pitch shift, pan, etc.

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "ADSR.h"
#include "../Utils/Constants.h"
#include <cmath>

namespace ArkDrums {

/// Represents a single playing sample instance
class Voice {
public:
    Voice()
        : active_(false)
        , pad_index_(-1)
        , velocity_(0)
        , playback_position_(0.0)
        , sample_buffer_(nullptr)
        , volume_(1.0f)
        , pan_(0.5f)
        , pitch_ratio_(1.0)
        , sample_rate_(DEFAULT_SAMPLE_RATE)
    {
    }

    // ========================================================================
    // TRIGGER
    // ========================================================================

    /// Start playing a sample
    void trigger(
        int pad_index,
        int velocity,
        const juce::AudioBuffer<float>* sample_buffer,
        float volume,
        float pan,
        float tune_semitones,
        const ADSR& adsr_template
    ) {
        pad_index_ = pad_index;
        velocity_ = velocity;
        sample_buffer_ = sample_buffer;
        volume_ = volume;
        pan_ = pan;

        // Calculate pitch ratio from semitones
        // ratio = 2^(semitones/12)
        pitch_ratio_ = std::pow(2.0, tune_semitones / 12.0);

        // Reset playback
        playback_position_ = 0.0;

        // Copy ADSR template and trigger
        adsr_ = adsr_template;
        adsr_.setSampleRate(sample_rate_);
        adsr_.noteOn();

        active_ = true;
    }

    /// Stop the voice (release)
    void release() {
        if (active_) {
            adsr_.noteOff();
        }
    }

    /// Immediately kill the voice (for kill groups)
    void kill() {
        active_ = false;
        adsr_.reset();
    }

    // ========================================================================
    // PROCESSING
    // ========================================================================

    /// Render audio into output buffer
    /// @param output_buffer Destination buffer (stereo)
    /// @param num_samples Number of samples to render
    void render(juce::AudioBuffer<float>& output_buffer, int num_samples) {
        if (!active_ || sample_buffer_ == nullptr || sample_buffer_->getNumSamples() == 0) {
            return;
        }

        const int num_channels = output_buffer.getNumChannels();
        const int sample_channels = sample_buffer_->getNumChannels();
        const int sample_length = sample_buffer_->getNumSamples();

        // Pre-calculate pan gains (constant power)
        float left_gain = std::cos(pan_ * 1.5707963f);   // cos(pan * π/2)
        float right_gain = std::sin(pan_ * 1.5707963f);  // sin(pan * π/2)

        // Apply velocity curve (linear for now, could be exponential)
        float velocity_gain = static_cast<float>(velocity_) / 127.0f;

        for (int i = 0; i < num_samples; ++i) {
            // Check if we've reached end of sample
            int sample_index = static_cast<int>(playback_position_);
            if (sample_index >= sample_length) {
                active_ = false;
                break;
            }

            // Get sample value (with linear interpolation for pitch shift)
            float sample_value = getSampleValueInterpolated(sample_index);

            // Apply ADSR envelope
            float envelope = adsr_.process();

            // Apply gains
            float final_value = sample_value * envelope * volume_ * velocity_gain;

            // Render to output (stereo)
            if (num_channels > 0) {
                output_buffer.addSample(0, i, final_value * left_gain);
            }
            if (num_channels > 1) {
                output_buffer.addSample(1, i, final_value * right_gain);
            }

            // Advance playback position (with pitch shift)
            playback_position_ += pitch_ratio_;

            // If ADSR finished and we're in release, deactivate
            if (!adsr_.isActive()) {
                active_ = false;
                break;
            }
        }
    }

    // ========================================================================
    // QUERY
    // ========================================================================

    bool isActive() const { return active_; }
    int getPadIndex() const { return pad_index_; }
    int getVelocity() const { return velocity_; }

    // ========================================================================
    // CONFIGURATION
    // ========================================================================

    void setSampleRate(double sample_rate) {
        sample_rate_ = sample_rate;
        adsr_.setSampleRate(sample_rate);
    }

private:
    /// Get sample value with linear interpolation (for pitch shifting)
    float getSampleValueInterpolated(int base_index) const {
        if (sample_buffer_ == nullptr || base_index < 0) {
            return 0.0f;
        }

        const int sample_length = sample_buffer_->getNumSamples();
        const int sample_channels = sample_buffer_->getNumChannels();

        // Bounds check
        if (base_index >= sample_length - 1) {
            // Last sample, no interpolation
            if (base_index < sample_length) {
                return sample_channels > 0 ? sample_buffer_->getSample(0, base_index) : 0.0f;
            }
            return 0.0f;
        }

        // Linear interpolation
        float frac = playback_position_ - static_cast<float>(base_index);
        float sample1 = sample_channels > 0 ? sample_buffer_->getSample(0, base_index) : 0.0f;
        float sample2 = sample_channels > 0 ? sample_buffer_->getSample(0, base_index + 1) : 0.0f;

        // Mix stereo to mono if sample is stereo
        if (sample_channels > 1) {
            sample1 = (sample1 + sample_buffer_->getSample(1, base_index)) * 0.5f;
            sample2 = (sample2 + sample_buffer_->getSample(1, base_index + 1)) * 0.5f;
        }

        return sample1 + frac * (sample2 - sample1);
    }

    // State
    bool active_;
    int pad_index_;
    int velocity_;
    double playback_position_;

    // Sample reference (not owned)
    const juce::AudioBuffer<float>* sample_buffer_;

    // Voice parameters
    float volume_;
    float pan_;
    double pitch_ratio_;
    double sample_rate_;

    // Envelope
    ADSR adsr_;
};

} // namespace ArkDrums
