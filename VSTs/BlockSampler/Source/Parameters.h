#pragma once

#include <juce_audio_processors/juce_audio_processors.h>

namespace BlockSampler
{

constexpr int NUM_PADS = 16;
constexpr int NUM_VELOCITY_LAYERS = 4;
constexpr int MIDI_NOTE_OFFSET = 36;  // C1 = Pad 0

// Parameter indices per pad
namespace PadParam
{
    enum ID
    {
        Volume = 0,
        Pan,
        Tune,
        Attack,
        Decay,
        Sustain,
        Release,
        FilterCutoff,
        FilterReso,
        KillGroup,
        OneShot,      // 0 = obey note-off, 1 = one-shot
        Reverse,      // 0 = forward, 1 = reverse
        COUNT
    };

    inline int index(int pad, ID param)
    {
        return pad * COUNT + static_cast<int>(param);
    }

    inline juce::String id(int pad, ID param)
    {
        static const char* names[] = {
            "volume", "pan", "tune", "attack", "decay", "sustain",
            "release", "cutoff", "reso", "killgroup", "oneshot", "reverse"
        };
        return "p" + juce::String(pad) + "_" + names[param];
    }
}

// Create all parameters for AudioProcessorValueTreeState
inline juce::AudioProcessorValueTreeState::ParameterLayout createParameterLayout()
{
    std::vector<std::unique_ptr<juce::RangedAudioParameter>> params;

    for (int pad = 0; pad < NUM_PADS; ++pad)
    {
        auto prefix = "Pad " + juce::String(pad + 1) + " ";

        // Volume (0-1)
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::Volume), 1 },
            prefix + "Volume",
            0.0f, 1.0f, 0.8f));

        // Pan (-1 to +1)
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::Pan), 1 },
            prefix + "Pan",
            -1.0f, 1.0f, 0.0f));

        // Tune (-24 to +24 semitones)
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::Tune), 1 },
            prefix + "Tune",
            -24.0f, 24.0f, 0.0f));

        // Attack (0-2000ms)
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::Attack), 1 },
            prefix + "Attack",
            juce::NormalisableRange<float>(0.0f, 2000.0f, 1.0f, 0.3f),
            0.0f, "ms"));

        // Decay (0-2000ms)
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::Decay), 1 },
            prefix + "Decay",
            juce::NormalisableRange<float>(0.0f, 2000.0f, 1.0f, 0.3f),
            100.0f, "ms"));

        // Sustain (0-1)
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::Sustain), 1 },
            prefix + "Sustain",
            0.0f, 1.0f, 1.0f));

        // Release (0-5000ms)
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::Release), 1 },
            prefix + "Release",
            juce::NormalisableRange<float>(0.0f, 5000.0f, 1.0f, 0.3f),
            200.0f, "ms"));

        // Filter Cutoff (20-20000 Hz, log scale)
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::FilterCutoff), 1 },
            prefix + "Cutoff",
            juce::NormalisableRange<float>(20.0f, 20000.0f, 1.0f, 0.25f),
            20000.0f, "Hz"));

        // Filter Resonance (0-1)
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::FilterReso), 1 },
            prefix + "Resonance",
            0.0f, 1.0f, 0.0f));

        // Kill Group (0-8, 0 = none)
        params.push_back(std::make_unique<juce::AudioParameterInt>(
            juce::ParameterID { PadParam::id(pad, PadParam::KillGroup), 1 },
            prefix + "Kill Group",
            0, 8, 0));

        // One-Shot mode
        params.push_back(std::make_unique<juce::AudioParameterBool>(
            juce::ParameterID { PadParam::id(pad, PadParam::OneShot), 1 },
            prefix + "One-Shot",
            true));  // Default: one-shot for drums

        // Reverse
        params.push_back(std::make_unique<juce::AudioParameterBool>(
            juce::ParameterID { PadParam::id(pad, PadParam::Reverse), 1 },
            prefix + "Reverse",
            false));
    }

    return { params.begin(), params.end() };
}

}  // namespace BlockSampler
