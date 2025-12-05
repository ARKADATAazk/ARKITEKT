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
    return numSamples > 0 || !roundRobinBuffers.empty();
}

int VelocityLayer::getRoundRobinCount() const
{
    return static_cast<int>(roundRobinBuffers.size());
}

const juce::AudioBuffer<float>& VelocityLayer::getCurrentBuffer() const
{
    if (roundRobinBuffers.empty())
        return buffer;
    return roundRobinBuffers[roundRobinIndex % roundRobinBuffers.size()];
}

int VelocityLayer::getCurrentNumSamples() const
{
    if (roundRobinBuffers.empty())
        return numSamples;
    return static_cast<int>(getCurrentBuffer().getNumSamples());
}

double VelocityLayer::getCurrentSampleRate() const
{
    if (roundRobinBuffers.empty() || roundRobinSampleRates.empty())
        return sourceSampleRate;
    return roundRobinSampleRates[roundRobinIndex % roundRobinSampleRates.size()];
}

float VelocityLayer::getCurrentNormGain() const
{
    if (roundRobinBuffers.empty() || roundRobinNormGains.empty())
        return normGain;
    return roundRobinNormGains[roundRobinIndex % roundRobinNormGains.size()];
}

void VelocityLayer::advanceRoundRobin(bool randomMode)
{
    if (!roundRobinBuffers.empty())
    {
        if (randomMode)
        {
            // Random selection (avoid repeating same sample if possible)
            int count = static_cast<int>(roundRobinBuffers.size());
            if (count > 1)
            {
                int newIndex;
                do {
                    newIndex = juce::Random::getSystemRandom().nextInt(count);
                } while (newIndex == roundRobinIndex);
                roundRobinIndex = newIndex;
            }
        }
        else
        {
            // Sequential cycling
            roundRobinIndex = (roundRobinIndex + 1) % static_cast<int>(roundRobinBuffers.size());
        }
    }
}

void VelocityLayer::clear()
{
    buffer.setSize(0, 0);
    numSamples = 0;
    filePath.clear();
    normGain = 1.0f;
    roundRobinBuffers.clear();
    roundRobinSampleRates.clear();
    roundRobinPaths.clear();
    roundRobinNormGains.clear();
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
    currentVelocity = velocity / 127.0f;
    isPlaying = true;

    // Reset and trigger envelope
    updateEnvelopeParams();
    envelope.reset();
    envelope.noteOn();
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

    auto& layer = layers[currentLayer];
    if (!layer.isLoaded())
        return 0;

    // Get current buffer (accounting for round-robin)
    const auto& sampleBuffer = layer.getCurrentBuffer();
    const int sampleNumSamples = layer.getCurrentNumSamples();
    const double sampleRate = layer.getCurrentSampleRate();
    const float normGain = normalize ? layer.getCurrentNormGain() : 1.0f;

    const int numChannels = juce::jmin(2, sampleBuffer.getNumChannels());

    // Calculate pitch ratio for tuning
    const double pitchRatio = std::pow(2.0, tune / 12.0) *
                              (sampleRate / currentSampleRate);

    // Clear temp buffer for this render
    tempBuffer.clear(0, numSamples);

    int samplesRendered = 0;

    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Check playback boundaries
        if (reverse)
        {
            if (playPosition < playStartSample)
            {
                if (oneShot)
                {
                    isPlaying = false;
                    break;
                }
                playPosition = playEndSample - 1;  // Loop back to end
            }
        }
        else
        {
            if (playPosition >= playEndSample)
            {
                if (oneShot)
                {
                    isPlaying = false;
                    break;
                }
                playPosition = playStartSample;  // Loop back to start
            }
        }

        // Get envelope value
        float envValue = envelope.getNextSample();
        if (!envelope.isActive())
        {
            isPlaying = false;
            break;
        }

        // Linear interpolation for pitch shifting
        int pos0 = static_cast<int>(playPosition);
        int pos1 = reverse ? (pos0 - 1) : (pos0 + 1);
        pos1 = juce::jlimit(0, sampleNumSamples - 1, pos1);
        float frac = static_cast<float>(playPosition - pos0);

        // Apply volume, velocity, envelope, normalization
        float gain = volume * currentVelocity * envValue * normGain;

        for (int ch = 0; ch < numChannels; ++ch)
        {
            const float* src = sampleBuffer.getReadPointer(ch);
            float s0 = src[pos0];
            float s1 = src[pos1];
            float interpolated = s0 + frac * (s1 - s0);

            // Apply pan (constant power)
            float panGain = 1.0f;
            if (ch == 0)  // Left
                panGain = std::cos((pan + 1.0f) * 0.25f * juce::MathConstants<float>::pi);
            else  // Right
                panGain = std::sin((pan + 1.0f) * 0.25f * juce::MathConstants<float>::pi);

            tempBuffer.addSample(ch, sample, interpolated * gain * panGain);
        }

        // Advance position
        if (reverse)
            playPosition -= pitchRatio;
        else
            playPosition += pitchRatio;

        ++samplesRendered;
    }

    // Apply filter (LP if cutoff < 20kHz, HP if cutoff > 20Hz)
    bool applyFilter = (filterType == 0 && filterCutoff < 19999.0f) ||
                       (filterType == 1 && filterCutoff > 21.0f);

    if (samplesRendered > 0 && applyFilter)
    {
        filter.setType(filterType == 0
            ? juce::dsp::StateVariableTPTFilterType::lowpass
            : juce::dsp::StateVariableTPTFilterType::highpass);
        filter.setCutoffFrequency(filterCutoff);
        filter.setResonance(filterReso);

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

    if (peak > 0.0001f)
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

    auto& layer = layers[layerIndex];

    juce::AudioBuffer<float> newBuffer;
    newBuffer.setSize(static_cast<int>(reader->numChannels),
                      static_cast<int>(reader->lengthInSamples));
    reader->read(&newBuffer, 0, static_cast<int>(reader->lengthInSamples), 0, true, true);

    float gain = computeNormGain(newBuffer);

    layer.roundRobinBuffers.push_back(std::move(newBuffer));
    layer.roundRobinSampleRates.push_back(reader->sampleRate);
    layer.roundRobinPaths.push_back(file.getFullPathName());
    layer.roundRobinNormGains.push_back(gain);

    return true;
}

void Pad::setSampleBuffer(int layerIndex,
                          juce::AudioBuffer<float>&& buffer,
                          double sampleRate,
                          const juce::String& path,
                          float normGain)
{
    if (layerIndex < 0 || layerIndex >= NUM_VELOCITY_LAYERS)
        return;

    auto& layer = layers[layerIndex];
    layer.buffer = std::move(buffer);
    layer.numSamples = layer.buffer.getNumSamples();
    layer.sourceSampleRate = sampleRate;
    layer.filePath = path;
    layer.normGain = normGain;
}

void Pad::addRoundRobinBuffer(int layerIndex,
                              juce::AudioBuffer<float>&& buffer,
                              double sampleRate,
                              const juce::String& path,
                              float normGain)
{
    if (layerIndex < 0 || layerIndex >= NUM_VELOCITY_LAYERS)
        return;

    auto& layer = layers[layerIndex];
    layer.roundRobinBuffers.push_back(std::move(buffer));
    layer.roundRobinSampleRates.push_back(sampleRate);
    layer.roundRobinPaths.push_back(path);
    layer.roundRobinNormGains.push_back(normGain);
}

void Pad::clearSample(int layerIndex)
{
    if (layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS)
        layers[layerIndex].clear();
}

void Pad::clearRoundRobin(int layerIndex)
{
    if (layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS)
    {
        layers[layerIndex].roundRobinBuffers.clear();
        layers[layerIndex].roundRobinSampleRates.clear();
        layers[layerIndex].roundRobinPaths.clear();
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

// =============================================================================
// PRIVATE HELPERS
// =============================================================================

int Pad::selectVelocityLayer(int velocity)
{
    // Velocity thresholds: 0-31, 32-63, 64-95, 96-127
    // Returns highest loaded layer that matches velocity
    if (velocity >= 96 && layers[3].isLoaded()) return 3;
    if (velocity >= 64 && layers[2].isLoaded()) return 2;
    if (velocity >= 32 && layers[1].isLoaded()) return 1;
    if (layers[0].isLoaded()) return 0;
    return -1;
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
