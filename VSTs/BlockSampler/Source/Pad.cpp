// =============================================================================
// BlockSampler/Source/Pad.cpp
// Pad implementation - audio playback, sample loading, ADSR, filtering
// =============================================================================

#include "Pad.h"
#include <limits>
#include <cstring>  // For memcpy (type-punning)

namespace BlockSampler
{

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
    return roundRobinSamples[roundRobinIndex % roundRobinSamples.size()].buffer;
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
    return roundRobinSamples[roundRobinIndex % roundRobinSamples.size()].sampleRate;
}

float VelocityLayer::getCurrentNormGain() const
{
    if (roundRobinSamples.empty())
        return normGain;
    return roundRobinSamples[roundRobinIndex % roundRobinSamples.size()].normGain;
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
        for (int attempts = 0; attempts < 10 && newIndex == roundRobinIndex; ++attempts)
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
    static const juce::String emptyString;
    if (index >= 0 && index < static_cast<int>(roundRobinSamples.size()))
        return roundRobinSamples[index].path;
    return emptyString;
}

void VelocityLayer::clear()
{
    buffer.setSize(0, 0);
    numSamples = 0;
    sourceSampleRate = 44100.0;  // Reset to default
    filePath.clear();
    normGain = 1.0f;
    roundRobinSamples.clear();
    roundRobinIndex = 0;
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

    // Prepare filter
    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = static_cast<juce::uint32>(samplesPerBlock);
    spec.numChannels = 2;
    filter.prepare(spec);
    filter.setType(juce::dsp::StateVariableTPTFilterType::lowpass);
}

void Pad::trigger(int velocity)
{
    // Validate velocity range (MIDI is 0-127, but be defensive)
    if (velocity <= 0)
    {
        noteOff();
        return;
    }
    velocity = juce::jmin(velocity, 127);  // Clamp to valid MIDI range

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
    if (velCrossfade > 0.001f)
    {
        // Layer thresholds: 0-31 (L0), 32-63 (L1), 64-95 (L2), 96-127 (L3)
        constexpr int thresholds[] = { 0, VELOCITY_LAYER_1_MIN, VELOCITY_LAYER_2_MIN, VELOCITY_LAYER_3_MIN, 128 };

        const int layerMin = thresholds[currentLayer];
        const int layerMax = thresholds[currentLayer + 1];
        const int layerRange = layerMax - layerMin;

        // Calculate blend zone width (as velocity units)
        const float blendWidth = layerRange * velCrossfade;

        // Check if we're in the upper blend zone (transitioning to higher layer)
        // Guard against division by zero when blendWidth is too small
        if (currentLayer < NUM_VELOCITY_LAYERS - 1 && blendWidth > 0.5f)
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
            if (velocity < blendZoneEnd && layers[currentLayer - 1].isLoaded() && lowerBlendWidth > 0.5f)
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
    // Maps to exponent: 2.0 (soft) → 1.0 (linear) → 0.5 (hard)
    const float normalizedVel = velocity / 127.0f;
    const float curveExp = std::pow(2.0f, 1.0f - 2.0f * velCurve);
    currentVelocity = std::pow(normalizedVel, curveExp);

    isPlaying = true;

    // Reset ping-pong direction (always start in initial direction)
    pingPongForward = !reverse;

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
    // In non-one-shot modes, note-off triggers release phase
    if (loopMode != LoopMode::OneShot)
    {
        envelope.noteOff();
        pitchEnvelope.noteOff();
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
    isPlaying = false;
    envelope.reset();
    pitchEnvelope.reset();
}

// =============================================================================
// AUDIO PROCESSING
// =============================================================================

// Fast approximation of 2^x using bit manipulation + polynomial refinement
// Accurate to ~0.1% for x in [-24, 24], much faster than std::pow
inline float fastPow2(float x)
{
    // Clamp to avoid overflow/underflow
    x = juce::jlimit(-24.0f, 24.0f, x);

    // Split into integer and fractional parts
    const int i = static_cast<int>(x >= 0 ? x : x - 1);
    const float f = x - static_cast<float>(i);

    // Polynomial approximation for 2^f where f is in [0, 1)
    // Using a cubic minimax polynomial: max error ~0.07%
    const float p = 1.0f + f * (0.6931472f + f * (0.2402265f + f * 0.0558011f));

    // Combine with integer exponent via bit manipulation
    // Use memcpy for well-defined type-punning (avoids strict aliasing UB)
    const int32_t bits = (i + 127) << 23;  // Create 2^i as float bits
    float pow2i;
    std::memcpy(&pow2i, &bits, sizeof(float));

    return pow2i * p;
}

int Pad::renderNextBlock(int numSamples)
{
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
                          && layerBlendFactor > 0.001f;
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

    // Pre-calculate pan gains (constant power panning)
    const float panAngle = (pan + 1.0f) * 0.25f * juce::MathConstants<float>::pi;
    const float panGainL = std::cos(panAngle);
    const float panGainR = std::sin(panAngle);

    // Pre-calculate base gain (volume * velocity)
    // Note: normGain is applied per-layer since they may differ
    const float baseGain = volume * currentVelocity;

    // Blend weights
    const float primaryWeight = 1.0f - layerBlendFactor;
    const float secondaryWeight = layerBlendFactor;

    // Clear temp buffer for this render
    tempBuffer.clear(0, numSamples);

    int samplesRendered = 0;

    // Base pitch ratio from sample rate conversion and static tuning
    const double baseSampleRateRatio = sampleRate / currentSampleRate;
    const double secBaseSampleRateRatio = (secSampleRate > 0) ? (secSampleRate / currentSampleRate) : 0.0;

    // Check if pitch envelope is active (optimization: skip per-sample pow if not)
    const bool hasPitchEnv = std::abs(pitchEnvAmount) >= 0.001f;

    // Pre-calculate static pitch ratio when no pitch envelope
    const double staticPitchRatio = hasPitchEnv ? 0.0
        : std::pow(2.0, tune / 12.0) * baseSampleRateRatio;
    const double secStaticPitchRatio = hasPitchEnv ? 0.0
        : std::pow(2.0, tune / 12.0) * secBaseSampleRateRatio;

    // Determine base playback direction (for non-ping-pong modes)
    // Ping-pong uses pingPongForward which changes dynamically
    const bool baseForward = !reverse;

    // Pre-compute static position delta for non-ping-pong, no-pitch-envelope case
    // This avoids per-sample conditional computation in the most common scenario
    const double staticPositionDelta = hasPitchEnv ? 0.0
        : (baseForward ? staticPitchRatio : -staticPitchRatio);
    const double secStaticPositionDelta = (hasPitchEnv || !blendActive) ? 0.0
        : (baseForward ? secStaticPitchRatio : -secStaticPitchRatio);

    // Pre-compute interpolation offset for non-ping-pong modes (1 if forward, -1 if reverse)
    const int interpOffset = baseForward ? 1 : -1;

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

        if (JUCE_UNLIKELY(isPingPong))
        {
            // Ping-pong mode: direction can change, must compute per-sample
            movingForward = pingPongForward;
            if (JUCE_UNLIKELY(hasPitchEnv))
            {
                const float envValue = pitchEnvelope.getNextSample();
                const float totalPitch = tune + pitchEnvAmount * envValue;
                const float pitchMult = fastPow2(totalPitch / 12.0f);
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
        else if (JUCE_UNLIKELY(hasPitchEnv))
        {
            // Pitch envelope active: must compute pitch per-sample, but direction is constant
            movingForward = baseForward;
            const float envValue = pitchEnvelope.getNextSample();
            const float totalPitch = tune + pitchEnvAmount * envValue;
            const float pitchMult = fastPow2(totalPitch / 12.0f);
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

        if (JUCE_UNLIKELY(pastBoundary))
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

                    // Handle multiple bounces (for extreme pitch ratios)
                    // Max iterations guard prevents infinite loop from edge cases
                    for (int bounces = 0; bounces < 100 && overshoot >= 0; ++bounces)
                    {
                        pingPongForward = !pingPongForward;
                        if (overshoot < loopLength)
                        {
                            // Final bounce
                            playPosition = pingPongForward
                                ? (startBoundary + overshoot)
                                : (endBoundaryMinus1 - overshoot);
                            break;
                        }
                        overshoot -= loopLength;
                    }

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

            if (JUCE_UNLIKELY(secPastBoundary))
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

                        // Max iterations guard prevents infinite loop from edge cases
                        for (int bounces = 0; bounces < 100 && overshoot >= 0; ++bounces)
                        {
                            secondaryPingPongForward = !secondaryPingPongForward;
                            if (overshoot < secLoopLength)
                            {
                                secondaryPlayPosition = secondaryPingPongForward
                                    ? (secStartBoundary + overshoot)
                                    : (secEndBoundaryMinus1 - overshoot);
                                break;
                            }
                            overshoot -= secLoopLength;
                        }

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

        // Linear interpolation for pitch shifting (primary layer)
        const int pos0 = static_cast<int>(playPosition);

        // Debug assertion: playPosition should always be valid at this point
        jassert(pos0 >= 0 && pos0 <= sampleLastIndex);

        // Bounds check pos0 to prevent buffer overrun (defense-in-depth for release builds)
        if (JUCE_UNLIKELY(pos0 < 0 || pos0 > sampleLastIndex))
        {
            isPlaying = false;
            break;
        }

        // Calculate interpolation position (use pre-computed sampleLastIndex)
        // For non-ping-pong modes, use pre-computed interpOffset; for ping-pong, compute per-sample
        const int pos1 = juce::jlimit(0, sampleLastIndex,
            isPingPong ? (pos0 + (movingForward ? 1 : -1)) : (pos0 + interpOffset));
        const float frac = static_cast<float>(playPosition - static_cast<double>(pos0));

        // Combined gain with envelope
        const float gain = baseGain * envValue;

        // Sample primary layer
        float sampleL, sampleR;
        if (isMono)
        {
            const float s0 = srcL[pos0];
            const float s1 = srcL[pos1];
            sampleL = sampleR = (s0 + frac * (s1 - s0)) * normGain;
        }
        else
        {
            const float sL0 = srcL[pos0], sL1 = srcL[pos1];
            const float sR0 = srcR[pos0], sR1 = srcR[pos1];
            sampleL = (sL0 + frac * (sL1 - sL0)) * normGain;
            sampleR = (sR0 + frac * (sR1 - sR0)) * normGain;
        }

        // Blend with secondary layer (if active)
        if (blendActive)
        {
            const int secPos0 = static_cast<int>(secondaryPlayPosition);
            if (secPos0 >= 0 && secPos0 <= secSampleLastIndex)
            {
                const int secPos1 = juce::jlimit(0, secSampleLastIndex,
                    isPingPong ? (secPos0 + (secMovingForward ? 1 : -1)) : (secPos0 + interpOffset));
                const float secFrac = static_cast<float>(secondaryPlayPosition - static_cast<double>(secPos0));

                float secSampleL, secSampleR;
                if (secIsMono)
                {
                    const float s0 = secSrcL[secPos0];
                    const float s1 = secSrcL[secPos1];
                    secSampleL = secSampleR = (s0 + secFrac * (s1 - s0)) * secNormGain;
                }
                else
                {
                    const float sL0 = secSrcL[secPos0], sL1 = secSrcL[secPos1];
                    const float sR0 = secSrcR[secPos0], sR1 = secSrcR[secPos1];
                    secSampleL = (sL0 + secFrac * (sL1 - sL0)) * secNormGain;
                    secSampleR = (sR0 + secFrac * (sR1 - sR0)) * secNormGain;
                }

                // Blend primary and secondary
                sampleL = sampleL * primaryWeight + secSampleL * secondaryWeight;
                sampleR = sampleR * primaryWeight + secSampleR * secondaryWeight;
            }
        }

        // Apply gain and panning, write to output
        destL[sample] = sampleL * gain * panGainL;
        destR[sample] = sampleR * gain * panGainR;

        // Advance positions
        playPosition += positionDelta;
        if (blendActive)
            secondaryPlayPosition += secPositionDelta;

        ++samplesRendered;

        // Drift correction: every 4096 samples, re-anchor to nearest integer to prevent
        // cumulative floating-point precision errors during long playback (hours)
        // Uses fast floor+0.5 instead of std::round for better performance
        if ((samplesRendered & 0xFFF) == 0)  // Every 4096 samples (~93ms at 44.1kHz)
        {
            // Fast round: floor(x + 0.5) - works for positive values (playPosition is always >= 0)
            playPosition = static_cast<double>(static_cast<int64_t>(playPosition + 0.5));
            if (blendActive)
                secondaryPlayPosition = static_cast<double>(static_cast<int64_t>(secondaryPlayPosition + 0.5));
        }
    }

    // Apply filter (LP if cutoff < 20kHz, HP if cutoff > 20Hz, BP always)
    const bool applyFilter = (filterType == 0 && filterCutoff < FILTER_LP_BYPASS_THRESHOLD) ||
                             (filterType == 1 && filterCutoff > FILTER_HP_BYPASS_THRESHOLD) ||
                             (filterType == 2);  // Bandpass always applies

    if (samplesRendered > 0 && applyFilter)
    {
        // Only update filter params when changed (optimization)
        if (filterType != lastFilterType)
        {
            // Filter types: 0=LP, 1=HP, 2=BP (matching Parameters.h definition)
            switch (filterType)
            {
                case 0:  filter.setType(juce::dsp::StateVariableTPTFilterType::lowpass);  break;
                case 1:  filter.setType(juce::dsp::StateVariableTPTFilterType::highpass); break;
                case 2:  filter.setType(juce::dsp::StateVariableTPTFilterType::bandpass); break;
                default: filter.setType(juce::dsp::StateVariableTPTFilterType::lowpass);  break;  // Fallback to LP for invalid values
            }
            lastFilterType = filterType;
        }
        if (filterCutoff != lastFilterCutoff)
        {
            filter.setCutoffFrequency(filterCutoff);
            lastFilterCutoff = filterCutoff;
        }
        if (filterReso != lastFilterReso)
        {
            // Map 0-1 resonance to Q factor (0.707 Butterworth to 10 high-reso)
            float q = FILTER_Q_MIN + filterReso * (FILTER_Q_MAX - FILTER_Q_MIN);
            filter.setResonance(q);
            lastFilterReso = filterReso;
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

    // Stop playback unconditionally to prevent race conditions
    // (audio thread could switch layers mid-render)
    stop();

    auto& layer = layers[layerIndex];
    layer.buffer = std::move(buffer);
    layer.numSamples = layer.buffer.getNumSamples();
    layer.sourceSampleRate = sampleRate;
    layer.filePath = path;
    layer.normGain = inNormGain;
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

    // Stop playback unconditionally to prevent race conditions
    stop();

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
        // Stop playback unconditionally to prevent race conditions
        stop();
        layers[layerIndex].clear();
    }
}

void Pad::clearRoundRobin(int layerIndex)
{
    if (layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS)
    {
        // Stop playback unconditionally to prevent race conditions
        stop();

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
    static const juce::String emptyString;
    if (layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS)
        return layers[layerIndex].getRoundRobinPath(rrIndex);
    return emptyString;
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
    params.attack = attack / 1000.0f;   // ms to seconds
    params.decay = decay / 1000.0f;
    params.sustain = sustain;
    params.release = release / 1000.0f;
    envelope.setParameters(params);
}

void Pad::updatePitchEnvelopeParams()
{
    // Pitch envelope: attack → decay → sustain level
    // For 808-style kicks: attack=0, decay=50-200ms, sustain=0 (full sweep)
    juce::ADSR::Parameters params;
    params.attack = pitchEnvAttack / 1000.0f;   // ms to seconds
    params.decay = pitchEnvDecay / 1000.0f;
    params.sustain = pitchEnvSustain;           // 0 = full sweep to base pitch
    params.release = 0.001f;                    // Very short release (instant)
    pitchEnvelope.setParameters(params);
}

}  // namespace BlockSampler
