/*
  ==============================================================================

   YUP Plugin Template - the audio processor.

  ==============================================================================
*/

#include "PluginProcessor.h"
#include "PluginEditor.h"

namespace
{
constexpr float millisecondsToSeconds = 0.001f;

yup::AudioParameter::Ptr addSynthParameter (PluginProcessor& processor,
                                            const yup::String& id,
                                            const yup::String& name,
                                            yup::uint32 hostID,
                                            yup::NormalisableRange<float> range,
                                            float defaultValue,
                                            yup::AudioParameter::ParameterUnit unit = yup::AudioParameter::ParameterUnit::Generic,
                                            yup::StringArray enumNames = {})
{
    auto metadata = yup::AudioParameter::Metadata {};
    metadata.name = name;
    metadata.hostParameterID = hostID;
    metadata.valueRange = range;
    metadata.defaultValue = defaultValue;
    metadata.modulePath = "Main";
    metadata.unit = unit;

    yup::AudioParameter::ValueToString valueToString;
    yup::AudioParameter::StringToValue stringToValue;

    if (! enumNames.isEmpty())
    {
        metadata.setStepped (true);
        metadata.setEnum (true);

        valueToString = [enumNames] (float value) -> yup::String
        {
            return enumNames[yup::jlimit (0, enumNames.size() - 1, yup::roundToInt (value))];
        };

        stringToValue = [enumNames] (const yup::String& text) -> float
        {
            return static_cast<float> (yup::jmax (0, enumNames.indexOf (text)));
        };
    }
    else
    {
        // Percent parameters are stored as a 0..1 gain but shown as 0..100 %.
        const auto isPercent = unit == yup::AudioParameter::ParameterUnit::Percent;
        const yup::String suffix (yup::AudioParameter::getParameterUnitShortName (unit));

        valueToString = [isPercent, suffix] (float value) -> yup::String
        {
            const auto displayValue = isPercent ? value * 100.0f : value;
            auto text = yup::String (displayValue, isPercent ? 0 : 2);

            if (suffix.isNotEmpty())
                text << " " << suffix;

            return text;
        };

        stringToValue = [isPercent] (const yup::String& text) -> float
        {
            const auto parsed = text.getFloatValue();
            return isPercent ? parsed * 0.01f : parsed;
        };
    }

    yup::AudioParameter::Ptr parameter = new yup::AudioParameter (id, metadata, valueToString, stringToValue);
    processor.addParameter (parameter);
    return parameter;
}
} // namespace

//==============================================================================
yup::AudioBusLayout PluginProcessor::makeBusLayout()
{
    return yup::AudioBusLayout (
        {},
        { yup::AudioBus ("Output", yup::AudioBus::Type::Audio, yup::AudioBus::Direction::Output, 2) });
}

//==============================================================================
PluginProcessor::PluginProcessor()
    : yup::AudioProcessor ("YupPlugin", makeBusLayout())
{
    gain = addSynthParameter (*this, "gain", "Gain", gainParam, { 0.0f, 1.0f }, 0.8f, yup::AudioParameter::ParameterUnit::Percent);
    waveform = addSynthParameter (*this, "waveform", "Waveform", waveformParam, { 0.0f, 2.0f, 1.0f }, 0.0f, yup::AudioParameter::ParameterUnit::Generic, { "Sine", "Saw", "Square" });
    attack = addSynthParameter (*this, "attack", "Attack", attackParam, { 1.0f, 2000.0f }, 5.0f, yup::AudioParameter::ParameterUnit::Milliseconds);
    release = addSynthParameter (*this, "release", "Release", releaseParam, { 1.0f, 2000.0f }, 150.0f, yup::AudioParameter::ParameterUnit::Milliseconds);
}

//==============================================================================
void PluginProcessor::prepareToPlay (const yup::AudioSpec& spec)
{
    engine.prepare (spec.sampleRate);
    gainSmoothed.reset (spec.sampleRate, 0.02);
    gainSmoothed.setCurrentAndTargetValue (gain->getValue());
    updateEngineParameters();
}

void PluginProcessor::releaseResources()
{
    engine.reset();
}

//==============================================================================
void PluginProcessor::updateEngineParameters() noexcept
{
    engine.setEnvelope (attack->getValue() * millisecondsToSeconds,
                        release->getValue() * millisecondsToSeconds);
    engine.setWaveform (static_cast<SynthWaveform> (static_cast<int> (waveform->getValue())));
}

//==============================================================================
void PluginProcessor::processBlock (yup::AudioProcessContext<float>& context)
{
    auto& audio = context.audio;
    const auto numSamples = audio.getNumSamples();
    const auto numChannels = audio.getNumChannels();

    updateEngineParameters();

    // Merge the notes played by the editor's on-screen keyboard into the host MIDI.
    keyboardState.processNextMidiBuffer (context.midi, 0, numSamples, true);

    gainSmoothed.setTargetValue (gain->getValue());

    int nextEvent = 0;
    auto eventIterator = context.midi.begin();
    const auto eventEnd = context.midi.end();

    for (int sample = 0; sample < numSamples; ++sample)
    {
        while (eventIterator != eventEnd && (*eventIterator).samplePosition <= sample)
        {
            const auto message = (*eventIterator).getMessage();

            if (message.isNoteOn())
                engine.noteOn (message.getNoteNumber(), message.getFloatVelocity());
            else if (message.isNoteOff())
                engine.noteOff (message.getNoteNumber());
            else if (message.isAllNotesOff() || message.isAllSoundOff())
                engine.allNotesOff();

            ++eventIterator;
            ++nextEvent;
        }

        const auto value = engine.renderSample() * gainSmoothed.getNextValue();

        for (int channel = 0; channel < numChannels; ++channel)
            audio.setSample (channel, sample, value);
    }

    yup::ignoreUnused (nextEvent);
}

//==============================================================================
yup::Result PluginProcessor::loadStateFromDataTree (const yup::DataTree& state)
{
    for (const auto& parameter : getParameters())
    {
        const auto id = parameter->getID();
        if (state.hasProperty (id))
            parameter->setValue (static_cast<float> (state.getProperty (id)));
    }

    updateEngineParameters();
    return yup::Result::ok();
}

yup::Result PluginProcessor::saveStateIntoDataTree (yup::DataTree& state)
{
    state = yup::DataTree ("YupPluginState");
    auto transaction = state.beginTransaction();

    for (const auto& parameter : getParameters())
        transaction.setProperty (parameter->getID(), parameter->getValue());

    return yup::Result::ok();
}

//==============================================================================
yup::AudioProcessorEditor* PluginProcessor::createEditor()
{
    return new PluginEditor (*this);
}

//==============================================================================
extern "C" yup::AudioProcessor* createPluginProcessor()
{
    return new PluginProcessor();
}
