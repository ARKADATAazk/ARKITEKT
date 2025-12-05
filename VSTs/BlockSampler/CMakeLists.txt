cmake_minimum_required(VERSION 3.22)

project(BlockSampler VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Fetch JUCE
include(FetchContent)
FetchContent_Declare(
    JUCE
    GIT_REPOSITORY https://github.com/juce-framework/JUCE.git
    GIT_TAG        7.0.9  # Or latest stable
)
FetchContent_MakeAvailable(JUCE)

# Plugin target
juce_add_plugin(BlockSampler
    COMPANY_NAME "ARKITEKT"
    PLUGIN_MANUFACTURER_CODE Arkt
    PLUGIN_CODE Bsmp

    # Formats to build
    FORMATS VST3 Standalone  # Add AU for Mac

    # Plugin info
    PRODUCT_NAME "BlockSampler"
    DESCRIPTION "16-pad drum sampler for DrumBlocks"

    # Multi-out: 1 main stereo + 16 pad stereo = 17 stereo buses
    VST3_AUTO_MANIFEST FALSE

    # No editor - DrumBlocks is the UI
    EDITOR_WANTS_KEYBOARD_FOCUS FALSE

    IS_SYNTH TRUE
    NEEDS_MIDI_INPUT TRUE
    NEEDS_MIDI_OUTPUT FALSE
    IS_MIDI_EFFECT FALSE
)

# Source files
target_sources(BlockSampler
    PRIVATE
        Source/PluginProcessor.cpp
        Source/Pad.cpp
)

# JUCE modules we need
target_link_libraries(BlockSampler
    PRIVATE
        juce::juce_audio_basics
        juce::juce_audio_devices
        juce::juce_audio_formats
        juce::juce_audio_plugin_client
        juce::juce_audio_processors
        juce::juce_audio_utils
        juce::juce_core
        juce::juce_dsp  # For StateVariableTPTFilter
    PUBLIC
        juce::juce_recommended_config_flags
        juce::juce_recommended_lto_flags
        juce::juce_recommended_warning_flags
)

# Compile definitions
target_compile_definitions(BlockSampler
    PUBLIC
        JUCE_WEB_BROWSER=0
        JUCE_USE_CURL=0
        JUCE_VST3_CAN_REPLACE_VST2=0
        JUCE_DISPLAY_SPLASH_SCREEN=0
)
