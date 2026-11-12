cmake_minimum_required(VERSION 3.31)

enable_testing()

# ==== Setup googletests
if (YUP_PLATFORM_EMSCRIPTEN)
    set (gtest_disable_pthreads ON CACHE BOOL "" FORCE)
    set (gtest_disable_warnings ON CACHE BOOL "" FORCE)
    set (gtest_hide_internal_symbols ON CACHE BOOL "" FORCE)
    add_definitions (-DTEST_HAS_PTHREAD=0)
endif()

set (gtest_force_shared_crt ON CACHE BOOL "" FORCE)

_yup_fetchcontent_declare (googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG v1.17.0)

FetchContent_MakeAvailable (googletest)

if (YUP_PLATFORM_EMSCRIPTEN)
    target_compile_options (gmock PRIVATE -pthread)
    target_compile_options (gtest PRIVATE -pthread)
endif()

set_target_properties (gtest PROPERTIES FOLDER "Tests")
set_target_properties (gtest_main PROPERTIES FOLDER "Tests")
set_target_properties (gmock PROPERTIES FOLDER "Tests")
set_target_properties (gmock_main PROPERTIES FOLDER "Tests")

# ==== Create executable
set (target_name ${PROJECT_NAME}_tests)
set (target_version ${TARGET_VERSION})
set (target_company "${BUNDLE_ID}")
set (target_console OFF)
set (target_gtest_modules "")
set (target_app_modules "")
set (target_preloaded "")

# Base modules available on all platforms
list (APPEND target_app_modules
    yup::yup_core
    yup::yup_events
    yup::yup_graphics)

if (NOT YUP_PLATFORM_EMSCRIPTEN)
    list (APPEND target_app_modules
        yup::yup_gui
        yup::yup_audio_processors
        yup::yup_audio_gui)
    list (APPEND target_gtest_modules
        GTest::gtest
        GTest::gmock)
else()
    set (target_console ON)
    list (APPEND target_gtest_modules
        GTest::gtest
        GTest::gmock)

    file (GLOB_RECURSE data_files "${CMAKE_CURRENT_LIST_DIR}/data/*")
    foreach (data_file ${data_files})
        file (RELATIVE_PATH rel_path "${CMAKE_CURRENT_LIST_DIR}" "${data_file}")
        list (APPEND target_preloaded "${data_file}@${rel_path}")
    endforeach()
endif()

yup_standalone_app (
    TARGET_NAME ${target_name}
    TARGET_VERSION ${target_version}
    TARGET_IDE_GROUP "Tests"
    TARGET_APP_ID "${target_company}.${target_name}"
    TARGET_APP_NAMESPACE "${target_company}"
    TARGET_CONSOLE ${target_console}
    DEFINITIONS
        YUP_USE_CURL=0
        YUP_MODAL_LOOPS_PERMITTED=1
    PRELOAD_FILES
        ${target_preloaded}
    MODULES
        ${target_app_modules}
        ${target_gtest_modules})

# ==== Setup test sources
# The engine (source/dsp) is header-only; on desktop the plugin implementation
# sources (PluginProcessor/PluginEditor) are compiled in below so coverage
# instruments the whole source/ tree, not just source/dsp.
file (GLOB test_sources "${CMAKE_CURRENT_LIST_DIR}/test_*.cpp")
list (APPEND test_sources "${CMAKE_CURRENT_LIST_DIR}/main.cpp")

if (YUP_PLATFORM_EMSCRIPTEN)
    # The plugin tests need yup_audio_processors/yup_audio_gui (desktop SDL
    # video), so Emscripten covers only the DSP engine.
    list (REMOVE_ITEM test_sources
        "${CMAKE_CURRENT_LIST_DIR}/test_processor.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/test_editor.cpp")
endif()

target_include_directories (${target_name} PRIVATE "${CMAKE_CURRENT_LIST_DIR}/../source")
target_sources (${target_name} PRIVATE ${test_sources})
source_group (TREE ${CMAKE_CURRENT_LIST_DIR}/ FILES ${test_sources})

if (NOT YUP_PLATFORM_EMSCRIPTEN)
    set (plugin_impl_sources
        "${CMAKE_CURRENT_LIST_DIR}/../source/PluginProcessor.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/../source/PluginEditor.cpp")
    target_sources (${target_name} PRIVATE ${plugin_impl_sources})
    source_group ("Source Files" FILES ${plugin_impl_sources})
endif()

# ==== Reuse YUP's shared GoogleTest runner (adds the runner source + gtest link)
yup_add_test_runner (${target_name})

# ==== Setup target properties
set_target_properties (${target_name} PROPERTIES
    XCODE_SCHEME_ARGUMENTS "--gtest_filter=*"
    VS_DEBUGGER_COMMAND_ARGUMENTS "--gtest_filter=*")

# ==== Register with CTest (desktop only; Emscripten runs via `just emscripten_test`)
if (NOT YUP_PLATFORM_EMSCRIPTEN)
    add_test (NAME ${target_name} COMMAND ${target_name} --gtest_filter=*)
endif()

# ==== Setup coverage support
if (ENABLE_COVERAGE AND (CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang"))
    target_compile_options (${target_name} PRIVATE
        --coverage
        -fprofile-arcs
        -ftest-coverage
        -fprofile-update=atomic
        "$<$<COMPILE_LANGUAGE:CXX>:-fno-elide-constructors>")
    target_link_options (${target_name} PRIVATE --coverage)
    if (CMAKE_CXX_COMPILER_ID MATCHES "GNU")
        target_link_libraries (${target_name} PRIVATE gcov)
    endif()

    _yup_setup_coverage_targets (${target_name} "")
endif()
