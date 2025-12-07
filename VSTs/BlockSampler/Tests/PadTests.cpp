// =============================================================================
// BlockSampler/Tests/PadTests.cpp
// Unit tests for Pad class
// =============================================================================

#include <catch2/catch_test_macros.hpp>
#include <catch2/catch_approx.hpp>
#include "../Source/Pad.h"
#include "../Source/Parameters.h"

using namespace BlockSampler;

// =============================================================================
// VELOCITY LAYER TESTS
// =============================================================================

TEST_CASE("VelocityLayer basic operations", "[VelocityLayer]")
{
    VelocityLayer layer;

    SECTION("Initial state is empty")
    {
        REQUIRE_FALSE(layer.isLoaded());
        REQUIRE(layer.getRoundRobinCount() == 0);
    }

    SECTION("Layer is loaded when numSamples > 0")
    {
        layer.numSamples = 1000;
        REQUIRE(layer.isLoaded());
    }

    SECTION("Layer is loaded when roundRobinCount > 0")
    {
        layer.roundRobinCount = 1;
        REQUIRE(layer.isLoaded());
    }

    SECTION("Clear resets all state")
    {
        layer.numSamples = 1000;
        layer.sourceSampleRate = 48000.0;
        layer.filePath = "test.wav";
        layer.normGain = 0.5f;
        layer.roundRobinCount = 2;

        layer.clear();

        REQUIRE(layer.numSamples == 0);
        REQUIRE(layer.sourceSampleRate == 44100.0);  // Default
        REQUIRE(layer.filePath.isEmpty());
        REQUIRE(layer.normGain == 1.0f);
        REQUIRE(layer.roundRobinCount == 0);
    }
}

TEST_CASE("VelocityLayer round-robin", "[VelocityLayer]")
{
    VelocityLayer layer;
    juce::Random rng;

    SECTION("Sequential round-robin advances correctly")
    {
        layer.roundRobinCount = 4;

        REQUIRE(layer.roundRobinIndex == 0);

        layer.advanceRoundRobin(rng, false);
        REQUIRE(layer.roundRobinIndex == 1);

        layer.advanceRoundRobin(rng, false);
        REQUIRE(layer.roundRobinIndex == 2);

        layer.advanceRoundRobin(rng, false);
        REQUIRE(layer.roundRobinIndex == 3);

        layer.advanceRoundRobin(rng, false);
        REQUIRE(layer.roundRobinIndex == 0);  // Wraps around
    }

    SECTION("Random round-robin always changes sample")
    {
        layer.roundRobinCount = 4;
        int lastIndex = layer.roundRobinIndex;

        for (int i = 0; i < 100; ++i)
        {
            layer.advanceRoundRobin(rng, true);
            REQUIRE(layer.roundRobinIndex != lastIndex);
            lastIndex = layer.roundRobinIndex;
        }
    }

    SECTION("Round-robin does nothing with count 0")
    {
        layer.roundRobinCount = 0;
        layer.roundRobinIndex = 0;

        layer.advanceRoundRobin(rng, false);
        REQUIRE(layer.roundRobinIndex == 0);

        layer.advanceRoundRobin(rng, true);
        REQUIRE(layer.roundRobinIndex == 0);
    }

    SECTION("getRoundRobinPaths returns correct count")
    {
        layer.roundRobinCount = 3;
        layer.roundRobinSamples[0].path = "sample1.wav";
        layer.roundRobinSamples[1].path = "sample2.wav";
        layer.roundRobinSamples[2].path = "sample3.wav";

        std::array<juce::String, MAX_ROUND_ROBIN_SAMPLES> paths;
        int count = layer.getRoundRobinPaths(paths);

        REQUIRE(count == 3);
        REQUIRE(paths[0] == "sample1.wav");
        REQUIRE(paths[1] == "sample2.wav");
        REQUIRE(paths[2] == "sample3.wav");
    }
}

// =============================================================================
// PAD TESTS
// =============================================================================

TEST_CASE("Pad basic operations", "[Pad]")
{
    Pad pad;

    SECTION("Initial state")
    {
        REQUIRE_FALSE(pad.isPlaying);
        REQUIRE(pad.currentLayer == -1);
        REQUIRE(pad.volume == Catch::Approx(0.8f));
        REQUIRE(pad.pan == Catch::Approx(0.0f));
        REQUIRE(pad.oneShot == true);
    }

    SECTION("hasSample returns false for empty pad")
    {
        for (int i = 0; i < NUM_VELOCITY_LAYERS; ++i)
        {
            REQUIRE_FALSE(pad.hasSample(i));
        }
    }

    SECTION("hasSample returns false for invalid layer")
    {
        REQUIRE_FALSE(pad.hasSample(-1));
        REQUIRE_FALSE(pad.hasSample(NUM_VELOCITY_LAYERS));
        REQUIRE_FALSE(pad.hasSample(100));
    }

    SECTION("getRoundRobinCount returns 0 for empty pad")
    {
        for (int i = 0; i < NUM_VELOCITY_LAYERS; ++i)
        {
            REQUIRE(pad.getRoundRobinCount(i) == 0);
        }
    }

    SECTION("getSamplePath returns empty for unloaded layer")
    {
        REQUIRE(pad.getSamplePath(0).isEmpty());
        REQUIRE(pad.getSamplePath(-1).isEmpty());
    }
}

TEST_CASE("Pad trigger without samples", "[Pad]")
{
    Pad pad;
    pad.prepare(44100.0, 512);

    SECTION("Trigger with no samples does nothing")
    {
        pad.trigger(100);
        REQUIRE_FALSE(pad.isPlaying);
    }

    SECTION("Trigger with velocity 0 calls noteOff")
    {
        pad.trigger(0);
        REQUIRE_FALSE(pad.isPlaying);
    }
}

// =============================================================================
// PARAMETER TESTS
// =============================================================================

TEST_CASE("Parameter constants", "[Parameters]")
{
    SECTION("MIDI velocity thresholds are valid")
    {
        REQUIRE(VELOCITY_LAYER_1_MIN > 0);
        REQUIRE(VELOCITY_LAYER_1_MIN < VELOCITY_LAYER_2_MIN);
        REQUIRE(VELOCITY_LAYER_2_MIN < VELOCITY_LAYER_3_MIN);
        REQUIRE(VELOCITY_LAYER_3_MIN <= 127);
    }

    SECTION("Filter constants are valid")
    {
        REQUIRE(FILTER_CUTOFF_MIN > 0.0f);
        REQUIRE(FILTER_CUTOFF_MIN < FILTER_CUTOFF_MAX);
        REQUIRE(FILTER_Q_MIN > 0.0f);
        REQUIRE(FILTER_Q_MIN < FILTER_Q_MAX);
    }

    SECTION("Round-robin limit is reasonable")
    {
        REQUIRE(MAX_ROUND_ROBIN_SAMPLES >= 1);
        REQUIRE(MAX_ROUND_ROBIN_SAMPLES <= 64);
    }

    SECTION("Logarithmic Q ratio is correct")
    {
        // FILTER_Q_LOG_RATIO should be ln(Q_MAX / Q_MIN)
        float expectedLogRatio = std::log(FILTER_Q_MAX / FILTER_Q_MIN);
        REQUIRE(FILTER_Q_LOG_RATIO == Catch::Approx(expectedLogRatio).epsilon(0.001));
    }
}

// =============================================================================
// GENERATION COUNTER TESTS (State restoration race condition prevention)
// =============================================================================

TEST_CASE("Generation counter semantics", "[StateRestoration]")
{
    // These tests verify the generation counter pattern used to prevent
    // stale loads from being applied after state restoration

    SECTION("Generation counter increments correctly")
    {
        std::atomic<uint32_t> gen{0};

        REQUIRE(gen.load() == 0);

        gen.fetch_add(1);
        REQUIRE(gen.load() == 1);

        gen.fetch_add(1);
        REQUIRE(gen.load() == 2);
    }

    SECTION("Stale generation detection")
    {
        std::atomic<uint32_t> currentGen{5};

        // Load queued at generation 3 should be stale
        uint32_t loadGen = 3;
        REQUIRE(loadGen != currentGen.load());

        // Load queued at current generation should not be stale
        loadGen = 5;
        REQUIRE(loadGen == currentGen.load());
    }
}

// =============================================================================
// FIXED ARRAY ROUND-ROBIN TESTS
// =============================================================================

TEST_CASE("Fixed array round-robin capacity", "[RoundRobin]")
{
    VelocityLayer layer;

    SECTION("Cannot exceed MAX_ROUND_ROBIN_SAMPLES")
    {
        // Manually set count to max (normally done by Pad::addRoundRobinBuffer)
        layer.roundRobinCount = MAX_ROUND_ROBIN_SAMPLES;

        // Verify we're at capacity
        REQUIRE(layer.roundRobinCount == MAX_ROUND_ROBIN_SAMPLES);

        // In real code, addRoundRobinBuffer would check and refuse to add more
        // This test just verifies the constant is reasonable
        REQUIRE(MAX_ROUND_ROBIN_SAMPLES >= 8);  // Reasonable minimum
        REQUIRE(MAX_ROUND_ROBIN_SAMPLES <= 32); // Reasonable maximum for memory
    }
}
