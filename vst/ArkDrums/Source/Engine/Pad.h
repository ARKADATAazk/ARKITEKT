/*
  ==============================================================================

    Pad.h
    ArkDrums - Professional Drum Sampler
    Individual drum pad with sample(s), ADSR, and per-pad settings

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "ADSR.h"
#include "../Utils/Constants.h"
#include <vector>
#include <memory>
#include <string>

namespace ArkDrums {

/// Represents a single drum pad
class Pad {
public:
    /// Sample layer (velocity-sensitive)
    struct SampleLayer {
        int velocity_min;  // 0-127
        int velocity_max;  // 0-127
        std::vector<std::unique_ptr<juce::AudioBuffer<float>>> samples;  // Round-robin
        int round_robin_index = 0;

        SampleLayer(int vel_min = 0, int vel_max = 127)
            : velocity_min(vel_min), velocity_max(vel_max) {}

        // Add a sample to this layer
        void addSample(std::unique_ptr<juce::AudioBuffer<float>> sample) {
            samples.push_back(std::move(sample));
        }

        // Get next sample (round-robin)
        const juce::AudioBuffer<float>* getNextSample() {
            if (samples.empty()) return nullptr;

            const auto* sample = samples[round_robin_index].get();
            round_robin_index = (round_robin_index + 1) % samples.size();
            return sample;
        }

        bool hasSamples() const {
            return !samples.empty();
        }
    };

    // ========================================================================
    // CONSTRUCTOR
    // ========================================================================

    Pad(int index, int midi_note)
        : index_(index)
        , midi_note_(midi_note)
        , name_("Pad " + std::to_string(index + 1))
        , volume_(DEFAULT_VOLUME)
        , pan_(DEFAULT_PAN)
        , tune_(DEFAULT_TUNE)
        , fine_tune_(DEFAULT_FINE_TUNE)
        , muted_(false)
        , soloed_(false)
        , output_bus_(0)  // Main output
        , kill_group_(NO_KILL_GROUP)
    {
        // Setup ADSR with drum defaults
        adsr_template_.setParameters(DEFAULT_ATTACK, DEFAULT_DECAY, DEFAULT_SUSTAIN, DEFAULT_RELEASE);

        // Setup default velocity layers (3 layers)
        velocity_layers_.emplace_back(0, VELOCITY_LAYER_1_MAX);        // Soft
        velocity_layers_.emplace_back(VELOCITY_LAYER_1_MAX + 1, VELOCITY_LAYER_2_MAX);  // Medium
        velocity_layers_.emplace_back(VELOCITY_LAYER_2_MAX + 1, VELOCITY_LAYER_3_MAX);  // Hard
    }

    // ========================================================================
    // SAMPLE MANAGEMENT
    // ========================================================================

    /// Load a sample into a velocity layer
    /// @param layer_index Velocity layer (0 = soft, 1 = med, 2 = hard)
    /// @param audio_buffer Sample data (ownership transferred)
    void loadSample(int layer_index, std::unique_ptr<juce::AudioBuffer<float>> audio_buffer) {
        if (layer_index >= 0 && layer_index < velocity_layers_.size()) {
            velocity_layers_[layer_index].addSample(std::move(audio_buffer));
        }
    }

    /// Load a sample from file
    /// @param layer_index Velocity layer
    /// @param file_path Path to WAV/AIFF file
    /// @return true if loaded successfully
    bool loadSampleFromFile(int layer_index, const juce::File& file_path) {
        juce::AudioFormatManager format_manager;
        format_manager.registerBasicFormats();  // WAV, AIFF, etc.

        std::unique_ptr<juce::AudioFormatReader> reader(format_manager.createReaderFor(file_path));
        if (reader == nullptr) {
            return false;
        }

        // Create buffer and read sample
        auto buffer = std::make_unique<juce::AudioBuffer<float>>(
            static_cast<int>(reader->numChannels),
            static_cast<int>(reader->lengthInSamples)
        );

        reader->read(buffer.get(), 0, static_cast<int>(reader->lengthInSamples), 0, true, true);

        // Store sample info
        sample_paths_[layer_index] = file_path.getFullPathName().toStdString();
        sample_rate_ = reader->sampleRate;

        loadSample(layer_index, std::move(buffer));
        return true;
    }

    /// Clear all samples
    void clearSamples() {
        for (auto& layer : velocity_layers_) {
            layer.samples.clear();
            layer.round_robin_index = 0;
        }
        sample_paths_.clear();
    }

    /// Get sample for a given velocity
    const juce::AudioBuffer<float>* getSampleForVelocity(int velocity) {
        for (auto& layer : velocity_layers_) {
            if (velocity >= layer.velocity_min && velocity <= layer.velocity_max) {
                return layer.getNextSample();
            }
        }
        return nullptr;
    }

    // ========================================================================
    // PARAMETERS
    // ========================================================================

    // Name
    void setName(const std::string& name) { name_ = name; }
    const std::string& getName() const { return name_; }

    // Volume
    void setVolume(float volume) { volume_ = std::clamp(volume, MIN_VOLUME, MAX_VOLUME); }
    float getVolume() const { return volume_; }

    // Pan (0.0 = left, 0.5 = center, 1.0 = right)
    void setPan(float pan) { pan_ = std::clamp(pan, MIN_PAN, MAX_PAN); }
    float getPan() const { return pan_; }

    // Tune (semitones)
    void setTune(float tune) { tune_ = std::clamp(tune, MIN_TUNE, MAX_TUNE); }
    float getTune() const { return tune_; }

    // Fine Tune (cents)
    void setFineTune(float fine_tune) { fine_tune_ = std::clamp(fine_tune, MIN_FINE_TUNE, MAX_FINE_TUNE); }
    float getFineTune() const { return fine_tune_; }

    // Combined pitch in semitones
    float getTotalPitch() const { return tune_ + (fine_tune_ / 100.0f); }

    // Mute/Solo
    void setMuted(bool muted) { muted_ = muted; }
    bool isMuted() const { return muted_; }

    void setSoloed(bool soloed) { soloed_ = soloed; }
    bool isSoloed() const { return soloed_; }

    // Output Bus (0 = main, 1-16 = separate outputs)
    void setOutputBus(int bus) { output_bus_ = std::clamp(bus, 0, NUM_PADS); }
    int getOutputBus() const { return output_bus_; }

    // Kill Group (-1 = none, 0+ = group index)
    void setKillGroup(int group) { kill_group_ = group; }
    int getKillGroup() const { return kill_group_; }

    // ADSR
    void setADSR(float attack, float decay, float sustain, float release) {
        adsr_template_.setParameters(attack, decay, sustain, release);
    }

    const ADSR& getADSRTemplate() const { return adsr_template_; }

    // ========================================================================
    // QUERY
    // ========================================================================

    int getIndex() const { return index_; }
    int getMidiNote() const { return midi_note_; }
    bool hasSamples() const {
        for (const auto& layer : velocity_layers_) {
            if (layer.hasSamples()) return true;
        }
        return false;
    }

    double getSampleRate() const { return sample_rate_; }

    // ========================================================================
    // SERIALIZATION (for presets)
    // ========================================================================

    juce::var toJSON() const {
        auto obj = new juce::DynamicObject();
        obj->setProperty("index", index_);
        obj->setProperty("name", name_);
        obj->setProperty("midi_note", midi_note_);
        obj->setProperty("volume", volume_);
        obj->setProperty("pan", pan_);
        obj->setProperty("tune", tune_);
        obj->setProperty("fine_tune", fine_tune_);
        obj->setProperty("muted", muted_);
        obj->setProperty("soloed", soloed_);
        obj->setProperty("output_bus", output_bus_);
        obj->setProperty("kill_group", kill_group_);

        // Sample paths (for reloading)
        juce::Array<juce::var> paths;
        for (const auto& [layer_idx, path] : sample_paths_) {
            auto path_obj = new juce::DynamicObject();
            path_obj->setProperty("layer", layer_idx);
            path_obj->setProperty("path", path);
            paths.add(juce::var(path_obj));
        }
        obj->setProperty("sample_paths", paths);

        return juce::var(obj);
    }

    void fromJSON(const juce::var& json) {
        auto* obj = json.getDynamicObject();
        if (obj == nullptr) return;

        name_ = obj->getProperty("name").toString().toStdString();
        volume_ = obj->getProperty("volume");
        pan_ = obj->getProperty("pan");
        tune_ = obj->getProperty("tune");
        fine_tune_ = obj->getProperty("fine_tune");
        muted_ = obj->getProperty("muted");
        soloed_ = obj->getProperty("soloed");
        output_bus_ = obj->getProperty("output_bus");
        kill_group_ = obj->getProperty("kill_group");

        // Reload samples from paths
        auto paths = obj->getProperty("sample_paths");
        if (paths.isArray()) {
            for (int i = 0; i < paths.size(); ++i) {
                auto* path_obj = paths[i].getDynamicObject();
                if (path_obj) {
                    int layer = path_obj->getProperty("layer");
                    juce::String path = path_obj->getProperty("path");
                    loadSampleFromFile(layer, juce::File(path));
                }
            }
        }
    }

private:
    // Identity
    int index_;
    int midi_note_;
    std::string name_;

    // Parameters
    float volume_;
    float pan_;
    float tune_;
    float fine_tune_;
    bool muted_;
    bool soloed_;
    int output_bus_;
    int kill_group_;

    // Samples
    std::vector<SampleLayer> velocity_layers_;
    std::map<int, std::string> sample_paths_;  // layer_index -> file path
    double sample_rate_ = DEFAULT_SAMPLE_RATE;

    // ADSR template (copied to each voice)
    ADSR adsr_template_;
};

} // namespace ArkDrums
