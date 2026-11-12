/*
  ==============================================================================

   YUP Plugin Template - TEST application.

   This application runs the test suite for the YUP Plugin Template using
   Google Test. Run this application with `just test` (or build the `*_tests`
   target with -DBUILD_TESTS=ON and execute it directly).

  ==============================================================================
*/

#include <gtest/gtest.h>

#include "dsp/SynthVoice.h"

#include <cmath>

namespace
{
float renderPeak (SynthEngine<>& engine, int numSamples)
{
    float peak = 0.0f;
    for (int i = 0; i < numSamples; ++i)
        peak = std::max (peak, std::abs (engine.renderSample()));

    return peak;
}
} // namespace

TEST (SynthVoice, MidiNoteToHertz)
{
    EXPECT_NEAR (SynthVoice::midiNoteToHertz (69), 440.0, 1e-6);
    EXPECT_NEAR (SynthVoice::midiNoteToHertz (57), 220.0, 1e-6);
    EXPECT_NEAR (SynthVoice::midiNoteToHertz (81), 880.0, 1e-6);
}

TEST (SynthVoice, StartsSilentAndIdle)
{
    SynthVoice voice;
    voice.prepare (48000.0);

    EXPECT_FALSE (voice.isActive());
    EXPECT_EQ (voice.getNoteNumber(), -1);
    EXPECT_FLOAT_EQ (voice.renderSample(), 0.0f);
}

TEST (SynthVoice, NoteOnProducesSoundThenReleaseSilences)
{
    SynthVoice voice;
    voice.prepare (48000.0);
    voice.setEnvelope (0.001f, 0.001f);
    voice.noteOn (69, 1.0f);

    EXPECT_TRUE (voice.isActive());
    EXPECT_EQ (voice.getNoteNumber(), 69);

    float peak = 0.0f;
    for (int i = 0; i < 4800; ++i)
        peak = std::max (peak, std::abs (voice.renderSample()));

    EXPECT_GT (peak, 0.1f);

    voice.noteOff();
    for (int i = 0; i < 4800; ++i)
        voice.renderSample();

    EXPECT_FALSE (voice.isActive());
}

TEST (SynthEngine, PolyphonyTracksActiveVoices)
{
    SynthEngine<> engine;
    engine.prepare (48000.0);
    engine.setEnvelope (0.01f, 0.1f);

    EXPECT_EQ (engine.getNumActiveVoices(), 0);

    engine.noteOn (60, 1.0f);
    engine.noteOn (64, 1.0f);
    engine.noteOn (67, 1.0f);
    EXPECT_EQ (engine.getNumActiveVoices(), 3);

    engine.noteOff (64);
    engine.renderSample();
    EXPECT_GE (engine.getNumActiveVoices(), 2);

    engine.allNotesOff();
    for (int i = 0; i < 48000; ++i)
        engine.renderSample();

    EXPECT_EQ (engine.getNumActiveVoices(), 0);
}

TEST (SynthEngine, WaveformSelectionRenders)
{
    for (auto waveform : { SynthWaveform::sine, SynthWaveform::saw, SynthWaveform::square })
    {
        SynthEngine<> engine;
        engine.prepare (48000.0);
        engine.setEnvelope (0.001f, 0.2f);
        engine.setWaveform (waveform);
        engine.noteOn (69, 1.0f);

        EXPECT_GT (renderPeak (engine, 4800), 0.1f);
    }
}
