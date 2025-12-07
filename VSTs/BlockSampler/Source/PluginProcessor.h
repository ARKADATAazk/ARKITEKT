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
#include <mutex>
#include <shared_mutex>

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
    uint32_t generation = 0;  // State generation when load was queued
};

// Lock-free SPSC queue size (must be power of 2)
constexpr int LOAD_QUEUE_SIZE = 64;
static_assert((LOAD_QUEUE_SIZE & (LOAD_QUEUE_SIZE - 1)) == 0,
              "LOAD_QUEUE_SIZE must be power of 2");

// =============================================================================
// THREAD-SAFE PAD METADATA (for message thread queries)
// =============================================================================

struct PadMetadata
{
    // Atomic snapshot of pad state - updated by audio thread, read by message thread
    std::array<juce::String, NUM_VELOCITY_LAYERS> samplePaths;
    std::array<std::vector<juce::String>, NUM_VELOCITY_LAYERS> roundRobinPaths;
    std::array<int, NUM_VELOCITY_LAYERS> roundRobinCounts = {};
    std::array<double, NUM_VELOCITY_LAYERS> sampleDurations = {};
    std::array<bool, NUM_VELOCITY_LAYERS> hasLayerSample = {};
    bool hasSample = false;
};

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
    Trigger,        // Trigger pad with velocity
    Stop,           // Stop pad immediately
    Release,        // Trigger release phase (graceful stop)
    StopAll,        // Stop all pads
    ReleaseAll,     // Release all pads
    ClearLayer,     // Clear specific layer (requires layerIndex)
    ClearRoundRobin,// Clear round-robin samples for layer (requires layerIndex)
    ClearPad,       // Clear all layers for pad
    ClearAllPads    // Clear all samples from all pads (single command)
};

struct PadCommand
{
    PadCommandType type = PadCommandType::Stop;
    int padIndex = -1;      // -1 for "all pads" commands
    int velocity = 100;     // For Trigger command
    int layerIndex = 0;     // For layer-specific commands (ClearLayer, ClearRoundRobin)
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
    // SAMPLE MANAGEMENT
    // -------------------------------------------------------------------------

    // Asynchronous sample loading (returns immediately, loads in background thread)
    // Sample is applied to pad on next audio processBlock via lock-free FIFO
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
    void updatePadMetadata(int padIndex);  // Update thread-safe metadata after sample changes (audio thread)
    void updatePadMetadataAfterClear(int padIndex, int layerIndex);  // Update after clearing layer (audio thread)

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

    // Async sample loading - FIFO with mutex protection for multiple producers
    // Producer: background thread pool (multiple threads), Consumer: audio thread
    juce::ThreadPool loadPool { 2 };  // 2 worker threads
    juce::AbstractFifo loadFifo { LOAD_QUEUE_SIZE };
    std::array<LoadedSample, LOAD_QUEUE_SIZE> loadQueue;
    std::mutex loadFifoWriteMutex;  // Protects writes from multiple producer threads

    // Thread-safe metadata for message thread queries
    // Protected by shared_mutex: audio thread writes, message thread reads
    mutable std::shared_mutex metadataMutex;
    std::array<PadMetadata, NUM_PADS> padMetadata;

    // Command queue - lock-free SPSC FIFO for message-to-audio-thread operations
    // Producer: message thread (named config params), Consumer: audio thread
    juce::AbstractFifo commandFifo { COMMAND_QUEUE_SIZE };
    std::array<PadCommand, COMMAND_QUEUE_SIZE> commandQueue;

    // Debug counters for FIFO overflow detection (atomic for thread-safe reads)
    std::atomic<uint32_t> droppedLoadCount { 0 };
    std::atomic<uint32_t> droppedCommandCount { 0 };

    // State restoration generation counter - incremented on each setStateInformation
    // Loads tagged with old generation are discarded to prevent race conditions
    std::atomic<uint32_t> stateGeneration { 0 };

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(Processor)
};

}  // namespace BlockSampler
