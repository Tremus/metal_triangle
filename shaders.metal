/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal shaders used for this sample
*/

#include <metal_stdlib>

using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands.
#include "AAPLShaderTypes.h"
// Vertex shader outputs and fragment shader inputs
struct RasterizerData
{
    // The [[position]] attribute of this member indicates that this value
    // is the clip space position of the vertex when this structure is
    // returned from the vertex function.
    float4 position [[position]];

    // Since this member does not have a special attribute, the rasterizer
    // interpolates its value with the values of the other triangle vertices
    // and then passes the interpolated value to the fragment shader for each
    // fragment in the triangle.
    half4 colour;
};

vertex RasterizerData
triangle_vert(uint vertexID [[vertex_id]],
             constant AAPLVertex *vertices [[buffer(AAPLVertexInputIndexVertices)]],
             constant vector_float2* viewportSizePointer [[buffer(AAPLVertexInputIndexViewportSize)]])
{
    RasterizerData out;

    // Index into the array of positions to get the current vertex.
    // The positions are specified in pixel dimensions (i.e. a value of 100
    // is 100 pixels from the origin).
    float2 pixelSpacePosition = vertices[vertexID].position.xy;

    // Get the viewport size and cast to float.
    vector_float2 viewportSize = vector_float2(*viewportSizePointer);
    

    // To convert from positions in pixel space to positions in clip-space,
    // divide the pixel coordinates by half the size of the viewport.
    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
    out.position.xy = pixelSpacePosition / (viewportSize / 2.0);

    // Pass the input colour directly to the rasterizer.
    out.colour = half4(vertices[vertexID].colour);

    return out;
}

fragment half4 triangle_frag(RasterizerData in [[stage_in]])
{
    // Return the interpolated colour.
    return in.colour;
}


vertex RasterizerData
square_vert(uint vertexID [[vertex_id]],
            constant SimpleVertex* vertices [[buffer(AAPLVertexInputIndexVertices)]])
{
    RasterizerData out;
    
    out.position.xy = vertices[vertexID].position.xy;
    out.position.zw = float2(0, 1);

    out.colour = half4(vertices[vertexID].colour);

    return out;
}

fragment half4 square_frag(RasterizerData in [[stage_in]])
{
    return in.colour;
}

// TODO rounded rectangle
// TODO circle
// TODO ellipse
// TODO point
// TODO straight line
// TODO bezier line