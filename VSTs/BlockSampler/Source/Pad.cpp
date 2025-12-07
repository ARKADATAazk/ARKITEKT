// =============================================================================
// BlockSampler/Source/Pad.cpp
// Pad implementation - audio playback, sample loading, ADSR, filtering
// =============================================================================

#include "Pad.h"
#include <limits>

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
        int newIndex;
        do {
            newIndex = rng.nextInt(count);
        } while (newIndex == roundRobinIndex);
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
        if (currentLayer < NUM_VELOCITY_LAYERS - 1)
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

            if (velocity < blendZoneEnd && layers[currentLayer - 1].isLoaded())
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
    union { float f; int32_t i; } u;
    u.i = (i + 127) << 23;  // Create 2^i as float

    return u.f * p;
}

int Pad::renderNextBlock(int numSamples)
{
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
            }
        }
    }

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

    // Loop boundaries as doubles (avoid repeated casts)
    const double startBoundary = static_cast<double>(playStartSample);
    const double endBoundary = static_cast<double>(playEndSample);
    const double endBoundaryMinus1 = static_cast<double>(playEndSample - 1);

    // Secondary layer boundaries (using normalized positions)
    double secStartBoundary = 0.0, secEndBoundary = 0.0, secEndBoundaryMinus1 = 0.0;
    if (hasBlend && secSrcL != nullptr)
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

    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Calculate pitch ratio (fast path for static pitch, slow path for envelope)
        double pitchRatio, secPitchRatio = 0.0;
        if (hasPitchEnv)
        {
            // Get pitch envelope modulation and compute pitch ratio
            const float envValue = pitchEnvelope.getNextSample();
            const float totalPitch = tune + pitchEnvAmount * envValue;
            const float pitchMult = fastPow2(totalPitch / 12.0f);
            pitchRatio = static_cast<double>(pitchMult) * baseSampleRateRatio;
            if (hasBlend && secSrcL != nullptr)
                secPitchRatio = static_cast<double>(pitchMult) * secBaseSampleRateRatio;
        }
        else
        {
            pitchRatio = staticPitchRatio;
            secPitchRatio = secStaticPitchRatio;
        }

        // Determine playback direction (accounting for reverse and ping-pong)
        const bool movingForward = (loopMode == LoopMode::PingPong) ? pingPongForward : baseForward;
        const double positionDelta = movingForward ? pitchRatio : -pitchRatio;

        const bool secMovingForward = (loopMode == LoopMode::PingPong) ? secondaryPingPongForward : baseForward;
        const double secPositionDelta = secMovingForward ? secPitchRatio : -secPitchRatio;

        // Check playback boundaries (primary layer)
        const bool pastBoundary = movingForward
            ? (playPosition >= endBoundary)
            : (playPosition < startBoundary);

        if (pastBoundary)
        {
            switch (loopMode)
            {
                case LoopMode::OneShot:
                    isPlaying = false;
                    break;

                case LoopMode::Loop:
                    // Simple loop: jump back to start
                    playPosition = movingForward ? startBoundary : endBoundaryMinus1;
                    break;

                case LoopMode::PingPong:
                {
                    // Handle potentially multiple bounces for high pitch ratios
                    const double loopLength = endBoundary - startBoundary;
                    if (loopLength <= 0)
                    {
                        isPlaying = false;
                        break;
                    }

                    // Calculate overshoot
                    double overshoot = movingForward
                        ? (playPosition - endBoundary)
                        : (startBoundary - playPosition);

                    // Handle multiple bounces (for extreme pitch ratios)
                    while (overshoot >= 0)
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
                    break;
                }
            }

            if (!isPlaying)
                break;
        }

        // Handle secondary layer boundaries (if blending)
        if (hasBlend && secSrcL != nullptr)
        {
            const bool secPastBoundary = secMovingForward
                ? (secondaryPlayPosition >= secEndBoundary)
                : (secondaryPlayPosition < secStartBoundary);

            if (secPastBoundary)
            {
                switch (loopMode)
                {
                    case LoopMode::OneShot:
                        // Secondary stops but primary continues
                        break;

                    case LoopMode::Loop:
                        secondaryPlayPosition = secMovingForward ? secStartBoundary : secEndBoundaryMinus1;
                        break;

                    case LoopMode::PingPong:
                    {
                        const double secLoopLength = secEndBoundary - secStartBoundary;
                        if (secLoopLength > 0)
                        {
                            double overshoot = secMovingForward
                                ? (secondaryPlayPosition - secEndBoundary)
                                : (secStartBoundary - secondaryPlayPosition);

                            while (overshoot >= 0)
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
                        break;
                    }
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

        // Bounds check pos0 to prevent buffer overrun
        if (pos0 < 0 || pos0 >= sampleNumSamples)
        {
            isPlaying = false;
            break;
        }

        const int pos1 = juce::jlimit(0, sampleNumSamples - 1, movingForward ? (pos0 + 1) : (pos0 - 1));
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
        if (hasBlend && secSrcL != nullptr)
        {
            const int secPos0 = static_cast<int>(secondaryPlayPosition);
            if (secPos0 >= 0 && secPos0 < secNumSamples)
            {
                const int secPos1 = juce::jlimit(0, secNumSamples - 1, secMovingForward ? (secPos0 + 1) : (secPos0 - 1));
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
        if (hasBlend && secSrcL != nullptr)
            secondaryPlayPosition += secPositionDelta;

        ++samplesRendered;
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
            switch (filterType)
            {
                case 0:  filter.setType(juce::dsp::StateVariableTPTFilterType::lowpass);  break;
                case 1:  filter.setType(juce::dsp::StateVariableTPTFilterType::highpass); break;
                default: filter.setType(juce::dsp::StateVariableTPTFilterType::bandpass); break;
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
