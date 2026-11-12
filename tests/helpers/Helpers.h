/*
  ==============================================================================

   YUP Plugin Template - shared test helpers.

   Small, header-only utilities shared by the plugin tests: block analysis
   helpers, a one-call processing wrapper, and factories that hand back a
   prepared processor (and a processor paired with a constructed editor) so
   individual tests stay focused on the behaviour under test.

   Only the desktop plugin tests include this header; the header-only DSP tests
   (which also build under Emscripten) do not depend on it.

  ==============================================================================
*/

#pragma once

#include "PluginEditor.h"
#include "PluginProcessor.h"

#include <algorithm>
#include <cmath>
#include <memory>

namespace test
{

//==============================================================================
/** Largest absolute sample value across every channel of a buffer. */
inline float blockPeak (const yup::AudioBuffer<float>& audio)
{
    float peak = 0.0f;
    for (int channel = 0; channel < audio.getNumChannels(); ++channel)
    {
        const auto* data = audio.getReadPointer (channel);
        for (int sample = 0; sample < audio.getNumSamples(); ++sample)
            peak = std::max (peak, std::abs (data[sample]));
    }
    return peak;
}

/** True when every sample across every channel is finite (no NaN / inf). */
inline bool blockIsFinite (const yup::AudioBuffer<float>& audio)
{
    for (int channel = 0; channel < audio.getNumChannels(); ++channel)
    {
        const auto* data = audio.getReadPointer (channel);
        for (int sample = 0; sample < audio.getNumSamples(); ++sample)
            if (! std::isfinite (data[sample]))
                return false;
    }
    return true;
}

/** Renders a single block through the processor with the given MIDI events. */
inline void renderBlock (PluginProcessor& processor, yup::AudioBuffer<float>& audio, yup::MidiBuffer& midi)
{
    yup::ParameterChangeBuffer params;
    yup::AudioProcessContext<float> context { audio, midi, params };
    processor.processBlock (context);
}

//==============================================================================
/** Returns a processor already prepared for the given sample rate / block size. */
inline std::unique_ptr<PluginProcessor> makePreparedProcessor (float sampleRate = 48000.0f, int blockSize = 512)
{
    auto processor = std::make_unique<PluginProcessor>();
    processor->prepareToPlay (yup::AudioSpec (sampleRate, blockSize));
    return processor;
}

/** A processor paired with a constructed editor, so editor tests have a live
    processor context without repeating the wiring in every case. The editor is
    destroyed before the processor (declaration order), matching host teardown.
*/
struct EditorContext
{
    explicit EditorContext (float sampleRate = 48000.0f, int blockSize = 512)
    {
        processor.prepareToPlay (yup::AudioSpec (sampleRate, blockSize));
    }

    PluginProcessor processor;
    PluginEditor editor { processor };
};

} // namespace test
