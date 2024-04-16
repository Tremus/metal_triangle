#include <Cocoa/Cocoa.h>
#include <MetalKit/MetalKit.h>

#include "AAPLShaderTypes.h"

@interface Delegate : NSObject <NSApplicationDelegate, MTKViewDelegate>
{
@public
    NSWindow*    _window;
    MTKView*     _view;
    vector_uint2 _viewportSize;

    // The render pipeline generated from the vertex and fragment shaders in the .metal shader file.
    id<MTLRenderPipelineState> _pipelineState;

    // The command queue used to pass commands to the device.
    id<MTLCommandQueue> _commandQueue;
};

@end

@implementation Delegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)application
{
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
    _window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 600, 500)
                                          styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                            backing:NSBackingStoreBuffered
                                              defer:NO];
    [_window setReleasedWhenClosed:TRUE];
    [_window cascadeTopLeftFromPoint:NSMakePoint(20, 20)];
    [_window setTitle:[[NSProcessInfo processInfo] processName]];
    [_window makeKeyAndOrderFront:nil];

    _view            = [[MTKView alloc] init];
    _view.device     = MTLCreateSystemDefaultDevice();
    _view.clearColor = MTLClearColorMake(0.0, 0.5, 1.0, 1.0);
    // 'setNeedsDisplay' marks the view as dirty. This is for on demand rendering, rather than rendering every frame
    // _view.enableSetNeedsDisplay = YES;
    _view.delegate = self;

    // Load all the shader files with a .metal file extension in the project.
    id<MTLLibrary> defaultLibrary = nil;
    if (@available(macOS 10.13, *))
    {
        NSURL* url     = [[NSURL alloc] initWithString:@(SHADER_LIB_PATH)];
        defaultLibrary = [_view.device newLibraryWithURL:url error:nil];
        assert(defaultLibrary);
        [url release];
    }
    else
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        defaultLibrary = [_view.device newLibraryWithFile:@(SHADER_LIB_PATH) error:nil];
        assert(defaultLibrary);
#pragma clang diagnostic pop
    }

    id<MTLFunction> vertexFunction   = [defaultLibrary newFunctionWithName:@"vertexShader"];
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];
    assert(vertexFunction != nil);
    assert(fragmentFunction != nil);

    // Configure a pipeline descriptor that is used to create a pipeline state.
    MTLRenderPipelineDescriptor* pipelineStateDescriptor    = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label                           = @"Simple Pipeline";
    pipelineStateDescriptor.vertexFunction                  = vertexFunction;
    pipelineStateDescriptor.fragmentFunction                = fragmentFunction;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = _view.colorPixelFormat;

    NSError* error;
    _pipelineState = [_view.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];

    // Pipeline State creation could fail if the pipeline descriptor isn't set up properly.
    //  If the Metal API validation is enabled, you can find out more information about what
    //  went wrong.  (Metal API validation is enabled by default when a debug build is run
    //  from Xcode.)
    NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error);

    // Create the command queue
    _commandQueue = [_view.device newCommandQueue];

    [_window setContentView:_view];
}
- (void)applicationWillTerminate:(NSNotification*)notification
{
    // Shutdown
}

- (void)mtkView:(nonnull MTKView*)view drawableSizeWillChange:(CGSize)size;
{
    printf("drawing\n");
    // Save the size of the drawable to pass to the vertex shader.
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
}

- (void)drawInMTKView:(nonnull MTKView*)view
{
    static const AAPLVertex triangleVertices[] = {
        // 2D positions,    RGBA colors
        {{250, -250}, {1, 0, 0, 1}},
        {{-250, -250}, {0, 1, 0, 1}},
        {{0, 250}, {0, 0, 1, 1}},
    };

    // Create a new command buffer for each render pass to the current drawable.
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label                = @"MyCommand";

    // Obtain a renderPassDescriptor generated from the view's drawable textures.
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;

    if (renderPassDescriptor != nil)
    {
        // Create a render command encoder.
        id<MTLRenderCommandEncoder> renderEncoder =
            [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        // Set the region of the drawable to draw into.
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, _viewportSize.x, _viewportSize.y, 0.0, 1.0}];

        [renderEncoder setRenderPipelineState:_pipelineState];

        // Pass in the parameter data.
        [renderEncoder setVertexBytes:triangleVertices
                               length:sizeof(triangleVertices)
                              atIndex:AAPLVertexInputIndexVertices];

        [renderEncoder setVertexBytes:&_viewportSize
                               length:sizeof(_viewportSize)
                              atIndex:AAPLVertexInputIndexViewportSize];

        // Draw the triangle.
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];

        [renderEncoder endEncoding];

        // Schedule a present once the framebuffer is complete using the current drawable.
        [commandBuffer presentDrawable:view.currentDrawable];
    }

    // Finalize rendering here & push the command buffer to the GPU.
    [commandBuffer commit];
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