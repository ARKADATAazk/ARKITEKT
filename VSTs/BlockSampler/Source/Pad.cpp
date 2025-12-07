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
    return numSamples > 0 || roundRobinCount > 0;
}

int VelocityLayer::getRoundRobinCount() const
{
    return roundRobinCount;
}

const juce::AudioBuffer<float>& VelocityLayer::getCurrentBuffer() const
{
    if (roundRobinCount == 0)
        return buffer;
    jassert(roundRobinIndex >= 0 && roundRobinIndex < roundRobinCount);
    return roundRobinSamples[static_cast<size_t>(roundRobinIndex)].buffer;
}

int VelocityLayer::getCurrentNumSamples() const
{
    if (roundRobinCount == 0)
        return numSamples;
    return getCurrentBuffer().getNumSamples();
}

double VelocityLayer::getCurrentSampleRate() const
{
    if (roundRobinCount == 0)
        return sourceSampleRate;
    jassert(roundRobinIndex >= 0 && roundRobinIndex < roundRobinCount);
    return roundRobinSamples[static_cast<size_t>(roundRobinIndex)].sampleRate;
}

float VelocityLayer::getCurrentNormGain() const
{
    if (roundRobinCount == 0)
        return normGain;
    jassert(roundRobinIndex >= 0 && roundRobinIndex < roundRobinCount);
    return roundRobinSamples[static_cast<size_t>(roundRobinIndex)].normGain;
}

void VelocityLayer::advanceRoundRobin(juce::Random& rng, bool randomMode)
{
    if (roundRobinCount == 0)
        return;

    if (randomMode && roundRobinCount > 1)
    {
        // Random selection using offset to guarantee different sample (no infinite loop)
        // Pick random offset 1..(count-1), add to current index
        int offset = 1 + rng.nextInt(roundRobinCount - 1);
        roundRobinIndex = (roundRobinIndex + offset) % roundRobinCount;
    }
    else
    {
        // Sequential cycling
        roundRobinIndex = (roundRobinIndex + 1) % roundRobinCount;
    }
}

std::vector<juce::String> VelocityLayer::getRoundRobinPaths() const
{
    std::vector<juce::String> paths;
    paths.reserve(static_cast<size_t>(roundRobinCount));
    for (int i = 0; i < roundRobinCount; ++i)
        paths.push_back(roundRobinSamples[static_cast<size_t>(i)].path);
    return paths;
}

void VelocityLayer::clear()
{
    buffer.setSize(0, 0);
    numSamples = 0;
    sourceSampleRate = 44100.0;  // Reset to default
    filePath.clear();
    normGain = 1.0f;
    // Clear round-robin slots
    for (int i = 0; i < roundRobinCount; ++i)
    {
        roundRobinSamples[static_cast<size_t>(i)].buffer.setSize(0, 0);
        roundRobinSamples[static_cast<size_t>(i)].path.clear();
        roundRobinSamples[static_cast<size_t>(i)].isLoaded = false;
    }
    roundRobinCount = 0;
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

    // Select velocity layer
    currentLayer = selectVelocityLayer(velocity);
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

    auto& layer = layers[currentLayer];

    // Advance round-robin before getting sample info (uses per-pad RNG for thread safety)
    layer.advanceRoundRobin(rng, roundRobinMode == 1);

    // Get current sample length (accounting for round-robin)
    int currentNumSamples = layer.getCurrentNumSamples();
    if (currentNumSamples <= 0)
        return;  // Empty or corrupted sample

    // Calculate actual start/end sample positions using double precision
    // to avoid truncation errors with large sample counts (>2^24 frames)
    double effectiveStart = static_cast<double>(sampleStart);
    double effectiveEnd = static_cast<double>(sampleEnd);

    // Swap if start > end (user set them backwards)
    if (effectiveStart > effectiveEnd)
        std::swap(effectiveStart, effectiveEnd);

    // Use double for intermediate calculation to preserve precision
    const double numSamplesD = static_cast<double>(currentNumSamples);
    int startSample = static_cast<int>(std::floor(effectiveStart * numSamplesD));
    int endSample = static_cast<int>(std::ceil(effectiveEnd * numSamplesD));

    // Clamp to valid range and ensure at least 1 sample of playback
    startSample = juce::jlimit(0, currentNumSamples - 1, startSample);
    endSample = juce::jlimit(startSample + 1, currentNumSamples, endSample);

    // Store for playback
    playStartSample = startSample;
    playEndSample = endSample;

    // Reset playback position
    playPosition = reverse ? (endSample - 1) : startSample;
    currentVelocity = velocity / 127.0f;
    isPlaying = true;

    // Reset envelope and trigger
    updateEnvelopeParams();
    envelope.reset();
    envelope.noteOn();

    // Reset filter DSP state to prevent artifacts from previous note
    filter.reset();
    lastFilterCutoff = -1.0f;
    lastFilterReso = -1.0f;
    lastFilterType = -1;
}

void Pad::noteOff()
{
    if (!oneShot)
    {
        envelope.noteOff();
    }
}

void Pad::forceRelease()
{
    // Trigger release phase regardless of oneShot mode
    // Allows graceful fade-out of long one-shot samples
    if (isPlaying)
    {
        envelope.noteOff();
    }
}

void Pad::stop()
{
    isPlaying = false;
    envelope.reset();
}

// =============================================================================
// AUDIO PROCESSING
// =============================================================================

void Pad::updateCachedParams()
{
    // Update cached pitch ratio when tune or source sample rate changes
    // This avoids expensive std::pow() call every render block
    auto& layer = layers[currentLayer.load()];
    const double sampleRate = layer.getCurrentSampleRate();

    if (tune != lastTune || sampleRate != cachedSourceSampleRate)
    {
        cachedPitchRatio = std::pow(2.0, static_cast<double>(tune) / 12.0);
        cachedSourceSampleRate = sampleRate;
        lastTune = tune;
    }

    // Update cached pan gains when pan changes
    // This avoids expensive sin/cos calls every render block
    if (pan != lastPan)
    {
        const float panAngle = (pan + 1.0f) * 0.25f * juce::MathConstants<float>::pi;
        cachedPanGainL = std::cos(panAngle);
        cachedPanGainR = std::sin(panAngle);
        lastPan = pan;
    }
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
    const float normGainValue = normalize ? layer.getCurrentNormGain() : 1.0f;

    const int numChannels = juce::jmin(2, sampleBuffer.getNumChannels());
    // Validate sample data: need channels, frames, and valid sample rates
    if (numChannels == 0 || sampleNumSamples <= 0 || sampleRate <= 0 || currentSampleRate <= 0)
        return 0;

    const bool isMono = (numChannels == 1);

    // Cache sample read pointers outside loop (optimization)
    const float* srcL = sampleBuffer.getReadPointer(0);
    const float* srcR = isMono ? srcL : sampleBuffer.getReadPointer(1);

    // Get write pointers for temp buffer
    float* destL = tempBuffer.getWritePointer(0);
    float* destR = tempBuffer.getWritePointer(1);

    // Update cached pitch/pan values if params changed (avoids pow/sin/cos per block)
    updateCachedParams();

    // Calculate final pitch ratio including sample rate conversion
    const double pitchRatio = cachedPitchRatio * (sampleRate / currentSampleRate);

    // Use cached pan gains
    const float panGainL = cachedPanGainL;
    const float panGainR = cachedPanGainR;

    // Pre-calculate base gain (volume * velocity * normalization)
    const float baseGain = volume * currentVelocity * normGainValue;

    // Clear temp buffer for this render
    tempBuffer.clear(0, numSamples);

    int samplesRendered = 0;

    // Hoist direction-specific logic outside main loop
    const double positionDelta = reverse ? -pitchRatio : pitchRatio;
    const int boundaryCheck = reverse ? playStartSample : playEndSample;

    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Check playback boundaries (direction-agnostic comparison)
        bool pastBoundary = reverse ? (playPosition < boundaryCheck) : (playPosition >= boundaryCheck);
        if (pastBoundary)
        {
            if (oneShot)
            {
                isPlaying = false;
                break;
            }
            playPosition = reverse ? (playEndSample - 1) : playStartSample;
        }

        // Get envelope value
        const float envValue = envelope.getNextSample();
        if (!envelope.isActive())
        {
            isPlaying = false;
            break;
        }

        // Linear interpolation for pitch shifting
        const int pos0 = static_cast<int>(playPosition);

        // Bounds check pos0 to prevent buffer overrun
        if (pos0 < 0 || pos0 >= sampleNumSamples)
        {
            isPlaying = false;
            break;
        }

        const int pos1 = juce::jlimit(0, sampleNumSamples - 1, reverse ? (pos0 - 1) : (pos0 + 1));
        const float frac = static_cast<float>(std::fabs(playPosition - pos0));

        // Combined gain with envelope
        const float gain = baseGain * envValue;

        // Interpolate and write samples (mono path optimized)
        if (isMono)
        {
            const float s0 = srcL[pos0];
            const float s1 = srcL[pos1];
            const float monoSample = (s0 + frac * (s1 - s0)) * gain;
            destL[sample] = monoSample * panGainL;
            destR[sample] = monoSample * panGainR;
        }
        else
        {
            // Stereo: process both channels inline (avoid loop overhead)
            const float sL0 = srcL[pos0], sL1 = srcL[pos1];
            const float sR0 = srcR[pos0], sR1 = srcR[pos1];
            destL[sample] = (sL0 + frac * (sL1 - sL0)) * gain * panGainL;
            destR[sample] = (sR0 + frac * (sR1 - sR0)) * gain * panGainR;
        }

        // Advance position
        playPosition += positionDelta;
        ++samplesRendered;
    }

    // Apply filter (LP if cutoff < 20kHz, HP if cutoff > 20Hz)
    const bool applyFilter = (filterType == 0 && filterCutoff < FILTER_LP_BYPASS_THRESHOLD) ||
                             (filterType == 1 && filterCutoff > FILTER_HP_BYPASS_THRESHOLD);

    if (samplesRendered > 0 && applyFilter)
    {
        // Only update filter params when changed (optimization)
        if (filterType != lastFilterType)
        {
            filter.setType(filterType == 0
                ? juce::dsp::StateVariableTPTFilterType::lowpass
                : juce::dsp::StateVariableTPTFilterType::highpass);
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

    auto& layer = layers[layerIndex];

    // Enforce fixed array capacity limit (no allocations on audio thread)
    if (layer.roundRobinCount >= MAX_ROUND_ROBIN_SAMPLES)
    {
        DBG("BlockSampler: Round-robin capacity exceeded for layer " << layerIndex);
        return;
    }

    // Stop playback unconditionally to prevent race conditions
    stop();

    // Use next available slot in fixed array
    const int slotIndex = layer.roundRobinCount;
    auto& slot = layer.roundRobinSamples[static_cast<size_t>(slotIndex)];
    slot.buffer = std::move(buffer);
    slot.sampleRate = sampleRate;
    slot.path = path;
    slot.normGain = inNormGain;
    slot.isLoaded = true;

    layer.roundRobinCount++;
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

        auto& layer = layers[layerIndex];
        // Clear all loaded round-robin slots
        for (int i = 0; i < layer.roundRobinCount; ++i)
        {
            auto& slot = layer.roundRobinSamples[static_cast<size_t>(i)];
            slot.buffer.setSize(0, 0);
            slot.path.clear();
            slot.isLoaded = false;
        }
        layer.roundRobinCount = 0;
        layer.roundRobinIndex = 0;
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

}  // namespace BlockSampler
