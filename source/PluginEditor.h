/*
  ==============================================================================

   YUP Plugin Template - the editor.

  ==============================================================================
*/

#pragma once

#include <yup_audio_gui/yup_audio_gui.h>

#include "PluginProcessor.h"

#include <array>
#include <memory>

//==============================================================================
/** The plugin editor: four rotary controls over a playable keyboard.

    Each control is bound to its parameter with an AudioParameterAttachment, so the
    knobs follow host automation and host automation follows the knobs. The keyboard
    plays the shared MidiKeyboardState, which the processor merges into the audio
    block, so notes played here sound through the instrument.

    @see PluginProcessor
*/
class PluginEditor final : public yup::AudioProcessorEditor
{
public:
    explicit PluginEditor (PluginProcessor& processorToEdit);
    ~PluginEditor() override;

    //==============================================================================
    bool isResizable() const override { return true; }

    yup::Size<int> getPreferredSize() const override { return { 520, 320 }; }

    bool shouldPreserveAspectRatio() const override { return true; }

    //==============================================================================
    void resized() override;
    void paint (yup::Graphics& g) override;

private:
    //==============================================================================
    struct Knob
    {
        yup::Slider slider { yup::Slider::Rotary };
        std::unique_ptr<yup::AudioParameterAttachment> attachment;
        yup::AudioParameter::Ptr parameter;
        yup::Label caption;
        yup::String name;
    };

    void bindKnob (Knob& knob, const yup::String& parameterID, const yup::String& caption);
    void updateCaption (Knob& knob);
    float getScaleFactor() const;

    PluginProcessor& processor;
    std::array<Knob, 4> knobs;
    yup::Label title;
    yup::MidiKeyboardComponent keyboard;
    yup::Font font;
    bool updatingFromParameter = false;

    YUP_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (PluginEditor)
};
