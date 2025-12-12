// =============================================================================
// DrumBlocks/Source/PluginEditor.h
// Minimal editor UI - directs users to the Lua script interface
// =============================================================================

#pragma once

#include <juce_audio_processors/juce_audio_processors.h>
#include <juce_graphics/juce_graphics.h>
#include "PluginProcessor.h"

namespace DrumBlocks
{

class Editor : public juce::AudioProcessorEditor
{
public:
    explicit Editor(Processor& p);
    ~Editor() override = default;

    void paint(juce::Graphics& g) override;
    void resized() override {}

private:
    Processor& processor;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(Editor)
};

}  // namespace DrumBlocks
