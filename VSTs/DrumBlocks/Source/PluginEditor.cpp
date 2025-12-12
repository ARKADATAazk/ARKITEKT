// =============================================================================
// DrumBlocks/Source/PluginEditor.cpp
// Minimal editor UI - directs users to the Lua script interface
// =============================================================================

#include "PluginEditor.h"

namespace DrumBlocks
{

Editor::Editor(Processor& p)
    : AudioProcessorEditor(p), processor(p)
{
    setSize(400, 200);
    setResizable(false, false);
}

void Editor::paint(juce::Graphics& g)
{
    // Dark background
    g.fillAll(juce::Colour(0xFF1A1A1A));

    auto bounds = getLocalBounds();

    // Footer (reserve space first)
    auto footerArea = bounds.removeFromBottom(20);
    g.setColour(juce::Colour(0xFF555555));
    g.setFont(juce::Font(11.0f));
    g.drawText("ARKADATA", footerArea, juce::Justification::centred);

    // Content area with padding
    bounds.reduce(20, 15);

    // Title
    g.setColour(juce::Colour(0xFFFFFFFF));
    g.setFont(juce::Font(22.0f, juce::Font::bold));
    g.drawText("DrumBlocks", bounds.removeFromTop(28), juce::Justification::centred);

    // Subtitle
    g.setColour(juce::Colour(0xFF888888));
    g.setFont(juce::Font(12.0f));
    g.drawText("128-Pad Drum Sampler", bounds.removeFromTop(18), juce::Justification::centred);

    // Spacing
    bounds.removeFromTop(15);

    // Main message
    g.setColour(juce::Colour(0xFFAAAAAA));
    g.setFont(juce::Font(13.0f));
    g.drawFittedText(
        "This VST is controlled by the DrumBlocks Lua script.\n\n"
        "Run the script from REAPER's Actions menu to access\n"
        "the full pad grid, sample browser, and controls.",
        bounds,
        juce::Justification::centredTop,
        4
    );
}

}  // namespace DrumBlocks
