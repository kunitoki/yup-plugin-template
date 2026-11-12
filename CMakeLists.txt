# =============================================================================
# YUP PLUGIN TEMPLATE - CMakeLists.txt
# =============================================================================
# This is a template for creating cross-platform audio plugins (CLAP, VST3, AU,
# AUv3, LV2, AAX and a Standalone app) using the YUP framework. Customize the
# variables below to match your plugin.
# =============================================================================

cmake_minimum_required (VERSION 3.31)

# =============================================================================
# VERSION MANAGEMENT
# =============================================================================
# Read version from VERSION file for centralized version control.
file (READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" CURRENT_VERSION)
string (STRIP "${CURRENT_VERSION}" CURRENT_VERSION)
string (REGEX MATCH "^([0-9]+)\\.([0-9]+)\\.([0-9]+)" _ "${CURRENT_VERSION}")
set (VERSION_MAJOR "${CMAKE_MATCH_1}")
set (VERSION_MINOR "${CMAKE_MATCH_2}")
set (VERSION_PATCH "${CMAKE_MATCH_3}")

# =============================================================================
# PLATFORM DEPLOYMENT TARGETS
# =============================================================================
# Newer Xcode releases drop support for older minimum deployment targets, so
# the supported floor is detected from the installed Xcode (mirroring YUP's own
# _yup_apple_setup_deployment_target logic). Keep this in sync with YUP.
if (CMAKE_HOST_APPLE)
  set (CMAKE_XCODE_GENERATE_SCHEME OFF)

  if (IOS OR CMAKE_SYSTEM_NAME MATCHES "iOS")
    set (_YUP_TEMPLATE_IS_MAC OFF)
  else()
    set (_YUP_TEMPLATE_IS_MAC ON)
  endif()

  execute_process (COMMAND xcodebuild -version OUTPUT_VARIABLE _xcode_version_output ERROR_QUIET)
  string (REGEX MATCH "Xcode ([0-9]+)" _ "${_xcode_version_output}")
  set (_xcode_major "${CMAKE_MATCH_1}")

  if (_xcode_major GREATER_EQUAL 27)
    if (_YUP_TEMPLATE_IS_MAC)
      set (_yup_min_deployment_target 12.0)
    else()
      set (_yup_min_deployment_target 15.0)
    endif()
  else()
    if (_YUP_TEMPLATE_IS_MAC)
      set (_yup_min_deployment_target 11.0)
    else()
      set (_yup_min_deployment_target 13.0)
    endif()
  endif()

  if (NOT DEFINED CMAKE_OSX_DEPLOYMENT_TARGET OR CMAKE_OSX_DEPLOYMENT_TARGET VERSION_LESS _yup_min_deployment_target)
    set (CMAKE_OSX_DEPLOYMENT_TARGET ${_yup_min_deployment_target})
  endif()

  message (STATUS "YUP template: CMAKE_OSX_DEPLOYMENT_TARGET is set to ${CMAKE_OSX_DEPLOYMENT_TARGET}")
endif()

# =============================================================================
# PROJECT CONFIGURATION - CHANGE THESE VALUES FOR YOUR PLUGIN!
# =============================================================================

# The internal name of the project and the plugin targets (no spaces allowed).
set (PROJECT_NAME "YupPlugin")

# The display name shown to users (spaces allowed).
set (PRODUCT_NAME "YUP Instrument")

# Company / author name, used for attribution, bundle ids and code signing.
set (COMPANY_NAME "YUP Audio")

# Bundle identifier prefix for macOS/iOS (reverse domain notation).
set (BUNDLE_ID "audio.yup.yupplugin")

# Short descriptive text for the plugin.
set (PLUGIN_DESCRIPTION "A simple polyphonic instrument built with YUP.")

# Your website / support URL.
set (PLUGIN_URL "https://github.com/kunitoki/yup-plugin-template")

# Contact e-mail embedded in the plugin metadata.
set (PLUGIN_EMAIL "support@yourcompany.com")

# Four character codes. These are case sensitive and must stay stable once shipped.
set (PLUGIN_CODE "YpIn")          # Unique plugin id (AU subtype / AAX product id)
set (PLUGIN_MANUFACTURER_CODE "Yup!") # Manufacturer id (exactly 4 characters, one uppercase)

# Application icon file (path to .png).
set (APPLICATION_ICON "${CMAKE_CURRENT_SOURCE_DIR}/assets/app-icon.png")

# Version can be overridden via command line: cmake -DTARGET_VERSION="2.0.0" ..
set (TARGET_VERSION "${CURRENT_VERSION}" CACHE STRING "Plugin version")

# =============================================================================
# BUILD OPTIONS & FEATURES
# =============================================================================

option (BUILD_TESTS "Build test suite" ON)
option (BUILD_BENCHMARKS "Build the DSP micro-benchmarks (google/benchmark)" ON)
option (ENABLE_COVERAGE "Enable code coverage analysis (requires lcov/gcov)" OFF)
option (ENABLE_CODE_SIGNING "Enable code signing (macOS/iOS)" OFF)

# Plugin formats to build. Toggle these to match your distribution targets.
option (PLUGIN_BUILD_CLAP "Build the CLAP format" ON)
option (PLUGIN_BUILD_VST3 "Build the VST3 format" ON)
option (PLUGIN_BUILD_AU "Build the Audio Unit format (macOS)" ON)
option (PLUGIN_BUILD_AUV3 "Build the Audio Unit v3 app extension" ON)
option (PLUGIN_BUILD_LV2 "Build the LV2 format" ON)
option (PLUGIN_BUILD_STANDALONE "Build the Standalone application" ON)

# Code signing configuration (macOS/iOS).
set (MACOS_SIGNING_IDENTITY "" CACHE STRING "macOS code signing identity")
set (DEVELOPMENT_TEAM_ID "" CACHE STRING "Apple Developer Team ID")

# =============================================================================
# PROJECT DECLARATION
# =============================================================================

set (_template_project_languages C CXX)
if (CMAKE_HOST_APPLE)
  list (APPEND _template_project_languages OBJC OBJCXX)
endif()

project (${PROJECT_NAME} VERSION ${TARGET_VERSION} LANGUAGES ${_template_project_languages})

# =============================================================================
# YUP FRAMEWORK SETUP
# =============================================================================

set (YUP_BUILD_EXAMPLES OFF)
set (YUP_BUILD_PLUGINS OFF)
set (YUP_BUILD_TESTS OFF)
set (YUP_ENABLE_VST3_VALIDATOR ON)
set (YUP_ENABLE_CLAP_VALIDATOR ON)
set (YUP_ENABLE_AUVAL_VALIDATOR ON)
set (YUP_ENABLE_PLUGINVAL ON)
add_subdirectory (yup)

# =============================================================================
# SOURCE FILES
# =============================================================================

file (GLOB_RECURSE PLUGIN_SOURCES
  CONFIGURE_DEPENDS
  "${CMAKE_CURRENT_SOURCE_DIR}/source/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/source/*.h"
)

source_group (TREE ${CMAKE_CURRENT_SOURCE_DIR}/source PREFIX "Source Files" FILES ${PLUGIN_SOURCES})

# =============================================================================
# AAX (optional, auto-detected)
# =============================================================================
# AAX requires the Avid SDK. If YUP_AAX_SDK_ROOT is set (env or cache) the AAX
# target is enabled automatically.
set (plugin_create_aax OFF)
if (DEFINED YUP_AAX_SDK_ROOT OR DEFINED ENV{YUP_AAX_SDK_ROOT})
    if (DEFINED ENV{YUP_AAX_SDK_ROOT} AND NOT DEFINED YUP_AAX_SDK_ROOT)
        set (YUP_AAX_SDK_ROOT "$ENV{YUP_AAX_SDK_ROOT}" CACHE PATH "Path to the AAX SDK")
    endif()
    message (STATUS "AAX SDK using YUP_AAX_SDK_ROOT: ${YUP_AAX_SDK_ROOT}")
    set (plugin_create_aax ON)
endif()

# =============================================================================
# AUDIO PLUGIN TARGET
# =============================================================================

yup_audio_plugin (
    TARGET_NAME ${PROJECT_NAME}
    TARGET_VERSION ${TARGET_VERSION}
    TARGET_APP_ID "${BUNDLE_ID}"
    TARGET_APP_NAMESPACE "${BUNDLE_ID}"
    TARGET_CXX_STANDARD 20
    TARGET_IDE_GROUP "Plugin"
    TARGET_ICON "${APPLICATION_ICON}"

    PLUGIN_ID "${BUNDLE_ID}"
    PLUGIN_NAME "${PRODUCT_NAME}"
    PLUGIN_VENDOR "${COMPANY_NAME}"
    PLUGIN_EMAIL "${PLUGIN_EMAIL}"
    PLUGIN_VERSION "${TARGET_VERSION}"
    PLUGIN_DESCRIPTION "${PLUGIN_DESCRIPTION}"
    PLUGIN_URL "${PLUGIN_URL}"

    # An instrument: receives MIDI, produces audio, no audio input.
    PLUGIN_IS_SYNTH ON
    PLUGIN_IS_MONO OFF

    PLUGIN_CREATE_CLAP ${PLUGIN_BUILD_CLAP}
    PLUGIN_CREATE_VST3 ${PLUGIN_BUILD_VST3}
    PLUGIN_CREATE_AU ${PLUGIN_BUILD_AU}
    PLUGIN_CREATE_AUv3 ${PLUGIN_BUILD_AUV3}
    PLUGIN_CREATE_LV2 ${PLUGIN_BUILD_LV2}
    PLUGIN_CREATE_STANDALONE ${PLUGIN_BUILD_STANDALONE}
    PLUGIN_CREATE_AAX ${plugin_create_aax}

    PLUGIN_AU_MANUFACTURER "${PLUGIN_MANUFACTURER_CODE}"
    PLUGIN_AU_SUBTYPE "${PLUGIN_CODE}"
    PLUGIN_AAX_MANUFACTURER_ID "${PLUGIN_MANUFACTURER_CODE}"
    PLUGIN_AAX_PRODUCT_ID "${PLUGIN_CODE}"
    PLUGIN_AAX_CATEGORY "AAX_ePlugInCategory_SWGenerators"

    PLUGIN_COPY_AFTER_BUILD ON

    MODULES
      yup::yup_gui
      yup::yup_audio_processors
      yup::yup_audio_gui
)

# The plugin sources compile once into the shared plugin core.
target_sources (${PROJECT_NAME}_shared PRIVATE ${PLUGIN_SOURCES})

# =============================================================================
# CODE SIGNING (macOS)
# =============================================================================

if (APPLE AND ENABLE_CODE_SIGNING AND MACOS_SIGNING_IDENTITY)
    foreach (plugin_format clap vst3 au auv3 lv2 standalone aax)
        set (fmt_target ${PROJECT_NAME}_${plugin_format}_plugin)
        if (TARGET ${fmt_target})
            set_target_properties (${fmt_target} PROPERTIES
                XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "${MACOS_SIGNING_IDENTITY}"
                XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${DEVELOPMENT_TEAM_ID}"
                XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Manual")
        endif()
    endforeach()
    message (STATUS "macOS Code Signing: ${MACOS_SIGNING_IDENTITY}")
endif()

# =============================================================================
# TESTING
# =============================================================================

if (BUILD_TESTS AND NOT YUP_PLATFORM_MOBILE)
    enable_testing()
    add_subdirectory (tests)
    message (STATUS "Building test suite")
endif()

if (BUILD_BENCHMARKS AND NOT YUP_PLATFORM_MOBILE AND NOT YUP_PLATFORM_EMSCRIPTEN)
    add_subdirectory (benchmarks)
    message (STATUS "Building DSP benchmarks")
endif()
