/*
  ==============================================================================

   YUP Plugin Template - the editor.

  ==============================================================================
*/

#include "PluginEditor.h"

namespace
{
// Reference metrics, expressed at the editor's preferred size. Everything is
// multiplied by a uniform scale factor in resized()/paint() so the layout keeps
// its proportions at any window size (the editor preserves its aspect ratio, so
// a single factor is enough and the knobs never turn into ovals).
constexpr float referenceWidth = 520.0f;
constexpr float referenceHeight = 320.0f;
constexpr float titleHeight = 52.0f;
constexpr float keyboardHeight = 92.0f;
constexpr float captionHeight = 22.0f;
constexpr float knobPadding = 12.0f;
constexpr float titleFontHeight = 26.0f;
constexpr float captionFontHeight = 14.0f;

// Two octaves give comfortably wide keys instead of the default 84-key span,
// which renders as very thin keys in a compact plugin window.
constexpr int keyboardLowestNote = 48;  // C3
constexpr int keyboardHighestNote = 72; // C5
} // namespace

//==============================================================================
PluginEditor::PluginEditor (PluginProcessor& processorToEdit)
    : processor (processorToEdit)
    , keyboard (processorToEdit.getKeyboardState(), yup::MidiKeyboardComponent::horizontalKeyboard)
    , font (yup::ApplicationTheme::getGlobalTheme()->getDefaultFont())
{
    title.setText ("YUP Instrument", yup::dontSendNotification);
    title.setJustification (yup::Justification::center);
    title.setColor (yup::Label::Style::textFillColorId, yup::Colors::white);
    addAndMakeVisible (title);

    bindKnob (knobs[0], "gain", "Gain");
    bindKnob (knobs[1], "waveform", "Waveform");
    bindKnob (knobs[2], "attack", "Attack");
    bindKnob (knobs[3], "release", "Release");

    keyboard.setAvailableRange (0, 127);
    keyboard.setVisibleRange (keyboardLowestNote, keyboardHighestNote);
    addAndMakeVisible (keyboard);

    setSize (getPreferredSize().to<float>());
}

//==============================================================================
float PluginEditor::getScaleFactor() const
{
    const auto bounds = getLocalBounds();
    return yup::jmin (bounds.getWidth() / referenceWidth,
                      bounds.getHeight() / referenceHeight);
}

PluginEditor::~PluginEditor() = default;

//==============================================================================
void PluginEditor::bindKnob (Knob& knob, const yup::String& parameterID, const yup::String& caption)
{
    knob.parameter = processor.getParameterByID (parameterID);
    knob.name = caption;

    knob.caption.setJustification (yup::Justification::center);
    knob.caption.setColor (yup::Label::Style::textFillColorId, yup::Color (0xffb9bec9));
    addAndMakeVisible (knob.caption);

    if (knob.parameter == nullptr)
        return;

    const auto step = knob.parameter->isStepped() ? 1.0 : 0.0;
    knob.slider.setRange (knob.parameter->getMinimumValue(), knob.parameter->getMaximumValue(), step);
    knob.slider.setValue (knob.parameter->getValue(), yup::dontSendNotification);
    updateCaption (knob);

    auto* parameter = knob.parameter.get();
    knob.slider.onValueChanged = [this, knobPtr = &knob, parameter] (double value)
    {
        if (updatingFromParameter)
            return;

        parameter->beginChangeGesture();
        parameter->setValueNotifyingHost (static_cast<float> (value));
        parameter->endChangeGesture();
        updateCaption (*knobPtr);
    };

    knob.attachment = std::make_unique<yup::AudioParameterAttachment> (
        *this,
        knob.parameter,
        [this, knobPtr = &knob]
        {
            updatingFromParameter = true;
            knobPtr->slider.setValue (knobPtr->parameter->getValue(), yup::dontSendNotification);
            updatingFromParameter = false;
            updateCaption (*knobPtr);
        },
        true);

    addAndMakeVisible (knob.slider);
}

//==============================================================================
void PluginEditor::updateCaption (Knob& knob)
{
    if (knob.parameter == nullptr)
        return;

    knob.caption.setText (knob.name + ": " + knob.parameter->toString(), yup::dontSendNotification);
}

//==============================================================================
void PluginEditor::resized()
{
    const auto scale = getScaleFactor();
    auto area = getLocalBounds();

    keyboard.setBounds (area.removeFromBottom (keyboardHeight * scale));

    title.setFont (font.withHeight (titleFontHeight * scale));
    title.setBounds (area.removeFromTop (titleHeight * scale));

    const auto columnWidth = area.getWidth() / static_cast<float> (knobs.size());

    for (auto& knob : knobs)
    {
        auto column = area.removeFromLeft (columnWidth);

        const auto captionH = captionHeight * scale;

        // Keep rotary sliders circular by using a square, then stack the caption
        // directly beneath it and centre the whole knob + caption group.
        const auto side = yup::jmin (column.getWidth(), column.getHeight() - captionH)
                        - knobPadding * scale * 2.0f;
        const auto groupHeight = side + captionH;
        const auto groupTop = column.getY() + (column.getHeight() - groupHeight) * 0.5f;
        const auto centerX = column.getCenterX();

        knob.slider.setBounds (yup::Rectangle<float> (centerX - side * 0.5f, groupTop, side, side));

        knob.caption.setFont (font.withHeight (captionFontHeight * scale));
        knob.caption.setBounds (yup::Rectangle<float> (column.getX(), groupTop + side, column.getWidth(), captionH));
    }
}

//==============================================================================
void PluginEditor::paint (yup::Graphics& g)
{
    g.setFillColor (0xff1d1f24);
    g.fillAll();
}

