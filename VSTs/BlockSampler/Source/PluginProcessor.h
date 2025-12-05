// =============================================================================
// BlockSampler/Source/PluginProcessor.h
// Main VST3 processor - headless drum sampler with 128 pads
// =============================================================================

#pragma once

#include <juce_audio_processors/juce_audio_processors.h>
#include <juce_audio_formats/juce_audio_formats.h>
#include "Parameters.h"
#include "Pad.h"

namespace BlockSampler
{

// =============================================================================
// PROCESSOR CLASS
// =============================================================================

class Processor : public juce::AudioProcessor,
                  public juce::AudioProcessorValueTreeState::Listener,
                  public juce::VST3ClientExtensions
{
public:
    Processor();
    ~Processor() override;

    // -------------------------------------------------------------------------
    // AUDIO PROCESSOR OVERRIDES
    // -------------------------------------------------------------------------

    void prepareToPlay(double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;
    void processBlock(juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

    // -------------------------------------------------------------------------
    // EDITOR (headless - no GUI)
    // -------------------------------------------------------------------------

    juce::AudioProcessorEditor* createEditor() override { return nullptr; }
    bool hasEditor() const override { return false; }

    // -------------------------------------------------------------------------
    // PLUGIN INFO
    // -------------------------------------------------------------------------

    const juce::String getName() const override { return "BlockSampler"; }
    bool acceptsMidi() const override { return true; }
    bool producesMidi() const override { return false; }
    bool isMidiEffect() const override { return false; }
    double getTailLengthSeconds() const override { return 0.5; }

    // -------------------------------------------------------------------------
    // PRESETS
    // -------------------------------------------------------------------------

    int getNumPrograms() override { return 1; }
    int getCurrentProgram() override { return 0; }
    void setCurrentProgram(int) override {}
    const juce::String getProgramName(int) override { return {}; }
    void changeProgramName(int, const juce::String&) override {}

    // -------------------------------------------------------------------------
    // STATE PERSISTENCE
    // -------------------------------------------------------------------------

    void getStateInformation(juce::MemoryBlock& destData) override;
    void setStateInformation(const void* data, int sizeInBytes) override;

    // -------------------------------------------------------------------------
    // BUS LAYOUT
    // -------------------------------------------------------------------------

    bool isBusesLayoutSupported(const BusesLayout& layouts) const override;

    // -------------------------------------------------------------------------
    // SAMPLE MANAGEMENT (called from Lua via chunk commands)
    // -------------------------------------------------------------------------

    bool loadSampleToPad(int padIndex, int layerIndex, const juce::String& filePath);
    void clearPadSample(int padIndex, int layerIndex);

    // -------------------------------------------------------------------------
    // PARAMETER LISTENER
    // -------------------------------------------------------------------------

    void parameterChanged(const juce::String& parameterID, float newValue) override;

    // -------------------------------------------------------------------------
    // VST3 CLIENT EXTENSIONS (REAPER integration)
    // -------------------------------------------------------------------------

    VST3ClientExtensions* getVST3ClientExtensions() override { return this; }

    // Named config param support: P{pad}_L{layer}_SAMPLE = file_path
    bool handleNamedConfigParam(const juce::String& name, const juce::String& value);
    juce::String getNamedConfigParam(const juce::String& name) const;

private:
    // -------------------------------------------------------------------------
    // PRIVATE METHODS
    // -------------------------------------------------------------------------

    void handleMidiEvent(const juce::MidiMessage& msg);
    void updatePadParameters(int padIndex);
    void processKillGroups(int triggeredPad);

    // -------------------------------------------------------------------------
    // PRIVATE STATE
    // -------------------------------------------------------------------------

    juce::AudioProcessorValueTreeState parameters;
    juce::AudioFormatManager formatManager;

    std::array<Pad, NUM_PADS> pads;

    // Cached parameter pointers for fast audio-thread access
    struct PadParams
    {
        std::atomic<float>* volume = nullptr;
        std::atomic<float>* pan = nullptr;
        std::atomic<float>* tune = nullptr;
        std::atomic<float>* attack = nullptr;
        std::atomic<float>* decay = nullptr;
        std::atomic<float>* sustain = nullptr;
        std::atomic<float>* release = nullptr;
        std::atomic<float>* filterCutoff = nullptr;
        std::atomic<float>* filterReso = nullptr;
        std::atomic<float>* killGroup = nullptr;
        std::atomic<float>* outputGroup = nullptr;
        std::atomic<float>* oneShot = nullptr;
        std::atomic<float>* reverse = nullptr;
        std::atomic<float>* sampleStart = nullptr;
        std::atomic<float>* sampleEnd = nullptr;
    };
    std::array<PadParams, NUM_PADS> padParams;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(Processor)
};

}  // namespace BlockSampler
