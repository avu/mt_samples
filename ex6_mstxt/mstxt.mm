#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <GLKit/GLKit.h>
#import "../ex3_txtriangle/txtng.h"

constexpr int W = 800;
constexpr int H = 800;

// Vertex structure on CPU memory.
struct Vertex {
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
    id<MTLRenderPipelineState>  _pipelineState;
    id <MTLBuffer>              _uniformBuffer;
    id<MTLBuffer>  			    _vertexBuffer;
    id<MTLBuffer>  			    _vertexBuffer2;
    BOOL 				        _sizeUpdated;
    MTLRenderPassDescriptor    *rpd;
    id<MTLTexture> _earthTxt;
    id<MTLDepthStencilState> _depthState;
    id<MTLTexture>              _sampleTxt;
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
        cml.framebufferOnly = YES;

        _commandQueue = [cml.device newCommandQueue];
        if (!_commandQueue)
        {
            printf("ERROR: Couldn't create a command queue.");
            return nil;
        }

        NSError *error = nil;

        _shaders = [cml.device newLibraryWithFile: @"mstxt.metallib" error:&error];
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

        MTLRenderPipelineDescriptor *pipelineStateDesc = [MTLRenderPipelineDescriptor new];

        if (!pipelineStateDesc)
        {
            printf("ERROR: Failed creating a pipeline state descriptor!");
            return nil;
        }

        _uniformBuffer = [cml.device newBufferWithLength:sizeof(FrameUniforms)
                                              options:MTLResourceCPUCacheModeWriteCombined];
        // Create vertex descriptor.

        NSDictionary *opt = [NSDictionary dictionaryWithObject:@(YES) forKey:MTKTextureLoaderOptionOrigin];

        MTKTextureLoader* txtLoader = [[MTKTextureLoader alloc] initWithDevice:cml.device];
        NSError *err;
        _earthTxt = [txtLoader newTextureWithContentsOfURL: [NSURL fileURLWithPath:@"earth.png"] options: opt error:&err];

        MTLDepthStencilDescriptor *depthDescriptor = [[MTLDepthStencilDescriptor alloc] init];
        depthDescriptor.depthWriteEnabled = YES;
        depthDescriptor.depthCompareFunction = MTLCompareFunctionLess;
        _depthState = [cml.device newDepthStencilStateWithDescriptor:depthDescriptor];

        MTLVertexDescriptor *vertDesc = [MTLVertexDescriptor new];
        vertDesc.attributes[VertexAttributePosition].format = MTLVertexFormatFloat3;
        vertDesc.attributes[VertexAttributePosition].offset = 0;
        vertDesc.attributes[VertexAttributePosition].bufferIndex = MeshVertexBuffer;
        vertDesc.attributes[VertexAttributeColor].format = MTLVertexFormatUChar4;
        vertDesc.attributes[VertexAttributeColor].offset = sizeof(Vertex::position);
        vertDesc.attributes[VertexAttributeColor].bufferIndex = MeshVertexBuffer;
        vertDesc.attributes[VertexAttributeTexPos].format = MTLVertexFormatFloat2;
        vertDesc.attributes[VertexAttributeTexPos].offset = sizeof(Vertex::position) + sizeof(Vertex::color);
        vertDesc.attributes[VertexAttributeTexPos].bufferIndex = MeshVertexBuffer;

        vertDesc.layouts[MeshVertexBuffer].stride = sizeof(Vertex);
        vertDesc.layouts[MeshVertexBuffer].stepRate = 1;
        vertDesc.layouts[MeshVertexBuffer].stepFunction = MTLVertexStepFunctionPerVertex;

        pipelineStateDesc.depthAttachmentPixelFormat      = MTLPixelFormatDepth32Float;

        pipelineStateDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        pipelineStateDesc.colorAttachments[0].rgbBlendOperation =   MTLBlendOperationAdd;
        pipelineStateDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
        pipelineStateDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDesc.sampleCount      = 4;
        pipelineStateDesc.colorAttachments[0].blendingEnabled = YES;


        pipelineStateDesc.vertexFunction   = vertexProgram;
        pipelineStateDesc.fragmentFunction = fragmentProgram;
        pipelineStateDesc.vertexDescriptor = vertDesc;

        MTLTextureDescriptor *desc = [MTLTextureDescriptor new];
        desc.textureType = MTLTextureType2DMultisample;
        desc.width = (NSUInteger)(self.frame.size.width *  [[NSScreen mainScreen] backingScaleFactor]);
        desc.height = (NSUInteger)(self.frame.size.height *  [[NSScreen mainScreen] backingScaleFactor]);
        desc.sampleCount = 4;
        desc.pixelFormat = MTLPixelFormatBGRA8Unorm;
        desc.storageMode = MTLStorageModePrivate;

        _sampleTxt = [cml.device newTextureWithDescriptor:desc];

        _pipelineState = [cml.device newRenderPipelineStateWithDescriptor:pipelineStateDesc
                                                                 error:&error];


        if (!_pipelineState) {
            printf("ERROR: Failed acquiring pipeline state descriptor.");
            return nil;
        }

        // Create vertices.
        Vertex verts[] = {
                Vertex{{-0.5f, -0.5f, 0}, {255, 0, 0, 255}, {0, 0}},
                Vertex{{-0.5f, 0.5f, 0}, {0, 255, 0, 255}, {0, 1}},
                Vertex{{0.5, -0.5f, 0}, {0, 0, 255, 255}, {1, 0}},
                Vertex{{-0.5f, 0.5f, 0}, {0, 255, 0, 255}, {0, 1}},
                Vertex{{0.5f, 0.5f, 0}, {255, 0, 0, 255}, {1, 1}},
                Vertex{{0.5, -0.5f, 0}, {0, 0, 255, 255}, {1, 0}}
        };

        _vertexBuffer = [cml.device newBufferWithBytes:verts
                                                length:sizeof(verts)
                                               options:MTLResourceCPUCacheModeDefaultCache];
        if (!_vertexBuffer) {
            printf("ERROR: Failed to create quad vertex buffer.");
            return nil;
        }

        // Create vertices.
        Vertex verts2[] = {
                Vertex{{-0.3f, -0.5f, 0}, {255, 0, 0, 255}, {0, 0}},
                Vertex{{-0.3f, 0.5f, 0}, {0, 255, 0, 255}, {0, 1}},
                Vertex{{0.7, -0.5f, 0}, {0, 0, 255, 255}, {1, 0}},
                Vertex{{-0.3f, 0.5f, 0}, {0, 255, 0, 255}, {0, 1}},
                Vertex{{0.7f, 0.5f, 0}, {255, 0, 0, 255}, {1, 1}},
                Vertex{{0.7, -0.5f, 0}, {0, 0, 255, 255}, {1, 0}}
        };

        _vertexBuffer2 = [cml.device newBufferWithBytes:verts2
                                                 length:sizeof(verts2)
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
        MTLRenderPassDescriptor* rpd = [MTLRenderPassDescriptor renderPassDescriptor];

        MTLRenderPassColorAttachmentDescriptor *colorAttachment = rpd.colorAttachments[0];
        //colorAttachment.texture = cdl.texture;
        colorAttachment.texture = _sampleTxt;
        colorAttachment.resolveTexture = cdl.texture;
        colorAttachment.loadAction = MTLLoadActionClear;
        colorAttachment.clearColor = MTLClearColorMake(0.0f, 0.0f, 0.0f, 1.0f);

        //colorAttachment.storeAction = MTLStoreActionStore;
        colorAttachment.storeAction = MTLStoreActionMultisampleResolve;


        id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

        simd::float4x4 rot(simd::float4{1, 0, 0, 0},
                           simd::float4{0, 1, 0, 0},
                           simd::float4{0, 0, 1, 0},
                           simd::float4{0, 0, 0, 1});

        FrameUniforms *uniforms = (FrameUniforms *) [_uniformBuffer contents];
        uniforms->projectionViewModel = rot;

        // Create a command buffer.

        // Encode render command.
        id <MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:rpd];
        [encoder pushDebugGroup:@"encode balls"];
        [encoder setDepthStencilState:_depthState];
        [encoder setFrontFacingWinding:MTLWindingCounterClockwise];
        [encoder setRenderPipelineState:_pipelineState];
        [encoder setVertexBuffer:_vertexBuffer
                          offset:0
                         atIndex:MeshVertexBuffer];
        [encoder setVertexBuffer:_uniformBuffer
                          offset:0 atIndex:FrameUniformBuffer];
        [encoder setFragmentTexture: _earthTxt atIndex: 0];
        // [encoder setViewport:{0, 0, 800, 600, 0, 1}];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:2*3];

        [encoder setVertexBuffer:_vertexBuffer2
                          offset:0
                         atIndex:MeshVertexBuffer];

        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:2*3];


        [encoder endEncoding];

        [encoder popDebugGroup];


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
