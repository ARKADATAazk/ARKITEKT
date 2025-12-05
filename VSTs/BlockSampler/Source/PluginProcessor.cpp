// =============================================================================
// BlockSampler/Source/PluginProcessor.cpp
// Main VST3 processor implementation
// =============================================================================

#include "PluginProcessor.h"

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

    // Cache parameter pointers and register listeners
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
        padParams[pad].oneShot = parameters.getRawParameterValue(PadParam::id(pad, PadParam::OneShot));
        padParams[pad].reverse = parameters.getRawParameterValue(PadParam::id(pad, PadParam::Reverse));
        padParams[pad].normalize = parameters.getRawParameterValue(PadParam::id(pad, PadParam::Normalize));
        padParams[pad].sampleStart = parameters.getRawParameterValue(PadParam::id(pad, PadParam::SampleStart));
        padParams[pad].sampleEnd = parameters.getRawParameterValue(PadParam::id(pad, PadParam::SampleEnd));
        padParams[pad].roundRobinMode = parameters.getRawParameterValue(PadParam::id(pad, PadParam::RoundRobinMode));

        for (int p = 0; p < PadParam::COUNT; ++p)
        {
            parameters.addParameterListener(PadParam::id(pad, static_cast<PadParam::ID>(p)), this);
        }
    }
}

Processor::~Processor()
{
    loadPool.removeAllJobs(true, 1000);  // Wait up to 1s for jobs to finish

    for (int pad = 0; pad < NUM_PADS; ++pad)
    {
        for (int p = 0; p < PadParam::COUNT; ++p)
        {
            parameters.removeParameterListener(PadParam::id(pad, static_cast<PadParam::ID>(p)), this);
        }
    }
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

    // Apply any completed async sample loads (thread-safe: only audio thread consumes)
    applyCompletedLoads();

    const int numSamples = buffer.getNumSamples();

    // Clear all output channels (buffer.clear() handles all buses)
    buffer.clear();

    // Process MIDI events (update parameters for triggered pads)
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
    pad.oneShot = params.oneShot->load() > 0.5f;
    pad.reverse = params.reverse->load() > 0.5f;
    pad.normalize = params.normalize->load() > 0.5f;
    pad.sampleStart = params.sampleStart->load();
    pad.sampleEnd = params.sampleEnd->load();
    pad.roundRobinMode = static_cast<int>(params.roundRobinMode->load());
}

void Processor::parameterChanged(const juce::String& parameterID, float /*newValue*/)
{
    // Parse pad index from ID: "p{pad}_{param}"
    if (parameterID.startsWith("p") && parameterID.contains("_"))
    {
        int underscorePos = parameterID.indexOf("_");
        int padIndex = parameterID.substring(1, underscorePos).getIntValue();

        if (padIndex >= 0 && padIndex < NUM_PADS)
        {
            updatePadParameters(padIndex);
        }
    }
}

// =============================================================================
// SAMPLE MANAGEMENT
// =============================================================================

bool Processor::loadSampleToPad(int padIndex, int layerIndex, const juce::String& filePath)
{
    if (padIndex < 0 || padIndex >= NUM_PADS)
        return false;

    juce::File file(filePath);
    if (!file.existsAsFile())
        return false;

    return pads[padIndex].loadSample(layerIndex, file, formatManager);
}

void Processor::clearPadSample(int padIndex, int layerIndex)
{
    if (padIndex >= 0 && padIndex < NUM_PADS)
    {
        pads[padIndex].clearSample(layerIndex);
    }
}

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

    loadPool.addJob([=]()
    {
        // Load sample in background thread
        std::unique_ptr<juce::AudioFormatReader> reader(fmt->createReaderFor(file));
        if (!reader)
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

        // Queue result for audio thread via lock-free FIFO
        int start1, size1, start2, size2;
        fifo->prepareToWrite(1, start1, size1, start2, size2);

        if (size1 > 0)
        {
            (*queue)[start1] = std::move(result);
            fifo->finishedWrite(1);
        }
        // If FIFO is full, drop the load (will be retried by user)
    });
}

// =============================================================================
// ASYNC LOAD COMPLETION (Called at start of processBlock - audio thread)
// =============================================================================

void Processor::applyCompletedLoads()
{
    int start1, size1, start2, size2;
    loadFifo.prepareToRead(loadFifo.getNumReady(), start1, size1, start2, size2);

    // Process first contiguous block
    for (int i = 0; i < size1; ++i)
    {
        auto& loaded = loadQueue[start1 + i];

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
        }

        // Clear the slot for reuse
        loaded = LoadedSample{};
    }

    // Process second contiguous block (wrap-around)
    for (int i = 0; i < size2; ++i)
    {
        auto& loaded = loadQueue[start2 + i];

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
        }

        // Clear the slot for reuse
        loaded = LoadedSample{};
    }

    loadFifo.finishedRead(size1 + size2);
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
    for (int i = 1; i < layouts.outputBuses.size(); ++i)
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

    // Add sample paths as child nodes
    juce::ValueTree samplesNode("Samples");
    for (int pad = 0; pad < NUM_PADS; ++pad)
    {
        for (int layer = 0; layer < NUM_VELOCITY_LAYERS; ++layer)
        {
            auto path = pads[pad].getSamplePath(layer);
            if (path.isNotEmpty())
            {
                juce::ValueTree sampleNode("Sample");
                sampleNode.setProperty("pad", pad, nullptr);
                sampleNode.setProperty("layer", layer, nullptr);
                sampleNode.setProperty("path", path, nullptr);
                samplesNode.addChild(sampleNode, -1, nullptr);
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

                    if (pad >= 0 && pad < NUM_PADS)
                    {
                        if (path.isEmpty())
                            clearPadSample(pad, layer);
                        else
                            loadSampleToPad(pad, layer, path);
                    }
                }
                else if (cmdType == "ClearPad")
                {
                    int pad = cmd.getProperty("pad", -1);
                    if (pad >= 0 && pad < NUM_PADS)
                    {
                        for (int layer = 0; layer < NUM_VELOCITY_LAYERS; ++layer)
                            clearPadSample(pad, layer);
                    }
                }
                else if (cmdType == "ClearAll")
                {
                    for (int pad = 0; pad < NUM_PADS; ++pad)
                        for (int layer = 0; layer < NUM_VELOCITY_LAYERS; ++layer)
                            clearPadSample(pad, layer);
                }
            }

            state.removeChild(commandsNode, nullptr);
        }

        parameters.replaceState(state);

        // Reload samples from stored paths
        auto samplesNode = state.getChildWithName("Samples");
        if (samplesNode.isValid())
        {
            for (int i = 0; i < samplesNode.getNumChildren(); ++i)
            {
                auto sampleNode = samplesNode.getChild(i);
                int pad = sampleNode.getProperty("pad", -1);
                int layer = sampleNode.getProperty("layer", 0);
                juce::String path = sampleNode.getProperty("path", "");

                if (pad >= 0 && pad < NUM_PADS && path.isNotEmpty())
                {
                    loadSampleToPad(pad, layer, path);
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

    padIndex = name.substring(1, underscorePos).getIntValue();

    int lPos = name.indexOf("_L") + 2;
    int secondUnderscorePos = name.indexOf(lPos, "_");
    if (secondUnderscorePos <= lPos)
        return false;

    layerIndex = name.substring(lPos, secondUnderscorePos).getIntValue();

    return padIndex >= 0 && padIndex < NUM_PADS &&
           layerIndex >= 0 && layerIndex < NUM_VELOCITY_LAYERS;
}

bool Processor::handleNamedConfigParam(const juce::String& name, const juce::String& value)
{
    int padIndex, layerIndex;

    // Pattern: P{pad}_L{layer}_SAMPLE_ASYNC (async load)
    if (parsePadLayerParam(name, "_SAMPLE_ASYNC", padIndex, layerIndex))
    {
        if (value.isEmpty())
            clearPadSample(padIndex, layerIndex);
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
    if (parsePadLayerParam(name, "_CLEAR_RR", padIndex, layerIndex))
    {
        pads[padIndex].clearRoundRobin(layerIndex);
        return true;
    }

    // Pattern: P{pad}_L{layer}_SAMPLE (sync load)
    if (parsePadLayerParam(name, "_SAMPLE", padIndex, layerIndex))
    {
        if (value.isEmpty())
            clearPadSample(padIndex, layerIndex);
        else
            loadSampleToPad(padIndex, layerIndex, value);
        return true;
    }

    // Pattern: P{pad}_CLEAR
    if (name.startsWith("P") && name.endsWith("_CLEAR"))
    {
        padIndex = name.substring(1, name.length() - 6).getIntValue();
        if (padIndex >= 0 && padIndex < NUM_PADS)
        {
            for (int layer = 0; layer < NUM_VELOCITY_LAYERS; ++layer)
                clearPadSample(padIndex, layer);
            return true;
        }
    }

    // Pattern: P{pad}_PREVIEW (trigger pad for preview, value = velocity 1-127, default 100)
    if (name.startsWith("P") && name.endsWith("_PREVIEW"))
    {
        padIndex = name.substring(1, name.length() - 8).getIntValue();
        if (padIndex >= 0 && padIndex < NUM_PADS)
        {
            int velocity = value.isEmpty() ? 100 : juce::jlimit(1, 127, value.getIntValue());
            updatePadParameters(padIndex);
            processKillGroups(padIndex);
            pads[padIndex].trigger(velocity);
            return true;
        }
    }

    // Pattern: P{pad}_STOP (stop pad playback)
    if (name.startsWith("P") && name.endsWith("_STOP"))
    {
        padIndex = name.substring(1, name.length() - 5).getIntValue();
        if (padIndex >= 0 && padIndex < NUM_PADS)
        {
            pads[padIndex].stop();
            return true;
        }
    }

    // Pattern: STOP_ALL (stop all pads)
    if (name == "STOP_ALL")
    {
        for (auto& pad : pads)
            pad.stop();
        return true;
    }

    return false;
}

juce::String Processor::getNamedConfigParam(const juce::String& name) const
{
    int padIndex, layerIndex;

    // Pattern: P{pad}_L{layer}_SAMPLE
    if (parsePadLayerParam(name, "_SAMPLE", padIndex, layerIndex))
        return pads[padIndex].getSamplePath(layerIndex);

    // Pattern: P{pad}_L{layer}_RR_COUNT (get round-robin sample count)
    if (parsePadLayerParam(name, "_RR_COUNT", padIndex, layerIndex))
        return juce::String(pads[padIndex].getRoundRobinCount(layerIndex));

    // Pattern: P{pad}_L{layer}_DURATION (get sample duration in seconds)
    if (parsePadLayerParam(name, "_DURATION", padIndex, layerIndex))
        return juce::String(pads[padIndex].getSampleDuration(layerIndex), 3);

    // Pattern: P{pad}_HAS_SAMPLE
    if (name.startsWith("P") && name.endsWith("_HAS_SAMPLE"))
    {
        padIndex = name.substring(1, name.length() - 11).getIntValue();
        if (padIndex >= 0 && padIndex < NUM_PADS)
        {
            for (int layer = 0; layer < NUM_VELOCITY_LAYERS; ++layer)
            {
                if (pads[padIndex].hasSample(layer))
                    return "1";
            }
            return "0";
        }
    }

    // Pattern: P{pad}_IS_PLAYING
    if (name.startsWith("P") && name.endsWith("_IS_PLAYING"))
    {
        padIndex = name.substring(1, name.length() - 11).getIntValue();
        if (padIndex >= 0 && padIndex < NUM_PADS)
            return pads[padIndex].isPlaying ? "1" : "0";
    }

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
