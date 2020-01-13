#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <GLKit/GLKit.h>
#import "../ex1_main/common.h"

constexpr int W = 800;
constexpr int H = 800;

// Vertex structure on CPU memory.
struct Vertex {
    float position[3];
    unsigned char color[4];
};

// Vertex structure on CPU memory.
struct TVertex {
    float position[3];
    unsigned char color[4];
    float texpos[2];
};

@interface OSXMetalView : NSView


@property (atomic) BOOL sizeUpdated;
@end

@implementation OSXMetalView {

    id <MTLLibrary> _shaders;
    id<MTLCommandQueue>         _commandQueue;
    id<MTLRenderPipelineState>  _pipelineState1;
    id<MTLRenderPipelineState>  _pipelineState2;
    id<MTLRenderPipelineState>  _pipelineState3;
    id <MTLBuffer>              _uniformBuffer2;
    id <MTLBuffer>              _uniformBuffer1;
    id <MTLBuffer>              _uniformBuffer3;
    id<MTLBuffer>  			    _vertexBuffer1;
    id<MTLBuffer>  			    _vertexBuffer2;
    BOOL 				        _sizeUpdated;
    id<MTLTexture>              _sampleTxt;
    id<MTLTexture>              _bufTxt;
@public
    CVDisplayLinkRef _displayLink;
    dispatch_semaphore_t 	    _renderSemaphore;
}
@synthesize sizeUpdated = _sizeUpdated;

static CVReturn OnDisplayLinkFrame(CVDisplayLinkRef displayLink,
                                   const CVTimeStamp *now,
                                   const CVTimeStamp *outputTime,
                                   CVOptionFlags flagsIn,
                                   CVOptionFlags *flagsOut,
                                   void *displayLinkContext) {
    OSXMetalView *view = (__bridge OSXMetalView *) displayLinkContext;

    @autoreleasepool {
        [view update];
    }

    return kCVReturnSuccess;
}

+ (Class)layerClass {
    return [CAMetalLayer class];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

    if (self) {
        self.wantsLayer = YES;
        CAMetalLayer* cml = [CAMetalLayer layer];
        self.layer = cml;
        cml.device = MTLCreateSystemDefaultDevice();
        cml.pixelFormat = MTLPixelFormatBGRA8Unorm;
        cml.framebufferOnly = NO; // YES;

        _commandQueue = [cml.device newCommandQueue];
        if (!_commandQueue)
        {
            printf("ERROR: Couldn't create a command queue.");
            return nil;
        }

        NSError *error = nil;

        _shaders = [cml.device newLibraryWithFile: @"aarect.metallib" error:&error];
        if (!_shaders)
        {
            printf("ERROR: Failed to load shader library.");
            return nil;
        }

        id<MTLFunction> fragmentProgram = [_shaders newFunctionWithName:@"frag"];
        if (!fragmentProgram)
        {
            printf("ERROR: Couldn't load fragment function from default library.");
            return nil;
        }

        id<MTLFunction> vertexProgram = [_shaders newFunctionWithName:@"vert"];
        if (!vertexProgram)
        {
            printf("ERROR: Couldn't load vertex function from default library.");
            return nil;
        }

        id<MTLFunction> txFragmentProgram = [_shaders newFunctionWithName:@"tx_frag"];
        if (!fragmentProgram)
        {
            printf("ERROR: Couldn't load fragment function from default library.");
            return nil;
        }

        id<MTLFunction> txVertexProgram = [_shaders newFunctionWithName:@"tx_vert"];
        if (!txVertexProgram)
        {
            printf("ERROR: Couldn't load vertex function from default library.");
            return nil;
        }

        MTLRenderPipelineDescriptor *pipelineStateDesc = [MTLRenderPipelineDescriptor new];

        if (!pipelineStateDesc)
        {
            printf("ERROR: Failed creating a pipeline state descriptor!");
            return nil;
        }

        _uniformBuffer1 = [cml.device newBufferWithLength:sizeof(FrameUniforms)
                                                  options:MTLResourceCPUCacheModeWriteCombined];
        _uniformBuffer2 = [cml.device newBufferWithLength:sizeof(FrameUniforms)
                                                  options:MTLResourceCPUCacheModeWriteCombined];
        _uniformBuffer3 = [cml.device newBufferWithLength:sizeof(FrameUniforms)
                                                  options:MTLResourceCPUCacheModeWriteCombined];

        // Create vertex descriptor.
        MTLVertexDescriptor *vertDesc = [MTLVertexDescriptor new];
        vertDesc.attributes[VertexAttributePosition].format = MTLVertexFormatFloat3;
        vertDesc.attributes[VertexAttributePosition].offset = 0;
        vertDesc.attributes[VertexAttributePosition].bufferIndex = MeshVertexBuffer;
        vertDesc.attributes[VertexAttributeColor].format = MTLVertexFormatUChar4;
        vertDesc.attributes[VertexAttributeColor].offset = sizeof(Vertex::position);
        vertDesc.attributes[VertexAttributeColor].bufferIndex = MeshVertexBuffer;
        vertDesc.layouts[MeshVertexBuffer].stride = sizeof(Vertex);
        vertDesc.layouts[MeshVertexBuffer].stepRate = 1;
        vertDesc.layouts[MeshVertexBuffer].stepFunction = MTLVertexStepFunctionPerVertex;
        pipelineStateDesc.colorAttachments[0].blendingEnabled = YES;
        pipelineStateDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        pipelineStateDesc.colorAttachments[0].rgbBlendOperation =   MTLBlendOperationAdd;
        pipelineStateDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
        pipelineStateDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDesc.sampleCount      = 1;
        pipelineStateDesc.vertexFunction   = vertexProgram;
        pipelineStateDesc.fragmentFunction = fragmentProgram;
        pipelineStateDesc.vertexDescriptor = vertDesc;
        _pipelineState1 = [cml.device newRenderPipelineStateWithDescriptor:pipelineStateDesc
                                                                     error:&error];
        pipelineStateDesc.colorAttachments[0].blendingEnabled = YES;
        pipelineStateDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        pipelineStateDesc.colorAttachments[0].rgbBlendOperation =   MTLBlendOperationAdd;
        pipelineStateDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
        pipelineStateDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDesc.sampleCount      = 8;
        pipelineStateDesc.vertexFunction   = vertexProgram;
        pipelineStateDesc.fragmentFunction = fragmentProgram;
        pipelineStateDesc.vertexDescriptor = vertDesc;
        _pipelineState2 = [cml.device newRenderPipelineStateWithDescriptor:pipelineStateDesc
                error:&error];

        vertDesc = [MTLVertexDescriptor new];
        vertDesc.attributes[VertexAttributePosition].format = MTLVertexFormatFloat3;
        vertDesc.attributes[VertexAttributePosition].offset = 0;
        vertDesc.attributes[VertexAttributePosition].bufferIndex = MeshVertexBuffer;
        vertDesc.attributes[VertexAttributeColor].format = MTLVertexFormatUChar4;
        vertDesc.attributes[VertexAttributeColor].offset = sizeof(TVertex::position);
        vertDesc.attributes[VertexAttributeColor].bufferIndex = MeshVertexBuffer;
        vertDesc.attributes[VertexAttributeTexPos].format = MTLVertexFormatFloat2;
        vertDesc.attributes[VertexAttributeTexPos].offset = sizeof(TVertex::position) + sizeof(TVertex::color);
        vertDesc.attributes[VertexAttributeTexPos].bufferIndex = MeshVertexBuffer;

        vertDesc.layouts[MeshVertexBuffer].stride = sizeof(TVertex);
        vertDesc.layouts[MeshVertexBuffer].stepRate = 1;
        vertDesc.layouts[MeshVertexBuffer].stepFunction = MTLVertexStepFunctionPerVertex;
        pipelineStateDesc.colorAttachments[0].blendingEnabled = YES;
        pipelineStateDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        pipelineStateDesc.colorAttachments[0].rgbBlendOperation =   MTLBlendOperationAdd;
        pipelineStateDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
        pipelineStateDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDesc.sampleCount      = 1;
        pipelineStateDesc.vertexFunction   = txVertexProgram;
        pipelineStateDesc.fragmentFunction = txFragmentProgram;
        pipelineStateDesc.vertexDescriptor = vertDesc;
        _pipelineState3 = [cml.device newRenderPipelineStateWithDescriptor:pipelineStateDesc
                                                                     error:&error];
        MTLTextureDescriptor *desc = [MTLTextureDescriptor new];
        desc.textureType = MTLTextureType2DMultisample;
        desc.width = (NSUInteger)(self.frame.size.width *  [[NSScreen mainScreen] backingScaleFactor]);
        desc.height = (NSUInteger)(self.frame.size.height *  [[NSScreen mainScreen] backingScaleFactor]);
        desc.sampleCount = 8;
        desc.pixelFormat = MTLPixelFormatBGRA8Unorm;
        desc.storageMode = MTLStorageModePrivate;

        _sampleTxt = [cml.device newTextureWithDescriptor:desc];
        desc = [MTLTextureDescriptor new];
        desc.textureType = MTLTextureType2DMultisample;
        desc.width = (NSUInteger)(self.frame.size.width *  [[NSScreen mainScreen] backingScaleFactor]);
        desc.height = (NSUInteger)(self.frame.size.height *  [[NSScreen mainScreen] backingScaleFactor]);
        desc.pixelFormat = MTLPixelFormatBGRA8Unorm;
        desc.storageMode = MTLStorageModePrivate;
        desc.textureType = MTLTextureType2D;
        _bufTxt = [cml.device newTextureWithDescriptor:desc];

        if (!_pipelineState2) {
            printf("ERROR: Failed acquiring pipeline state descriptor.");
            return nil;
        }

        // Create vertices.
        Vertex verts[] = {
                Vertex{{-0.55f, -0.5f, 0}, {255, 255, 255, 255}},
                Vertex{{0.55, -0.5f, 0}, {255, 255, 255, 255}},
                Vertex{{-0.55, 0.5f, 0}, {255, 255, 255, 255}},
                Vertex{{0.55, 0.5f, 0}, {255, 255, 255, 255}}
        };

        _vertexBuffer1 = [cml.device newBufferWithBytes:verts
                                                length:sizeof(verts)
                                               options:MTLResourceCPUCacheModeDefaultCache];
        if (!_vertexBuffer1) {
            printf("ERROR: Failed to create quad vertex buffer.");
            return nil;
        }

        // Create vertices.
        TVertex verts1[] = {
                TVertex{{-1.0f, -1.0f, 0}, {255, 0, 0, 255}, {0, 0}},
                TVertex{{-1.0f, 1.0f, 0}, {0, 255, 0, 255}, {0, 1}},
                TVertex{{1.0, -1.0f, 0}, {0, 0, 255, 255}, {1, 0}},
                TVertex{{-1.0f, 1.0f, 0}, {0, 255, 0, 255}, {0, 1}},
                TVertex{{1.0f, 1.0f, 0}, {255, 0, 0, 255}, {1, 1}},
                TVertex{{1.0, -1.0f, 0}, {0, 0, 255, 255}, {1, 0}}
        };
        _vertexBuffer2 = [cml.device newBufferWithBytes:verts1
                                                 length:sizeof(verts1)
                                                options:MTLResourceCPUCacheModeDefaultCache];
        if (!_vertexBuffer2) {
            printf("ERROR: Failed to create quad vertex buffer.");
            return nil;
        }

        _renderSemaphore = dispatch_semaphore_create(2);
        if (CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink) != kCVReturnSuccess) {
            printf("ERROR: CVDisplayLinkCreateWithActiveCGDisplays failed");
            return nil;
        }

        if (CVDisplayLinkSetOutputCallback(_displayLink, &OnDisplayLinkFrame, (__bridge void *) self) !=
            kCVReturnSuccess)
        {
            printf("ERROR: CVDisplayLinkSetOutputCallback failed");
            return nil;

        }

        if (CVDisplayLinkSetCurrentCGDisplay(_displayLink, CGMainDisplayID()) != kCVReturnSuccess) {
            printf("ERROR: CVDisplayLinkSetOutputCallback failed");
            return nil;
        }

        _sizeUpdated = YES;
        CVDisplayLinkStart(_displayLink);

        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

        [notificationCenter addObserver:self
                               selector:@selector(windowWillClose:)
                                   name:NSWindowWillCloseNotification
                                 object:self.window];
    }

    return self;
}

- (void)dealloc {
    if (_displayLink) {
        [self stopUpdate];
    }
}

- (void)windowWillClose:(NSNotification *)notification {
// Stop the display link when the window is closing because we will
// not be able to get a drawable, but the display link may continue
// to fire
    if (notification.object == self.window) {
        CVDisplayLinkStop(_displayLink);
    }
}

- (void)update {
    dispatch_semaphore_wait(_renderSemaphore, DISPATCH_TIME_FOREVER);

    if (self.sizeUpdated)
    {
        // Set the metal layer to the drawable size in case orientation or size changes.
        CGSize drawableSize = self.bounds.size;

        // Scale drawableSize so that drawable is 1:1 width pixels not 1:1 to points.
        NSScreen* screen = self.window.screen ?: [NSScreen mainScreen];
        drawableSize.width *= screen.backingScaleFactor;
        drawableSize.height *= screen.backingScaleFactor;

        ((CAMetalLayer *)self.layer).drawableSize = drawableSize;

        self.sizeUpdated = NO;
    }

    id<CAMetalDrawable> cdl = [((CAMetalLayer *)self.layer) nextDrawable];

    if (!cdl) {
        printf("ERROR: Failed to get a valid drawable.");
    } else {
        MTLRenderPassDescriptor* rpd1 = [MTLRenderPassDescriptor renderPassDescriptor];

        MTLRenderPassColorAttachmentDescriptor *colorAttachment = rpd1.colorAttachments[0];
        colorAttachment.texture = cdl.texture;

        colorAttachment.loadAction = MTLLoadActionClear;
        colorAttachment.clearColor = MTLClearColorMake(0.0f, 0.0f, 0.0f, 0.0f);

        colorAttachment.storeAction = MTLStoreActionStore;

        MTLRenderPassDescriptor* rpd2 = [MTLRenderPassDescriptor renderPassDescriptor];

        colorAttachment = rpd2.colorAttachments[0];
        //colorAttachment.texture = cdl.texture;
        colorAttachment.texture = _sampleTxt;
       // colorAttachment.resolveTexture = cdl.texture;
        colorAttachment.resolveTexture = _bufTxt;

        colorAttachment.loadAction = MTLLoadActionClear;
        colorAttachment.clearColor = MTLClearColorMake(0.0f, 0.0f, 0.0f, 0.0f);
        colorAttachment.storeAction = MTLStoreActionMultisampleResolve;

        MTLRenderPassDescriptor* rpd3 = [MTLRenderPassDescriptor renderPassDescriptor];
        colorAttachment = rpd3.colorAttachments[0];
        colorAttachment.texture = cdl.texture;

        colorAttachment.loadAction = MTLLoadActionLoad;
        colorAttachment.clearColor = MTLClearColorMake(0.0f, 0.0f, 0.0f, 1.0f);
        colorAttachment.storeAction = MTLStoreActionStore;


        id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

        simd::float4x4 rot(simd::float4{(float)cos(0.3),-(float)sin(0.3), 0, 0},
                           simd::float4{(float)sin(0.3), (float)cos(0.3), 0, 0},
                           simd::float4{       0,        0, 1, 0},
                           simd::float4{       0,        0, 0, 1});
        simd::float4x4 mrot(simd::float4{(float)cos(-0.1),-(float)sin(-0.1), 0, 0},
                           simd::float4{(float)sin(-0.1), (float)cos(-0.1), 0, 0},
                           simd::float4{       0,        0, 1, 0},
                           simd::float4{       0,        0, 0, 1});
        simd::float4x4 ed(simd::float4{        1,        0, 0, 0},
                            simd::float4{      0,        1, 0, 0},
                            simd::float4{       0,        0, 1, 0},
                            simd::float4{       0,        0, 0, 1});

        FrameUniforms *uniforms1 = (FrameUniforms *) [_uniformBuffer1 contents];
        uniforms1->projectionViewModel = mrot;

        FrameUniforms *uniforms2 = (FrameUniforms *) [_uniformBuffer2 contents];
        uniforms2->projectionViewModel = rot;

        FrameUniforms *uniforms3 = (FrameUniforms *) [_uniformBuffer3 contents];
        uniforms3->projectionViewModel = ed;

        // Create a command buffer.

        // Encode render command.
        id <MTLRenderCommandEncoder> encoder1 = [commandBuffer renderCommandEncoderWithDescriptor:rpd1];
        [encoder1 setFrontFacingWinding:MTLWindingCounterClockwise];
        [encoder1 setRenderPipelineState:_pipelineState1];
        [encoder1 setVertexBuffer:_vertexBuffer1
                          offset:0
                         atIndex:MeshVertexBuffer];
        [encoder1 setVertexBuffer:_uniformBuffer1
                          offset:0 atIndex:FrameUniformBuffer];
        [encoder1 drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
        [encoder1 endEncoding];

        id <MTLRenderCommandEncoder> encoder2 = [commandBuffer renderCommandEncoderWithDescriptor:rpd2];

        [encoder2 setFrontFacingWinding:MTLWindingCounterClockwise];
        [encoder2 setRenderPipelineState:_pipelineState2];
        [encoder2 setVertexBuffer:_vertexBuffer1
                          offset:0
                         atIndex:MeshVertexBuffer];
        [encoder2 setVertexBuffer:_uniformBuffer2
                          offset:0 atIndex:FrameUniformBuffer];
        // [encoder setViewport:{0, 0, 800, 600, 0, 1}];
        [encoder2 drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
        [encoder2 endEncoding];

        //[encoder1 setRenderPipelineState:_pipelineState3];
        id <MTLRenderCommandEncoder> encoder3 = [commandBuffer renderCommandEncoderWithDescriptor:rpd3];

        [encoder3 setRenderPipelineState:_pipelineState3];
        [encoder3 setVertexBuffer:_vertexBuffer2
                          offset:0
                         atIndex:MeshVertexBuffer];
        [encoder3 setVertexBuffer:_uniformBuffer3
                          offset:0 atIndex:FrameUniformBuffer];
        [encoder3 setFragmentTexture: _bufTxt atIndex: 0];

        [encoder3 drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:2*3];
        [encoder3 endEncoding];

        __block dispatch_semaphore_t blockRenderSemaphore = _renderSemaphore;
        [commandBuffer addCompletedHandler:^(id <MTLCommandBuffer> cmdBuff) {
            dispatch_semaphore_signal(blockRenderSemaphore);
        }];
        [commandBuffer presentDrawable:cdl];
        [commandBuffer commit];
    }
}

- (void)stopUpdate {
    if (_displayLink) {
        CVDisplayLinkStop(_displayLink);
        CVDisplayLinkRelease(_displayLink);
    }
}

@end

int main () {
    @autoreleasepool {
            [NSApplication sharedApplication];
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

            NSRect frame = NSMakeRect(0, 0, W, H);
            NSWindow* window = [[NSWindow alloc]
            initWithContentRect:frame styleMask:NSTitledWindowMask
            backing:NSBackingStoreBuffered defer:NO];
            [window cascadeTopLeftFromPoint:NSMakePoint(20,20)];
            window.title = [[NSProcessInfo processInfo] processName];
            OSXMetalView* view = [[OSXMetalView alloc] initWithFrame:frame];
            window.contentView = view;
            view.needsDisplay = YES;

            [window makeKeyAndOrderFront:nil];

            [NSApp activateIgnoringOtherApps:YES];
            [NSApp run];
    }
    return 0;
}
