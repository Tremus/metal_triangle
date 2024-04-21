#include <Cocoa/Cocoa.h>
#include <MetalKit/MetalKit.h>

#include "AAPLShaderTypes.h"
#include "stb_image.h"

#define ARRLEN(a)     (sizeof(a) / sizeof(a[0]))
#define xassert(cond) (cond) ? (void)0 : __builtin_debugtrap()

@interface Delegate : NSObject <NSApplicationDelegate, MTKViewDelegate>
{
@public
    NSWindow*     _window;
    MTKView*      _view;
    vector_float2 _viewsize;

    // The render pipeline generated from the vertex and fragment shaders in the .metal shader file.
    id<MTLRenderPipelineState> _tri_pipeline;
    id<MTLRenderPipelineState> _square_pipeline;
    id<MTLRenderPipelineState> _circle_pipeline;
    id<MTLRenderPipelineState> _image_pipeline;

    // The command queue used to pass commands to the device.
    id<MTLCommandQueue> _commandQueue;

    id<MTLTexture>      _tex_chad;
    id<MTLSamplerState> _samplerState;
};

@end

@implementation Delegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)application
{
    return YES;
}

- (void)mtkView:(nonnull MTKView*)view drawableSizeWillChange:(CGSize)size;
{
    // Save the size of the drawable to pass to the vertex shader.
    _viewsize.x = size.width;
    _viewsize.y = size.height;
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
    _window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 500, 500)
                                          styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                            backing:NSBackingStoreBuffered
                                              defer:NO];
    [_window setReleasedWhenClosed:TRUE];
    [_window cascadeTopLeftFromPoint:NSMakePoint(20, 20)];
    [_window setTitle:[[NSProcessInfo processInfo] processName]];
    [_window makeKeyAndOrderFront:nil];

    _view            = [[MTKView alloc] init];
    _view.device     = MTLCreateSystemDefaultDevice();
    _view.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    // 'setNeedsDisplay' marks the view as dirty. This is for on demand rendering, rather than rendering every frame
    // _view.enableSetNeedsDisplay = YES;
    _view.delegate = self;

    NSError* error;

    // TEXTURES
    {
        stbi_set_flip_vertically_on_load(1);

        int width, height, channels_in_file;
        // The jpg image will only have 3 colour channels (RGB), but we require RGBA for the stack blur algorithm
        const int      desired_channels = 4;
        unsigned char* imgbuf =
            stbi_load(PATH_RESOURCES "brain.jpg", &width, &height, &channels_in_file, desired_channels);

        MTLTextureDescriptor* desc = [MTLTextureDescriptor new];

        desc.pixelFormat = MTLPixelFormatRGBA8Unorm;
        desc.width       = width;
        desc.height      = height;

        _tex_chad = [_view.device newTextureWithDescriptor:desc];
        xassert(_tex_chad);

        const NSUInteger bytesperrow = desired_channels * width;

        MTLRegion region = {{0, 0, 0}, {width, height, 1}};

        [_tex_chad replaceRegion:region mipmapLevel:0 withBytes:imgbuf bytesPerRow:bytesperrow];

        stbi_image_free(imgbuf);
    }
    {
        MTLSamplerDescriptor* desc = [[MTLSamplerDescriptor alloc] init];
        desc.minFilter             = MTLSamplerMinMagFilterLinear;
        desc.magFilter             = MTLSamplerMinMagFilterLinear;

        _samplerState = [_view.device newSamplerStateWithDescriptor:desc];
        xassert(_samplerState);
    }

    // PIPELINES & SHADERS
    {
        // Load all the shader files with a .metal file extension in the project.
        id<MTLLibrary> defaultLibrary = nil;
        if (@available(macOS 10.13, *))
        {
            NSURL* url     = [[NSURL alloc] initWithString:@(PATH_SHADERS)];
            defaultLibrary = [_view.device newLibraryWithURL:url error:nil];
            xassert(defaultLibrary);
            [url release];
        }
        else
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            defaultLibrary = [_view.device newLibraryWithFile:@(PATH_SHADERS) error:nil];
            xassert(defaultLibrary);
#pragma clang diagnostic pop
        }

        // Configure a pipeline descriptor that is used to create a pipeline state.
        MTLRenderPipelineDescriptor* tri_pipeline = [[MTLRenderPipelineDescriptor alloc] init];

        tri_pipeline.label            = @"Triangle Pipeline";
        tri_pipeline.vertexFunction   = [defaultLibrary newFunctionWithName:@"triangle_vert"];
        tri_pipeline.fragmentFunction = [defaultLibrary newFunctionWithName:@"triangle_frag"];
        xassert(tri_pipeline.vertexFunction != nil);
        xassert(tri_pipeline.fragmentFunction != nil);
        tri_pipeline.colorAttachments[0].pixelFormat = _view.colorPixelFormat;

        _tri_pipeline = [_view.device newRenderPipelineStateWithDescriptor:tri_pipeline error:&error];
        // Pipeline State creation could fail if the pipeline descriptor isn't set up properly.
        // If the Metal API validation is enabled, you can find out more information about what went wrong.
        // (Metal API validation is enabled by default when a debug build is run from Xcode.)
        xassert(_tri_pipeline);

        MTLRenderPipelineDescriptor* square_pipeline = [[MTLRenderPipelineDescriptor alloc] init];
        square_pipeline.vertexFunction               = [defaultLibrary newFunctionWithName:@"square_vert"];
        square_pipeline.fragmentFunction             = [defaultLibrary newFunctionWithName:@"square_frag"];
        assert(square_pipeline.vertexFunction != nil);
        assert(square_pipeline.fragmentFunction != nil);
        square_pipeline.colorAttachments[0].pixelFormat = _view.colorPixelFormat;
        _square_pipeline = [_view.device newRenderPipelineStateWithDescriptor:square_pipeline error:&error];
        xassert(_square_pipeline);

        MTLRenderPipelineDescriptor* circle_pipeline = [[MTLRenderPipelineDescriptor alloc] init];
        circle_pipeline.vertexFunction               = [defaultLibrary newFunctionWithName:@"circle_vert"];
        circle_pipeline.fragmentFunction             = [defaultLibrary newFunctionWithName:@"circle_frag"];
        xassert(circle_pipeline.vertexFunction != nil);
        xassert(circle_pipeline.fragmentFunction != nil);
        circle_pipeline.colorAttachments[0].pixelFormat = _view.colorPixelFormat;
        _circle_pipeline = [_view.device newRenderPipelineStateWithDescriptor:circle_pipeline error:&error];
        xassert(_circle_pipeline);

        MTLRenderPipelineDescriptor* image_pipeline = [[MTLRenderPipelineDescriptor alloc] init];
        image_pipeline.vertexFunction               = [defaultLibrary newFunctionWithName:@"image_vert"];
        image_pipeline.fragmentFunction             = [defaultLibrary newFunctionWithName:@"image_frag"];
        xassert(image_pipeline.vertexFunction != nil);
        xassert(image_pipeline.fragmentFunction != nil);
        image_pipeline.colorAttachments[0].pixelFormat = _view.colorPixelFormat;
        _image_pipeline = [_view.device newRenderPipelineStateWithDescriptor:image_pipeline error:&error];
        xassert(_image_pipeline);
    }

    // Create the command queue
    _commandQueue = [_view.device newCommandQueue];

    [_window setContentView:_view];
}

- (void)applicationWillTerminate:(NSNotification*)notification
{
    // Shutdown
    [_tri_pipeline release];
    [_square_pipeline release];
    [_circle_pipeline release];
    [_image_pipeline release];
    [_tex_chad release];
    [_samplerState release];
}

- (void)drawInMTKView:(nonnull MTKView*)view
{
    // [self drawTriangle:view];
    // [self drawSquare:view];
    // [self drawSquare2:view];
    // [self drawCircle:view];
    [self drawImage:view];
}

- (void)drawTriangle:(nonnull MTKView*)view
{
    static const AAPLVertex triangleVertices[] = {
        // 2D positions,    RGBA colors
        {{250, -250}, {1, 0, 0, 1}},
        {{-250, -250}, {0, 1, 0, 1}},
        {{0, 250}, {0, 0, 1, 1}},
    };

    // Create a new command buffer for each render pass to the current drawable.
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    // commandBuffer.label                = @"MyCommand";

    // Obtain a renderPassDescriptor generated from the view's drawable textures.
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;

    if (renderPassDescriptor != nil)
    {
        // Create a render command encoder.
        id<MTLRenderCommandEncoder> renderEncoder =
            [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        // renderEncoder.label = @"MyRenderEncoder";

        // Set the region of the drawable to draw into.
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, _viewsize.x, _viewsize.y, 0.0, 1.0}];

        [renderEncoder setRenderPipelineState:_tri_pipeline];

        // Pass in the parameter data.
        [renderEncoder setVertexBytes:triangleVertices
                               length:sizeof(triangleVertices)
                              atIndex:AAPLVertexInputIndexVertices];

        [renderEncoder setVertexBytes:&_viewsize length:sizeof(_viewsize) atIndex:AAPLVertexInputIndexViewportSize];

        // Draw the triangle.
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];

        [renderEncoder endEncoding];

        // Schedule a present once the framebuffer is complete using the current drawable.
        [commandBuffer presentDrawable:view.currentDrawable];
    }

    // Finalize rendering here & push the command buffer to the GPU.
    [commandBuffer commit];
}

- (void)drawSquare:(nonnull MTKView*)view
{
    static SimpleVertex verts[] = {
        // 2D positions,    RGBA colors
        {{0.5, -0.5}, {1, 0, 0, 1}},
        {{-0.5, -0.5}, {0, 1, 0, 1}},
        {{-0.5, 0.5}, {0, 0, 1, 1}},

        {{0.5, -0.5}, {1, 0, 0, 1}},
        {{0.5, 0.5}, {1, 1, 1, 1}},
        {{-0.5, 0.5}, {0, 0, 1, 1}},
    };

    id<MTLCommandBuffer>     commandBuffer        = [_commandQueue commandBuffer];
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    // Change the BG colour on the fly
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0.5, 1, 1);
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [renderEncoder setViewport:(MTLViewport){0.0, 0.0, _viewsize.x, _viewsize.y, 0.0, 1.0}];
    [renderEncoder setRenderPipelineState:_square_pipeline];

    [renderEncoder setVertexBytes:verts length:sizeof(verts) atIndex:AAPLVertexInputIndexVertices];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:ARRLEN(verts)];
    [renderEncoder endEncoding];

    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

- (void)drawSquare2:(nonnull MTKView*)view
{
    // clang-format off
    static const SimpleVertex vertices[] = {
        // 2D positions,    RGBA colors
        {{-0.5, 0.5}, {1, 0, 0, 1}},
        {{-0.5, -0.5}, {0, 1, 0, 1}},
        {{0.5, -0.5}, {0, 0, 1, 1}},
        {{0.5, 0.5}, {1, 1, 1, 1}},
    };
    static const UInt16 indices[] = {
        0, 1, 2,
        2, 3, 0,
    };
    // clang-format on

    id<MTLCommandBuffer>     cmdbuf               = [_commandQueue commandBuffer];
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    // Change the BG colour on the fly
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0.5, 1, 1);

    id<MTLRenderCommandEncoder> cmdenc = [cmdbuf renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [cmdenc setViewport:(MTLViewport){0.0, 0.0, _viewsize.x, _viewsize.y, 0.0, 1.0}];
    [cmdenc setRenderPipelineState:_square_pipeline];

    [cmdenc setVertexBytes:vertices length:sizeof(vertices) atIndex:0];
    [cmdenc setVertexBytes:indices length:sizeof(vertices) atIndex:1];
    id<MTLBuffer> vbuf = [view.device newBufferWithBytesNoCopy:vertices
                                                        length:sizeof(vertices)
                                                       options:0
                                                   deallocator:nil];
    id<MTLBuffer> ibuf = [view.device newBufferWithBytesNoCopy:indices
                                                        length:sizeof(indices)
                                                       options:0
                                                   deallocator:nil];

    [cmdenc setVertexBuffer:vbuf offset:0 atIndex:0];
    [cmdenc drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                       indexCount:ARRLEN(indices)
                        indexType:MTLIndexTypeUInt16
                      indexBuffer:ibuf
                indexBufferOffset:0];

    [cmdenc endEncoding];

    [cmdbuf presentDrawable:view.currentDrawable];
    [cmdbuf commit];
}

- (void)drawCircle:(nonnull MTKView*)view
{
    // https://youtube.com/watch?v=vasfdPx5cvY
    static const size_t tris = 100;
    simd_float2         verts[tris * 3 + 3];
    float               prevX = 0;
    float               prevY = -1;
    for (int i = 0; i < tris + 1; i++)
    {
        float theta = 2 * M_PI * (float)i / (float)tris;

        float x = sinf(theta);
        float y = -cosf(theta);

        verts[3 * i]     = (simd_float2){0, 0};
        verts[3 * i + 1] = (simd_float2){prevX, prevY};
        verts[3 * i + 2] = (simd_float2){x, y};

        prevX = x;
        prevY = y;
    }

    id<MTLCommandBuffer>        commandBuffer        = [_commandQueue commandBuffer];
    MTLRenderPassDescriptor*    renderPassDescriptor = view.currentRenderPassDescriptor;
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [renderEncoder setViewport:(MTLViewport){0.0, 0.0, _viewsize.x, _viewsize.y, 0.0, 1.0}];
    [renderEncoder setRenderPipelineState:_circle_pipeline];

    [renderEncoder setVertexBytes:verts length:sizeof(verts) atIndex:AAPLVertexInputIndexVertices];
    [renderEncoder setVertexBytes:&_viewsize length:sizeof(_viewsize) atIndex:AAPLVertexInputIndexViewportSize];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:ARRLEN(verts)];
    [renderEncoder endEncoding];

    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

- (void)drawImage:(nonnull MTKView*)view
{
    // clang-format off
    static const TexVertex vertices[] = {
        // 2D positions, Tex coords
        {{-0.5, 0.5}, {0, 1}},
        {{-0.5, -0.5}, {0, 0}},
        {{0.5, -0.5}, {1, 0}},
        {{0.5, 0.5}, {1, 1}},
    };
    static const UInt16 indices[] = {
        0, 1, 2,
        2, 3, 0,
    };
    // clang-format on

    id<MTLCommandBuffer>     cmdbuf               = [_commandQueue commandBuffer];
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    // Change the BG colour on the fly
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0.5, 1, 1);

    id<MTLRenderCommandEncoder> rcenc = [cmdbuf renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [rcenc setViewport:(MTLViewport){0.0, 0.0, _viewsize.x, _viewsize.y, 0.0, 1.0}];
    [rcenc setRenderPipelineState:_image_pipeline];

    [rcenc setVertexBytes:vertices length:sizeof(vertices) atIndex:0];
    [rcenc setVertexBytes:indices length:sizeof(vertices) atIndex:1];
    [rcenc setFragmentTexture:_tex_chad atIndex:0];
    [rcenc setFragmentSamplerState:_samplerState atIndex:0];

    id<MTLBuffer> vertexBuffer, indexBuffer;
    vertexBuffer = [view.device newBufferWithBytesNoCopy:vertices length:sizeof(vertices) options:0 deallocator:nil];
    indexBuffer  = [view.device newBufferWithBytesNoCopy:indices length:sizeof(indices) options:0 deallocator:nil];

    [rcenc setVertexBuffer:vertexBuffer offset:0 atIndex:0];
    [rcenc drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                      indexCount:ARRLEN(indices)
                       indexType:MTLIndexTypeUInt16
                     indexBuffer:indexBuffer
               indexBufferOffset:0];

    [rcenc endEncoding];

    [cmdbuf presentDrawable:view.currentDrawable];
    [cmdbuf commit];
}

@end

int main()
{
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp setDelegate:[[Delegate alloc] init]];

    [NSApp run];

    return 0;
}