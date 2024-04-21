cmake_minimum_required(VERSION 3.15)
project(metal_triangle VERSION 0.0.1 LANGUAGES C OBJC)

set(CMAKE_OSX_DEPLOYMENT_TARGET "10.11")

add_executable(${PROJECT_NAME} MACOSX_BUNDLE
    main.m
    ${CMAKE_BINARY_DIR}/shaders.metallib
    )
set_target_properties(${PROJECT_NAME} PROPERTIES
    BUNDLE True
    MACOSX_BUNDLE_GUI_IDENTIFIER com.${PROJECT_NAME}.app
    MACOSX_BUNDLE_BUNDLE_NAME ${PROJECT_NAME}
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION}
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_SOURCE_DIR}/app.plist.in
)
target_compile_definitions(${PROJECT_NAME} PRIVATE SHADER_LIB_PATH="${CMAKE_BINARY_DIR}/shaders.metallib")
target_link_libraries(${PROJECT_NAME} PRIVATE "-framework Cocoa -framework Metal -framework MetalKit")

# Compile metal shaders
# .metal -> .ir and/or .metalar -> .metallib
# https://developer.apple.com/documentation/metal/shader_libraries/building_a_shader_library_by_precompiling_source_files?language=objc
add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/shaders.metallib
        COMMAND echo "Recompiling shaders"
        COMMAND xcrun -sdk macosx metal    -o ${CMAKE_BINARY_DIR}/shaders.ir    -c ${CMAKE_SOURCE_DIR}/shaders.metal
        COMMAND xcrun -sdk macosx metallib -o ${CMAKE_BINARY_DIR}/shaders.metallib ${CMAKE_BINARY_DIR}/shaders.ir
        DEPENDS shaders.metal
        )