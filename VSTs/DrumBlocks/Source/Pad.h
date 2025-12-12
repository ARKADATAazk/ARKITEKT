// =============================================================================
// DrumBlocks/Source/Pad.h
// Single pad with velocity layers, round-robin, ADSR, filter
// =============================================================================

#pragma once

#include <juce_audio_basics/juce_audio_basics.h>
#include <juce_audio_formats/juce_audio_formats.h>
#include <juce_dsp/juce_dsp.h>
#include "Parameters.h"
#include <atomic>

namespace DrumBlocks
{

// =============================================================================
// ROUND-ROBIN SAMPLE (consolidated for cache locality)
// =============================================================================

struct RoundRobinSample
{
    juce::AudioBuffer<float> buffer;
    double sampleRate = DEFAULT_SAMPLE_RATE;
    juce::String path;
    float normGain = 1.0f;
};

// =============================================================================
// VELOCITY LAYER
// =============================================================================

// Peak resolution constants for waveform visualization
constexpr int PEAKS_MINI_RESOLUTION = 64;   // For pad thumbnails
constexpr int PEAKS_FULL_RESOLUTION = 512;  // For full waveform editor

struct VelocityLayer
{
    VelocityLayer() { roundRobinSamples.reserve(MAX_ROUND_ROBIN_SAMPLES); }

    // Primary sample
    juce::AudioBuffer<float> buffer;
    int numSamples = 0;
    double sourceSampleRate = DEFAULT_SAMPLE_RATE;
    juce::String filePath;
    float normGain = 1.0f;  // Peak normalization gain (computed on load)

    // Waveform peaks for visualization (computed on load)
    // Format: [max1..maxN, min1..minN] - same as Lua waveform_cache
    std::vector<float> peaksMini;  // 128 floats (64 max + 64 min)
    std::vector<float> peaksFull;  // 1024 floats (512 max + 512 min)

    // Round-robin samples (pre-reserved to avoid audio-thread allocation)
    std::vector<RoundRobinSample> roundRobinSamples;
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

    // Get all round-robin paths for state persistence (allocates - use for non-audio-thread only)
    std::vector<juce::String> getRoundRobinPaths() const;

    // Get single round-robin path by index (allocation-free - safe for audio thread)
    // Returns empty string if index is out of range
    const juce::String& getRoundRobinPath(int index) const;

    // Waveform peak computation (call after loading sample)
    void computePeaks();

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
    void stop();          // Immediate stop (with click-free fade)
    void stopImmediate(); // Hard stop without fade (for internal use)

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
    std::vector<juce::String> getRoundRobinPaths(int layerIndex) const;  // Allocates - non-audio-thread only
    const juce::String& getRoundRobinPath(int layerIndex, int rrIndex) const;  // Allocation-free
    bool hasSample(int layerIndex) const;
    int getRoundRobinCount(int layerIndex) const;
    double getSampleDuration(int layerIndex) const;  // Duration in seconds
    float getPlaybackProgress() const;  // Returns 0-1 normalized progress within start/end region

    // Waveform peaks for visualization (computed on sample load)
    const std::vector<float>& getPeaksMini(int layerIndex) const;
    const std::vector<float>& getPeaksFull(int layerIndex) const;

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
    int filterType = 0;          // 0=LP, 1=HP, 2=BP
    int killGroup = 0;           // 0 = none, 1-16 = group
    int outputGroup = 0;         // 0 = main, 1-16 = group bus
    LoopMode loopMode = LoopMode::OneShot;  // OneShot, Loop, or PingPong
    NoteOffMode noteOffMode = NoteOffMode::Ignore;  // Note-off behavior
    bool reverse = false;
    bool normalize = false;      // Apply peak normalization
    float sampleStart = 0.0f;    // 0-1 normalized
    float sampleEnd = 1.0f;      // 0-1 normalized
    int roundRobinMode = 0;      // 0=sequential, 1=random

    // Pitch envelope parameters (for 808-style pitch drops)
    float pitchEnvAmount = 0.0f;    // semitones (-24 to +24), 0 = off
    float pitchEnvAttack = 0.0f;    // ms (0-100)
    float pitchEnvDecay = 50.0f;    // ms (0-2000)
    float pitchEnvSustain = 0.0f;   // 0-1 (sustain level, 0 = full sweep)

    // Velocity layer crossfade
    float velCrossfade = 0.0f;      // 0-1 (0 = hard switch, 1 = full blend zone)

    // Velocity curve (response shaping)
    float velCurve = 0.5f;          // 0=soft/log, 0.5=linear, 1=hard/exp

    // Interpolation quality (0=Normal/8-tap, 1=High/16-tap, 2=Ultra/32-tap)
    InterpolationQuality interpolationQuality = InterpolationQuality::High;

    // Saturation parameters
    float satDrive = 0.0f;          // 0-1 (0 = off, maps to 1x-20x internal gain)
    int satType = 0;                // 0=Soft, 1=Hard, 2=Tube, 3=Tape, 4=Fold, 5=Crush
    float satMix = 1.0f;            // 0-1 dry/wet blend

    // Transient shaper parameters
    float transAttack = 0.0f;       // -1 to +1 (boost/cut attack)
    float transSustain = 0.0f;      // -1 to +1 (boost/cut sustain)

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
    void updatePitchEnvelopeParams();

    // -------------------------------------------------------------------------
    // PRIVATE STATE
    // -------------------------------------------------------------------------

    std::array<VelocityLayer, NUM_VELOCITY_LAYERS> layers;
    juce::ADSR envelope;
    juce::ADSR pitchEnvelope;  // Separate envelope for pitch modulation
    juce::dsp::StateVariableTPTFilter<float> filter;

    double currentSampleRate = DEFAULT_SAMPLE_RATE;
    double playPosition = 0.0;
    float currentVelocity = 1.0f;
    int playStartSample = 0;
    int playEndSample = 0;

    // Ping-pong state
    bool pingPongForward = true;  // Direction for ping-pong mode

    // Velocity layer crossfade state (for blending two adjacent layers)
    int secondaryLayer = -1;        // Secondary layer index (-1 = no blending)
    float layerBlendFactor = 0.0f;  // 0 = 100% primary, 1 = 100% secondary
    double secondaryPlayPosition = 0.0;
    bool secondaryPingPongForward = true;

    // Cached filter state to avoid redundant updates
    float lastFilterCutoff = -1.0f;
    float lastFilterReso = -1.0f;
    int lastFilterType = -1;

    // Per-pad random generator (thread-safe: only used on audio thread)
    juce::Random rng;

    // Temp buffer for per-pad filtering (avoids filtering other pads' audio)
    juce::AudioBuffer<float> tempBuffer;

    // -------------------------------------------------------------------------
    // DSP QUALITY IMPROVEMENTS
    // -------------------------------------------------------------------------

    // Click-free stop: fade-out ramp (samples remaining, 0 = not fading)
    int fadeOutSamplesRemaining = 0;
    static constexpr int FADE_OUT_SAMPLES = 128;  // ~3ms at 44.1kHz

    // Parameter smoothing (one-pole filters for zipper-free automation)
    float smoothedVolume = 0.8f;
    float smoothedPanL = 0.707f;
    float smoothedPanR = 0.707f;
    float smoothedFilterCutoff = 20000.0f;
    float smoothedFilterReso = 0.0f;
    float paramSmoothCoeff = 0.995f;  // Computed from sample rate in prepare()

    // Anti-aliasing filter for pitch-up (biquad LP, 12dB/octave)
    // State: [0-1] = L channel z^-1 and z^-2, [2-3] = R channel
    float antiAliasState[4] = {0.0f, 0.0f, 0.0f, 0.0f};

    // Smoothed biquad coefficients (prevents artifacts from rapid coefficient changes)
    float smoothedAAb0 = 0.0f;
    float smoothedAAb1 = 0.0f;
    float smoothedAAa1 = 0.0f;
    float smoothedAAa2 = 0.0f;
    bool aaCoeffsInitialized = false;  // First sample needs instant coefficient set
    float aaCoeffSmoothAlpha = 0.1f;   // Computed from sample rate in prepare()

    // Kahan summation error compensation for drift-free position accumulation
    double playPositionError = 0.0;
    double secondaryPositionError = 0.0;

    // Transient shaper envelope followers (for attack/sustain detection)
    // Fast envelope tracks transients, slow envelope tracks sustain
    // Difference = transient signal, sum = sustain signal
    float transEnvFast = 0.0f;          // Fast envelope follower state
    float transEnvSlow = 0.0f;          // Slow envelope follower state
    float transAttackCoeff = 0.0f;      // Fast attack coefficient (computed in prepare)
    float transReleaseCoeffFast = 0.0f; // Fast release coefficient
    float transReleaseCoeffSlow = 0.0f; // Slow release coefficient

    // DC blocker state (one-pole highpass at ~10Hz to remove DC offset from saturation)
    // Applied after saturation to prevent DC buildup from asymmetric waveshaping
    float dcBlockerStateL = 0.0f;
    float dcBlockerStateR = 0.0f;
    float dcBlockerCoeff = 0.9995f;     // Computed from sample rate in prepare()
};

}  // namespace DrumBlocks
