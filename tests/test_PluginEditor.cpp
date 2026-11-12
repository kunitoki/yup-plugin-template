#include <gtest/gtest.h>

#include "PluginEditor.h"
#include "PluginProcessor.h"

#include <memory>

TEST (PluginEditor, ConstructsWithPreferredSizeAndResizes)
{
    PluginProcessor processor;
    PluginEditor editor (processor);

    EXPECT_TRUE (editor.isResizable());
    EXPECT_TRUE (editor.shouldPreserveAspectRatio());

    const auto preferred = editor.getPreferredSize();
    EXPECT_EQ (preferred.getWidth(), 520);
    EXPECT_EQ (preferred.getHeight(), 320);

    editor.setBounds (0.0f,
                      0.0f,
                      static_cast<float> (preferred.getWidth()),
                      static_cast<float> (preferred.getHeight()));

    editor.setBounds (0.0f,
                      0.0f,
                      static_cast<float> (preferred.getWidth()) * 2.0f,
                      static_cast<float> (preferred.getHeight()) * 2.0f);
}

TEST (PluginEditor, ProcessorCreatesEditor)
{
    PluginProcessor processor;

    std::unique_ptr<yup::AudioProcessorEditor> editor (processor.createEditor());
    ASSERT_NE (editor, nullptr);
    EXPECT_EQ (editor->getPreferredSize().getWidth(), 520);
    EXPECT_EQ (editor->getPreferredSize().getHeight(), 320);
}
