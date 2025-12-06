// =============================================================================
// BlockSampler/Source/PluginProcessor.h
// Main VST3 processor - headless drum sampler with 128 pads
// =============================================================================

#pragma once

#include <juce_audio_processors/juce_audio_processors.h>
#include <juce_audio_formats/juce_audio_formats.h>
#include "Parameters.h"
#include "Pad.h"
#include <bitset>
#include <atomic>

namespace BlockSampler
{

// =============================================================================
// ASYNC SAMPLE LOAD RESULT
// =============================================================================

struct LoadedSample
{
    int padIndex = -1;
    int layerIndex = -1;
    bool isRoundRobin = false;
    juce::AudioBuffer<float> buffer;
    double sampleRate = 44100.0;
    juce::String path;
    float normGain = 1.0f;
};

// Lock-free SPSC queue size (must be power of 2)
constexpr int LOAD_QUEUE_SIZE = 64;
static_assert((LOAD_QUEUE_SIZE & (LOAD_QUEUE_SIZE - 1)) == 0,
              "LOAD_QUEUE_SIZE must be power of 2");

// Max samples to apply per processBlock (prevents audio dropout from batch loads)
constexpr int MAX_LOADS_PER_BLOCK = 4;

// Command queue for message-thread-to-audio-thread operations
constexpr int COMMAND_QUEUE_SIZE = 64;
static_assert((COMMAND_QUEUE_SIZE & (COMMAND_QUEUE_SIZE - 1)) == 0,
              "COMMAND_QUEUE_SIZE must be power of 2");

// Max commands to process per processBlock
constexpr int MAX_COMMANDS_PER_BLOCK = 16;

// =============================================================================
// PAD COMMAND (for thread-safe message-to-audio operations)
// =============================================================================

enum class PadCommandType : uint8_t
{
    Trigger,      // Trigger pad with velocity
    Stop,         // Stop pad immediately
    Release,      // Trigger release phase (graceful stop)
    StopAll,      // Stop all pads
    ReleaseAll    // Release all pads
};

struct PadCommand
{
    PadCommandType type = PadCommandType::Stop;
    int padIndex = -1;      // -1 for "all pads" commands
    int velocity = 100;     // For Trigger command
};

// =============================================================================
// PROCESSOR CLASS
// =============================================================================

class Processor : public juce::AudioProcessor,
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
    double getTailLengthSeconds() const override { return 5.0; }  // Max release time

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

    // Synchronous (blocks calling thread - use for state restore)
    bool loadSampleToPad(int padIndex, int layerIndex, const juce::String& filePath);
    void clearPadSample(int padIndex, int layerIndex);

    // Asynchronous (returns immediately, loads in background)
    void loadSampleToPadAsync(int padIndex, int layerIndex, const juce::String& filePath, bool roundRobin = false);

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
    void applyCompletedLoads();    // Called at start of processBlock (audio thread)
    void applyQueuedCommands();    // Called at start of processBlock (audio thread)
    void queueCommand(PadCommand cmd);  // Thread-safe command queuing (message thread)

    // Helper for parsing pad/layer from named config params
    // Returns true if parsed successfully, fills padIndex and layerIndex
    static bool parsePadLayerParam(const juce::String& name,
                                   const juce::String& suffix,
                                   int& padIndex,
                                   int& layerIndex);

    // -------------------------------------------------------------------------
    // PRIVATE STATE
    // -------------------------------------------------------------------------

    juce::AudioProcessorValueTreeState parameters;
    juce::AudioFormatManager formatManager;

    std::array<Pad, NUM_PADS> pads;

    // Active pad tracking for optimized rendering
    std::bitset<NUM_PADS> activePads;

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
        std::atomic<float>* filterType = nullptr;
        std::atomic<float>* killGroup = nullptr;
        std::atomic<float>* outputGroup = nullptr;
        std::atomic<float>* oneShot = nullptr;
        std::atomic<float>* reverse = nullptr;
        std::atomic<float>* normalize = nullptr;
        std::atomic<float>* sampleStart = nullptr;
        std::atomic<float>* sampleEnd = nullptr;
        std::atomic<float>* roundRobinMode = nullptr;
    };
    std::array<PadParams, NUM_PADS> padParams;

    // Async sample loading - lock-free SPSC FIFO
    // Producer: background thread pool, Consumer: audio thread
    juce::ThreadPool loadPool { 2 };  // 2 worker threads
    juce::AbstractFifo loadFifo { LOAD_QUEUE_SIZE };
    std::array<LoadedSample, LOAD_QUEUE_SIZE> loadQueue;

    // Command queue - lock-free SPSC FIFO for message-to-audio-thread operations
    // Producer: message thread (named config params), Consumer: audio thread
    juce::AbstractFifo commandFifo { COMMAND_QUEUE_SIZE };
    std::array<PadCommand, COMMAND_QUEUE_SIZE> commandQueue;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(Processor)
};

}  // namespace BlockSampler
