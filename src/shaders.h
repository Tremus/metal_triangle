#ifndef SHADERS_H
#define SHADERS_H

#include <simd/simd.h>

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs
// match Metal API buffer set calls.
typedef enum SimpleVertexInputIndex
{
    SimpleVertexInputIndexVertices     = 0,
    SimpleVertexInputIndexViewportSize = 1,
} SimpleVertexInputIndex;

typedef struct
{
    vector_float2 position;
    vector_float4 colour;
} SimpleVertex;

typedef struct
{
    vector_float2 position;
    vector_float2 texCoords;
} TexVertex;

#endif // SHADERS_H
