cmake_minimum_required(VERSION 3.22)

project(BlockSampler VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Fetch JUCE
include(FetchContent)
FetchContent_Declare(
    JUCE
    GIT_REPOSITORY https://github.com/juce-framework/JUCE.git
    GIT_TAG        8.0.11
)
FetchContent_MakeAvailable(JUCE)

# Fetch clap-juce-extensions for CLAP support
# Note: Using main branch as there are no formal releases and JUCE 8 support
# requires recent commits. Monitor for breaking changes.
FetchContent_Declare(
    clap-juce-extensions
    GIT_REPOSITORY https://github.com/free-audio/clap-juce-extensions.git
    GIT_TAG        main
)
FetchContent_MakeAvailable(clap-juce-extensions)

# Plugin formats (platform-specific)
if(APPLE)
    set(BLOCKSAMPLER_FORMATS VST3 AU Standalone)
else()
    set(BLOCKSAMPLER_FORMATS VST3 Standalone)
endif()

# Plugin target
juce_add_plugin(BlockSampler
    COMPANY_NAME "ARKITEKT"
    PLUGIN_MANUFACTURER_CODE Arkt
    PLUGIN_CODE Bsmp

    # Formats to build
    FORMATS ${BLOCKSAMPLER_FORMATS}

    # Plugin info
    PRODUCT_NAME "BlockSampler"
    DESCRIPTION "128-pad drum sampler for DrumBlocks"

    # Multi-out: 1 main stereo + 16 group stereo = 17 stereo buses
    VST3_AUTO_MANIFEST FALSE

    # No editor - DrumBlocks is the UI
    EDITOR_WANTS_KEYBOARD_FOCUS FALSE

    IS_SYNTH TRUE
    NEEDS_MIDI_INPUT TRUE
    NEEDS_MIDI_OUTPUT FALSE
    IS_MIDI_EFFECT FALSE
)

# Add CLAP format via clap-juce-extensions
clap_juce_extensions_plugin(
    TARGET BlockSampler
    CLAP_ID "com.arkitekt.blocksampler"
    CLAP_FEATURES instrument sampler drum
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

# =============================================================================
# UNIT TESTS (Optional - build with -DBUILD_TESTS=ON)
# =============================================================================

option(BUILD_TESTS "Build unit tests" OFF)

if(BUILD_TESTS)
    # Fetch Catch2
    FetchContent_Declare(
        Catch2
        GIT_REPOSITORY https://github.com/catchorg/Catch2.git
        GIT_TAG        v3.5.2
    )
    FetchContent_MakeAvailable(Catch2)

    # Test executable
    add_executable(BlockSamplerTests
        Tests/TestMain.cpp
        Tests/PadTests.cpp
        Source/Pad.cpp
    )

    target_include_directories(BlockSamplerTests
        PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}/Source
    )

    target_link_libraries(BlockSamplerTests
        PRIVATE
            Catch2::Catch2WithMain
            juce::juce_audio_basics
            juce::juce_audio_formats
            juce::juce_core
            juce::juce_dsp
    )

    target_compile_definitions(BlockSamplerTests
        PRIVATE
            JUCE_STANDALONE_APPLICATION=1
            JUCE_WEB_BROWSER=0
            JUCE_USE_CURL=0
    )

    # Enable CTest integration
    include(CTest)
    include(Catch)
    catch_discover_tests(BlockSamplerTests)
endif()
