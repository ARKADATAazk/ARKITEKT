// =============================================================================
// BlockSampler/Source/Pad.h
// Single pad with velocity layers, round-robin, ADSR, filter
// =============================================================================

#pragma once

#include <juce_audio_basics/juce_audio_basics.h>
#include <juce_audio_formats/juce_audio_formats.h>
#include <juce_dsp/juce_dsp.h>
#include "Parameters.h"
#include <atomic>

namespace BlockSampler
{

// =============================================================================
// ROUND-ROBIN SAMPLE (consolidated for cache locality)
// =============================================================================

struct RoundRobinSample
{
    juce::AudioBuffer<float> buffer;
    double sampleRate = 44100.0;
    juce::String path;
    float normGain = 1.0f;
    bool isLoaded = false;  // Slot occupancy flag for fixed array
};

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
    float normGain = 1.0f;  // Peak normalization gain (computed on load)

    // Round-robin samples (fixed array - no allocations on audio thread)
    std::array<RoundRobinSample, MAX_ROUND_ROBIN_SAMPLES> roundRobinSamples;
    int roundRobinCount = 0;  // Number of loaded round-robin samples
    int roundRobinIndex = 0;

    // Queries
    bool isLoaded() const;
    int getRoundRobinCount() const;

    // Round-robin access
    const juce::AudioBuffer<float>& getCurrentBuffer() const;
    int getCurrentNumSamples() const;
    double getCurrentSampleRate() const;
    float getCurrentNormGain() const;
    void advanceRoundRobin(juce::Random& rng, bool randomMode);

    // Get all round-robin paths for state persistence (fixed array, no allocation)
    // Returns number of paths written to outPaths array
    int getRoundRobinPaths(std::array<juce::String, MAX_ROUND_ROBIN_SAMPLES>& outPaths) const;

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
    void forceRelease();  // Trigger release phase even in one-shot mode
    void stop();

    // -------------------------------------------------------------------------
    // AUDIO PROCESSING
    // -------------------------------------------------------------------------

    // Renders to internal buffer, returns samples rendered (0 if not playing)
    int renderNextBlock(int numSamples);

    // Get rendered audio (valid after renderNextBlock)
    const juce::AudioBuffer<float>& getOutputBuffer() const { return tempBuffer; }

    // -------------------------------------------------------------------------
    // SAMPLE MANAGEMENT (Audio thread only)
    // -------------------------------------------------------------------------

    // Buffer assignment from pre-loaded data (called by Processor::applyCompletedLoads)
    // IMPORTANT: These methods must only be called from the audio thread.
    // They stop playback before modifying to prevent races within the audio thread.
    void setSampleBuffer(int layerIndex,
                         juce::AudioBuffer<float>&& buffer,
                         double sampleRate,
                         const juce::String& path,
                         float inNormGain);

    void addRoundRobinBuffer(int layerIndex,
                             juce::AudioBuffer<float>&& buffer,
                             double sampleRate,
                             const juce::String& path,
                             float inNormGain);

    void clearSample(int layerIndex);
    void clearRoundRobin(int layerIndex);

    // -------------------------------------------------------------------------
    // QUERIES
    // -------------------------------------------------------------------------

    juce::String getSamplePath(int layerIndex) const;
    // Returns number of paths written to outPaths array (0 if invalid layer)
    int getRoundRobinPaths(int layerIndex, std::array<juce::String, MAX_ROUND_ROBIN_SAMPLES>& outPaths) const;
    bool hasSample(int layerIndex) const;
    int getRoundRobinCount(int layerIndex) const;
    double getSampleDuration(int layerIndex) const;  // Duration in seconds

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
    int filterType = 0;          // 0=LP, 1=HP
    int killGroup = 0;           // 0 = none, 1-8 = group
    int outputGroup = 0;         // 0 = main, 1-16 = group bus
    bool oneShot = true;
    bool reverse = false;
    bool normalize = false;      // Apply peak normalization
    float sampleStart = 0.0f;    // 0-1 normalized
    float sampleEnd = 1.0f;      // 0-1 normalized
    int roundRobinMode = 0;      // 0=sequential, 1=random

    // -------------------------------------------------------------------------
    // PUBLIC STATE (read by PluginProcessor)
    // -------------------------------------------------------------------------

    std::atomic<bool> isPlaying{false};
    std::atomic<int> currentLayer{-1};

private:
    // -------------------------------------------------------------------------
    // PRIVATE HELPERS
    // -------------------------------------------------------------------------

    int selectVelocityLayer(int velocity);
    void updateEnvelopeParams();
    void updateCachedParams();  // Update cached pitch/pan when params change

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

    // Cached filter state to avoid redundant updates
    float lastFilterCutoff = -1.0f;
    float lastFilterReso = -1.0f;
    int lastFilterType = -1;

    // Cached pitch/pan state to avoid redundant calculations (pow, sin, cos are expensive)
    float lastTune = 0.0f;
    float lastPan = 0.0f;
    double cachedPitchRatio = 1.0;       // 2^(tune/12)
    float cachedPanGainL = 0.707f;       // cos(panAngle)
    float cachedPanGainR = 0.707f;       // sin(panAngle)
    double cachedSourceSampleRate = 0.0; // For pitch ratio recalc on sample change

    // Per-pad random generator (thread-safe: only used on audio thread)
    juce::Random rng;

    // Temp buffer for per-pad filtering (avoids filtering other pads' audio)
    juce::AudioBuffer<float> tempBuffer;
};

}  // namespace BlockSampler
