/*
  ==============================================================================

    Sampler.h
    ArkDrums - Professional Drum Sampler
    Main sampler engine - manages pads, voices, and MIDI processing

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "Pad.h"
#include "Voice.h"
#include "../Utils/Constants.h"
#include <array>
#include <memory>

namespace ArkDrums {

class Sampler {
public:
    Sampler() {
        // Initialize pads with default MIDI mapping (36-51)
        for (int i = 0; i < NUM_PADS; ++i) {
            pads_[i] = std::make_unique<Pad>(i, MIDI_NOTE_BASE + i);
        }

        // Initialize voice pool
        for (int i = 0; i < MAX_TOTAL_VOICES; ++i) {
            voices_[i] = std::make_unique<Voice>();
        }
    }

    // ========================================================================
    // AUDIO PROCESSING
    // ========================================================================

    /// Process audio for one block
    /// @param buffer Output buffer (stereo)
    /// @param midi_messages MIDI events for this block
    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi_messages) {
        // Clear output buffer
        buffer.clear();

        // Check if any pad is soloed
        bool any_soloed = false;
        for (const auto& pad : pads_) {
            if (pad->isSoloed()) {
                any_soloed = true;
                break;
            }
        }

        // Process MIDI events
        for (const auto metadata : midi_messages) {
            const auto msg = metadata.getMessage();
            const int sample_position = metadata.samplePosition;

            if (msg.isNoteOn()) {
                handleNoteOn(msg.getNoteNumber(), msg.getVelocity(), sample_position);
            } else if (msg.isNoteOff()) {
                handleNoteOff(msg.getNoteNumber(), sample_position);
            }
        }

        // Render active voices
        for (auto& voice : voices_) {
            if (!voice->isActive()) continue;

            // Check mute/solo
            int pad_index = voice->getPadIndex();
            if (pad_index >= 0 && pad_index < NUM_PADS) {
                const auto& pad = pads_[pad_index];

                // Skip if muted
                if (pad->isMuted()) continue;

                // Skip if not soloed (when any pad is soloed)
                if (any_soloed && !pad->isSoloed()) continue;
            }

            // Render voice into buffer
            voice->render(buffer, buffer.getNumSamples());
        }
    }

    /// Set sample rate (call when host sample rate changes)
    void setSampleRate(double sample_rate) {
        sample_rate_ = sample_rate;
        for (auto& voice : voices_) {
            voice->setSampleRate(sample_rate);
        }
    }

    // ========================================================================
    // MIDI HANDLING
    // ========================================================================

    void handleNoteOn(int midi_note, int velocity, int sample_position) {
        // Find pad for this MIDI note
        int pad_index = midi_note - MIDI_NOTE_BASE;
        if (pad_index < 0 || pad_index >= NUM_PADS) {
            return;  // Out of range
        }

        auto& pad = pads_[pad_index];
        if (!pad->hasSamples()) {
            return;  // No sample loaded
        }

        // Get sample for velocity
        const auto* sample_buffer = pad->getSampleForVelocity(velocity);
        if (sample_buffer == nullptr) {
            return;
        }

        // Handle kill groups (e.g., hi-hat choking)
        int kill_group = pad->getKillGroup();
        if (kill_group != NO_KILL_GROUP) {
            killGroup(kill_group, pad_index);  // Kill other voices in same group
        }

        // Find free voice
        Voice* voice = findFreeVoice();
        if (voice == nullptr) {
            // Steal oldest voice
            voice = stealVoice();
        }

        if (voice != nullptr) {
            // Trigger voice
            voice->trigger(
                pad_index,
                velocity,
                sample_buffer,
                pad->getVolume(),
                pad->getPan(),
                pad->getTotalPitch(),
                pad->getADSRTemplate()
            );
        }
    }

    void handleNoteOff(int midi_note, int sample_position) {
        // For drums, note-off is often ignored (one-shot samples)
        // But we implement it for sustained samples (cymbals, etc.)

        int pad_index = midi_note - MIDI_NOTE_BASE;
        if (pad_index < 0 || pad_index >= NUM_PADS) {
            return;
        }

        // Release all voices playing this pad
        for (auto& voice : voices_) {
            if (voice->isActive() && voice->getPadIndex() == pad_index) {
                voice->release();
            }
        }
    }

    // ========================================================================
    // VOICE MANAGEMENT
    // ========================================================================

    /// Find a free voice
    Voice* findFreeVoice() {
        for (auto& voice : voices_) {
            if (!voice->isActive()) {
                return voice.get();
            }
        }
        return nullptr;
    }

    /// Steal the oldest voice (simple strategy: first active voice)
    Voice* stealVoice() {
        // TODO: Implement smarter stealing (lowest velocity, oldest note, etc.)
        for (auto& voice : voices_) {
            if (voice->isActive()) {
                voice->kill();
                return voice.get();
            }
        }
        return nullptr;
    }

    /// Kill all voices in a kill group except one pad
    void killGroup(int kill_group, int except_pad_index) {
        for (auto& voice : voices_) {
            if (!voice->isActive()) continue;

            int voice_pad = voice->getPadIndex();
            if (voice_pad == except_pad_index) continue;

            if (voice_pad >= 0 && voice_pad < NUM_PADS) {
                if (pads_[voice_pad]->getKillGroup() == kill_group) {
                    voice->kill();
                }
            }
        }
    }

    // ========================================================================
    // PAD ACCESS
    // ========================================================================

    Pad* getPad(int index) {
        if (index >= 0 && index < NUM_PADS) {
            return pads_[index].get();
        }
        return nullptr;
    }

    const Pad* getPad(int index) const {
        if (index >= 0 && index < NUM_PADS) {
            return pads_[index].get();
        }
        return nullptr;
    }

    int getNumPads() const { return NUM_PADS; }

    // ========================================================================
    // PRESET MANAGEMENT
    // ========================================================================

    /// Save current state to JSON
    juce::var toJSON() const {
        auto obj = new juce::DynamicObject();
        obj->setProperty("version", VERSION);

        // Save all pads
        juce::Array<juce::var> pads_array;
        for (const auto& pad : pads_) {
            pads_array.add(pad->toJSON());
        }
        obj->setProperty("pads", pads_array);

        return juce::var(obj);
    }

    /// Load state from JSON
    void fromJSON(const juce::var& json) {
        auto* obj = json.getDynamicObject();
        if (obj == nullptr) return;

        // Load pads
        auto pads_array = obj->getProperty("pads");
        if (pads_array.isArray()) {
            for (int i = 0; i < pads_array.size() && i < NUM_PADS; ++i) {
                pads_[i]->fromJSON(pads_array[i]);
            }
        }
    }

    /// Save preset to file
    bool savePreset(const juce::File& file) {
        auto json = toJSON();
        juce::String json_string = juce::JSON::toString(json, true);

        return file.replaceWithText(json_string);
    }

    /// Load preset from file
    bool loadPreset(const juce::File& file) {
        if (!file.existsAsFile()) return false;

        juce::String json_string = file.loadFileAsString();
        auto json = juce::JSON::parse(json_string);

        if (json.isVoid()) return false;

        fromJSON(json);
        return true;
    }

    // ========================================================================
    // STATS
    // ========================================================================

    int getActiveVoiceCount() const {
        int count = 0;
        for (const auto& voice : voices_) {
            if (voice->isActive()) ++count;
        }
        return count;
    }

private:
    std::array<std::unique_ptr<Pad>, NUM_PADS> pads_;
    std::array<std::unique_ptr<Voice>, MAX_TOTAL_VOICES> voices_;
    double sample_rate_ = DEFAULT_SAMPLE_RATE;
};

} // namespace ArkDrums
