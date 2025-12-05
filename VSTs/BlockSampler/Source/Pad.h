// =============================================================================
// BlockSampler/Source/Pad.h
// Single pad with velocity layers, round-robin, ADSR, filter
// =============================================================================

#pragma once

#include <juce_audio_basics/juce_audio_basics.h>
#include <juce_audio_formats/juce_audio_formats.h>
#include <juce_dsp/juce_dsp.h>
#include "Parameters.h"

namespace BlockSampler
{

// =============================================================================
// VELOCITY LAYER
// =============================================================================

struct VelocityLayer
{
    // Primary sample
    juce::AudioBuffer<float> buffer;
    int numSamples = 0;
    double sourceSampleRate = 44100.0;
    juce::String filePath;

    // Round-robin: multiple samples that cycle on each trigger
    std::vector<juce::AudioBuffer<float>> roundRobinBuffers;
    std::vector<double> roundRobinSampleRates;
    std::vector<juce::String> roundRobinPaths;
    int roundRobinIndex = 0;

    // Queries
    bool isLoaded() const;
    int getRoundRobinCount() const;

    // Round-robin access
    const juce::AudioBuffer<float>& getCurrentBuffer() const;
    int getCurrentNumSamples() const;
    double getCurrentSampleRate() const;
    void advanceRoundRobin();

    // Management
    void clear();
};

// =============================================================================
// PAD CLASS
// =============================================================================

class Pad
{
public:
    Pad() = default;

    // -------------------------------------------------------------------------
    // LIFECYCLE
    // -------------------------------------------------------------------------

    void prepare(double sampleRate, int samplesPerBlock);
    void trigger(int velocity);
    void noteOff();
    void stop();

    // -------------------------------------------------------------------------
    // AUDIO PROCESSING
    // -------------------------------------------------------------------------

    void renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                         int startSample,
                         int numSamples);

    // -------------------------------------------------------------------------
    // SAMPLE MANAGEMENT
    // -------------------------------------------------------------------------

    bool loadSample(int layerIndex,
                    const juce::File& file,
                    juce::AudioFormatManager& formatManager);

    bool addRoundRobinSample(int layerIndex,
                             const juce::File& file,
                             juce::AudioFormatManager& formatManager);

    void clearSample(int layerIndex);
    void clearRoundRobin(int layerIndex);

    // -------------------------------------------------------------------------
    // QUERIES
    // -------------------------------------------------------------------------

    juce::String getSamplePath(int layerIndex) const;
    bool hasSample(int layerIndex) const;
    int getRoundRobinCount(int layerIndex) const;

    // -------------------------------------------------------------------------
    // PUBLIC PARAMETERS (set from PluginProcessor)
    // -------------------------------------------------------------------------

    float volume = 0.8f;
    float pan = 0.0f;
    float tune = 0.0f;           // semitones (-24 to +24)
    float attack = 0.0f;         // ms
    float decay = 100.0f;        // ms
    float sustain = 1.0f;        // 0-1
    float release = 200.0f;      // ms
    float filterCutoff = 20000.0f;  // Hz
    float filterReso = 0.0f;     // 0-1
    int killGroup = 0;           // 0 = none, 1-8 = group
    int outputGroup = 0;         // 0 = main, 1-16 = group bus
    bool oneShot = true;
    bool reverse = false;
    float sampleStart = 0.0f;    // 0-1 normalized
    float sampleEnd = 1.0f;      // 0-1 normalized

    // -------------------------------------------------------------------------
    // PUBLIC STATE (read by PluginProcessor)
    // -------------------------------------------------------------------------

    bool isPlaying = false;
    int currentLayer = -1;

private:
    // -------------------------------------------------------------------------
    // PRIVATE HELPERS
    // -------------------------------------------------------------------------

    int selectVelocityLayer(int velocity);
    void updateEnvelopeParams();

    // -------------------------------------------------------------------------
    // PRIVATE STATE
    // -------------------------------------------------------------------------

    std::array<VelocityLayer, NUM_VELOCITY_LAYERS> layers;
    juce::ADSR envelope;
    juce::dsp::StateVariableTPTFilter<float> filter;

    double currentSampleRate = 44100.0;
    double playPosition = 0.0;
    float currentVelocity = 1.0f;
    int playStartSample = 0;
    int playEndSample = 0;

    // Temp buffer for per-pad filtering (avoids filtering other pads' audio)
    juce::AudioBuffer<float> tempBuffer;
};

}  // namespace BlockSampler
