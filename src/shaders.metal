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

// Hard fill
vertex float4 circle_tris_vert(
    const device float2* vertices [[buffer(0)]],
    constant vector_float2* pViewport [[buffer(1)]],
    uint vertexID [[vertex_id]])
{
    float4 pos;
    pos.xy = vertices[vertexID].xy;
    pos.zw = float2(0, 1);

    return pos;
}

fragment half4 circle_tris_frag(RasterizerData in [[stage_in]])
{
    return half4(1);
}

struct PositionData
{
    float4 position [[position]];
    float2 pos2;
};

// 0-w,0-h -> uv -1 - 1
float2 normalise_point(float2 coord, float2 frame)
{
    float2 quarterview = frame / 4;
    float2 uv = (coord - quarterview) / quarterview;
    return uv;
}

vertex PositionData
circle_sdf_vert(uint vertexID [[vertex_id]],
            constant float2* vertices [[buffer(0)]],
            constant float2* view [[buffer(1)]])
{
    PositionData out;

    float2 uv = normalise_point(vertices[vertexID].xy, view->xy);

    out.position.xy = uv;
    out.position.zw = float2(0, 1);

    out.pos2 = vertices[vertexID];

    return out;
}

fragment half4 circle_sdf_frag(PositionData in [[stage_in]],
                            constant float2* view [[buffer(0)]])
{
    half4 col = half4(0,0,0,1);

    float2 uv = normalise_point(in.pos2, view->xy);

    float distance = 1 - length(uv);

    col.rgb = smoothstep(0, 0.005, distance);

    return col;
}

vertex PositionData
line_vert(uint vertexID [[vertex_id]],
          constant float2* vertices [[buffer(0)]],
          constant float2* view [[buffer(1)]])
{
    PositionData out;

    float2 uv = normalise_point(vertices[vertexID].xy, view->xy);

    out.position.xy = uv;
    out.position.zw = float2(0, 1);

    out.pos2 = vertices[vertexID];

    return out;
}

fragment half4 line_frag(PositionData in [[stage_in]],
                         constant float2* view [[buffer(0)]])
{
    // https://www.youtube.com/watch?v=cU5WcrU_YI4
    half4 col = half4(0,0,0,1);

    // TODO: fix coordinates.
    // Currently p1 will show up on the bottom left of the screen and p2 on the top right
    // I'd like the y value to be inverted
    float2 p1 = float2(100, 100);
    float2 p2 = float2(400, 400);
    float2 p3 = in.pos2;

    float2 p12 = p2 - p1;
    float2 p13 = p3 - p1;

    float d = dot(p12, p13) / length(p12);
    float2 p4 = p1 + normalize(p12) * d;

    if (length(p3 - p4) < 5.0 &&
        length(p4 - p1) <= length(p12) &&
        length(p4 - p2) <= length(p12))
        col.g = 1;

    return col;
}

struct RasterizeImage
{
    float4 position [[position]];
    float2 texCoords;
};

vertex RasterizeImage
image_vert(uint vertexID [[vertex_id]],
           constant TexVertex* vertices [[buffer(0)]])
{
    RasterizeImage out;

    out.position.xy = vertices[vertexID].position.xy;
    out.position.zw = float2(0, 1);
    out.texCoords   = vertices[vertexID].texCoords;

    return out;
}

fragment half4 image_frag(RasterizeImage in [[stage_in]],
                          sampler sampler2d [[sampler(0)]],
                          texture2d<float> texture [[texture(0)]])
{
    float4 sample = texture.sample(sampler2d, in.texCoords);
    return half4(sample.r, sample.g, sample.b, 1);
}

// TODO rounded rectangle
// TODO circle antialiased
// TODO ellipse
// TODO point
// TODO straight line
// TODO bezier line
// TODO image resize
// TODO image blur