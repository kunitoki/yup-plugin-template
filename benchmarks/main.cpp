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

BENCHMARK_MAIN();
