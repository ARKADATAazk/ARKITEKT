// =============================================================================
// DrumBlocks/Source/SincInterpolator.h
// High-quality polyphase sinc interpolation for pitch shifting
// Professional-grade resampling with configurable quality levels
// =============================================================================

#pragma once

#include <cmath>
#include <array>

namespace DrumBlocks
{

// =============================================================================
// SINC INTERPOLATOR CONFIGURATION
// =============================================================================

// Quality levels: 8, 16, or 32 taps
constexpr int SINC_TAPS_NORMAL = 8;    // Fast - composing/live
constexpr int SINC_TAPS_HIGH = 16;     // Balanced - mixing (default)
constexpr int SINC_TAPS_ULTRA = 32;    // Best - mastering

constexpr int SINC_NUM_PHASES = 256;        // Sub-sample resolution (same for all)
constexpr float SINC_KAISER_BETA = 7.0f;    // Kaiser window shape

// Table sizes
constexpr int SINC_TABLE_SIZE_NORMAL = SINC_TAPS_NORMAL * SINC_NUM_PHASES;  // 2KB
constexpr int SINC_TABLE_SIZE_HIGH = SINC_TAPS_HIGH * SINC_NUM_PHASES;      // 4KB
constexpr int SINC_TABLE_SIZE_ULTRA = SINC_TAPS_ULTRA * SINC_NUM_PHASES;    // 8KB

// =============================================================================
// MATH HELPERS
// =============================================================================

// Modified Bessel function I0 (for Kaiser window)
inline double besselI0(double x)
{
    double sum = 1.0;
    double term = 1.0;
    const double x2_4 = (x * x) / 4.0;

    for (int k = 1; k < 25; ++k)
    {
        term *= x2_4 / (static_cast<double>(k) * static_cast<double>(k));
        sum += term;
        if (term < 1e-12 * sum)
            break;
    }
    return sum;
}

// Kaiser window function
inline double kaiserWindow(double n, double N, double beta)
{
    const double halfN = N / 2.0;
    const double normalized = (n - halfN) / halfN;
    // Clamp to prevent sqrt(negative) from floating-point edge cases
    const double sqrtArg = std::max(0.0, 1.0 - normalized * normalized);
    const double arg = beta * std::sqrt(sqrtArg);
    return besselI0(arg) / besselI0(beta);
}

// Sinc function with handling for x=0
inline double sinc(double x)
{
    if (std::abs(x) < 1e-10)
        return 1.0;
    const double pi_x = 3.14159265358979323846 * x;
    return std::sin(pi_x) / pi_x;
}

// =============================================================================
// TEMPLATED SINC TABLE GENERATOR
// =============================================================================

template<int NUM_TAPS>
class SincTableT
{
public:
    static constexpr int HALF_TAPS = NUM_TAPS / 2;
    static constexpr int TABLE_SIZE = NUM_TAPS * SINC_NUM_PHASES;

    std::array<float, TABLE_SIZE> coefficients;

    SincTableT()
    {
        generateTable();
    }

private:
    void generateTable()
    {
        const double invPhases = 1.0 / static_cast<double>(SINC_NUM_PHASES);
        const double filterLength = static_cast<double>(NUM_TAPS);

        for (int phase = 0; phase < SINC_NUM_PHASES; ++phase)
        {
            const double frac = static_cast<double>(phase) * invPhases;
            double sum = 0.0;

            for (int tap = 0; tap < NUM_TAPS; ++tap)
            {
                const double t = static_cast<double>(tap - HALF_TAPS) + (1.0 - frac);
                const double sincVal = sinc(t);
                const double windowVal = kaiserWindow(
                    static_cast<double>(tap) + frac,
                    filterLength,
                    static_cast<double>(SINC_KAISER_BETA)
                );
                const double coeff = sincVal * windowVal;

                coefficients[phase * NUM_TAPS + tap] = static_cast<float>(coeff);
                sum += coeff;
            }

            // Normalize for unity DC gain
            if (std::abs(sum) > 1e-10)
            {
                const float normFactor = static_cast<float>(1.0 / sum);
                for (int tap = 0; tap < NUM_TAPS; ++tap)
                    coefficients[phase * NUM_TAPS + tap] *= normFactor;
            }
        }
    }
};

// =============================================================================
// GLOBAL SINC TABLES (initialized on first use)
// =============================================================================

inline const SincTableT<SINC_TAPS_NORMAL>& getSincTableNormal()
{
    static const SincTableT<SINC_TAPS_NORMAL> table;
    return table;
}

inline const SincTableT<SINC_TAPS_HIGH>& getSincTableHigh()
{
    static const SincTableT<SINC_TAPS_HIGH> table;
    return table;
}

inline const SincTableT<SINC_TAPS_ULTRA>& getSincTableUltra()
{
    static const SincTableT<SINC_TAPS_ULTRA> table;
    return table;
}

// =============================================================================
// BOUNDARY REFLECTION HELPER
// =============================================================================

// Reflects sample position at boundaries for smoother interpolation near edges
// Uses reflection (mirror) padding: sample[-1] = sample[1], sample[N] = sample[N-2]
// This preserves continuity better than clamping (which repeats edge samples)
inline int reflectBoundary(int pos, int srcLen)
{
    if (pos < 0)
    {
        // Reflect: -1 -> 1, -2 -> 2, etc.
        pos = -pos;
        // Handle case where reflection still exceeds bounds (very small samples)
        if (pos >= srcLen)
            pos = srcLen - 1;
    }
    else if (pos >= srcLen)
    {
        // Reflect: srcLen -> srcLen-2, srcLen+1 -> srcLen-3, etc.
        pos = 2 * (srcLen - 1) - pos;
        // Handle case where reflection goes negative (very small samples)
        if (pos < 0)
            pos = 0;
    }
    return pos;
}

// =============================================================================
// INTERPOLATION FUNCTIONS - NORMAL (8-tap)
// =============================================================================

inline float sincInterpolateNormal(const float* src, int pos, float frac, int srcLen)
{
    const auto& table = getSincTableNormal();
    const int phase = static_cast<int>(frac * SINC_NUM_PHASES) & (SINC_NUM_PHASES - 1);
    const float* coeffs = &table.coefficients[phase * SINC_TAPS_NORMAL];
    const int startPos = pos - (SINC_TAPS_NORMAL / 2) + 1;

    float result = 0.0f;
    for (int i = 0; i < SINC_TAPS_NORMAL; ++i)
    {
        const int samplePos = startPos + i;
        const int reflectedPos = reflectBoundary(samplePos, srcLen);
        result += src[reflectedPos] * coeffs[i];
    }
    return result;
}

inline float sincInterpolateFastNormal(const float* src, int pos, float frac)
{
    const auto& table = getSincTableNormal();
    const int phase = static_cast<int>(frac * SINC_NUM_PHASES) & (SINC_NUM_PHASES - 1);
    const float* coeffs = &table.coefficients[phase * SINC_TAPS_NORMAL];
    const float* samples = src + pos - (SINC_TAPS_NORMAL / 2) + 1;

    return samples[0] * coeffs[0] + samples[1] * coeffs[1] +
           samples[2] * coeffs[2] + samples[3] * coeffs[3] +
           samples[4] * coeffs[4] + samples[5] * coeffs[5] +
           samples[6] * coeffs[6] + samples[7] * coeffs[7];
}

inline bool canUseFastSincNormal(int pos, int srcLen)
{
    return (pos >= SINC_TAPS_NORMAL / 2) && (pos < srcLen - SINC_TAPS_NORMAL / 2);
}

// =============================================================================
// INTERPOLATION FUNCTIONS - HIGH (16-tap)
// =============================================================================

inline float sincInterpolateHigh(const float* src, int pos, float frac, int srcLen)
{
    const auto& table = getSincTableHigh();
    const int phase = static_cast<int>(frac * SINC_NUM_PHASES) & (SINC_NUM_PHASES - 1);
    const float* coeffs = &table.coefficients[phase * SINC_TAPS_HIGH];
    const int startPos = pos - (SINC_TAPS_HIGH / 2) + 1;

    float result = 0.0f;
    for (int i = 0; i < SINC_TAPS_HIGH; ++i)
    {
        const int samplePos = startPos + i;
        const int reflectedPos = reflectBoundary(samplePos, srcLen);
        result += src[reflectedPos] * coeffs[i];
    }
    return result;
}

inline float sincInterpolateFastHigh(const float* src, int pos, float frac)
{
    const auto& table = getSincTableHigh();
    const int phase = static_cast<int>(frac * SINC_NUM_PHASES) & (SINC_NUM_PHASES - 1);
    const float* coeffs = &table.coefficients[phase * SINC_TAPS_HIGH];
    const float* samples = src + pos - (SINC_TAPS_HIGH / 2) + 1;

    return samples[0]  * coeffs[0]  + samples[1]  * coeffs[1]  +
           samples[2]  * coeffs[2]  + samples[3]  * coeffs[3]  +
           samples[4]  * coeffs[4]  + samples[5]  * coeffs[5]  +
           samples[6]  * coeffs[6]  + samples[7]  * coeffs[7]  +
           samples[8]  * coeffs[8]  + samples[9]  * coeffs[9]  +
           samples[10] * coeffs[10] + samples[11] * coeffs[11] +
           samples[12] * coeffs[12] + samples[13] * coeffs[13] +
           samples[14] * coeffs[14] + samples[15] * coeffs[15];
}

inline bool canUseFastSincHigh(int pos, int srcLen)
{
    return (pos >= SINC_TAPS_HIGH / 2) && (pos < srcLen - SINC_TAPS_HIGH / 2);
}

// =============================================================================
// INTERPOLATION FUNCTIONS - ULTRA (32-tap)
// =============================================================================

inline float sincInterpolateUltra(const float* src, int pos, float frac, int srcLen)
{
    const auto& table = getSincTableUltra();
    const int phase = static_cast<int>(frac * SINC_NUM_PHASES) & (SINC_NUM_PHASES - 1);
    const float* coeffs = &table.coefficients[phase * SINC_TAPS_ULTRA];
    const int startPos = pos - (SINC_TAPS_ULTRA / 2) + 1;

    float result = 0.0f;
    for (int i = 0; i < SINC_TAPS_ULTRA; ++i)
    {
        const int samplePos = startPos + i;
        const int reflectedPos = reflectBoundary(samplePos, srcLen);
        result += src[reflectedPos] * coeffs[i];
    }
    return result;
}

inline float sincInterpolateFastUltra(const float* src, int pos, float frac)
{
    const auto& table = getSincTableUltra();
    const int phase = static_cast<int>(frac * SINC_NUM_PHASES) & (SINC_NUM_PHASES - 1);
    const float* coeffs = &table.coefficients[phase * SINC_TAPS_ULTRA];
    const float* samples = src + pos - (SINC_TAPS_ULTRA / 2) + 1;

    // Unrolled 32-tap accumulation
    return samples[0]  * coeffs[0]  + samples[1]  * coeffs[1]  +
           samples[2]  * coeffs[2]  + samples[3]  * coeffs[3]  +
           samples[4]  * coeffs[4]  + samples[5]  * coeffs[5]  +
           samples[6]  * coeffs[6]  + samples[7]  * coeffs[7]  +
           samples[8]  * coeffs[8]  + samples[9]  * coeffs[9]  +
           samples[10] * coeffs[10] + samples[11] * coeffs[11] +
           samples[12] * coeffs[12] + samples[13] * coeffs[13] +
           samples[14] * coeffs[14] + samples[15] * coeffs[15] +
           samples[16] * coeffs[16] + samples[17] * coeffs[17] +
           samples[18] * coeffs[18] + samples[19] * coeffs[19] +
           samples[20] * coeffs[20] + samples[21] * coeffs[21] +
           samples[22] * coeffs[22] + samples[23] * coeffs[23] +
           samples[24] * coeffs[24] + samples[25] * coeffs[25] +
           samples[26] * coeffs[26] + samples[27] * coeffs[27] +
           samples[28] * coeffs[28] + samples[29] * coeffs[29] +
           samples[30] * coeffs[30] + samples[31] * coeffs[31];
}

inline bool canUseFastSincUltra(int pos, int srcLen)
{
    return (pos >= SINC_TAPS_ULTRA / 2) && (pos < srcLen - SINC_TAPS_ULTRA / 2);
}

// =============================================================================
// LEGACY COMPATIBILITY (default to High quality)
// =============================================================================

inline float sincInterpolate(const float* src, int pos, float frac, int srcLen)
{
    return sincInterpolateHigh(src, pos, frac, srcLen);
}

inline float sincInterpolateFast(const float* src, int pos, float frac)
{
    return sincInterpolateFastHigh(src, pos, frac);
}

inline bool canUseFastSinc(int pos, int srcLen)
{
    return canUseFastSincHigh(pos, srcLen);
}

// =============================================================================
// FUNCTION POINTER TYPES (for avoiding per-sample quality switch)
// =============================================================================

// Function pointer types for interpolation dispatch
using SincInterpolateFn = float (*)(const float*, int, float, int);
using SincInterpolateFastFn = float (*)(const float*, int, float);
using CanUseFastSincFn = bool (*)(int, int);

// Interpolation function set (selected once per render, used per-sample)
struct SincFunctions
{
    SincInterpolateFn interpolate;
    SincInterpolateFastFn interpolateFast;
    CanUseFastSincFn canUseFast;
};

// Get function set for quality level (call once at start of render loop)
inline SincFunctions getSincFunctions(int quality)
{
    switch (quality)
    {
        case 0:  // Normal (8-tap)
            return { sincInterpolateNormal, sincInterpolateFastNormal, canUseFastSincNormal };
        case 2:  // Ultra (32-tap)
            return { sincInterpolateUltra, sincInterpolateFastUltra, canUseFastSincUltra };
        case 1:  // High (16-tap) - default
        default:
            return { sincInterpolateHigh, sincInterpolateFastHigh, canUseFastSincHigh };
    }
}

}  // namespace DrumBlocks
