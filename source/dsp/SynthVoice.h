/*
  ==============================================================================

   YUP Plugin Template - a simple polyphonic instrument.

   This header holds the whole sound engine. It depends only on the C++ standard
   library, so it can be unit tested on its own, without the audio or GUI modules.

  ==============================================================================
*/

#pragma once

#include <array>
#include <cmath>
#include <cstddef>

//==============================================================================
/** The oscillator shapes the instrument can play. Keep the order stable: the
    values are the automation values of the "waveform" parameter.
*/
enum class SynthWaveform
{
    sine = 0,
    saw = 1,
    square = 2
};

//==============================================================================
/** One sounding note: an oscillator plus a linear attack/release envelope.

    A voice is silent until noteOn() starts it and keeps sounding, releasing, until
    its envelope reaches zero. renderSample() advances it by a single frame.
*/
class SynthVoice
{
public:
    SynthVoice() = default;

    /** Prepares the voice for a sample rate, clearing any sound. */
    void prepare (double newSampleRate) noexcept
    {
        sampleRate = newSampleRate > 0.0 ? newSampleRate : 44100.0;
        reset();
    }

    /** Silences the voice immediately. */
    void reset() noexcept
    {
        stage = Stage::idle;
        phase = 0.0;
        level = 0.0f;
        noteNumber = -1;
    }

    /** Returns true when the voice is producing (or finishing) sound. */
    bool isActive() const noexcept { return stage != Stage::idle; }

    /** Returns the MIDI note the voice is playing, or -1 when idle. */
    int getNoteNumber() const noexcept { return noteNumber; }

    /** Starts a note, entering the attack stage. */
    void noteOn (int midiNoteNumber, float velocity) noexcept
    {
        noteNumber = midiNoteNumber;
        velocityGain = velocity;
        phase = 0.0;
        phaseIncrement = midiNoteToHertz (midiNoteNumber) / sampleRate;
        stage = Stage::attack;
    }

    /** Releases the note, entering the release stage. */
    void noteOff() noexcept
    {
        if (stage != Stage::idle)
            stage = Stage::release;
    }

    /** Sets the attack and release times, in seconds. */
    void setEnvelope (float attackSeconds, float releaseSeconds) noexcept
    {
        attackRate = rateForTime (attackSeconds);
        releaseRate = rateForTime (releaseSeconds);
    }

    /** Selects the oscillator shape. */
    void setWaveform (SynthWaveform newWaveform) noexcept { waveform = newWaveform; }

    /** Advances the envelope and returns the next mono sample. */
    float renderSample() noexcept
    {
        if (stage == Stage::idle)
            return 0.0f;

        switch (stage)
        {
            case Stage::attack:
                level += attackRate;
                if (level >= 1.0f)
                {
                    level = 1.0f;
                    stage = Stage::sustain;
                }
                break;

            case Stage::release:
                level -= releaseRate;
                if (level <= 0.0f)
                {
                    reset();
                    return 0.0f;
                }
                break;

            case Stage::sustain:
            case Stage::idle:
            default:
                break;
        }

        const auto sample = oscillator();

        phase += phaseIncrement;
        if (phase >= 1.0)
            phase -= 1.0;

        return sample * level * velocityGain;
    }

    /** Converts a MIDI note number to a frequency in Hertz (A4 = 69 = 440 Hz). */
    static double midiNoteToHertz (int midiNoteNumber, double frequencyOfA = 440.0) noexcept
    {
        return frequencyOfA * std::pow (2.0, (midiNoteNumber - 69) / 12.0);
    }

private:
    enum class Stage
    {
        idle,
        attack,
        sustain,
        release
    };

    float oscillator() const noexcept
    {
        switch (waveform)
        {
            case SynthWaveform::saw:
                return static_cast<float> (2.0 * phase - 1.0);

            case SynthWaveform::square:
                return phase < 0.5 ? 1.0f : -1.0f;

            case SynthWaveform::sine:
            default:
                return static_cast<float> (std::sin (phase * 2.0 * 3.14159265358979323846));
        }
    }

    float rateForTime (float timeSeconds) const noexcept
    {
        const auto samples = static_cast<double> (timeSeconds) * sampleRate;
        return samples > 1.0 ? static_cast<float> (1.0 / samples) : 1.0f;
    }

    double sampleRate = 44100.0;
    double phase = 0.0;
    double phaseIncrement = 0.0;
    float level = 0.0f;
    float velocityGain = 1.0f;
    float attackRate = 0.01f;
    float releaseRate = 0.001f;
    int noteNumber = -1;
    Stage stage = Stage::idle;
    SynthWaveform waveform = SynthWaveform::sine;
};

//==============================================================================
/** A fixed pool of voices that turns MIDI notes into audio.

    The engine owns the polyphony: it picks a free (or the oldest) voice for each
    note on, releases the matching voice on note off, and sums every voice into the
    output. It is header-only and standard-library only, so it is unit tested
    directly.
*/
template <std::size_t numVoices = 16>
class SynthEngine
{
public:
    SynthEngine() = default;

    /** Prepares every voice for a sample rate. */
    void prepare (double sampleRate) noexcept
    {
        for (auto& voice : voices)
            voice.prepare (sampleRate);
    }

    /** Silences every voice. */
    void reset() noexcept
    {
        for (auto& voice : voices)
            voice.reset();
    }

    /** Applies the attack and release times, in seconds, to every voice. */
    void setEnvelope (float attackSeconds, float releaseSeconds) noexcept
    {
        for (auto& voice : voices)
            voice.setEnvelope (attackSeconds, releaseSeconds);
    }

    /** Selects the oscillator shape for every voice. */
    void setWaveform (SynthWaveform waveform) noexcept
    {
        for (auto& voice : voices)
            voice.setWaveform (waveform);
    }

    /** Starts a note on a free voice, stealing the first voice when all are busy. */
    void noteOn (int midiNoteNumber, float velocity) noexcept
    {
        SynthVoice* target = nullptr;

        for (auto& voice : voices)
        {
            if (! voice.isActive())
            {
                target = &voice;
                break;
            }
        }

        if (target == nullptr)
            target = &voices[stealIndex++ % numVoices];

        target->noteOn (midiNoteNumber, velocity);
    }

    /** Releases every voice currently playing a note. */
    void noteOff (int midiNoteNumber) noexcept
    {
        for (auto& voice : voices)
            if (voice.isActive() && voice.getNoteNumber() == midiNoteNumber)
                voice.noteOff();
    }

    /** Releases every sounding voice. */
    void allNotesOff() noexcept
    {
        for (auto& voice : voices)
            voice.noteOff();
    }

    /** Returns the summed output of every voice for the next frame. */
    float renderSample() noexcept
    {
        float sample = 0.0f;
        for (auto& voice : voices)
            sample += voice.renderSample();

        return sample;
    }

    /** Returns how many voices are currently sounding. */
    int getNumActiveVoices() const noexcept
    {
        int count = 0;
        for (const auto& voice : voices)
            if (voice.isActive())
                ++count;

        return count;
    }

private:
    std::array<SynthVoice, numVoices> voices;
    std::size_t stealIndex = 0;
};
