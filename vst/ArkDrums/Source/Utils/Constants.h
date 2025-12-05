/*
  ==============================================================================

    Constants.h
    ArkDrums - Professional Drum Sampler
    Global constants and configuration

  ==============================================================================
*/

#pragma once

#include <cstdint>

namespace ArkDrums {

// ============================================================================
// ARCHITECTURE
// ============================================================================

constexpr int NUM_PADS = 16;
constexpr int MAX_VOICES_PER_PAD = 4;    // Polyphonic samples (e.g., long cymbal tail)
constexpr int MAX_TOTAL_VOICES = 64;    // Total concurrent voices across all pads
constexpr int MAX_VELOCITY_LAYERS = 4;  // Max samples per pad (soft, med, hard, very hard)
constexpr int MAX_ROUND_ROBIN = 8;      // Max round-robin samples per velocity layer

// ============================================================================
// MIDI MAPPING
// ============================================================================

constexpr int MIDI_NOTE_BASE = 36;      // MIDI note for Pad 1 (C2 in some DAWs, C1 in others)
constexpr int MIDI_NOTE_MAX = 51;       // MIDI note for Pad 16

// Velocity layer thresholds (0-127 MIDI velocity)
constexpr int VELOCITY_LAYER_1_MAX = 42;   // Soft (0-42)
constexpr int VELOCITY_LAYER_2_MAX = 84;   // Medium (43-84)
constexpr int VELOCITY_LAYER_3_MAX = 127;  // Hard (85-127)

// ============================================================================
// AUDIO
// ============================================================================

constexpr double DEFAULT_SAMPLE_RATE = 48000.0;
constexpr int MAX_BUFFER_SIZE = 4096;   // Support up to 4096 sample buffers
constexpr int MAX_CHANNELS = 2;         // Stereo samples

// ============================================================================
// PAD DEFAULTS
// ============================================================================

// Volume
constexpr float DEFAULT_VOLUME = 0.8f;   // 80% volume
constexpr float MIN_VOLUME = 0.0f;
constexpr float MAX_VOLUME = 1.5f;       // Allow +3dB boost

// Pan
constexpr float DEFAULT_PAN = 0.5f;      // Center (0.0 = left, 0.5 = center, 1.0 = right)
constexpr float MIN_PAN = 0.0f;
constexpr float MAX_PAN = 1.0f;

// Tune (semitones)
constexpr float DEFAULT_TUNE = 0.0f;     // No pitch shift
constexpr float MIN_TUNE = -24.0f;       // -2 octaves
constexpr float MAX_TUNE = 24.0f;        // +2 octaves

// Fine Tune (cents)
constexpr float DEFAULT_FINE_TUNE = 0.0f;
constexpr float MIN_FINE_TUNE = -100.0f;
constexpr float MAX_FINE_TUNE = 100.0f;

// ============================================================================
// ADSR DEFAULTS
// ============================================================================

// Attack (seconds)
constexpr float DEFAULT_ATTACK = 0.001f;  // 1ms (fast attack for drums)
constexpr float MIN_ATTACK = 0.0f;
constexpr float MAX_ATTACK = 2.0f;

// Decay (seconds)
constexpr float DEFAULT_DECAY = 0.05f;    // 50ms
constexpr float MIN_DECAY = 0.0f;
constexpr float MAX_DECAY = 5.0f;

// Sustain (level 0-1)
constexpr float DEFAULT_SUSTAIN = 0.0f;   // No sustain (one-shot drums)
constexpr float MIN_SUSTAIN = 0.0f;
constexpr float MAX_SUSTAIN = 1.0f;

// Release (seconds)
constexpr float DEFAULT_RELEASE = 0.05f;  // 50ms
constexpr float MIN_RELEASE = 0.0f;
constexpr float MAX_RELEASE = 5.0f;

// ============================================================================
// FILTER DEFAULTS (Future)
// ============================================================================

constexpr float DEFAULT_FILTER_CUTOFF = 20000.0f;  // Wide open
constexpr float MIN_FILTER_CUTOFF = 20.0f;
constexpr float MAX_FILTER_CUTOFF = 20000.0f;

constexpr float DEFAULT_FILTER_RESONANCE = 0.707f;  // Butterworth
constexpr float MIN_FILTER_RESONANCE = 0.1f;
constexpr float MAX_FILTER_RESONANCE = 10.0f;

// ============================================================================
// KILL GROUPS
// ============================================================================

constexpr int NO_KILL_GROUP = -1;
constexpr int HIHAT_KILL_GROUP = 0;  // Typical: Closed Hat, Open Hat share group 0

// ============================================================================
// PARAMETER IDS (for VST automation)
// ============================================================================

enum ParameterID {
    // Master Controls (0-15)
    MASTER_VOLUME = 0,
    MASTER_PAN = 1,

    // Per-Pad Parameters (16-271)
    // Pattern: PAD_BASE + (pad_index * PARAMS_PER_PAD) + param_offset
    PAD_BASE = 16,
    PARAMS_PER_PAD = 16,

    // Offsets within each pad's parameter block
    PAD_VOLUME_OFFSET = 0,
    PAD_PAN_OFFSET = 1,
    PAD_TUNE_OFFSET = 2,
    PAD_FINE_TUNE_OFFSET = 3,
    PAD_ATTACK_OFFSET = 4,
    PAD_DECAY_OFFSET = 5,
    PAD_SUSTAIN_OFFSET = 6,
    PAD_RELEASE_OFFSET = 7,
    PAD_FILTER_CUTOFF_OFFSET = 8,
    PAD_FILTER_RESONANCE_OFFSET = 9,
    PAD_MUTE_OFFSET = 10,
    PAD_SOLO_OFFSET = 11,
    PAD_OUTPUT_OFFSET = 12,  // Multi-out routing (0 = main, 1-16 = separate)
    PAD_KILL_GROUP_OFFSET = 13,
    // Reserved: 14-15
};

// Helper macro to calculate parameter ID
#define PAD_PARAM_ID(pad_index, offset) \
    (PAD_BASE + ((pad_index) * PARAMS_PER_PAD) + (offset))

// Example: Pad 0 Volume = PAD_PARAM_ID(0, PAD_VOLUME_OFFSET) = 16 + 0 + 0 = 16
// Example: Pad 1 Attack = PAD_PARAM_ID(1, PAD_ATTACK_OFFSET) = 16 + 16 + 4 = 36

// ============================================================================
// SAMPLE LOADING
// ============================================================================

constexpr size_t MAX_SAMPLE_SIZE = 200 * 1024 * 1024; // 200MB per sample (safety limit)
constexpr int SUPPORTED_SAMPLE_RATES[] = { 44100, 48000, 88200, 96000, 176400, 192000 };

// ============================================================================
// VERSION
// ============================================================================

constexpr const char* VERSION = "0.1.0-alpha";
constexpr const char* PLUGIN_NAME = "ArkDrums";
constexpr const char* VENDOR = "ARKITEKT";

} // namespace ArkDrums
