#include "PluginProcessor.h"

namespace BlockSampler
{

Processor::Processor()
    : AudioProcessor(BusesProperties()
          // Main stereo output (always enabled)
          .withOutput("Main", juce::AudioChannelSet::stereo(), true)
          // 16 group buses for routing (disabled by default, user enables as needed)
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
    // Register audio formats
    formatManager.registerBasicFormats();

    // Cache parameter pointers and add listeners
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
        padParams[pad].killGroup = parameters.getRawParameterValue(PadParam::id(pad, PadParam::KillGroup));
        padParams[pad].outputGroup = parameters.getRawParameterValue(PadParam::id(pad, PadParam::OutputGroup));
        padParams[pad].oneShot = parameters.getRawParameterValue(PadParam::id(pad, PadParam::OneShot));
        padParams[pad].reverse = parameters.getRawParameterValue(PadParam::id(pad, PadParam::Reverse));

        // Add listener for all params
        for (int p = 0; p < PadParam::COUNT; ++p)
        {
            parameters.addParameterListener(PadParam::id(pad, static_cast<PadParam::ID>(p)), this);
        }
    }
}

Processor::~Processor()
{
    // Remove parameter listeners
    for (int pad = 0; pad < NUM_PADS; ++pad)
    {
        for (int p = 0; p < PadParam::COUNT; ++p)
        {
            parameters.removeParameterListener(PadParam::id(pad, static_cast<PadParam::ID>(p)), this);
        }
    }
}

void Processor::prepareToPlay(double sampleRate, int samplesPerBlock)
{
    for (auto& pad : pads)
    {
        pad.prepare(sampleRate, samplesPerBlock);
    }

    // Initial parameter sync
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

    // Clear output buffer
    buffer.clear();

    // Process MIDI
    for (const auto metadata : midiMessages)
    {
        handleMidiEvent(metadata.getMessage());
    }

    // Update parameters from automation
    for (int i = 0; i < NUM_PADS; ++i)
    {
        updatePadParameters(i);
    }

    // Render each pad to main output
    // TODO: Add multi-out support (render to separate buses)
    for (int i = 0; i < NUM_PADS; ++i)
    {
        pads[i].renderNextBlock(buffer, 0, buffer.getNumSamples());
    }
}

void Processor::handleMidiEvent(const juce::MidiMessage& msg)
{
    if (msg.isNoteOn())
    {
        int note = msg.getNoteNumber();
        int padIndex = note - MIDI_NOTE_OFFSET;

        if (padIndex >= 0 && padIndex < NUM_PADS)
        {
            // Process kill groups first
            processKillGroups(padIndex);

            // Trigger the pad
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
        return;  // No kill group

    for (int i = 0; i < NUM_PADS; ++i)
    {
        if (i != triggeredPad && pads[i].killGroup == killGroup && pads[i].isPlaying)
        {
            pads[i].stop();
        }
    }
}

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
    pad.killGroup = static_cast<int>(params.killGroup->load());
    pad.outputGroup = static_cast<int>(params.outputGroup->load());
    pad.oneShot = params.oneShot->load() > 0.5f;
    pad.reverse = params.reverse->load() > 0.5f;
}

void Processor::parameterChanged(const juce::String& parameterID, float /*newValue*/)
{
    // Extract pad index from parameter ID (e.g., "p5_volume" -> 5)
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

bool Processor::isBusesLayoutSupported(const BusesLayout& layouts) const
{
    // Main output must be stereo
    if (layouts.getMainOutputChannelSet() != juce::AudioChannelSet::stereo())
        return false;

    // All other buses (per-pad outputs) must be stereo or disabled
    for (int i = 1; i < layouts.outputBuses.size(); ++i)
    {
        const auto& bus = layouts.outputBuses[i];
        if (!bus.isDisabled() && bus != juce::AudioChannelSet::stereo())
            return false;
    }

    return true;
}

void Processor::getStateInformation(juce::MemoryBlock& destData)
{
    // Save parameters
    auto state = parameters.copyState();

    // Add sample paths
    for (int pad = 0; pad < NUM_PADS; ++pad)
    {
        // TODO: Store sample file paths in state
        // state.setProperty("p" + String(pad) + "_sample0", pads[pad].layers[0].filePath, nullptr);
    }

    std::unique_ptr<juce::XmlElement> xml(state.createXml());
    copyXmlToBinary(*xml, destData);
}

void Processor::setStateInformation(const void* data, int sizeInBytes)
{
    std::unique_ptr<juce::XmlElement> xml(getXmlFromBinary(data, sizeInBytes));
    if (xml && xml->hasTagName(parameters.state.getType()))
    {
        parameters.replaceState(juce::ValueTree::fromXml(*xml));

        // TODO: Reload samples from paths stored in state
    }
}

}  // namespace BlockSampler

// Plugin entry point
juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new BlockSampler::Processor();
}
