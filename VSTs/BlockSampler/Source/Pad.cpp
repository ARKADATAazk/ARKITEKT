// =============================================================================
// BlockSampler/Source/Pad.cpp
// Pad implementation - audio playback, sample loading, ADSR, filtering
// =============================================================================

#include "Pad.h"

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

void VelocityLayer::advanceRoundRobin(bool randomMode)
{
    const int count = static_cast<int>(roundRobinSamples.size());
    if (count == 0)
        return;

    if (randomMode && count > 1)
    {
        // Random selection (avoid repeating same sample)
        int newIndex;
        do {
            newIndex = juce::Random::getSystemRandom().nextInt(count);
        } while (newIndex == roundRobinIndex);
        roundRobinIndex = newIndex;
    }
    else
    {
        // Sequential cycling
        roundRobinIndex = (roundRobinIndex + 1) % count;
    }
}

void VelocityLayer::clear()
{
    buffer.setSize(0, 0);
    numSamples = 0;
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
    if (velocity == 0)
    {
        noteOff();
        return;
    }

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

    // Advance round-robin before getting sample info
    layer.advanceRoundRobin(roundRobinMode == 1);

    // Get current sample length (accounting for round-robin)
    int currentNumSamples = layer.getCurrentNumSamples();
    if (currentNumSamples <= 0)
        return;  // Empty or corrupted sample

    // Calculate actual start/end sample positions
    int startSample = static_cast<int>(sampleStart * currentNumSamples);
    int endSample = static_cast<int>(sampleEnd * currentNumSamples);

    // Clamp to valid range
    startSample = juce::jlimit(0, currentNumSamples - 1, startSample);
    endSample = juce::jlimit(startSample + 1, currentNumSamples, endSample);

    // Store for playback
    playStartSample = startSample;
    playEndSample = endSample;

    // Reset playback position
    playPosition = reverse ? (endSample - 1) : startSample;

    // Apply velocity curve
    float vel = velocity / 127.0f;
    switch (velocityCurve)
    {
        case 1: vel = vel * vel; break;              // Soft (logarithmic feel)
        case 2: vel = std::sqrt(vel); break;         // Hard (exponential feel)
        case 3: vel = vel > 0.5f ? 1.0f : 0.0f; break; // Switch (binary)
        default: break;                              // Linear (no change)
    }
    currentVelocity = vel;
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

void Pad::stop()
{
    isPlaying = false;
    envelope.reset();
}

// =============================================================================
// AUDIO PROCESSING
// =============================================================================

int Pad::renderNextBlock(int numSamples)
{
    if (!isPlaying || currentLayer < 0)
        return 0;

    // Safety check: ensure tempBuffer is prepared and clamp to its capacity
    // (some hosts may exceed the samplesPerBlock hint from prepareToPlay)
    const int bufferCapacity = tempBuffer.getNumSamples();
    if (bufferCapacity == 0)
        return 0;  // prepare() not called yet
    numSamples = juce::jmin(numSamples, bufferCapacity);

    auto& layer = layers[currentLayer];
    if (!layer.isLoaded())
        return 0;

    // Get current buffer (accounting for round-robin)
    const auto& sampleBuffer = layer.getCurrentBuffer();
    const int sampleNumSamples = layer.getCurrentNumSamples();
    const double sampleRate = layer.getCurrentSampleRate();
    const float normGain = normalize ? layer.getCurrentNormGain() : 1.0f;

    const int numChannels = juce::jmin(2, sampleBuffer.getNumChannels());
    if (numChannels == 0 || sampleNumSamples <= 0)
        return 0;  // Corrupted sample - no audio channels or no frames

    const bool isMono = (numChannels == 1);

    // Cache sample read pointers outside loop (optimization)
    const float* srcL = sampleBuffer.getReadPointer(0);
    const float* srcR = isMono ? srcL : sampleBuffer.getReadPointer(1);

    // Get write pointers for temp buffer
    float* destL = tempBuffer.getWritePointer(0);
    float* destR = tempBuffer.getWritePointer(1);

    // Calculate pitch ratio for tuning
    const double pitchRatio = std::pow(2.0, tune / 12.0) *
                              (sampleRate / currentSampleRate);

    // Pre-calculate pan gains (constant power panning)
    const float panAngle = (pan + 1.0f) * 0.25f * juce::MathConstants<float>::pi;
    const float panGainL = std::cos(panAngle);
    const float panGainR = std::sin(panAngle);

    // Pre-calculate base gain (volume * velocity * normalization)
    const float baseGain = volume * currentVelocity * normGain;

    // Clear temp buffer for this render
    tempBuffer.clear(0, numSamples);

    int samplesRendered = 0;

    // Direction-specific logic (may change in ping-pong mode)
    double positionDelta = reverse ? -pitchRatio : pitchRatio;

    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Check playback boundaries
        bool pastBoundary = reverse ? (playPosition < playStartSample) : (playPosition >= playEndSample);
        if (pastBoundary)
        {
            switch (loopMode)
            {
                case 0:  // One-shot: stop playback
                    isPlaying = false;
                    break;
                case 1:  // Loop: reset to start
                    playPosition = reverse ? (playEndSample - 1) : playStartSample;
                    break;
                case 2:  // Ping-pong: reverse direction and position delta
                    reverse = !reverse;
                    positionDelta = -positionDelta;
                    // Clamp position to valid range after direction change
                    playPosition = juce::jlimit(static_cast<double>(playStartSample),
                                                static_cast<double>(playEndSample - 1),
                                                playPosition);
                    break;
            }
            if (loopMode == 0)
                break;  // Exit sample loop
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

    // Apply filter (bypass LP at max cutoff, HP at min cutoff; BP/Notch always apply)
    bool applyFilter = false;
    switch (filterType)
    {
        case 0: applyFilter = (filterCutoff < FILTER_LP_BYPASS_THRESHOLD); break;  // LP
        case 1: applyFilter = (filterCutoff > FILTER_HP_BYPASS_THRESHOLD); break;  // HP
        case 2: applyFilter = true; break;  // BP - always apply
        case 3: applyFilter = true; break;  // Notch - always apply
    }

    if (samplesRendered > 0 && applyFilter)
    {
        // Only update filter params when changed (optimization)
        if (filterType != lastFilterType)
        {
            switch (filterType)
            {
                case 0: filter.setType(juce::dsp::StateVariableTPTFilterType::lowpass); break;
                case 1: filter.setType(juce::dsp::StateVariableTPTFilterType::highpass); break;
                case 2: filter.setType(juce::dsp::StateVariableTPTFilterType::bandpass); break;
                case 3: filter.setType(juce::dsp::StateVariableTPTFilterType::notch); break;
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
            filter.setResonance(filterReso);
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

// Compute gain to normalize buffer to peak = 1.0
static float computeNormGain(const juce::AudioBuffer<float>& buffer)
{
    float peak = 0.0f;
    for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        peak = juce::jmax(peak, buffer.getMagnitude(ch, 0, buffer.getNumSamples()));

    if (peak > NORM_PEAK_THRESHOLD)
        return 1.0f / peak;
    return 1.0f;
}

bool Pad::loadSample(int layerIndex,
                     const juce::File& file,
                     juce::AudioFormatManager& formatManager)
{
    if (layerIndex < 0 || layerIndex >= NUM_VELOCITY_LAYERS)
        return false;

    std::unique_ptr<juce::AudioFormatReader> reader(formatManager.createReaderFor(file));
    if (!reader)
        return false;

    // Stop playback to prevent race condition with audio thread
    stop();

    auto& layer = layers[layerIndex];
    layer.buffer.setSize(static_cast<int>(reader->numChannels),
                         static_cast<int>(reader->lengthInSamples));
    reader->read(&layer.buffer, 0, static_cast<int>(reader->lengthInSamples), 0, true, true);

    layer.numSamples = static_cast<int>(reader->lengthInSamples);
    layer.sourceSampleRate = reader->sampleRate;
    layer.filePath = file.getFullPathName();
    layer.normGain = computeNormGain(layer.buffer);

    return true;
}

bool Pad::addRoundRobinSample(int layerIndex,
                              const juce::File& file,
                              juce::AudioFormatManager& formatManager)
{
    if (layerIndex < 0 || layerIndex >= NUM_VELOCITY_LAYERS)
        return false;

    std::unique_ptr<juce::AudioFormatReader> reader(formatManager.createReaderFor(file));
    if (!reader)
        return false;

    // Stop playback to prevent race condition with audio thread
    // (push_back could reallocate vector while audio reads from it)
    stop();

    auto& layer = layers[layerIndex];

    RoundRobinSample sample;
    sample.buffer.setSize(static_cast<int>(reader->numChannels),
                          static_cast<int>(reader->lengthInSamples));
    reader->read(&sample.buffer, 0, static_cast<int>(reader->lengthInSamples), 0, true, true);
    sample.sampleRate = reader->sampleRate;
    sample.path = file.getFullPathName();
    sample.normGain = computeNormGain(sample.buffer);

    layer.roundRobinSamples.push_back(std::move(sample));
    return true;
}

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
        if (layer.isLoaded() && layer.sourceSampleRate > 0)
        {
            return static_cast<double>(layer.numSamples) / layer.sourceSampleRate;
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
