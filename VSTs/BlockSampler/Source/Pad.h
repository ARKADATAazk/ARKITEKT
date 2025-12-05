#pragma once

#include <juce_audio_basics/juce_audio_basics.h>
#include <juce_audio_formats/juce_audio_formats.h>
#include <juce_dsp/juce_dsp.h>
#include "Parameters.h"

namespace BlockSampler
{

struct VelocityLayer
{
    juce::AudioBuffer<float> buffer;
    int numSamples = 0;
    double sourceSampleRate = 44100.0;
    juce::String filePath;

    // Round-robin support
    std::vector<juce::AudioBuffer<float>> roundRobinBuffers;
    int roundRobinIndex = 0;

    bool isLoaded() const { return numSamples > 0; }

    void clear()
    {
        buffer.setSize(0, 0);
        numSamples = 0;
        filePath.clear();
        roundRobinBuffers.clear();
        roundRobinIndex = 0;
    }
};

class Pad
{
public:
    Pad() = default;

    void prepare(double sampleRate, int samplesPerBlock)
    {
        currentSampleRate = sampleRate;

        envelope.setSampleRate(sampleRate);
        updateEnvelopeParams();

        // Prepare filter
        juce::dsp::ProcessSpec spec;
        spec.sampleRate = sampleRate;
        spec.maximumBlockSize = static_cast<juce::uint32>(samplesPerBlock);
        spec.numChannels = 2;
        filter.prepare(spec);
        filter.setType(juce::dsp::StateVariableTPTFilterType::lowpass);
    }

    void trigger(int velocity)
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

        // Reset playback position
        playPosition = reverse ? (layers[currentLayer].numSamples - 1) : 0;
        currentVelocity = velocity / 127.0f;
        isPlaying = true;

        // Reset and trigger envelope
        updateEnvelopeParams();
        envelope.reset();
        envelope.noteOn();
    }

    void noteOff()
    {
        if (!oneShot)
        {
            envelope.noteOff();
        }
    }

    void stop()
    {
        isPlaying = false;
        envelope.reset();
    }

    void renderNextBlock(juce::AudioBuffer<float>& outputBuffer, int startSample, int numSamples)
    {
        if (!isPlaying || currentLayer < 0)
            return;

        auto& layer = layers[currentLayer];
        if (!layer.isLoaded())
            return;

        const int numChannels = juce::jmin(outputBuffer.getNumChannels(), layer.buffer.getNumChannels());

        // Calculate pitch ratio
        const double pitchRatio = std::pow(2.0, tune / 12.0) * (layer.sourceSampleRate / currentSampleRate);

        for (int sample = 0; sample < numSamples; ++sample)
        {
            // Check if we've reached the end
            if (reverse)
            {
                if (playPosition < 0)
                {
                    if (oneShot)
                    {
                        isPlaying = false;
                        return;
                    }
                    playPosition = layer.numSamples - 1;
                }
            }
            else
            {
                if (playPosition >= layer.numSamples)
                {
                    if (oneShot)
                    {
                        isPlaying = false;
                        return;
                    }
                    playPosition = 0;
                }
            }

            // Get envelope value
            float envValue = envelope.getNextSample();
            if (!envelope.isActive())
            {
                isPlaying = false;
                return;
            }

            // Linear interpolation for pitch shifting
            int pos0 = static_cast<int>(playPosition);
            int pos1 = reverse ? (pos0 - 1) : (pos0 + 1);
            pos1 = juce::jlimit(0, layer.numSamples - 1, pos1);
            float frac = static_cast<float>(playPosition - pos0);

            // Apply volume, velocity, envelope
            float gain = volume * currentVelocity * envValue;

            for (int ch = 0; ch < numChannels; ++ch)
            {
                const float* src = layer.buffer.getReadPointer(ch);
                float s0 = src[pos0];
                float s1 = src[pos1];
                float interpolated = s0 + frac * (s1 - s0);

                // Apply pan (simple constant power)
                float panGain = 1.0f;
                if (ch == 0)  // Left
                    panGain = std::cos((pan + 1.0f) * 0.25f * juce::MathConstants<float>::pi);
                else  // Right
                    panGain = std::sin((pan + 1.0f) * 0.25f * juce::MathConstants<float>::pi);

                outputBuffer.addSample(ch, startSample + sample, interpolated * gain * panGain);
            }

            // Advance position
            if (reverse)
                playPosition -= pitchRatio;
            else
                playPosition += pitchRatio;
        }

        // Apply filter to this pad's output
        if (filterCutoff < 19999.0f)  // Only filter if not wide open
        {
            filter.setCutoffFrequency(filterCutoff);
            filter.setResonance(filterReso);

            juce::dsp::AudioBlock<float> block(outputBuffer);
            auto subBlock = block.getSubBlock(static_cast<size_t>(startSample), static_cast<size_t>(numSamples));
            juce::dsp::ProcessContextReplacing<float> context(subBlock);
            filter.process(context);
        }
    }

    bool loadSample(int layerIndex, const juce::File& file, juce::AudioFormatManager& formatManager)
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

        return true;
    }

    void clearSample(int layerIndex)
    {
        if (layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS)
            layers[layerIndex].clear();
    }

    juce::String getSamplePath(int layerIndex) const
    {
        if (layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS)
            return layers[layerIndex].filePath;
        return {};
    }

    bool hasSample(int layerIndex) const
    {
        if (layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS)
            return layers[layerIndex].isLoaded();
        return false;
    }

    // Parameters (set from PluginProcessor)
    float volume = 0.8f;
    float pan = 0.0f;
    float tune = 0.0f;  // semitones
    float attack = 0.0f;
    float decay = 100.0f;
    float sustain = 1.0f;
    float release = 200.0f;
    float filterCutoff = 20000.0f;
    float filterReso = 0.0f;
    int killGroup = 0;
    int outputGroup = 0;  // 0 = main only, 1-16 = route to group bus
    bool oneShot = true;
    bool reverse = false;

    // State
    bool isPlaying = false;
    int currentLayer = -1;

private:
    int selectVelocityLayer(int velocity)
    {
        // Default thresholds: 0-31, 32-63, 64-95, 96-127
        // But use highest loaded layer that matches
        if (velocity >= 96 && layers[3].isLoaded()) return 3;
        if (velocity >= 64 && layers[2].isLoaded()) return 2;
        if (velocity >= 32 && layers[1].isLoaded()) return 1;
        if (layers[0].isLoaded()) return 0;
        return -1;
    }

    void updateEnvelopeParams()
    {
        juce::ADSR::Parameters params;
        params.attack = attack / 1000.0f;   // ms to seconds
        params.decay = decay / 1000.0f;
        params.sustain = sustain;
        params.release = release / 1000.0f;
        envelope.setParameters(params);
    }

    std::array<VelocityLayer, NUM_VELOCITY_LAYERS> layers;
    juce::ADSR envelope;
    juce::dsp::StateVariableTPTFilter<float> filter;

    double currentSampleRate = 44100.0;
    double playPosition = 0.0;
    float currentVelocity = 1.0f;
};

}  // namespace BlockSampler
