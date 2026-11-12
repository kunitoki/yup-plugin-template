/*
  ==============================================================================

   YUP Plugin Template - DSP micro-benchmarks.

   These benchmarks exercise the header-only sound engine (source/dsp) in
   isolation, so they depend only on google/benchmark and the C++ standard
   library. Run them with `just bench` (or build the `*_benchmarks` target with
   -DBUILD_BENCHMARKS=ON and execute it directly).

  ==============================================================================
*/

#include <benchmark/benchmark.h>

#include "dsp/SynthVoice.h"

#include <cstddef>
#include <cstdint>

namespace
{
constexpr double sampleRate = 48000.0;

//==============================================================================
void BM_SynthVoiceRender (benchmark::State& state)
{
    const auto blockSize = static_cast<std::size_t> (state.range (0));

    SynthVoice voice;
    voice.prepare (sampleRate);
    voice.noteOn (69, 1.0f);

    for (auto _ : state)
    {
        float acc = 0.0f;
        for (std::size_t i = 0; i < blockSize; ++i)
            acc += voice.renderSample();

        benchmark::DoNotOptimize (acc);
    }

    state.SetItemsProcessed (state.iterations() * static_cast<std::int64_t> (blockSize));
}

BENCHMARK (BM_SynthVoiceRender)->RangeMultiplier (4)->Range (64, 4096);

//==============================================================================
void BM_SynthEngineRenderPolyphonic (benchmark::State& state)
{
    const auto blockSize = static_cast<std::size_t> (state.range (0));

    SynthEngine engine;
    engine.prepare (sampleRate);
    engine.setWaveform (SynthWaveform::saw);

    for (int note = 48; note < 72; ++note)
        engine.noteOn (note, 0.8f);

    for (auto _ : state)
    {
        float acc = 0.0f;
        for (std::size_t i = 0; i < blockSize; ++i)
            acc += engine.renderSample();

        benchmark::DoNotOptimize (acc);
    }

    state.SetItemsProcessed (state.iterations() * static_cast<std::int64_t> (blockSize));
}

BENCHMARK (BM_SynthEngineRenderPolyphonic)->RangeMultiplier (4)->Range (64, 4096);

//==============================================================================
void BM_SynthEngineNoteAllocation (benchmark::State& state)
{
    SynthEngine engine;
    engine.prepare (sampleRate);

    int note = 36;
    for (auto _ : state)
    {
        engine.noteOn (note, 1.0f);
        engine.noteOff (note);
        note = note >= 96 ? 36 : note + 1;
        benchmark::DoNotOptimize (engine.getNumActiveVoices());
    }
}

BENCHMARK (BM_SynthEngineNoteAllocation);

} // namespace
