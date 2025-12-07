// =============================================================================
// BlockSampler/Source/Parameters.h
// Parameter definitions and layout for 128 pads × 18 params = 2304 total
// =============================================================================

#pragma once

#include <juce_audio_processors/juce_audio_processors.h>

namespace BlockSampler
{

// =============================================================================
// CONSTANTS
// =============================================================================

// Pad configuration
constexpr int NUM_PADS = 128;
constexpr int NUM_VELOCITY_LAYERS = 4;
constexpr int NUM_OUTPUT_GROUPS = 16;
constexpr int NUM_KILL_GROUPS = 8;

// MIDI mapping
constexpr int MIDI_NOTE_OFFSET = 0;  // Note 0 = Pad 0 (full MIDI range)

// Audio processing thresholds
constexpr float FILTER_CUTOFF_MAX = 20000.0f;  // Hz
constexpr float FILTER_CUTOFF_MIN = 20.0f;     // Hz
constexpr float FILTER_LP_BYPASS_THRESHOLD = 20000.0f;  // Skip LP filter at max cutoff
constexpr float FILTER_HP_BYPASS_THRESHOLD = 20.0f;     // Skip HP filter at min cutoff
constexpr float NORM_PEAK_THRESHOLD = 0.0001f;          // Min peak for normalization

// Filter Q mapping: 0-1 resonance parameter maps to Q_MIN-Q_MAX
constexpr float FILTER_Q_MIN = 0.707f;   // Butterworth (no resonance)
constexpr float FILTER_Q_MAX = 10.0f;    // High resonance

// Round-robin limits
constexpr int MAX_ROUND_ROBIN_SAMPLES = 16;  // Max RR samples per layer (for pre-allocation)

// Velocity layer thresholds (4 layers: 0-31, 32-63, 64-95, 96-127)
constexpr int VELOCITY_LAYER_1_MIN = 32;   // Layer 1 starts at velocity 32
constexpr int VELOCITY_LAYER_2_MIN = 64;   // Layer 2 starts at velocity 64
constexpr int VELOCITY_LAYER_3_MIN = 96;   // Layer 3 starts at velocity 96

// =============================================================================
// PARAMETER DEFINITIONS
// =============================================================================

// Loop modes for sample playback
enum class LoopMode
{
    OneShot = 0,    // Play once and stop
    Loop = 1,       // Loop continuously
    PingPong = 2    // Loop back and forth
};

namespace PadParam
{
    // Parameter IDs per pad (22 total)
    enum ID
    {
        Volume = 0,       // 0-1
        Pan,              // -1 to +1
        Tune,             // -24 to +24 semitones
        Attack,           // 0-2000 ms
        Decay,            // 0-2000 ms
        Sustain,          // 0-1
        Release,          // 0-5000 ms
        FilterCutoff,     // 20-20000 Hz
        FilterReso,       // 0-1
        FilterType,       // 0=LP, 1=HP
        KillGroup,        // 0-8 (0 = none)
        OutputGroup,      // 0-16 (0 = main only)
        LoopModeParam,    // 0=OneShot, 1=Loop, 2=PingPong (replaces OneShot bool)
        Reverse,          // bool
        Normalize,        // bool - apply peak normalization
        SampleStart,      // 0-1 normalized
        SampleEnd,        // 0-1 normalized
        RoundRobinMode,   // 0=sequential, 1=random
        PitchEnvAmount,   // -24 to +24 semitones (pitch envelope depth)
        PitchEnvAttack,   // 0-100 ms (pitch envelope attack)
        PitchEnvDecay,    // 0-2000 ms (pitch envelope decay)
        PitchEnvSustain,  // 0-1 (pitch envelope sustain level, 0=full sweep)
        VelCrossfade,     // 0-1 (velocity layer crossfade width, 0=hard switch)
        COUNT             // = 23
    };

    // Total parameters: 18 × 128 = 2304
    constexpr int TOTAL_PARAMS = COUNT * NUM_PADS;

    // Get flat index for parameter
    inline int index(int pad, ID param)
    {
        return pad * COUNT + static_cast<int>(param);
    }

    // Get parameter ID string (e.g., "p0_volume", "p127_end")
    inline juce::String id(int pad, ID param)
    {
        static const char* names[] = {
            "volume", "pan", "tune", "attack", "decay", "sustain",
            "release", "cutoff", "reso", "filtertype", "killgroup", "outgroup",
            "loopmode", "reverse", "normalize", "start", "end", "rrmode",
            "pitchenvamt", "pitchenvattack", "pitchenvdecay", "pitchenvsustain",
            "velcrossfade"
        };
        return "p" + juce::String(pad) + "_" + names[param];
    }
}

// =============================================================================
// PARAMETER LAYOUT FACTORY
// =============================================================================

inline juce::AudioProcessorValueTreeState::ParameterLayout createParameterLayout()
{
    std::vector<std::unique_ptr<juce::RangedAudioParameter>> params;
    params.reserve(PadParam::TOTAL_PARAMS);

    for (int pad = 0; pad < NUM_PADS; ++pad)
    {
        auto prefix = "Pad " + juce::String(pad + 1) + " ";

        // Volume (0-1, default 0.8)
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::Volume), 1 },
            prefix + "Volume",
            0.0f, 1.0f, 0.8f));

        // Pan (-1 to +1, default center)
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::Pan), 1 },
            prefix + "Pan",
            -1.0f, 1.0f, 0.0f));

        // Tune (-24 to +24 semitones)
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::Tune), 1 },
            prefix + "Tune",
            -24.0f, 24.0f, 0.0f));

        // Attack (0-2000ms, skewed for fine control at low values)
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

        // Filter Type (0=LP, 1=HP)
        params.push_back(std::make_unique<juce::AudioParameterInt>(
            juce::ParameterID { PadParam::id(pad, PadParam::FilterType), 1 },
            prefix + "Filter Type",
            0, 1, 0));

        // Kill Group (0-8, 0 = none)
        params.push_back(std::make_unique<juce::AudioParameterInt>(
            juce::ParameterID { PadParam::id(pad, PadParam::KillGroup), 1 },
            prefix + "Kill Group",
            0, NUM_KILL_GROUPS, 0));

        // Output Group (0 = main only, 1-16 = group bus)
        params.push_back(std::make_unique<juce::AudioParameterInt>(
            juce::ParameterID { PadParam::id(pad, PadParam::OutputGroup), 1 },
            prefix + "Output Group",
            0, NUM_OUTPUT_GROUPS, 0));

        // Loop Mode (0=OneShot, 1=Loop, 2=PingPong, default OneShot for drums)
        params.push_back(std::make_unique<juce::AudioParameterInt>(
            juce::ParameterID { PadParam::id(pad, PadParam::LoopModeParam), 1 },
            prefix + "Loop Mode",
            0, 2, 0));

        // Reverse playback
        params.push_back(std::make_unique<juce::AudioParameterBool>(
            juce::ParameterID { PadParam::id(pad, PadParam::Reverse), 1 },
            prefix + "Reverse",
            false));

        // Normalize (apply peak normalization)
        params.push_back(std::make_unique<juce::AudioParameterBool>(
            juce::ParameterID { PadParam::id(pad, PadParam::Normalize), 1 },
            prefix + "Normalize",
            false));

        // Sample Start (0-1 normalized)
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::SampleStart), 1 },
            prefix + "Start",
            0.0f, 1.0f, 0.0f));

        // Sample End (0-1 normalized)
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::SampleEnd), 1 },
            prefix + "End",
            0.0f, 1.0f, 1.0f));

        // Round-Robin Mode (0=sequential, 1=random)
        params.push_back(std::make_unique<juce::AudioParameterInt>(
            juce::ParameterID { PadParam::id(pad, PadParam::RoundRobinMode), 1 },
            prefix + "RR Mode",
            0, 1, 0));

        // Pitch Envelope Amount (-24 to +24 semitones, default 0 = off)
        // Classic 808 kicks use -12 to -24 for that "boing" attack
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::PitchEnvAmount), 1 },
            prefix + "Pitch Env Amt",
            -24.0f, 24.0f, 0.0f));

        // Pitch Envelope Attack (0-100ms, fast attack for punchy drums)
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::PitchEnvAttack), 1 },
            prefix + "Pitch Env Atk",
            juce::NormalisableRange<float>(0.0f, 100.0f, 0.1f, 0.5f),
            0.0f, "ms"));

        // Pitch Envelope Decay (0-2000ms, controls how fast pitch sweeps to sustain)
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::PitchEnvDecay), 1 },
            prefix + "Pitch Env Dcy",
            juce::NormalisableRange<float>(0.0f, 2000.0f, 1.0f, 0.3f),
            50.0f, "ms"));

        // Pitch Envelope Sustain (0-1, 0=full sweep to base pitch, 1=no sweep)
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::PitchEnvSustain), 1 },
            prefix + "Pitch Env Sus",
            0.0f, 1.0f, 0.0f));

        // Velocity Crossfade (0-1, 0=hard switch between layers, 1=full blend zone)
        // At 0: traditional hard switching at velocity thresholds
        // At 1: smooth crossfade across the full overlap zone between layers
        params.push_back(std::make_unique<juce::AudioParameterFloat>(
            juce::ParameterID { PadParam::id(pad, PadParam::VelCrossfade), 1 },
            prefix + "Vel Crossfade",
            0.0f, 1.0f, 0.0f));  // Default 0 = traditional hard switching
    }

    return { params.begin(), params.end() };
}

}  // namespace BlockSampler
