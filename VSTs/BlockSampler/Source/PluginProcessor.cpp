// =============================================================================
// BlockSampler/Source/PluginProcessor.cpp
// Main VST3 processor implementation
// =============================================================================

#include "PluginProcessor.h"
#include <limits>

namespace BlockSampler
{

// =============================================================================
// CONSTRUCTOR / DESTRUCTOR
// =============================================================================

Processor::Processor()
    : AudioProcessor(BusesProperties()
          // Main stereo output (always enabled)
          .withOutput("Main", juce::AudioChannelSet::stereo(), true)
          // 16 group buses for routing (disabled by default)
          .withOutput("Group 1 - Kicks", juce::AudioChannelSet::stereo(), false)
          .withOutput("Group 2 - Snares", juce::AudioChannelSet::stereo(), false)
          .withOutput("Group 3 - HiHats", juce::AudioChannelSet::stereo(), false)
          .withOutput("Group 4 - Percussion", juce::AudioChannelSet::stereo(), false)
          .withOutput("Group 5", juce::AudioChannelSet::stereo(), false)
          .withOutput("Group 6", juce::AudioChannelSet::stereo(), false)
          .withOutput("Group 7", juce::AudioChannelSet::stereo(), false)
          .withOutput("Group 8", juce::AudioChannelSet::stereo(), false)
          .withOutput("Group 9", juce::AudioChannelSet::stereo(), false)
          .withOutput("Group 10", juce::AudioChannelSet::stereo(), false)
          .withOutput("Group 11", juce::AudioChannelSet::stereo(), false)
          .withOutput("Group 12", juce::AudioChannelSet::stereo(), false)
          .withOutput("Group 13", juce::AudioChannelSet::stereo(), false)
          .withOutput("Group 14", juce::AudioChannelSet::stereo(), false)
          .withOutput("Group 15", juce::AudioChannelSet::stereo(), false)
          .withOutput("Group 16", juce::AudioChannelSet::stereo(), false)),
      parameters(*this, nullptr, "BlockSamplerParams", createParameterLayout())
{
    formatManager.registerBasicFormats();

    // Cache parameter pointers for audio-thread access
    // Note: We don't use parameter listeners to avoid race conditions.
    // Parameters are read directly from atomic pointers in processBlock.
    for (int pad = 0; pad < NUM_PADS; ++pad)
    {
        padParams[pad].volume = parameters.getRawParameterValue(PadParam::id(pad, PadParam::Volume));
        padParams[pad].pan = parameters.getRawParameterValue(PadParam::id(pad, PadParam::Pan));
        padParams[pad].tune = parameters.getRawParameterValue(PadParam::id(pad, PadParam::Tune));
        padParams[pad].attack = parameters.getRawParameterValue(PadParam::id(pad, PadParam::Attack));
        padParams[pad].decay = parameters.getRawParameterValue(PadParam::id(pad, PadParam::Decay));
        padParams[pad].sustain = parameters.getRawParameterValue(PadParam::id(pad, PadParam::Sustain));
        padParams[pad].release = parameters.getRawParameterValue(PadParam::id(pad, PadParam::Release));
        padParams[pad].filterCutoff = parameters.getRawParameterValue(PadParam::id(pad, PadParam::FilterCutoff));
        padParams[pad].filterReso = parameters.getRawParameterValue(PadParam::id(pad, PadParam::FilterReso));
        padParams[pad].filterType = parameters.getRawParameterValue(PadParam::id(pad, PadParam::FilterType));
        padParams[pad].killGroup = parameters.getRawParameterValue(PadParam::id(pad, PadParam::KillGroup));
        padParams[pad].outputGroup = parameters.getRawParameterValue(PadParam::id(pad, PadParam::OutputGroup));
        padParams[pad].loopMode = parameters.getRawParameterValue(PadParam::id(pad, PadParam::LoopModeParam));
        padParams[pad].reverse = parameters.getRawParameterValue(PadParam::id(pad, PadParam::Reverse));
        padParams[pad].normalize = parameters.getRawParameterValue(PadParam::id(pad, PadParam::Normalize));
        padParams[pad].sampleStart = parameters.getRawParameterValue(PadParam::id(pad, PadParam::SampleStart));
        padParams[pad].sampleEnd = parameters.getRawParameterValue(PadParam::id(pad, PadParam::SampleEnd));
        padParams[pad].roundRobinMode = parameters.getRawParameterValue(PadParam::id(pad, PadParam::RoundRobinMode));
        padParams[pad].pitchEnvAmount = parameters.getRawParameterValue(PadParam::id(pad, PadParam::PitchEnvAmount));
        padParams[pad].pitchEnvAttack = parameters.getRawParameterValue(PadParam::id(pad, PadParam::PitchEnvAttack));
        padParams[pad].pitchEnvDecay = parameters.getRawParameterValue(PadParam::id(pad, PadParam::PitchEnvDecay));
        padParams[pad].pitchEnvSustain = parameters.getRawParameterValue(PadParam::id(pad, PadParam::PitchEnvSustain));
        padParams[pad].velCrossfade = parameters.getRawParameterValue(PadParam::id(pad, PadParam::VelCrossfade));
        padParams[pad].velCurve = parameters.getRawParameterValue(PadParam::id(pad, PadParam::VelCurve));
    }
}

Processor::~Processor()
{
    // Wait indefinitely for jobs to finish (they capture raw pointers to our members)
    // Jobs are quick file loads, so this should complete promptly
    loadPool.removeAllJobs(true, -1);
}

// =============================================================================
// AUDIO PROCESSING
// =============================================================================

void Processor::prepareToPlay(double sampleRate, int samplesPerBlock)
{
    for (auto& pad : pads)
    {
        pad.prepare(sampleRate, samplesPerBlock);
    }

    for (int i = 0; i < NUM_PADS; ++i)
    {
        updatePadParameters(i);
    }
}

void Processor::releaseResources()
{
    for (auto& pad : pads)
    {
        pad.stop();
    }
}

void Processor::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages)
{
    juce::ScopedNoDenormals noDenormals;

    // Apply any queued commands from message thread (trigger, stop, release)
    applyQueuedCommands();

    // Apply any completed async sample loads (thread-safe: only audio thread consumes)
    applyCompletedLoads();

    const int numSamples = buffer.getNumSamples();

    // Clear all output channels (buffer.clear() handles all buses)
    buffer.clear();

    // Process MIDI events (update parameters for triggered pads)
    // TODO: MIDI timing improvement - currently all events trigger at sample 0
    // of the block. For sample-accurate timing, would need to split the render
    // loop by MIDI event boundaries using metadata.samplePosition.
    // Current latency: up to one block (e.g., 11ms at 44.1kHz/512 samples).
    for (const auto metadata : midiMessages)
    {
        handleMidiEvent(metadata.getMessage());
    }

    // Update active pads bitset
    for (int i = 0; i < NUM_PADS; ++i)
    {
        if (pads[i].isPlaying)
            activePads.set(i);
        else
            activePads.reset(i);
    }

    // Render only active pads (optimization: skip inactive pads entirely)
    if (activePads.none())
        return;

    for (int i = 0; i < NUM_PADS; ++i)
    {
        if (!activePads.test(i))
            continue;

        // Only update parameters for pads that are playing
        updatePadParameters(i);

        int rendered = pads[i].renderNextBlock(numSamples);
        if (rendered == 0)
        {
            activePads.reset(i);  // Pad stopped during render
            continue;
        }

        const auto& padOutput = pads[i].getOutputBuffer();

        // Always add to main output (bus 0)
        for (int ch = 0; ch < 2; ++ch)
            buffer.addFrom(ch, 0, padOutput, ch, 0, rendered);

        // Route to group bus if assigned (outputGroup 1-16 → bus 1-16)
        int group = pads[i].outputGroup;
        if (group > 0 && group <= NUM_OUTPUT_GROUPS)
        {
            auto* groupBuffer = getBusBuffer(buffer, false, group);
            if (groupBuffer && groupBuffer->getNumChannels() >= 2)
            {
                for (int ch = 0; ch < 2; ++ch)
                    groupBuffer->addFrom(ch, 0, padOutput, ch, 0, rendered);
            }
        }
    }
}

// =============================================================================
// MIDI HANDLING
// =============================================================================

void Processor::handleMidiEvent(const juce::MidiMessage& msg)
{
    if (msg.isNoteOn())
    {
        int note = msg.getNoteNumber();
        int padIndex = note - MIDI_NOTE_OFFSET;

        if (padIndex >= 0 && padIndex < NUM_PADS)
        {
            // Update parameters before triggering (needed since we optimized to only update playing pads)
            updatePadParameters(padIndex);
            processKillGroups(padIndex);
            pads[padIndex].trigger(msg.getVelocity());
        }
    }
    else if (msg.isNoteOff())
    {
        int note = msg.getNoteNumber();
        int padIndex = note - MIDI_NOTE_OFFSET;

        if (padIndex >= 0 && padIndex < NUM_PADS)
        {
            pads[padIndex].noteOff();
        }
    }
    else if (msg.isAllNotesOff() || msg.isAllSoundOff())
    {
        for (auto& pad : pads)
        {
            pad.stop();
        }
    }
}

void Processor::processKillGroups(int triggeredPad)
{
    int killGroup = pads[triggeredPad].killGroup;
    if (killGroup == 0)
        return;

    for (int i = 0; i < NUM_PADS; ++i)
    {
        if (i != triggeredPad &&
            pads[i].killGroup == killGroup &&
            pads[i].isPlaying)
        {
            pads[i].stop();
        }
    }
}

// =============================================================================
// PARAMETER HANDLING
// =============================================================================

void Processor::updatePadParameters(int padIndex)
{
    auto& pad = pads[padIndex];
    auto& params = padParams[padIndex];

    pad.volume = params.volume->load();
    pad.pan = params.pan->load();
    pad.tune = params.tune->load();
    pad.attack = params.attack->load();
    pad.decay = params.decay->load();
    pad.sustain = params.sustain->load();
    pad.release = params.release->load();
    pad.filterCutoff = params.filterCutoff->load();
    pad.filterReso = params.filterReso->load();
    pad.filterType = static_cast<int>(params.filterType->load());
    pad.killGroup = static_cast<int>(params.killGroup->load());
    pad.outputGroup = static_cast<int>(params.outputGroup->load());
    pad.loopMode = static_cast<LoopMode>(static_cast<int>(params.loopMode->load()));
    pad.reverse = params.reverse->load() > 0.5f;
    pad.normalize = params.normalize->load() > 0.5f;
    pad.sampleStart = params.sampleStart->load();
    pad.sampleEnd = params.sampleEnd->load();
    pad.roundRobinMode = static_cast<int>(params.roundRobinMode->load());
    pad.pitchEnvAmount = params.pitchEnvAmount->load();
    pad.pitchEnvAttack = params.pitchEnvAttack->load();
    pad.pitchEnvDecay = params.pitchEnvDecay->load();
    pad.pitchEnvSustain = params.pitchEnvSustain->load();
    pad.velCrossfade = params.velCrossfade->load();
    pad.velCurve = params.velCurve->load();
}

// =============================================================================
// SAMPLE MANAGEMENT
// =============================================================================

void Processor::loadSampleToPadAsync(int padIndex, int layerIndex,
                                      const juce::String& filePath, bool roundRobin)
{
    if (padIndex < 0 || padIndex >= NUM_PADS)
        return;
    if (layerIndex < 0 || layerIndex >= NUM_VELOCITY_LAYERS)
        return;

    juce::File file(filePath);
    if (!file.existsAsFile())
        return;

    // Capture pointers for thread pool job
    auto* fmt = &formatManager;
    auto* fifo = &loadFifo;
    auto* queue = &loadQueue;
    auto* fifoMutex = &loadFifoWriteMutex;
    auto* droppedCounter = &droppedLoads;

    loadPool.addJob([=]()
    {
        // Load sample in background thread
        std::unique_ptr<juce::AudioFormatReader> reader(fmt->createReaderFor(file));
        if (!reader)
            return;

        // Guard against integer overflow for very long samples
        if (reader->lengthInSamples > std::numeric_limits<int>::max())
            return;

        // Guard against OOM from extremely long samples (e.g., 6-hour recordings)
        if (reader->lengthInSamples > MAX_SAMPLE_LENGTH)
            return;

        // Validate sample has audio content
        if (reader->numChannels == 0 || reader->sampleRate <= 0)
            return;

        LoadedSample result;
        result.padIndex = padIndex;
        result.layerIndex = layerIndex;
        result.isRoundRobin = roundRobin;
        result.path = filePath;
        result.sampleRate = reader->sampleRate;

        result.buffer.setSize(static_cast<int>(reader->numChannels),
                              static_cast<int>(reader->lengthInSamples));
        reader->read(&result.buffer, 0,
                     static_cast<int>(reader->lengthInSamples), 0, true, true);

        // Compute normalization gain
        float peak = 0.0f;
        for (int ch = 0; ch < result.buffer.getNumChannels(); ++ch)
            peak = juce::jmax(peak, result.buffer.getMagnitude(ch, 0, result.buffer.getNumSamples()));
        result.normGain = (peak > NORM_PEAK_THRESHOLD) ? (1.0f / peak) : 1.0f;

        // Queue result for audio thread via FIFO
        // CRITICAL: Mutex required because multiple thread pool workers can write concurrently
        // AbstractFifo is SPSC (single-producer), so we serialize writes with a mutex
        {
            std::lock_guard<std::mutex> lock(*fifoMutex);
            int start1, size1, start2, size2;
            fifo->prepareToWrite(1, start1, size1, start2, size2);

            if (size1 > 0)
            {
                (*queue)[start1] = std::move(result);
                fifo->finishedWrite(1);
            }
            else
            {
                // FIFO full - increment dropped counter for diagnostics
                droppedCounter->fetch_add(1, std::memory_order_relaxed);
            }
        }
    });
}

// =============================================================================
// ASYNC LOAD COMPLETION (Called at start of processBlock - audio thread)
// =============================================================================

void Processor::applyCompletedLoads()
{
    // Limit loads per block to prevent audio dropout from batch operations
    const int numReady = juce::jmin(loadFifo.getNumReady(), MAX_LOADS_PER_BLOCK);
    if (numReady == 0)
        return;

    int start1, size1, start2, size2;
    loadFifo.prepareToRead(numReady, start1, size1, start2, size2);

    // Helper lambda to apply a single loaded sample
    auto applyLoad = [this](LoadedSample& loaded)
    {
        if (loaded.padIndex >= 0 && loaded.padIndex < NUM_PADS)
        {
            if (loaded.isRoundRobin)
            {
                pads[loaded.padIndex].addRoundRobinBuffer(
                    loaded.layerIndex,
                    std::move(loaded.buffer),
                    loaded.sampleRate,
                    loaded.path,
                    loaded.normGain);
            }
            else
            {
                pads[loaded.padIndex].setSampleBuffer(
                    loaded.layerIndex,
                    std::move(loaded.buffer),
                    loaded.sampleRate,
                    loaded.path,
                    loaded.normGain);
            }
            // Update thread-safe metadata for message thread queries
            updatePadMetadata(loaded.padIndex);
        }
        loaded = LoadedSample{};  // Clear slot for reuse
    };

    // Process both contiguous blocks
    for (int i = 0; i < size1; ++i)
        applyLoad(loadQueue[start1 + i]);

    for (int i = 0; i < size2; ++i)
        applyLoad(loadQueue[start2 + i]);

    loadFifo.finishedRead(size1 + size2);
}

// =============================================================================
// COMMAND QUEUE (Thread-safe message-to-audio operations)
// =============================================================================

void Processor::queueCommand(PadCommand cmd)
{
    // Called from message thread - queue command for audio thread
    // CRITICAL: Mutex required because multiple message threads can call concurrently
    std::lock_guard<std::mutex> lock(commandFifoWriteMutex);

    int start1, size1, start2, size2;
    commandFifo.prepareToWrite(1, start1, size1, start2, size2);

    if (size1 > 0)
    {
        commandQueue[start1] = cmd;
        commandFifo.finishedWrite(1);
    }
    else
    {
        // FIFO full - increment dropped counter for diagnostics
        droppedCommands.fetch_add(1, std::memory_order_relaxed);
    }
}

void Processor::applyQueuedCommands()
{
    // Called from audio thread at start of processBlock
    const int numReady = juce::jmin(commandFifo.getNumReady(), MAX_COMMANDS_PER_BLOCK);
    if (numReady == 0)
        return;

    int start1, size1, start2, size2;
    commandFifo.prepareToRead(numReady, start1, size1, start2, size2);

    auto processCommand = [this](const PadCommand& cmd)
    {
        switch (cmd.type)
        {
            case PadCommandType::Trigger:
                if (cmd.padIndex >= 0 && cmd.padIndex < NUM_PADS)
                {
                    updatePadParameters(cmd.padIndex);
                    processKillGroups(cmd.padIndex);
                    pads[cmd.padIndex].trigger(cmd.velocity);
                }
                break;

            case PadCommandType::Stop:
                if (cmd.padIndex >= 0 && cmd.padIndex < NUM_PADS)
                    pads[cmd.padIndex].stop();
                break;

            case PadCommandType::Release:
                if (cmd.padIndex >= 0 && cmd.padIndex < NUM_PADS)
                    pads[cmd.padIndex].forceRelease();
                break;

            case PadCommandType::StopAll:
                for (auto& pad : pads)
                    pad.stop();
                break;

            case PadCommandType::ReleaseAll:
                for (auto& pad : pads)
                    pad.forceRelease();
                break;

            case PadCommandType::ClearLayer:
                if (cmd.padIndex >= 0 && cmd.padIndex < NUM_PADS)
                {
                    pads[cmd.padIndex].clearSample(cmd.layerIndex);
                    updatePadMetadataAfterClear(cmd.padIndex, cmd.layerIndex);
                }
                break;

            case PadCommandType::ClearRoundRobin:
                if (cmd.padIndex >= 0 && cmd.padIndex < NUM_PADS)
                {
                    pads[cmd.padIndex].clearRoundRobin(cmd.layerIndex);
                    updatePadMetadataAfterClear(cmd.padIndex, cmd.layerIndex);
                }
                break;

            case PadCommandType::ClearPad:
                if (cmd.padIndex >= 0 && cmd.padIndex < NUM_PADS)
                {
                    for (int layer = 0; layer < NUM_VELOCITY_LAYERS; ++layer)
                        pads[cmd.padIndex].clearSample(layer);
                    updatePadMetadata(cmd.padIndex);
                }
                break;
        }
    };

    for (int i = 0; i < size1; ++i)
        processCommand(commandQueue[start1 + i]);

    for (int i = 0; i < size2; ++i)
        processCommand(commandQueue[start2 + i]);

    commandFifo.finishedRead(size1 + size2);
}

// =============================================================================
// PAD METADATA (Thread-safe snapshots for message thread queries)
// =============================================================================

void Processor::updatePadMetadata(int padIndex)
{
    if (padIndex < 0 || padIndex >= NUM_PADS)
        return;

    // Called from audio thread - write to back buffer, then swap atomically
    // CRITICAL: Must copy ALL pads from read to write buffer first to prevent
    // stale data when swapping. Without this, other pads' data could become
    // outdated after the swap.
    const int currentReadIndex = metadataBuffers.readIndex.load(std::memory_order_acquire);
    const int writeIndex = 1 - currentReadIndex;

    // Copy entire buffer to maintain consistency for all pads
    // This is O(NUM_PADS) but only happens during sample loading (rare)
    metadataBuffers.buffers[writeIndex] = metadataBuffers.buffers[currentReadIndex];

    // Now update the specific pad
    auto& meta = metadataBuffers.buffers[writeIndex][padIndex];
    auto& pad = pads[padIndex];

    meta.hasSample = false;

    for (int layer = 0; layer < NUM_VELOCITY_LAYERS; ++layer)
    {
        meta.samplePaths[layer] = pad.getSamplePath(layer);
        meta.roundRobinPaths[layer] = pad.getRoundRobinPaths(layer);
        meta.roundRobinCounts[layer] = pad.getRoundRobinCount(layer);
        meta.sampleDurations[layer] = pad.getSampleDuration(layer);
        meta.hasLayerSample[layer] = pad.hasSample(layer);

        if (meta.hasLayerSample[layer])
            meta.hasSample = true;
    }

    // Atomically swap the read index so message thread sees the new data
    metadataBuffers.readIndex.store(writeIndex, std::memory_order_release);
}

void Processor::updatePadMetadataAfterClear(int padIndex, int layerIndex)
{
    if (padIndex < 0 || padIndex >= NUM_PADS)
        return;
    if (layerIndex < 0 || layerIndex >= NUM_VELOCITY_LAYERS)
        return;

    // Called from audio thread - write to back buffer, then swap atomically
    const int currentReadIndex = metadataBuffers.readIndex.load(std::memory_order_acquire);
    const int writeIndex = 1 - currentReadIndex;

    // CRITICAL: Copy entire buffer to prevent stale data for other pads
    metadataBuffers.buffers[writeIndex] = metadataBuffers.buffers[currentReadIndex];

    // Now update only the affected pad/layer
    auto& meta = metadataBuffers.buffers[writeIndex][padIndex];
    auto& pad = pads[padIndex];

    // Update only the affected layer (rest was copied above)
    meta.samplePaths[layerIndex] = pad.getSamplePath(layerIndex);
    meta.roundRobinPaths[layerIndex] = pad.getRoundRobinPaths(layerIndex);
    meta.roundRobinCounts[layerIndex] = pad.getRoundRobinCount(layerIndex);
    meta.sampleDurations[layerIndex] = pad.getSampleDuration(layerIndex);
    meta.hasLayerSample[layerIndex] = pad.hasSample(layerIndex);

    // Recalculate hasSample for this pad
    meta.hasSample = false;
    for (int layer = 0; layer < NUM_VELOCITY_LAYERS; ++layer)
    {
        if (meta.hasLayerSample[layer])
        {
            meta.hasSample = true;
            break;
        }
    }

    // Atomically swap the read index
    metadataBuffers.readIndex.store(writeIndex, std::memory_order_release);
}

// =============================================================================
// BUS LAYOUT
// =============================================================================

bool Processor::isBusesLayoutSupported(const BusesLayout& layouts) const
{
    // Main output must be stereo
    if (layouts.getMainOutputChannelSet() != juce::AudioChannelSet::stereo())
        return false;

    // Group buses must be stereo or disabled
    const int numBuses = static_cast<int>(layouts.outputBuses.size());
    for (int i = 1; i < numBuses; ++i)
    {
        const auto& bus = layouts.outputBuses[i];
        if (!bus.isDisabled() && bus != juce::AudioChannelSet::stereo())
            return false;
    }

    return true;
}

// =============================================================================
// STATE PERSISTENCE
// =============================================================================

void Processor::getStateInformation(juce::MemoryBlock& destData)
{
    auto state = parameters.copyState();

    // Add sample paths as child nodes (both primary and round-robin)
    // THREAD SAFETY: Read from front buffer (lock-free, audio thread writes to back)
    juce::ValueTree samplesNode("Samples");
    {
        const int readIdx = metadataBuffers.readIndex.load(std::memory_order_acquire);
        for (int pad = 0; pad < NUM_PADS; ++pad)
        {
            const auto& meta = metadataBuffers.buffers[readIdx][pad];
            for (int layer = 0; layer < NUM_VELOCITY_LAYERS; ++layer)
            {
                // Primary sample
                const auto& path = meta.samplePaths[layer];
                if (path.isNotEmpty())
                {
                    juce::ValueTree sampleNode("Sample");
                    sampleNode.setProperty("pad", pad, nullptr);
                    sampleNode.setProperty("layer", layer, nullptr);
                    sampleNode.setProperty("path", path, nullptr);
                    samplesNode.addChild(sampleNode, -1, nullptr);
                }

                // Round-robin samples
                const auto& rrPaths = meta.roundRobinPaths[layer];
                for (const auto& rrPath : rrPaths)
                {
                    juce::ValueTree rrNode("RoundRobin");
                    rrNode.setProperty("pad", pad, nullptr);
                    rrNode.setProperty("layer", layer, nullptr);
                    rrNode.setProperty("path", rrPath, nullptr);
                    samplesNode.addChild(rrNode, -1, nullptr);
                }
            }
        }
    }
    state.addChild(samplesNode, -1, nullptr);

    std::unique_ptr<juce::XmlElement> xml(state.createXml());
    copyXmlToBinary(*xml, destData);
}

void Processor::setStateInformation(const void* data, int sizeInBytes)
{
    std::unique_ptr<juce::XmlElement> xml(getXmlFromBinary(data, sizeInBytes));
    if (xml && xml->hasTagName(parameters.state.getType()))
    {
        auto state = juce::ValueTree::fromXml(*xml);

        // Process runtime commands (transient, don't persist)
        auto commandsNode = state.getChildWithName("Commands");
        if (commandsNode.isValid())
        {
            for (int i = 0; i < commandsNode.getNumChildren(); ++i)
            {
                auto cmd = commandsNode.getChild(i);
                juce::String cmdType = cmd.getType().toString();

                if (cmdType == "LoadSample")
                {
                    int pad = cmd.getProperty("pad", -1);
                    int layer = cmd.getProperty("layer", 0);
                    juce::String path = cmd.getProperty("path", "");

                    if (pad >= 0 && pad < NUM_PADS &&
                        layer >= 0 && layer < NUM_VELOCITY_LAYERS)
                    {
                        if (path.isEmpty())
                            queueCommand({ PadCommandType::ClearLayer, pad, 0, layer });
                        else
                            loadSampleToPadAsync(pad, layer, path, false);
                    }
                }
                else if (cmdType == "ClearPad")
                {
                    int pad = cmd.getProperty("pad", -1);
                    if (pad >= 0 && pad < NUM_PADS)
                        queueCommand({ PadCommandType::ClearPad, pad, 0, 0 });
                }
                else if (cmdType == "ClearAll")
                {
                    for (int pad = 0; pad < NUM_PADS; ++pad)
                        queueCommand({ PadCommandType::ClearPad, pad, 0, 0 });
                }
            }

            state.removeChild(commandsNode, nullptr);
        }

        parameters.replaceState(state);

        // Reload samples from stored paths (async to avoid blocking message thread)
        auto samplesNode = state.getChildWithName("Samples");
        if (samplesNode.isValid())
        {
            for (int i = 0; i < samplesNode.getNumChildren(); ++i)
            {
                auto sampleNode = samplesNode.getChild(i);
                int pad = sampleNode.getProperty("pad", -1);
                int layer = sampleNode.getProperty("layer", 0);
                juce::String path = sampleNode.getProperty("path", "");
                juce::String nodeType = sampleNode.getType().toString();

                if (pad >= 0 && pad < NUM_PADS && path.isNotEmpty())
                {
                    bool isRoundRobin = (nodeType == "RoundRobin");
                    loadSampleToPadAsync(pad, layer, path, isRoundRobin);
                }
            }
        }
    }
}

// =============================================================================
// NAMED CONFIG PARAMS (REAPER/Lua integration)
// =============================================================================

// Helper to parse P{pad}_L{layer}_{suffix} pattern
// Returns true if valid, fills padIndex and layerIndex
bool Processor::parsePadLayerParam(const juce::String& name,
                                   const juce::String& suffix,
                                   int& padIndex,
                                   int& layerIndex)
{
    if (!name.startsWith("P") || !name.contains("_L") || !name.endsWith(suffix))
        return false;

    int underscorePos = name.indexOf("_");
    if (underscorePos <= 1)
        return false;

    // Validate pad index is digits only and not too long (prevent overflow)
    juce::String padStr = name.substring(1, underscorePos);
    if (!padStr.containsOnly("0123456789") || padStr.length() > 3)
        return false;
    padIndex = padStr.getIntValue();

    int lPos = name.indexOf("_L") + 2;
    int secondUnderscorePos = name.indexOf(lPos, "_");
    if (secondUnderscorePos <= lPos)
        return false;

    // Validate layer index is digits only and not too long (prevent overflow)
    juce::String layerStr = name.substring(lPos, secondUnderscorePos);
    if (!layerStr.containsOnly("0123456789") || layerStr.length() > 1)
        return false;
    layerIndex = layerStr.getIntValue();

    return padIndex >= 0 && padIndex < NUM_PADS &&
           layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS;
}

bool Processor::handleNamedConfigParam(const juce::String& name, const juce::String& value)
{
    int padIndex, layerIndex;

    // Pattern: P{pad}_L{layer}_SAMPLE_ASYNC (async load)
    // Note: Clear is queued to audio thread for thread safety
    if (parsePadLayerParam(name, "_SAMPLE_ASYNC", padIndex, layerIndex))
    {
        if (value.isEmpty())
            queueCommand({ PadCommandType::ClearLayer, padIndex, 0, layerIndex });
        else
            loadSampleToPadAsync(padIndex, layerIndex, value, false);
        return true;
    }

    // Pattern: P{pad}_L{layer}_RR_ASYNC (async round-robin add)
    if (parsePadLayerParam(name, "_RR_ASYNC", padIndex, layerIndex))
    {
        if (value.isNotEmpty())
            loadSampleToPadAsync(padIndex, layerIndex, value, true);
        return true;
    }

    // Pattern: P{pad}_L{layer}_CLEAR_RR (clear round-robin samples)
    // Note: Queued to audio thread for thread safety
    if (parsePadLayerParam(name, "_CLEAR_RR", padIndex, layerIndex))
    {
        queueCommand({ PadCommandType::ClearRoundRobin, padIndex, 0, layerIndex });
        return true;
    }

    // Pattern: P{pad}_L{layer}_SAMPLE (now uses async for thread safety)
    // Note: Previously sync, now routes through async path to avoid thread issues
    if (parsePadLayerParam(name, "_SAMPLE", padIndex, layerIndex))
    {
        if (value.isEmpty())
            queueCommand({ PadCommandType::ClearLayer, padIndex, 0, layerIndex });
        else
            loadSampleToPadAsync(padIndex, layerIndex, value, false);
        return true;
    }

    // Pattern: P{pad}_CLEAR (min length: "P0_CLEAR" = 8)
    // Note: Queued to audio thread for thread safety
    if (name.length() >= 8 && name.startsWith("P") && name.endsWith("_CLEAR"))
    {
        juce::String padStr = name.substring(1, name.length() - 6);
        if (padStr.containsOnly("0123456789"))
        {
            padIndex = padStr.getIntValue();
            if (padIndex >= 0 && padIndex < NUM_PADS)
            {
                queueCommand({ PadCommandType::ClearPad, padIndex, 0, 0 });
                return true;
            }
        }
    }

    // Pattern: P{pad}_PREVIEW (min length: "P0_PREVIEW" = 10)
    // Note: Command queued for audio thread to avoid thread safety issues
    if (name.length() >= 10 && name.startsWith("P") && name.endsWith("_PREVIEW"))
    {
        juce::String padStr = name.substring(1, name.length() - 8);
        if (padStr.containsOnly("0123456789"))
        {
            padIndex = padStr.getIntValue();
            if (padIndex >= 0 && padIndex < NUM_PADS)
            {
                int velocity = value.isEmpty() ? 100 : juce::jlimit(1, 127, value.getIntValue());
                queueCommand({ PadCommandType::Trigger, padIndex, velocity });
                return true;
            }
        }
    }

    // Pattern: P{pad}_STOP (min length: "P0_STOP" = 7)
    // Note: Command queued for audio thread to avoid thread safety issues
    if (name.length() >= 7 && name.startsWith("P") && name.endsWith("_STOP"))
    {
        juce::String padStr = name.substring(1, name.length() - 5);
        if (padStr.containsOnly("0123456789"))
        {
            padIndex = padStr.getIntValue();
            if (padIndex >= 0 && padIndex < NUM_PADS)
            {
                queueCommand({ PadCommandType::Stop, padIndex, 0 });
                return true;
            }
        }
    }

    // Pattern: P{pad}_RELEASE (min length: "P0_RELEASE" = 10) - graceful fade-out
    // Note: Command queued for audio thread to avoid thread safety issues
    if (name.length() >= 10 && name.startsWith("P") && name.endsWith("_RELEASE"))
    {
        juce::String padStr = name.substring(1, name.length() - 8);
        if (padStr.containsOnly("0123456789"))
        {
            padIndex = padStr.getIntValue();
            if (padIndex >= 0 && padIndex < NUM_PADS)
            {
                queueCommand({ PadCommandType::Release, padIndex, 0 });
                return true;
            }
        }
    }

    // Pattern: STOP_ALL (stop all pads immediately)
    // Note: Command queued for audio thread to avoid thread safety issues
    if (name == "STOP_ALL")
    {
        queueCommand({ PadCommandType::StopAll, -1, 0 });
        return true;
    }

    // Pattern: RELEASE_ALL (graceful fade-out for all playing pads)
    // Note: Command queued for audio thread to avoid thread safety issues
    if (name == "RELEASE_ALL")
    {
        queueCommand({ PadCommandType::ReleaseAll, -1, 0 });
        return true;
    }

    return false;
}

juce::String Processor::getNamedConfigParam(const juce::String& name) const
{
    int padIndex, layerIndex;

    // Helper lambda to get metadata buffer pointer with atomic index load
    // THREAD SAFETY: readIndex is loaded once, and that buffer won't be modified
    // until the audio thread swaps (which won't happen mid-read due to atomic ordering)
    auto getReadBuffer = [this]() -> const std::array<PadMetadata, NUM_PADS>& {
        const int readIdx = metadataBuffers.readIndex.load(std::memory_order_acquire);
        return metadataBuffers.buffers[readIdx];
    };

    // Pattern: P{pad}_L{layer}_SAMPLE
    // THREAD SAFETY: Copy string to ensure no reference issues
    if (parsePadLayerParam(name, "_SAMPLE", padIndex, layerIndex))
    {
        jassert(padIndex >= 0 && padIndex < NUM_PADS);
        jassert(layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS);
        return juce::String(getReadBuffer()[padIndex].samplePaths[layerIndex]);
    }

    // Pattern: P{pad}_L{layer}_RR_COUNT (get round-robin sample count)
    if (parsePadLayerParam(name, "_RR_COUNT", padIndex, layerIndex))
    {
        jassert(padIndex >= 0 && padIndex < NUM_PADS);
        jassert(layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS);
        return juce::String(getReadBuffer()[padIndex].roundRobinCounts[layerIndex]);
    }

    // Pattern: P{pad}_L{layer}_DURATION (get sample duration in seconds)
    if (parsePadLayerParam(name, "_DURATION", padIndex, layerIndex))
    {
        jassert(padIndex >= 0 && padIndex < NUM_PADS);
        jassert(layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS);
        return juce::String(getReadBuffer()[padIndex].sampleDurations[layerIndex], 3);
    }

    // Pattern: P{pad}_HAS_SAMPLE (min length: "P0_HAS_SAMPLE" = 13)
    if (name.length() >= 13 && name.startsWith("P") && name.endsWith("_HAS_SAMPLE"))
    {
        juce::String padStr = name.substring(1, name.length() - 11);
        if (padStr.containsOnly("0123456789"))
        {
            padIndex = padStr.getIntValue();
            if (padIndex >= 0 && padIndex < NUM_PADS)
            {
                return getReadBuffer()[padIndex].hasSample ? "1" : "0";
            }
        }
    }

    // Pattern: P{pad}_IS_PLAYING (min length: "P0_IS_PLAYING" = 13)
    // Note: isPlaying is atomic, so no lock needed
    if (name.length() >= 13 && name.startsWith("P") && name.endsWith("_IS_PLAYING"))
    {
        juce::String padStr = name.substring(1, name.length() - 11);
        if (padStr.containsOnly("0123456789"))
        {
            padIndex = padStr.getIntValue();
            if (padIndex >= 0 && padIndex < NUM_PADS)
                return pads[padIndex].isPlaying ? "1" : "0";
        }
    }

    // Diagnostic counters for debugging FIFO overflow issues
    if (name == "DROPPED_LOADS")
        return juce::String(droppedLoads.load(std::memory_order_relaxed));

    if (name == "DROPPED_COMMANDS")
        return juce::String(droppedCommands.load(std::memory_order_relaxed));

    // Reset diagnostic counters (write empty string to reset)
    // Note: These are handled in handleNamedConfigParam, but we return current value here

    return {};
}

}  // namespace BlockSampler

// =============================================================================
// PLUGIN ENTRY POINT
// =============================================================================

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new BlockSampler::Processor();
}
