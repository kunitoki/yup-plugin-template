/*
  ==============================================================================

   YUP Plugin Template - TEST application.

   This application runs the test suite for the YUP Plugin Template using
   Google Test. Run this application with `just test` (or build the `*_tests`
   target with -DBUILD_TESTS=ON and execute it directly).

  ==============================================================================
*/

#include <gtest/gtest.h>

#include "helpers/Helpers.h"

#include "PluginProcessor.h"

#include <cmath>

using test::blockIsFinite;
using test::blockPeak;
using test::renderBlock;

TEST (PluginProcessor, ExposesFourParametersWithExpectedDefaults)
{
    PluginProcessor processor;

    const auto parameters = processor.getParameters();
    EXPECT_EQ (parameters.size(), 4u);

    const auto gain = processor.getParameterByID ("gain");
    const auto waveform = processor.getParameterByID ("waveform");
    const auto attack = processor.getParameterByID ("attack");
    const auto release = processor.getParameterByID ("release");

    ASSERT_NE (gain.get(), nullptr);
    ASSERT_NE (waveform.get(), nullptr);
    ASSERT_NE (attack.get(), nullptr);
    ASSERT_NE (release.get(), nullptr);

    EXPECT_EQ (gain->getHostParameterID(), static_cast<yup::uint32> (PluginProcessor::gainParam));
    EXPECT_EQ (waveform->getHostParameterID(), static_cast<yup::uint32> (PluginProcessor::waveformParam));
    EXPECT_EQ (attack->getHostParameterID(), static_cast<yup::uint32> (PluginProcessor::attackParam));
    EXPECT_EQ (release->getHostParameterID(), static_cast<yup::uint32> (PluginProcessor::releaseParam));

    EXPECT_FLOAT_EQ (gain->getValue(), 0.8f);
    EXPECT_FLOAT_EQ (waveform->getValue(), 0.0f);
    EXPECT_FLOAT_EQ (attack->getValue(), 5.0f);
    EXPECT_FLOAT_EQ (release->getValue(), 150.0f);
}

TEST (PluginProcessor, ReportsCapabilities)
{
    PluginProcessor processor;

    EXPECT_EQ (processor.getNumVoices(), static_cast<int> (PluginProcessor::numVoices));
    EXPECT_TRUE (processor.hasEditor());
    EXPECT_TRUE (processor.supportsDataTreeState());
    EXPECT_EQ (processor.getNumPresets(), 0);
    EXPECT_EQ (processor.getCurrentPreset(), 0);
    EXPECT_TRUE (processor.getPresetName (0).isEmpty());

    processor.setCurrentPreset (1);
    processor.setPresetName (0, "ignored");
    EXPECT_EQ (processor.getCurrentPreset(), 0);
}

TEST (PluginProcessor, NoteOnProducesFiniteSound)
{
    PluginProcessor processor;
    processor.prepareToPlay (yup::AudioSpec (48000.0f, 2048));

    yup::AudioBuffer<float> audio (2, 2048);
    yup::MidiBuffer midi;
    midi.addEvent (yup::MidiMessage::noteOn (1, 69, 1.0f), 0);

    renderBlock (processor, audio, midi);

    EXPECT_TRUE (blockIsFinite (audio));
    EXPECT_GT (blockPeak (audio), 0.01f);
}

TEST (PluginProcessor, SilentWithoutNotes)
{
    PluginProcessor processor;
    processor.prepareToPlay (yup::AudioSpec (48000.0f, 512));

    yup::AudioBuffer<float> audio (2, 512);
    yup::MidiBuffer midi;

    renderBlock (processor, audio, midi);

    EXPECT_TRUE (blockIsFinite (audio));
    EXPECT_FLOAT_EQ (blockPeak (audio), 0.0f);
}

TEST (PluginProcessor, AllNotesOffReleasesVoices)
{
    PluginProcessor processor;
    processor.prepareToPlay (yup::AudioSpec (48000.0f, 4096));

    processor.getParameterByID ("release")->setValue (1.0f);

    yup::AudioBuffer<float> onAudio (2, 4096);
    yup::MidiBuffer onMidi;
    onMidi.addEvent (yup::MidiMessage::noteOn (1, 69, 1.0f), 0);
    renderBlock (processor, onAudio, onMidi);
    EXPECT_GT (blockPeak (onAudio), 0.01f);

    yup::AudioBuffer<float> offAudio (2, 4096);
    yup::MidiBuffer offMidi;
    offMidi.addEvent (yup::MidiMessage::allNotesOff (1), 0);
    renderBlock (processor, offAudio, offMidi);

    yup::AudioBuffer<float> tailAudio (2, 4096);
    yup::MidiBuffer tailMidi;
    renderBlock (processor, tailAudio, tailMidi);

    EXPECT_TRUE (blockIsFinite (tailAudio));
    EXPECT_FLOAT_EQ (blockPeak (tailAudio), 0.0f);
}

TEST (PluginProcessor, StateRoundTripRestoresParameters)
{
    PluginProcessor processor;

    processor.getParameterByID ("gain")->setValue (0.5f);
    processor.getParameterByID ("waveform")->setValue (2.0f);
    processor.getParameterByID ("attack")->setValue (42.0f);
    processor.getParameterByID ("release")->setValue (321.0f);

    yup::DataTree state;
    EXPECT_TRUE (processor.saveStateIntoDataTree (state).wasOk());

    processor.getParameterByID ("gain")->setValue (0.1f);
    processor.getParameterByID ("waveform")->setValue (0.0f);
    processor.getParameterByID ("attack")->setValue (5.0f);
    processor.getParameterByID ("release")->setValue (150.0f);

    EXPECT_TRUE (processor.loadStateFromDataTree (state).wasOk());

    EXPECT_FLOAT_EQ (processor.getParameterByID ("gain")->getValue(), 0.5f);
    EXPECT_FLOAT_EQ (processor.getParameterByID ("waveform")->getValue(), 2.0f);
    EXPECT_FLOAT_EQ (processor.getParameterByID ("attack")->getValue(), 42.0f);
    EXPECT_FLOAT_EQ (processor.getParameterByID ("release")->getValue(), 321.0f);
}

TEST (PluginProcessor, ReleaseResourcesIsCallable)
{
    PluginProcessor processor;
    processor.prepareToPlay (yup::AudioSpec (48000.0f, 256));
    processor.releaseResources();

    yup::AudioBuffer<float> audio (2, 256);
    yup::MidiBuffer midi;
    processor.prepareToPlay (yup::AudioSpec (48000.0f, 256));
    renderBlock (processor, audio, midi);
    EXPECT_TRUE (blockIsFinite (audio));
}
