// =============================================================================
// DrumBlocks/Source/Pad.cpp
// Pad implementation - audio playback, sample loading, ADSR, filtering
// =============================================================================

#include "Pad.h"
#include "SincInterpolator.h"
#include <limits>
#include <cstring>  // For memcpy (type-punning)
#include <cmath>    // For std::fmod, std::abs

namespace DrumBlocks
{

// File-scope empty string for safe reference returns (avoids function-local static)
static const juce::String kEmptyString;

// =============================================================================
// VELOCITY LAYER IMPLEMENTATION
// =============================================================================

bool VelocityLayer::isLoaded() const
{
    return numSamples > 0 || !roundRobinSamples.empty();
}

int VelocityLayer::getRoundRobinCount() const
{
    return static_cast<int>(roundRobinSamples.size());
}

const juce::AudioBuffer<float>& VelocityLayer::getCurrentBuffer() const
{
    if (roundRobinSamples.empty())
        return buffer;
    // Note: roundRobinIndex is kept in range by advanceRoundRobin(), no modulo needed
    return roundRobinSamples[roundRobinIndex].buffer;
}

int VelocityLayer::getCurrentNumSamples() const
{
    if (roundRobinSamples.empty())
        return numSamples;
    return getCurrentBuffer().getNumSamples();
}

double VelocityLayer::getCurrentSampleRate() const
{
    if (roundRobinSamples.empty())
        return sourceSampleRate;
    // Note: roundRobinIndex is kept in range by advanceRoundRobin(), no modulo needed
    return roundRobinSamples[roundRobinIndex].sampleRate;
}

float VelocityLayer::getCurrentNormGain() const
{
    if (roundRobinSamples.empty())
        return normGain;
    // Note: roundRobinIndex is kept in range by advanceRoundRobin(), no modulo needed
    return roundRobinSamples[roundRobinIndex].normGain;
}

void VelocityLayer::advanceRoundRobin(juce::Random& rng, bool randomMode)
{
    const int count = static_cast<int>(roundRobinSamples.size());
    if (count == 0)
        return;

    if (randomMode && count > 1)
    {
        // Random selection (avoid repeating same sample)
        // Max iterations guard prevents infinite loop if RNG misbehaves
        int newIndex = roundRobinIndex;
        for (int attempts = 0; attempts < RANDOM_RR_MAX_RETRIES && newIndex == roundRobinIndex; ++attempts)
        {
            newIndex = rng.nextInt(count);
        }
        roundRobinIndex = newIndex;
    }
    else
    {
        // Sequential cycling
        roundRobinIndex = (roundRobinIndex + 1) % count;
    }
}

std::vector<juce::String> VelocityLayer::getRoundRobinPaths() const
{
    std::vector<juce::String> paths;
    paths.reserve(roundRobinSamples.size());
    for (const auto& sample : roundRobinSamples)
        paths.push_back(sample.path);
    return paths;
}

const juce::String& VelocityLayer::getRoundRobinPath(int index) const
{
    // Allocation-free path access by index
    if (index >= 0 && index < static_cast<int>(roundRobinSamples.size()))
        return roundRobinSamples[index].path;
    return kEmptyString;
}

void VelocityLayer::clear()
{
    buffer.setSize(0, 0);
    numSamples = 0;
    sourceSampleRate = DEFAULT_SAMPLE_RATE;
    filePath.clear();
    normGain = 1.0f;
    roundRobinSamples.clear();
    roundRobinIndex = 0;
    peaksMini.clear();
    peaksFull.clear();
}

void VelocityLayer::computePeaks()
{
    // Compute peaks from current buffer at both resolutions in a SINGLE PASS
    // Format: [max1..maxN, min1..minN] - matches Lua waveform_cache format
    //
    // Optimization: Instead of iterating all samples twice (once per resolution),
    // we iterate once at the higher resolution (512) and downsample to mini (64).
    // This gives ~2x speedup for typical samples.

    if (numSamples == 0 || buffer.getNumChannels() == 0)
    {
        peaksMini.clear();
        peaksFull.clear();
        return;
    }

    const int channels = buffer.getNumChannels();
    const bool isMono = (channels == 1);

    // Get read pointers (cache for inner loop)
    const float* srcL = buffer.getReadPointer(0);
    const float* srcR = isMono ? srcL : buffer.getReadPointer(1);

    // Calculate actual resolutions (can't have more peaks than samples)
    const int fullRes = std::min(PEAKS_FULL_RESOLUTION, numSamples);
    const int miniRes = std::min(PEAKS_MINI_RESOLUTION, numSamples);

    if (fullRes < 1 || miniRes < 1)
    {
        peaksMini.clear();
        peaksFull.clear();
        return;
    }

    // Allocate output arrays
    peaksFull.resize(fullRes * 2);
    peaksMini.resize(miniRes * 2);

    const int samplesPerFullPeak = numSamples / fullRes;
    const int fullPeaksPerMiniPeak = fullRes / miniRes;  // 512/64 = 8

    float maxAbsPeakFull = 0.0f;
    float maxAbsPeakMini = 0.0f;

    // Single pass: compute full-resolution peaks
    // Every 8 full peaks, also update the corresponding mini peak
    int currentMiniPeak = 0;
    float miniMaxVal = 0.0f;
    float miniMinVal = 0.0f;

    for (int i = 0; i < fullRes; ++i)
    {
        const int startSample = i * samplesPerFullPeak;
        const int endSample = std::min(startSample + samplesPerFullPeak, numSamples);

        float maxVal = 0.0f;
        float minVal = 0.0f;

        // Inner loop: find min/max in this peak's sample range
        // Optimized: avoid division for mono, use direct pointers
        if (isMono)
        {
            for (int s = startSample; s < endSample; ++s)
            {
                const float sample = srcL[s];
                if (sample > maxVal) maxVal = sample;
                if (sample < minVal) minVal = sample;
            }
        }
        else
        {
            // Stereo: average channels (most common case)
            for (int s = startSample; s < endSample; ++s)
            {
                const float monoSample = (srcL[s] + srcR[s]) * 0.5f;  // Multiply faster than divide
                if (monoSample > maxVal) maxVal = monoSample;
                if (monoSample < minVal) minVal = monoSample;
            }
        }

        // Store full-resolution peak
        peaksFull[i] = maxVal;
        peaksFull[fullRes + i] = minVal;

        // Track for normalization
        maxAbsPeakFull = std::max(maxAbsPeakFull, std::abs(maxVal));
        maxAbsPeakFull = std::max(maxAbsPeakFull, std::abs(minVal));

        // Accumulate for mini peak (take max of 8 full peaks)
        if (maxVal > miniMaxVal) miniMaxVal = maxVal;
        if (minVal < miniMinVal) miniMinVal = minVal;

        // Every 8 full peaks, store a mini peak
        if ((i + 1) % fullPeaksPerMiniPeak == 0 && currentMiniPeak < miniRes)
        {
            peaksMini[currentMiniPeak] = miniMaxVal;
            peaksMini[miniRes + currentMiniPeak] = miniMinVal;

            maxAbsPeakMini = std::max(maxAbsPeakMini, std::abs(miniMaxVal));
            maxAbsPeakMini = std::max(maxAbsPeakMini, std::abs(miniMinVal));

            // Reset for next mini peak group
            miniMaxVal = 0.0f;
            miniMinVal = 0.0f;
            ++currentMiniPeak;
        }
    }

    // Handle any remaining mini peaks (if fullRes not evenly divisible)
    while (currentMiniPeak < miniRes)
    {
        peaksMini[currentMiniPeak] = miniMaxVal;
        peaksMini[miniRes + currentMiniPeak] = miniMinVal;
        miniMaxVal = 0.0f;
        miniMinVal = 0.0f;
        ++currentMiniPeak;
    }

    // Normalize full peaks (makes quiet waveforms visible)
    if (maxAbsPeakFull > 0.0f && maxAbsPeakFull < 1.0f)
    {
        const float scale = 1.0f / maxAbsPeakFull;
        for (auto& p : peaksFull)
            p *= scale;
    }

    // Normalize mini peaks (separate normalization for correct visual scaling)
    if (maxAbsPeakMini > 0.0f && maxAbsPeakMini < 1.0f)
    {
        const float scale = 1.0f / maxAbsPeakMini;
        for (auto& p : peaksMini)
            p *= scale;
    }
}

// =============================================================================
// PAD LIFECYCLE
// =============================================================================

void Pad::prepare(double sampleRate, int samplesPerBlock)
{
    currentSampleRate = sampleRate;

    envelope.setSampleRate(sampleRate);
    updateEnvelopeParams();

    // Initialize pitch envelope
    pitchEnvelope.setSampleRate(sampleRate);
    updatePitchEnvelopeParams();

    // Allocate temp buffer for per-pad filtering
    tempBuffer.setSize(2, samplesPerBlock);

    // Compute sample-rate-independent smoothing coefficient
    // Target: ~10ms time constant regardless of sample rate
    // Formula: coeff = exp(-1 / (sampleRate * timeConstant))
    constexpr double SMOOTH_TIME_CONSTANT = 0.010;  // 10ms
    paramSmoothCoeff = static_cast<float>(std::exp(-1.0 / (sampleRate * SMOOTH_TIME_CONSTANT)));

    // AA biquad coefficient smoothing (~2ms time constant for responsive tracking)
    constexpr double AA_SMOOTH_TIME_CONSTANT = 0.002;  // 2ms
    aaCoeffSmoothAlpha = static_cast<float>(1.0 - std::exp(-1.0 / (sampleRate * AA_SMOOTH_TIME_CONSTANT)));

    // Force sinc table initialization (avoid first-note glitch)
    (void)getSincTableNormal();
    (void)getSincTableHigh();
    (void)getSincTableUltra();

    // Prepare filter
    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = static_cast<juce::uint32>(samplesPerBlock);
    spec.numChannels = 2;
    filter.prepare(spec);
    filter.setType(juce::dsp::StateVariableTPTFilterType::lowpass);

    // Transient shaper envelope follower coefficients
    // Fast envelope: ~1ms attack, ~10ms release (catches transients)
    // Slow envelope: ~1ms attack, ~100ms release (tracks sustain)
    constexpr double TRANS_ATTACK_MS = 1.0;
    constexpr double TRANS_RELEASE_FAST_MS = 10.0;
    constexpr double TRANS_RELEASE_SLOW_MS = 100.0;
    transAttackCoeff = static_cast<float>(std::exp(-1.0 / (sampleRate * TRANS_ATTACK_MS * 0.001)));
    transReleaseCoeffFast = static_cast<float>(std::exp(-1.0 / (sampleRate * TRANS_RELEASE_FAST_MS * 0.001)));
    transReleaseCoeffSlow = static_cast<float>(std::exp(-1.0 / (sampleRate * TRANS_RELEASE_SLOW_MS * 0.001)));

    // DC blocker coefficient (~10Hz cutoff one-pole highpass)
    // coeff = exp(-2*pi*fc/fs) where fc=10Hz
    constexpr double DC_BLOCKER_CUTOFF_HZ = 10.0;
    dcBlockerCoeff = static_cast<float>(std::exp(-2.0 * juce::MathConstants<double>::pi * DC_BLOCKER_CUTOFF_HZ / sampleRate));
}

void Pad::trigger(int velocity)
{
    // Validate velocity range (MIDI is 0-127, but be defensive)
    if (velocity <= 0)
    {
        noteOff();
        return;
    }
    velocity = juce::jmin(velocity, MIDI_VELOCITY_MAX);  // Clamp to valid MIDI range

    // Select velocity layer and calculate crossfade
    currentLayer = selectVelocityLayer(velocity);
    secondaryLayer = -1;
    layerBlendFactor = 0.0f;

    if (currentLayer < 0 || !layers[currentLayer].isLoaded())
    {
        // Fallback to any loaded layer
        currentLayer = -1;
        for (int i = 0; i < NUM_VELOCITY_LAYERS; ++i)
        {
            if (layers[i].isLoaded())
            {
                currentLayer = i;
                break;
            }
        }
    }

    if (currentLayer < 0)
        return;  // No samples loaded

    // Calculate velocity crossfade between adjacent layers
    // Only blend if velCrossfade > 0 and we're near a layer boundary
    if (velCrossfade > VEL_CROSSFADE_MIN_THRESHOLD)
    {
        // Layer thresholds: 0-31 (L0), 32-63 (L1), 64-95 (L2), 96-127 (L3)
        constexpr int thresholds[] = { 0, VELOCITY_LAYER_1_MIN, VELOCITY_LAYER_2_MIN, VELOCITY_LAYER_3_MIN, MIDI_VELOCITY_MAX + 1 };

        const int layerMin = thresholds[currentLayer];
        const int layerMax = thresholds[currentLayer + 1];
        const int layerRange = layerMax - layerMin;

        // Calculate blend zone width (as velocity units)
        const float blendWidth = layerRange * velCrossfade;

        // Check if we're in the upper blend zone (transitioning to higher layer)
        // Guard against division by zero when blendWidth is too small
        if (currentLayer < NUM_VELOCITY_LAYERS - 1 && blendWidth > BLEND_WIDTH_MIN_THRESHOLD)
        {
            const int upperThreshold = layerMax;
            const int blendZoneStart = static_cast<int>(upperThreshold - blendWidth);

            if (velocity >= blendZoneStart && layers[currentLayer + 1].isLoaded())
            {
                secondaryLayer = currentLayer + 1;
                // Calculate blend factor: 0 at blendZoneStart, 1 at upperThreshold
                layerBlendFactor = static_cast<float>(velocity - blendZoneStart) / blendWidth;
                layerBlendFactor = juce::jlimit(0.0f, 1.0f, layerBlendFactor);
            }
        }

        // Check if we're in the lower blend zone (transitioning from lower layer)
        if (secondaryLayer < 0 && currentLayer > 0)
        {
            const int lowerThreshold = layerMin;
            // Use lower layer's range for its blend zone
            const int lowerLayerRange = thresholds[currentLayer] - thresholds[currentLayer - 1];
            const float lowerBlendWidth = lowerLayerRange * velCrossfade;
            const int blendZoneEnd = static_cast<int>(lowerThreshold + lowerBlendWidth);

            // Guard against division by zero when lowerBlendWidth is too small
            if (velocity < blendZoneEnd && layers[currentLayer - 1].isLoaded() && lowerBlendWidth > BLEND_WIDTH_MIN_THRESHOLD)
            {
                secondaryLayer = currentLayer - 1;
                // Calculate blend factor: 1 at lowerThreshold, 0 at blendZoneEnd
                layerBlendFactor = 1.0f - static_cast<float>(velocity - lowerThreshold) / lowerBlendWidth;
                layerBlendFactor = juce::jlimit(0.0f, 1.0f, layerBlendFactor);
            }
        }
    }

    auto& layer = layers[currentLayer];

    // Advance round-robin before getting sample info (uses per-pad RNG for thread safety)
    layer.advanceRoundRobin(rng, roundRobinMode == 1);

    // Also advance round-robin for secondary layer if blending
    if (secondaryLayer >= 0)
        layers[secondaryLayer].advanceRoundRobin(rng, roundRobinMode == 1);

    // Get current sample length (accounting for round-robin)
    int currentNumSamples = layer.getCurrentNumSamples();
    if (currentNumSamples <= 0)
        return;  // Empty or corrupted sample

    // Calculate actual start/end sample positions
    float effectiveStart = sampleStart;
    float effectiveEnd = sampleEnd;

    // Swap if start > end (user set them backwards)
    if (effectiveStart > effectiveEnd)
        std::swap(effectiveStart, effectiveEnd);

    int startSample = static_cast<int>(effectiveStart * currentNumSamples);
    int endSample = static_cast<int>(effectiveEnd * currentNumSamples);

    // Clamp to valid range and ensure at least 1 sample of playback
    startSample = juce::jlimit(0, currentNumSamples - 1, startSample);
    endSample = juce::jlimit(startSample + 1, currentNumSamples, endSample);

    // Store for playback
    playStartSample = startSample;
    playEndSample = endSample;

    // Reset playback position
    playPosition = reverse ? (endSample - 1) : startSample;

    // Apply velocity curve (response shaping)
    // velCurve: 0=soft/log, 0.5=linear, 1=hard/exp
    // Maps to exponent: 0.5 (soft/sqrt) → 1.0 (linear) → 2.0 (hard/square)
    const float normalizedVel = static_cast<float>(velocity) / static_cast<float>(MIDI_VELOCITY_MAX);
    const float curveExp = std::pow(2.0f, 2.0f * velCurve - 1.0f);  // 0→0.5, 0.5→1.0, 1→2.0
    currentVelocity = std::pow(normalizedVel, curveExp);

    isPlaying = true;

    // Reset ping-pong direction (always start in initial direction)
    pingPongForward = !reverse;

    // Reset click-free fade state (in case we're retriggering during fade-out)
    fadeOutSamplesRemaining = 0;

    // Reset Kahan summation error for fresh playback
    playPositionError = 0.0;
    secondaryPositionError = 0.0;

    // Reset anti-alias filter state (biquad: 2 states per channel)
    antiAliasState[0] = 0.0f;
    antiAliasState[1] = 0.0f;
    antiAliasState[2] = 0.0f;
    antiAliasState[3] = 0.0f;
    aaCoeffsInitialized = false;  // Force instant coefficient set on first sample

    // Initialize smoothed parameters to current values (avoid initial ramp)
    smoothedVolume = volume;
    const float panAngle = (pan + 1.0f) * 0.25f * juce::MathConstants<float>::pi;
    smoothedPanL = std::cos(panAngle);
    smoothedPanR = std::sin(panAngle);
    smoothedFilterCutoff = filterCutoff;
    smoothedFilterReso = filterReso;

    // Reset transient shaper envelope followers
    transEnvFast = 0.0f;
    transEnvSlow = 0.0f;

    // Reset DC blocker state
    dcBlockerStateL = 0.0f;
    dcBlockerStateR = 0.0f;

    // Setup secondary layer playback position (if crossfading)
    if (secondaryLayer >= 0)
    {
        auto& secLayer = layers[secondaryLayer];
        int secNumSamples = secLayer.getCurrentNumSamples();
        if (secNumSamples > 0)
        {
            int secStart = static_cast<int>(effectiveStart * secNumSamples);
            int secEnd = static_cast<int>(effectiveEnd * secNumSamples);
            secStart = juce::jlimit(0, secNumSamples - 1, secStart);
            secEnd = juce::jlimit(secStart + 1, secNumSamples, secEnd);

            secondaryPlayPosition = reverse ? (secEnd - 1) : secStart;
            secondaryPingPongForward = !reverse;
        }
        else
        {
            secondaryLayer = -1;  // Disable blending if secondary has no samples
            layerBlendFactor = 0.0f;
        }
    }

    // Reset envelope and trigger
    updateEnvelopeParams();
    envelope.reset();
    envelope.noteOn();

    // Reset and trigger pitch envelope (for 808-style pitch drops)
    updatePitchEnvelopeParams();
    pitchEnvelope.reset();
    pitchEnvelope.noteOn();

    // Reset filter DSP state to prevent artifacts from previous note
    filter.reset();
    lastFilterCutoff = -1.0f;
    lastFilterReso = -1.0f;
    lastFilterType = -1;
}

void Pad::noteOff()
{
    // Handle note-off based on noteOffMode setting
    switch (noteOffMode)
    {
        case NoteOffMode::Ignore:
            // Do nothing - sample plays to end (standard drum behavior)
            break;

        case NoteOffMode::Release:
            // Trigger ADSR release phase
            if (isPlaying)
            {
                envelope.noteOff();
                pitchEnvelope.noteOff();
            }
            break;

        case NoteOffMode::Cut:
            // Immediately stop the sample
            stop();
            break;
    }
}

void Pad::forceRelease()
{
    // Trigger release phase regardless of loopMode
    // Allows graceful fade-out of long one-shot samples
    if (isPlaying)
    {
        envelope.noteOff();
        pitchEnvelope.noteOff();
    }
}

void Pad::stop()
{
    // Click-free stop: start fade-out ramp instead of hard stop
    // If already fading or not playing, just finish immediately
    if (!isPlaying || fadeOutSamplesRemaining > 0)
    {
        stopImmediate();
        return;
    }

    // Start fade-out (will complete in renderNextBlock)
    fadeOutSamplesRemaining = FADE_OUT_SAMPLES;
}

void Pad::stopImmediate()
{
    // Hard stop without fade (used when pad is retriggered or at fade end)
    isPlaying = false;
    fadeOutSamplesRemaining = 0;
    envelope.reset();
    pitchEnvelope.reset();

    // Reset anti-alias filter state (biquad: 2 states per channel)
    antiAliasState[0] = 0.0f;
    antiAliasState[1] = 0.0f;
    antiAliasState[2] = 0.0f;
    antiAliasState[3] = 0.0f;

    // Reset Kahan summation error
    playPositionError = 0.0;
    secondaryPositionError = 0.0;

    // Reset transient shaper envelope followers
    transEnvFast = 0.0f;
    transEnvSlow = 0.0f;

    // Reset DC blocker state
    dcBlockerStateL = 0.0f;
    dcBlockerStateR = 0.0f;
}

// =============================================================================
// AUDIO PROCESSING
// =============================================================================

// Fast approximation of tan(x) for x in [0, pi/2)
// Using rational approximation, accurate to ~0.01% in typical range
// Much faster than std::tan() for per-sample biquad coefficient computation
inline float fastTan(float x)
{
    // Clamp to valid range (avoid infinity at pi/2 ≈ 1.5708)
    // Using 1.5607 (pi/2 - 0.01) for safe margin where approximation is still accurate
    x = juce::jlimit(0.0f, 1.5607f, x);

    // Rational approximation: tan(x) ≈ x * (1 + x²/3) / (1 - x²/3) for small x
    // Extended with higher-order terms for better accuracy
    const float x2 = x * x;
    // Padé approximant coefficients for tan(x)
    const float num = x * (1.0f + x2 * (0.1345787032f + x2 * 0.0039168706f));
    const float den = 1.0f + x2 * (-0.1982711324f + x2 * 0.0056048227f);
    return num / den;
}

// Fast approximation of 2^x using bit manipulation + minimax polynomial
// Accurate to ~0.01% for x in [-24, 24] (~0.17 cents pitch error)
inline float fastPow2(float x)
{
    // Clamp to avoid overflow/underflow
    x = juce::jlimit(-24.0f, 24.0f, x);

    // Split into integer and fractional parts using proper floor
    // std::floor ensures f is always in [0, 1) even for negative x
    const float floored = std::floor(x);
    const int i = static_cast<int>(floored);
    const float f = x - floored;

    // Minimax polynomial for 2^f where f is in [0, 1)
    // Optimized coefficients for minimum maximum error (~0.01%)
    // Derived using Remez algorithm for [0,1) interval
    const float p = 1.0f + f * (0.6931471806f + f * (0.2402264689f +
                    f * (0.0555040957f + f * 0.0096779502f)));

    // Combine with integer exponent via bit manipulation
    // Use memcpy for well-defined type-punning (avoids strict aliasing UB)
    const int32_t bits = (i + 127) << 23;  // Create 2^i as float bits
    float pow2i;
    std::memcpy(&pow2i, &bits, sizeof(float));

    return pow2i * p;
}

// Kahan summation: adds value to sum with error compensation
// Returns the new sum, updates error term for next iteration
inline double kahanAdd(double sum, double value, double& error)
{
    const double y = value - error;
    const double t = sum + y;
    error = (t - sum) - y;
    return t;
}

// =============================================================================
// SATURATION WAVESHAPERS
// =============================================================================
// Per-sample saturation with multiple algorithms (Serum-style)
// drive: 1.0-20.0 (internal gain before waveshaper)
// Returns shaped sample, normalized to prevent excessive output level

inline float saturateSample(float x, float drive, int type)
{
    x *= drive;  // Pre-gain

    switch (type)
    {
        case 0:  // Soft clip (tanh) - smooth, musical saturation
            return std::tanh(x);

        case 1:  // Hard clip - aggressive, digital distortion
            return juce::jlimit(-1.0f, 1.0f, x);

        case 2:  // Tube - asymmetric soft clip (adds even harmonics like real tubes)
        {
            // Self-compensating asymmetric tanh to minimize DC offset
            // Positive half clips harder (1.15x), negative half softer (0.85x)
            // The asymmetry factor (0.15) creates 2nd harmonic content like real tubes
            // Using equal but opposite scaling maintains near-zero DC
            constexpr float asymmetry = 0.15f;
            const float scale = 1.0f + asymmetry * (x >= 0.0f ? 1.0f : -1.0f);
            return std::tanh(x * scale);
        }

        case 3:  // Tape - soft saturation with subtle compression
        {
            // Tape-style: softer knee, slight asymmetry, HF rolloff implied
            const float sign = (x >= 0.0f) ? 1.0f : -1.0f;
            const float absX = std::abs(x);
            // Soft knee curve: y = x / (1 + |x|)
            return sign * absX / (1.0f + absX * 0.5f);
        }

        case 4:  // Fold - wavefolding for complex harmonics
        {
            // Sine fold: wraps signal back when exceeding threshold
            // Creates rich, complex harmonics - great for synth-y sounds
            return std::sin(x);
        }

        case 5:  // Crush - bit reduction for lo-fi grit
        {
            // Quantize to ~16 levels for crunchy digital distortion
            constexpr float levels = 16.0f;
            const float shaped = std::tanh(x);  // Soft clip first to bound
            return std::round(shaped * levels) / levels;
        }

        default:
            return std::tanh(x);  // Fallback to soft clip
    }
}

int Pad::renderNextBlock(int numSamples)
{
    // Prevent denormal CPU spikes (sets FTZ/DAZ flags for this scope)
    juce::ScopedNoDenormals noDenormals;

    // Debug assertions for development (stripped in release builds)
    jassert(numSamples > 0);
    jassert(currentSampleRate > 0);

    // Validate playback state and layer bounds
    const int layerIdx = currentLayer.load();
    if (!isPlaying || layerIdx < 0 || layerIdx >= NUM_VELOCITY_LAYERS)
        return 0;

    // Safety check: ensure tempBuffer is prepared and clamp to its capacity
    // (some hosts may exceed the samplesPerBlock hint from prepareToPlay)
    const int bufferCapacity = tempBuffer.getNumSamples();
    if (bufferCapacity == 0)
        return 0;  // prepare() not called yet
    numSamples = juce::jmin(numSamples, bufferCapacity);
    jassert(numSamples <= bufferCapacity);  // Sanity check after clamping

    auto& layer = layers[layerIdx];
    if (!layer.isLoaded())
        return 0;

    // Get current buffer (accounting for round-robin)
    const auto& sampleBuffer = layer.getCurrentBuffer();
    const int sampleNumSamples = layer.getCurrentNumSamples();
    const double sampleRate = layer.getCurrentSampleRate();
    const float normGain = normalize ? layer.getCurrentNormGain() : 1.0f;

    const int numChannels = juce::jmin(2, sampleBuffer.getNumChannels());
    // Validate sample data: need channels, frames, and valid sample rates
    if (numChannels == 0 || sampleNumSamples <= 0 || sampleRate <= 0 || currentSampleRate <= 0)
        return 0;

    // Pre-compute sample bounds (used multiple times in loop)
    const int sampleLastIndex = sampleNumSamples - 1;

    const bool isMono = (numChannels == 1);

    // Cache sample read pointers outside loop (optimization)
    const float* srcL = sampleBuffer.getReadPointer(0);
    const float* srcR = isMono ? srcL : sampleBuffer.getReadPointer(1);

    // Setup secondary layer pointers for crossfade (if blending)
    const bool hasBlend = secondaryLayer >= 0 && secondaryLayer < NUM_VELOCITY_LAYERS
                          && layerBlendFactor > VEL_CROSSFADE_MIN_THRESHOLD;
    const float* secSrcL = nullptr;
    const float* secSrcR = nullptr;
    int secNumSamples = 0;
    double secSampleRate = 0.0;
    float secNormGain = 1.0f;
    bool secIsMono = true;

    int secSampleLastIndex = 0;

    if (hasBlend)
    {
        auto& secLayer = layers[secondaryLayer];
        if (secLayer.isLoaded())
        {
            const auto& secBuffer = secLayer.getCurrentBuffer();
            secNumSamples = secLayer.getCurrentNumSamples();
            secSampleRate = secLayer.getCurrentSampleRate();
            secNormGain = normalize ? secLayer.getCurrentNormGain() : 1.0f;

            const int secNumChannels = juce::jmin(2, secBuffer.getNumChannels());
            if (secNumChannels > 0 && secNumSamples > 0 && secSampleRate > 0)
            {
                secIsMono = (secNumChannels == 1);
                secSrcL = secBuffer.getReadPointer(0);
                secSrcR = secIsMono ? secSrcL : secBuffer.getReadPointer(1);
                secSampleLastIndex = secNumSamples - 1;
            }
        }
    }

    // Cache combined blend condition (constant during render loop)
    const bool blendActive = hasBlend && secSrcL != nullptr;

    // Get write pointers for temp buffer
    float* destL = tempBuffer.getWritePointer(0);
    float* destR = tempBuffer.getWritePointer(1);

    // Target pan gains (constant power panning) - will be smoothed per-sample
    const float targetPanAngle = (pan + 1.0f) * 0.25f * juce::MathConstants<float>::pi;
    const float targetPanL = std::cos(targetPanAngle);
    const float targetPanR = std::sin(targetPanAngle);

    // Target volume (will be smoothed per-sample)
    const float targetVolume = volume;

    // Equal-power velocity crossfade weights (only compute when blending is active)
    // cos/sin gives constant power: primaryWeight^2 + secondaryWeight^2 = 1
    float primaryWeight = 1.0f;
    float secondaryWeight = 0.0f;
    if (blendActive)
    {
        const float blendAngle = layerBlendFactor * 0.5f * juce::MathConstants<float>::pi;
        primaryWeight = std::cos(blendAngle);
        secondaryWeight = std::sin(blendAngle);
    }

    int samplesRendered = 0;

    // Base pitch ratio from sample rate conversion and static tuning
    const double baseSampleRateRatio = sampleRate / currentSampleRate;
    const double secBaseSampleRateRatio = (secSampleRate > 0) ? (secSampleRate / currentSampleRate) : 0.0;

    // Check if pitch envelope is active (optimization: skip per-sample pow if not)
    const bool hasPitchEnv = std::abs(pitchEnvAmount) >= PITCH_ENV_THRESHOLD;

    // Pre-calculate static pitch ratio when no pitch envelope
    const double staticPitchRatio = hasPitchEnv ? 0.0
        : std::pow(2.0, tune / SEMITONES_PER_OCTAVE) * baseSampleRateRatio;
    const double secStaticPitchRatio = hasPitchEnv ? 0.0
        : std::pow(2.0, tune / SEMITONES_PER_OCTAVE) * secBaseSampleRateRatio;

    // Determine base playback direction (for non-ping-pong modes)
    // Ping-pong uses pingPongForward which changes dynamically
    const bool baseForward = !reverse;

    // Pre-compute static position delta for non-ping-pong, no-pitch-envelope case
    // This avoids per-sample conditional computation in the most common scenario
    const double staticPositionDelta = hasPitchEnv ? 0.0
        : (baseForward ? staticPitchRatio : -staticPitchRatio);
    const double secStaticPositionDelta = (hasPitchEnv || !blendActive) ? 0.0
        : (baseForward ? secStaticPitchRatio : -secStaticPitchRatio);

    // Anti-aliasing: check if we might need it (will compute exact coefficients per-sample when pitch envelope active)
    // For static pitch, compute coefficient once; for pitch envelope, recompute in loop
    // IMPORTANT: Must consider BOTH primary and secondary layer pitch ratios when blending
    const float basePitchRatioFloat = static_cast<float>(hasPitchEnv ? baseSampleRateRatio : staticPitchRatio);
    const float secBasePitchRatioFloat = blendActive
        ? static_cast<float>(hasPitchEnv ? secBaseSampleRateRatio : secStaticPitchRatio)
        : 0.0f;
    const float maxBasePitchRatio = std::max(basePitchRatioFloat, secBasePitchRatioFloat);
    const bool antiAliasMaybeNeeded = maxBasePitchRatio > 0.99f || hasPitchEnv;  // May pitch up at some point

    // Pre-compute smoothing alpha (constant for entire block - hoisted from loop)
    const float smoothAlpha = 1.0f - paramSmoothCoeff;
    // Note: aaCoeffSmoothAlpha is pre-computed in prepare() and stored as member variable

    // Pre-compute transient shaper gains (block-rate, not sample-rate!)
    // transAttack/transSustain: -1 to +1, maps to 0.25x to 4x gain (±12dB)
    const bool transientActive = std::abs(transAttack) > 0.001f || std::abs(transSustain) > 0.001f;
    const float transAttackGain = transientActive ? std::pow(4.0f, transAttack) : 1.0f;
    const float transSustainGain = transientActive ? std::pow(4.0f, transSustain) : 1.0f;

    // Pre-compute saturation drive (block-rate)
    const bool saturationActive = satDrive > 0.001f;
    const float internalSatDrive = saturationActive ? (1.0f + satDrive * 19.0f) : 1.0f;

    // Loop boundaries as doubles (avoid repeated casts)
    const double startBoundary = static_cast<double>(playStartSample);
    const double endBoundary = static_cast<double>(playEndSample);
    const double endBoundaryMinus1 = static_cast<double>(playEndSample - 1);

    // Secondary layer boundaries (using normalized positions)
    double secStartBoundary = 0.0, secEndBoundary = 0.0, secEndBoundaryMinus1 = 0.0;
    if (blendActive)
    {
        // Map same normalized range to secondary sample
        float effectiveStart = sampleStart;
        float effectiveEnd = sampleEnd;
        if (effectiveStart > effectiveEnd)
            std::swap(effectiveStart, effectiveEnd);

        int secStart = static_cast<int>(effectiveStart * secNumSamples);
        int secEnd = static_cast<int>(effectiveEnd * secNumSamples);
        secStart = juce::jlimit(0, secNumSamples - 1, secStart);
        secEnd = juce::jlimit(secStart + 1, secNumSamples, secEnd);

        secStartBoundary = static_cast<double>(secStart);
        secEndBoundary = static_cast<double>(secEnd);
        secEndBoundaryMinus1 = static_cast<double>(secEnd - 1);
    }

    // Clamp playPosition to valid bounds before loop starts
    // (prevents floating-point accumulation errors from causing out-of-bounds access)
    playPosition = juce::jlimit(startBoundary, endBoundaryMinus1, playPosition);
    if (blendActive)
        secondaryPlayPosition = juce::jlimit(secStartBoundary, secEndBoundaryMinus1, secondaryPlayPosition);

    // Pre-compute loop mode flags (constant during render)
    const bool isPingPong = (loopMode == LoopMode::PingPong);
    const bool isOneShot = (loopMode == LoopMode::OneShot);

    // Select interpolation functions once (avoids per-sample switch)
    const auto sincFuncs = getSincFunctions(static_cast<int>(interpolationQuality));

    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Calculate position delta based on mode:
        // - Ping-pong: must compute per-sample (direction changes on boundary)
        // - Pitch envelope: must compute per-sample (pitch changes per-sample)
        // - Otherwise: use pre-computed static value (most common case)
        double positionDelta;
        double secPositionDelta = 0.0;
        bool movingForward;
        bool secMovingForward = baseForward;

        if (isPingPong)
        {
            // Ping-pong mode: direction can change, must compute per-sample
            movingForward = pingPongForward;
            if (hasPitchEnv)
            {
                const float envValue = pitchEnvelope.getNextSample();
                const float totalPitch = tune + pitchEnvAmount * envValue;
                const float pitchMult = fastPow2(totalPitch / SEMITONES_PER_OCTAVE);
                const double pitchRatio = static_cast<double>(pitchMult) * baseSampleRateRatio;
                positionDelta = movingForward ? pitchRatio : -pitchRatio;
                if (blendActive)
                {
                    secMovingForward = secondaryPingPongForward;
                    const double secPitchRatio = static_cast<double>(pitchMult) * secBaseSampleRateRatio;
                    secPositionDelta = secMovingForward ? secPitchRatio : -secPitchRatio;
                }
            }
            else
            {
                positionDelta = movingForward ? staticPitchRatio : -staticPitchRatio;
                if (blendActive)
                {
                    secMovingForward = secondaryPingPongForward;
                    secPositionDelta = secMovingForward ? secStaticPitchRatio : -secStaticPitchRatio;
                }
            }
        }
        else if (hasPitchEnv)
        {
            // Pitch envelope active: must compute pitch per-sample, but direction is constant
            movingForward = baseForward;
            const float envValue = pitchEnvelope.getNextSample();
            const float totalPitch = tune + pitchEnvAmount * envValue;
            const float pitchMult = fastPow2(totalPitch / SEMITONES_PER_OCTAVE);
            const double pitchRatio = static_cast<double>(pitchMult) * baseSampleRateRatio;
            positionDelta = movingForward ? pitchRatio : -pitchRatio;
            if (blendActive)
            {
                const double secPitchRatio = static_cast<double>(pitchMult) * secBaseSampleRateRatio;
                secPositionDelta = movingForward ? secPitchRatio : -secPitchRatio;
            }
        }
        else
        {
            // Most common case: no ping-pong, no pitch envelope
            // Use pre-computed static values (fastest path)
            movingForward = baseForward;
            positionDelta = staticPositionDelta;
            if (blendActive)
                secPositionDelta = secStaticPositionDelta;
        }

        // Check playback boundaries (primary layer)
        // JUCE_LIKELY: most samples are within bounds, boundary crossing is rare
        const bool pastBoundary = movingForward
            ? (playPosition >= endBoundary)
            : (playPosition < startBoundary);

        if (pastBoundary)
        {
            // Handle boundary crossing based on pre-computed loop mode flags
            if (isOneShot)
            {
                isPlaying = false;
            }
            else if (isPingPong)
            {
                // Handle potentially multiple bounces for high pitch ratios
                const double loopLength = endBoundary - startBoundary;
                if (loopLength < 1.0)  // Must have at least 1 sample to loop
                {
                    isPlaying = false;
                }
                else
                {
                    // Calculate overshoot
                    double overshoot = movingForward
                        ? (playPosition - endBoundary)
                        : (startBoundary - playPosition);

                    // Mathematical solution for multiple bounces (O(1) instead of O(bounces))
                    // Number of full loop traversals in the overshoot
                    const int numBounces = static_cast<int>(overshoot / loopLength) + 1;
                    const double remainingOvershoot = std::fmod(overshoot, loopLength);

                    // Each bounce flips direction; odd bounces = direction changed
                    if (numBounces % 2 == 1)
                        pingPongForward = !pingPongForward;

                    // Calculate final position based on new direction
                    playPosition = pingPongForward
                        ? (startBoundary + remainingOvershoot)
                        : (endBoundaryMinus1 - remainingOvershoot);

                    // Clamp to valid range (safety)
                    playPosition = juce::jlimit(startBoundary, endBoundaryMinus1, playPosition);
                }
            }
            else  // LoopMode::Loop
            {
                // Simple loop: jump back to start
                playPosition = movingForward ? startBoundary : endBoundaryMinus1;
            }

            if (!isPlaying)
                break;
        }

        // Handle secondary layer boundaries (if blending)
        if (blendActive)
        {
            const bool secPastBoundary = secMovingForward
                ? (secondaryPlayPosition >= secEndBoundary)
                : (secondaryPlayPosition < secStartBoundary);

            if (secPastBoundary)
            {
                // OneShot: secondary stops but primary continues (do nothing)
                if (isPingPong)
                {
                    const double secLoopLength = secEndBoundary - secStartBoundary;
                    if (secLoopLength >= 1.0)  // Must have at least 1 sample to loop
                    {
                        double overshoot = secMovingForward
                            ? (secondaryPlayPosition - secEndBoundary)
                            : (secStartBoundary - secondaryPlayPosition);

                        // Mathematical solution for multiple bounces (O(1))
                        const int numBounces = static_cast<int>(overshoot / secLoopLength) + 1;
                        const double remainingOvershoot = std::fmod(overshoot, secLoopLength);

                        if (numBounces % 2 == 1)
                            secondaryPingPongForward = !secondaryPingPongForward;

                        secondaryPlayPosition = secondaryPingPongForward
                            ? (secStartBoundary + remainingOvershoot)
                            : (secEndBoundaryMinus1 - remainingOvershoot);

                        secondaryPlayPosition = juce::jlimit(secStartBoundary, secEndBoundaryMinus1, secondaryPlayPosition);
                    }
                }
                else if (!isOneShot)  // LoopMode::Loop
                {
                    secondaryPlayPosition = secMovingForward ? secStartBoundary : secEndBoundaryMinus1;
                }
            }
        }

        // Get amplitude envelope value
        const float envValue = envelope.getNextSample();
        if (!envelope.isActive())
        {
            isPlaying = false;
            break;
        }

        // Polyphase sinc interpolation for pitch shifting (primary layer)
        // Professional-grade 16-tap windowed sinc - same quality as Kontakt/Battery
        const int pos0 = static_cast<int>(playPosition);

        // Debug assertion: playPosition should always be valid at this point
        jassert(pos0 >= 0 && pos0 <= sampleLastIndex);

        // Bounds check pos0 to prevent buffer overrun (defense-in-depth for release builds)
        if (pos0 < 0 || pos0 > sampleLastIndex)
        {
            stopImmediate();
            break;
        }

        const float frac = static_cast<float>(playPosition - static_cast<double>(pos0));

        // Sinc interpolate primary layer using pre-selected function pointers
        // Use fast version when safely within bounds, clamped version near edges
        float sampleL, sampleR;
        if (isMono)
        {
            if (sincFuncs.canUseFast(pos0, sampleNumSamples))
                sampleL = sampleR = sincFuncs.interpolateFast(srcL, pos0, frac) * normGain;
            else
                sampleL = sampleR = sincFuncs.interpolate(srcL, pos0, frac, sampleNumSamples) * normGain;
        }
        else
        {
            if (sincFuncs.canUseFast(pos0, sampleNumSamples))
            {
                sampleL = sincFuncs.interpolateFast(srcL, pos0, frac) * normGain;
                sampleR = sincFuncs.interpolateFast(srcR, pos0, frac) * normGain;
            }
            else
            {
                sampleL = sincFuncs.interpolate(srcL, pos0, frac, sampleNumSamples) * normGain;
                sampleR = sincFuncs.interpolate(srcR, pos0, frac, sampleNumSamples) * normGain;
            }
        }

        // Blend with secondary layer using equal-power crossfade (if active)
        if (blendActive)
        {
            const int secPos0 = static_cast<int>(secondaryPlayPosition);
            if (secPos0 >= 0 && secPos0 <= secSampleLastIndex)
            {
                const float secFrac = static_cast<float>(secondaryPlayPosition - static_cast<double>(secPos0));

                // Sinc interpolate secondary layer using pre-selected function pointers
                float secSampleL, secSampleR;
                if (secIsMono)
                {
                    if (sincFuncs.canUseFast(secPos0, secNumSamples))
                        secSampleL = secSampleR = sincFuncs.interpolateFast(secSrcL, secPos0, secFrac) * secNormGain;
                    else
                        secSampleL = secSampleR = sincFuncs.interpolate(secSrcL, secPos0, secFrac, secNumSamples) * secNormGain;
                }
                else
                {
                    if (sincFuncs.canUseFast(secPos0, secNumSamples))
                    {
                        secSampleL = sincFuncs.interpolateFast(secSrcL, secPos0, secFrac) * secNormGain;
                        secSampleR = sincFuncs.interpolateFast(secSrcR, secPos0, secFrac) * secNormGain;
                    }
                    else
                    {
                        secSampleL = sincFuncs.interpolate(secSrcL, secPos0, secFrac, secNumSamples) * secNormGain;
                        secSampleR = sincFuncs.interpolate(secSrcR, secPos0, secFrac, secNumSamples) * secNormGain;
                    }
                }

                // Calculate fade-out gain for secondary layer approaching end in OneShot mode
                // This prevents abrupt dropout when secondary sample ends before primary
                // Use extended fade zone (1.5x) to ensure gain reaches ~0 before boundary skip
                float secFadeGain = 1.0f;
                if (isOneShot)
                {
                    // Calculate samples remaining until secondary reaches end boundary
                    // (moving forward: distance to secEndBoundary, reverse: distance from secStartBoundary)
                    const double distanceToEnd = secMovingForward
                        ? (secEndBoundary - secondaryPlayPosition)
                        : (secondaryPlayPosition - secStartBoundary);

                    // Extended fade zone ensures we reach ~0 gain before the bounds check skips us
                    // At distanceToEnd=0, fadeProgress=-0.5, secFadeGain=0 (clamped)
                    constexpr double EXTENDED_FADE_SAMPLES = FADE_OUT_SAMPLES * 1.5;
                    if (distanceToEnd < EXTENDED_FADE_SAMPLES)
                    {
                        // Map so that fadeProgress=1 at EXTENDED_FADE_SAMPLES, fadeProgress=0 at FADE_OUT_SAMPLES/2
                        const float fadeProgress = static_cast<float>((distanceToEnd - FADE_OUT_SAMPLES * 0.5) / static_cast<double>(FADE_OUT_SAMPLES));
                        secFadeGain = std::sqrt(std::max(0.0f, std::min(1.0f, fadeProgress)));  // Equal-power curve, clamped
                    }
                }

                // Equal-power blend with secondary fade-out applied
                // Fast path: when not fading, use pre-computed cos/sin weights directly
                // Fade path: recalculate primary weight to maintain constant energy
                // Math: since primaryWeight = cos(angle) and secondaryWeight = sin(angle),
                //       and cos^2 + sin^2 = 1, we have primaryWeight = sqrt(1 - secondaryWeight^2)
                const float effectiveSecWeight = secondaryWeight * secFadeGain;
                const float effectivePrimWeight = (secFadeGain >= 0.9999f)
                    ? primaryWeight  // Fast path: no fade, use pre-computed cos
                    : std::sqrt(1.0f - effectiveSecWeight * effectiveSecWeight);  // Maintain equal power
                sampleL = sampleL * effectivePrimWeight + secSampleL * effectiveSecWeight;
                sampleR = sampleR * effectivePrimWeight + secSampleR * effectiveSecWeight;
            }
        }

        // Apply anti-aliasing filter when pitching up (prevents harsh artifacts)
        // Compute coefficient dynamically based on current pitch ratio (handles pitch envelope)
        // IMPORTANT: Use max of primary and secondary pitch ratios to ensure AA is applied
        // when either layer needs it (they may have different source sample rates)
        if (antiAliasMaybeNeeded)
        {
            // Get current pitch ratio (positionDelta magnitude = pitch ratio)
            // Use max of primary and secondary to handle mixed sample rate velocity layers
            const float primaryPitchRatio = static_cast<float>(std::abs(positionDelta));
            const float secondaryPitchRatio = blendActive
                ? static_cast<float>(std::abs(secPositionDelta))
                : 0.0f;
            const float currentPitchRatio = std::max(primaryPitchRatio, secondaryPitchRatio);

            if (currentPitchRatio > 1.01f)
            {
                // Two-pole (biquad) lowpass for better rolloff (~12dB/octave vs 6dB for one-pole)
                // Cutoff frequency = Nyquist / pitchRatio
                const float cutoffNorm = 0.5f / currentPitchRatio;  // Normalized cutoff (0-0.5)
                const float k = fastTan(juce::MathConstants<float>::pi * juce::jlimit(AA_CUTOFF_MIN_NORM, AA_CUTOFF_MAX_NORM, cutoffNorm));
                const float k2 = k * k;
                const float sqrt2k = juce::MathConstants<float>::sqrt2 * k;  // Butterworth Q
                const float norm = 1.0f / (1.0f + sqrt2k + k2);

                // Target biquad coefficients (transposed direct form II)
                const float targetB0 = k2 * norm;
                const float targetB1 = 2.0f * targetB0;
                const float targetA1 = 2.0f * (k2 - 1.0f) * norm;
                const float targetA2 = (1.0f - sqrt2k + k2) * norm;

                // Smooth coefficients to prevent artifacts from rapid changes during pitch envelope
                if (!aaCoeffsInitialized)
                {
                    // First sample: instant set to avoid initial ramp
                    smoothedAAb0 = targetB0;
                    smoothedAAb1 = targetB1;
                    smoothedAAa1 = targetA1;
                    smoothedAAa2 = targetA2;
                    aaCoeffsInitialized = true;
                }
                else
                {
                    // Smooth toward target coefficients
                    smoothedAAb0 += (targetB0 - smoothedAAb0) * aaCoeffSmoothAlpha;
                    smoothedAAb1 += (targetB1 - smoothedAAb1) * aaCoeffSmoothAlpha;
                    smoothedAAa1 += (targetA1 - smoothedAAa1) * aaCoeffSmoothAlpha;
                    smoothedAAa2 += (targetA2 - smoothedAAa2) * aaCoeffSmoothAlpha;
                }

                // Apply biquad with smoothed coefficients to L channel
                const float inL = sampleL;
                sampleL = smoothedAAb0 * inL + antiAliasState[0];
                antiAliasState[0] = smoothedAAb1 * inL - smoothedAAa1 * sampleL + antiAliasState[1];
                antiAliasState[1] = smoothedAAb0 * inL - smoothedAAa2 * sampleL;

                // Apply biquad to R channel (using state[2] and state[3])
                const float inR = sampleR;
                sampleR = smoothedAAb0 * inR + antiAliasState[2];
                antiAliasState[2] = smoothedAAb1 * inR - smoothedAAa1 * sampleR + antiAliasState[3];
                antiAliasState[3] = smoothedAAb0 * inR - smoothedAAa2 * sampleR;
            }
        }

        // Apply saturation (waveshaping distortion)
        // Order: after anti-aliasing, before transient shaper and filter
        // Uses pre-computed saturationActive and internalSatDrive (block-rate)
        if (saturationActive)
        {
            // Get dry samples for mix
            const float dryL = sampleL;
            const float dryR = sampleR;

            // Apply saturation using pre-computed drive
            const float wetL = saturateSample(sampleL, internalSatDrive, satType);
            const float wetR = saturateSample(sampleR, internalSatDrive, satType);

            // Dry/wet mix
            sampleL = dryL + (wetL - dryL) * satMix;
            sampleR = dryR + (wetR - dryR) * satMix;

            // DC blocker (one-pole highpass at ~10Hz) to remove DC offset from asymmetric saturation
            // y[n] = x[n] - x[n-1] + coeff * y[n-1]
            // This is a classic leaky integrator highpass filter
            const float dcOutL = sampleL - dcBlockerStateL;
            dcBlockerStateL = sampleL - dcBlockerCoeff * dcOutL;
            sampleL = dcOutL;

            const float dcOutR = sampleR - dcBlockerStateR;
            dcBlockerStateR = sampleR - dcBlockerCoeff * dcOutR;
            sampleR = dcOutR;
        }

        // Apply transient shaper (attack/sustain control)
        // Uses dual envelope followers to separate transient from sustain
        // Uses pre-computed transientActive, transAttackGain, transSustainGain (block-rate)
        if (transientActive)
        {
            // Get mono signal level for envelope detection using RMS
            // RMS provides smoother envelope tracking than peak (sum of absolutes)
            const float monoLevelSquared = sampleL * sampleL + sampleR * sampleR;
            const float monoLevel = std::sqrt(monoLevelSquared);

            // Update fast envelope (tracks transients)
            if (monoLevel > transEnvFast)
                transEnvFast = monoLevel + (transEnvFast - monoLevel) * transAttackCoeff;
            else
                transEnvFast = monoLevel + (transEnvFast - monoLevel) * transReleaseCoeffFast;

            // Update slow envelope (tracks sustain)
            if (monoLevel > transEnvSlow)
                transEnvSlow = monoLevel + (transEnvSlow - monoLevel) * transAttackCoeff;
            else
                transEnvSlow = monoLevel + (transEnvSlow - monoLevel) * transReleaseCoeffSlow;

            // Transient signal = difference between fast and slow envelopes
            // When fast > slow, we're in an attack transient
            // Sustain signal = slow envelope (the "body" of the sound)
            const float transientSignal = std::max(0.0f, transEnvFast - transEnvSlow);
            const float sustainSignal = transEnvSlow;

            // Avoid division by zero
            const float envSum = transEnvFast + 0.0001f;

            // Blend pre-computed gains based on envelope content
            // Weight by how much of signal is transient vs sustain
            const float transientWeight = transientSignal / envSum;
            const float sustainWeight = sustainSignal / envSum;

            // Final gain = weighted combination (using pre-computed attackGain/sustainGain)
            float finalGain = 1.0f + transientWeight * (transAttackGain - 1.0f)
                                   + sustainWeight * (transSustainGain - 1.0f);

            // Soft limiter to prevent excessive gain from causing clipping
            // Uses tanh-style limiting: gain = targetGain / (1 + (targetGain/limit)^2)^0.5
            // This smoothly limits gains above 2.0 (6dB) while preserving lower gains
            constexpr float GAIN_LIMIT = 2.5f;  // Allow up to ~8dB boost before soft limiting
            if (finalGain > 1.0f)
            {
                const float ratio = finalGain / GAIN_LIMIT;
                finalGain = finalGain / std::sqrt(1.0f + ratio * ratio);
            }

            sampleL *= finalGain;
            sampleR *= finalGain;
        }

        // Smooth volume, pan, and filter parameters (prevents zipper noise on automation)
        smoothedVolume += (targetVolume - smoothedVolume) * smoothAlpha;
        smoothedPanL += (targetPanL - smoothedPanL) * smoothAlpha;
        smoothedPanR += (targetPanR - smoothedPanR) * smoothAlpha;
        smoothedFilterCutoff += (filterCutoff - smoothedFilterCutoff) * smoothAlpha;
        smoothedFilterReso += (filterReso - smoothedFilterReso) * smoothAlpha;

        // Calculate per-sample gain with smoothed parameters
        const float smoothedGain = smoothedVolume * currentVelocity;
        const float gainL = smoothedGain * smoothedPanL;
        const float gainR = smoothedGain * smoothedPanR;

        // Apply fade-out ramp if stopping (click-free stop with equal-power curve)
        float fadeGain = 1.0f;
        if (fadeOutSamplesRemaining > 0)
        {
            // Equal-power fade using sqrt for smoother perceptual fade
            const float fadeProgress = static_cast<float>(fadeOutSamplesRemaining) / static_cast<float>(FADE_OUT_SAMPLES);
            fadeGain = std::sqrt(fadeProgress);  // Equal-power: sqrt gives constant energy
            --fadeOutSamplesRemaining;
            if (fadeOutSamplesRemaining == 0)
            {
                stopImmediate();
                // Continue to write this last sample with near-zero gain, then break
            }
        }

        // Apply boundary fade for primary layer in OneShot mode (prevents click at sample end)
        // Similar to secondary layer fade, but for the main playback position
        if (isOneShot && fadeOutSamplesRemaining == 0)  // Don't double-fade if already stopping
        {
            const double distanceToEnd = movingForward
                ? (endBoundary - playPosition)
                : (playPosition - startBoundary);

            // Fade over ~3ms (FADE_OUT_SAMPLES) when approaching boundary
            if (distanceToEnd < static_cast<double>(FADE_OUT_SAMPLES))
            {
                const float boundaryFadeProgress = static_cast<float>(distanceToEnd / static_cast<double>(FADE_OUT_SAMPLES));
                fadeGain *= std::sqrt(std::max(0.0f, boundaryFadeProgress));  // Equal-power curve
            }
        }

        // Write to output with envelope, gain, and fade
        // Pre-multiply shared factors (envValue * fadeGain) to save one multiply per channel
        const float envFadeGain = envValue * fadeGain;
        destL[sample] = sampleL * gainL * envFadeGain;
        destR[sample] = sampleR * gainR * envFadeGain;

        ++samplesRendered;

        // Check if we just finished fading out
        if (!isPlaying)
            break;

        // Advance positions using Kahan summation for drift-free accumulation
        playPosition = kahanAdd(playPosition, positionDelta, playPositionError);
        if (blendActive)
            secondaryPlayPosition = kahanAdd(secondaryPlayPosition, secPositionDelta, secondaryPositionError);
    }

    // Apply filter (LP if cutoff < 20kHz, HP if cutoff > 20Hz, BP always)
    // Use smoothed parameters for consistent bypass decision
    const bool applyFilter = (filterType == 0 && smoothedFilterCutoff < FILTER_LP_BYPASS_THRESHOLD) ||
                             (filterType == 1 && smoothedFilterCutoff > FILTER_HP_BYPASS_THRESHOLD) ||
                             (filterType == 2);  // Bandpass always applies

    if (samplesRendered > 0 && applyFilter)
    {
        // Filter parameters are now smoothed per-sample in the main loop
        // Only update filter type when changed (type changes are discrete)
        if (filterType != lastFilterType)
        {
            // Filter types: 0=LP, 1=HP, 2=BP (matching Parameters.h definition)
            switch (filterType)
            {
                case 0:  filter.setType(juce::dsp::StateVariableTPTFilterType::lowpass);  break;
                case 1:  filter.setType(juce::dsp::StateVariableTPTFilterType::highpass); break;
                case 2:  filter.setType(juce::dsp::StateVariableTPTFilterType::bandpass); break;
                default: filter.setType(juce::dsp::StateVariableTPTFilterType::lowpass);  break;
            }
            // Reset filter state to prevent transient artifacts from type change mid-note
            filter.reset();
            lastFilterType = filterType;
        }

        // Only update cutoff/resonance when changed significantly
        // Threshold: ~0.1% change avoids redundant coefficient recalculation
        constexpr float FILTER_UPDATE_THRESHOLD = 0.001f;
        const float cutoffDelta = std::abs(smoothedFilterCutoff - lastFilterCutoff);
        const float resoDelta = std::abs(smoothedFilterReso - lastFilterReso);

        if (cutoffDelta > lastFilterCutoff * FILTER_UPDATE_THRESHOLD || lastFilterCutoff < 0.0f)
        {
            filter.setCutoffFrequency(smoothedFilterCutoff);
            lastFilterCutoff = smoothedFilterCutoff;
        }

        if (resoDelta > FILTER_UPDATE_THRESHOLD || lastFilterReso < 0.0f)
        {
            // Map 0-1 resonance to Q factor (0.707 Butterworth to 10 high-reso)
            const float q = FILTER_Q_MIN + smoothedFilterReso * (FILTER_Q_MAX - FILTER_Q_MIN);
            filter.setResonance(q);
            lastFilterReso = smoothedFilterReso;
        }

        juce::dsp::AudioBlock<float> block(tempBuffer);
        auto subBlock = block.getSubBlock(0, static_cast<size_t>(samplesRendered));
        juce::dsp::ProcessContextReplacing<float> context(subBlock);
        filter.process(context);
    }

    return samplesRendered;
}

// =============================================================================
// SAMPLE MANAGEMENT
// =============================================================================

void Pad::setSampleBuffer(int layerIndex,
                          juce::AudioBuffer<float>&& buffer,
                          double sampleRate,
                          const juce::String& path,
                          float inNormGain)
{
    if (layerIndex < 0 || layerIndex >= NUM_VELOCITY_LAYERS)
        return;

    // Stop playback synchronously to prevent race conditions
    // Using stopImmediate() ensures completion within this call (no fade-out)
    stopImmediate();

    auto& layer = layers[layerIndex];
    layer.buffer = std::move(buffer);
    layer.numSamples = layer.buffer.getNumSamples();
    layer.sourceSampleRate = sampleRate;
    layer.filePath = path;
    layer.normGain = inNormGain;

    // Compute waveform peaks for visualization
    layer.computePeaks();
}

void Pad::addRoundRobinBuffer(int layerIndex,
                              juce::AudioBuffer<float>&& buffer,
                              double sampleRate,
                              const juce::String& path,
                              float inNormGain)
{
    if (layerIndex < 0 || layerIndex >= NUM_VELOCITY_LAYERS)
        return;

    // Prevent vector reallocation on audio thread by enforcing capacity limit
    if (layers[layerIndex].roundRobinSamples.size() >= MAX_ROUND_ROBIN_SAMPLES)
        return;  // Silently drop - at capacity

    // Stop playback synchronously to prevent race conditions
    // Using stopImmediate() ensures completion within this call (no fade-out)
    stopImmediate();

    RoundRobinSample sample;
    sample.buffer = std::move(buffer);
    sample.sampleRate = sampleRate;
    sample.path = path;
    sample.normGain = inNormGain;

    layers[layerIndex].roundRobinSamples.push_back(std::move(sample));
}

void Pad::clearSample(int layerIndex)
{
    if (layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS)
    {
        // Stop playback synchronously to prevent race conditions
        // Using stopImmediate() ensures completion within this call (no fade-out)
        stopImmediate();
        layers[layerIndex].clear();
    }
}

void Pad::clearRoundRobin(int layerIndex)
{
    if (layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS)
    {
        // Stop playback synchronously to prevent race conditions
        // Using stopImmediate() ensures completion within this call (no fade-out)
        stopImmediate();

        layers[layerIndex].roundRobinSamples.clear();
        layers[layerIndex].roundRobinIndex = 0;
    }
}

// =============================================================================
// QUERIES
// =============================================================================

juce::String Pad::getSamplePath(int layerIndex) const
{
    if (layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS)
        return layers[layerIndex].filePath;
    return {};
}

std::vector<juce::String> Pad::getRoundRobinPaths(int layerIndex) const
{
    if (layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS)
        return layers[layerIndex].getRoundRobinPaths();
    return {};
}

const juce::String& Pad::getRoundRobinPath(int layerIndex, int rrIndex) const
{
    // Allocation-free path access - safe for audio thread
    if (layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS)
        return layers[layerIndex].getRoundRobinPath(rrIndex);
    return kEmptyString;
}

bool Pad::hasSample(int layerIndex) const
{
    if (layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS)
        return layers[layerIndex].isLoaded();
    return false;
}

int Pad::getRoundRobinCount(int layerIndex) const
{
    if (layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS)
        return layers[layerIndex].getRoundRobinCount();
    return 0;
}

double Pad::getSampleDuration(int layerIndex) const
{
    if (layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS)
    {
        const auto& layer = layers[layerIndex];
        if (layer.isLoaded())
        {
            // Use current sample (handles round-robin case correctly)
            int numSamples = layer.getCurrentNumSamples();
            double sampleRate = layer.getCurrentSampleRate();
            if (numSamples > 0 && sampleRate > 0)
                return static_cast<double>(numSamples) / sampleRate;
        }
    }
    return 0.0;
}

float Pad::getPlaybackProgress() const
{
    if (!isPlaying)
        return 0.0f;

    // Calculate normalized progress within start/end region
    const double regionLength = static_cast<double>(playEndSample - playStartSample);
    if (regionLength <= 0)
        return 0.0f;

    // playPosition is already clamped to [playStartSample, playEndSample] in renderNextBlock
    const double progress = (playPosition - static_cast<double>(playStartSample)) / regionLength;
    return static_cast<float>(juce::jlimit(0.0, 1.0, progress));
}

// Static empty vector for safe reference return
static const std::vector<float> kEmptyPeaks;

const std::vector<float>& Pad::getPeaksMini(int layerIndex) const
{
    if (layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS)
        return layers[layerIndex].peaksMini;
    return kEmptyPeaks;
}

const std::vector<float>& Pad::getPeaksFull(int layerIndex) const
{
    if (layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS)
        return layers[layerIndex].peaksFull;
    return kEmptyPeaks;
}

// =============================================================================
// PRIVATE HELPERS
// =============================================================================

int Pad::selectVelocityLayer(int velocity)
{
    // Select ideal layer based on velocity thresholds from Parameters.h
    int idealLayer;
    if (velocity >= VELOCITY_LAYER_3_MIN)
        idealLayer = 3;
    else if (velocity >= VELOCITY_LAYER_2_MIN)
        idealLayer = 2;
    else if (velocity >= VELOCITY_LAYER_1_MIN)
        idealLayer = 1;
    else
        idealLayer = 0;

    // Try ideal layer first
    if (layers[idealLayer].isLoaded())
        return idealLayer;

    // Fallback: find closest loaded layer (prefer lower layers for softer sound)
    for (int i = idealLayer - 1; i >= 0; --i)
    {
        if (layers[i].isLoaded())
            return i;
    }

    // Try higher layers if no lower ones available
    for (int i = idealLayer + 1; i < NUM_VELOCITY_LAYERS; ++i)
    {
        if (layers[i].isLoaded())
            return i;
    }

    return -1;  // No layers loaded
}

void Pad::updateEnvelopeParams()
{
    juce::ADSR::Parameters params;
    params.attack = attack * MS_TO_SECONDS;
    params.decay = decay * MS_TO_SECONDS;
    params.sustain = sustain;
    params.release = release * MS_TO_SECONDS;
    envelope.setParameters(params);
}

void Pad::updatePitchEnvelopeParams()
{
    // Pitch envelope: attack → decay → sustain level
    // For 808-style kicks: attack=0, decay=50-200ms, sustain=0 (full sweep)
    juce::ADSR::Parameters params;
    params.attack = pitchEnvAttack * MS_TO_SECONDS;
    params.decay = pitchEnvDecay * MS_TO_SECONDS;
    params.sustain = pitchEnvSustain;           // 0 = full sweep to base pitch
    params.release = 1.0f * MS_TO_SECONDS;      // 1ms - very short release (instant)
    pitchEnvelope.setParameters(params);
}

}  // namespace DrumBlocks
