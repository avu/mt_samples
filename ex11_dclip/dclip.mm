#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import "../ex1_main/common.h"

constexpr int W = 800;
constexpr int H = 800;

// Vertex structure on CPU memory.
struct Vertex {
    float position[3];
    unsigned char color[4];
};


@interface OSXMetalView : NSView


    @property (atomic) BOOL sizeUpdated;

- (void)clipVertexBuffer:(id<MTLBuffer>)vertexBuffer stencilTexture:(id<MTLTexture>)stencilTexture;

- (void)drawObj:(id <CAMetalDrawable>)cdl vertexBuffer:(id <MTLBuffer>)vertexBuffer stencilTexture:(id <MTLTexture>)stencilTexture clear:(BOOL)clear;

@end

@implementation OSXMetalView {

    id <MTLLibrary> _shaders;
    id<MTLCommandQueue>         _commandQueue;
    id<MTLRenderPipelineState>  _pipelineState;
    id<MTLRenderPipelineState>  _stencilRenderState;
    id<MTLDepthStencilState>    _stencilState;
    id <MTLTexture>             _stencilTexture;
    id <MTLTexture>             _stencilTexture1;

    MTLScissorRect              _clipRect;
    id <MTLBuffer>              _uniformBuffer;
    id<MTLBuffer>  			    _vertexBuffer;
    id<MTLBuffer>  			    _vertexBuffer1;
    id<MTLBuffer>  			    _vertexBuffer2;
    BOOL 				        _sizeUpdated;

    id<MTLDepthStencilState> _depthStencilClear;
    id<MTLRenderPipelineState> _pipelineStencilClear;
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

            _shaders = [cml.device newLibraryWithFile: @"dclipsh.metallib" error:&error];
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


            MTLRenderPipelineDescriptor *pipelineStateDesc = [[MTLRenderPipelineDescriptor new] autorelease];

            if (!pipelineStateDesc)
            {
                printf("ERROR: Failed creating a pipeline state descriptor!");
                return nil;
            }

            _uniformBuffer = [cml.device newBufferWithLength:sizeof(FrameUniforms)
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

            pipelineStateDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

            pipelineStateDesc.sampleCount      = 1;
            pipelineStateDesc.vertexFunction   = vertexProgram;
            pipelineStateDesc.fragmentFunction = fragmentProgram;
            pipelineStateDesc.vertexDescriptor = vertDesc;
            _pipelineState = [cml.device newRenderPipelineStateWithDescriptor:pipelineStateDesc
                                                                        error:&error];
            MTLDepthStencilDescriptor* stencilDescriptor;
            stencilDescriptor = [[MTLDepthStencilDescriptor new] autorelease];
            stencilDescriptor.frontFaceStencil.stencilCompareFunction = MTLCompareFunctionEqual;
            stencilDescriptor.frontFaceStencil.stencilFailureOperation = MTLStencilOperationKeep;

            stencilDescriptor.backFaceStencil.stencilCompareFunction = MTLCompareFunctionEqual;
            stencilDescriptor.backFaceStencil.stencilFailureOperation = MTLStencilOperationKeep;

            _stencilState = [cml.device newDepthStencilStateWithDescriptor:stencilDescriptor];

            MTLRenderPipelineDescriptor * stencilPipelineDesc = [[MTLRenderPipelineDescriptor new] autorelease];
            stencilPipelineDesc.sampleCount = 1;
            stencilPipelineDesc.vertexDescriptor = vertDesc;
            stencilPipelineDesc.vertexFunction = vertexProgram;
            stencilPipelineDesc.fragmentFunction = fragmentProgram;
            _stencilRenderState = [cml.device newRenderPipelineStateWithDescriptor:stencilPipelineDesc error:&error];

            MTLDepthStencilDescriptor *depthStencilDescriptor = [[MTLDepthStencilDescriptor new] autorelease];
            MTLStencilDescriptor *sd = [[MTLStencilDescriptor new] autorelease];
            sd.stencilCompareFunction = MTLCompareFunctionAlways;
            sd.depthStencilPassOperation = MTLStencilOperationReplace;
            depthStencilDescriptor.backFaceStencil = sd;
            depthStencilDescriptor.frontFaceStencil = sd;
            _depthStencilClear = [cml.device newDepthStencilStateWithDescriptor:depthStencilDescriptor];

            MTLRenderPipelineDescriptor *renderPipelineDescriptor = [[MTLRenderPipelineDescriptor new] autorelease];
            renderPipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth24Unorm_Stencil8;
            renderPipelineDescriptor.rasterSampleCount = 1;
            renderPipelineDescriptor.vertexFunction = vertexProgram;
            renderPipelineDescriptor.fragmentFunction = fragmentProgram;
            renderPipelineDescriptor.vertexDescriptor = vertDesc;

            renderPipelineDescriptor.label = @"pipelineDepthClear";
            _pipelineStencilClear = [cml.device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:&error];

            _clipRect.x = 0;
            _clipRect.y = 0;
            _clipRect.width = 800;
            _clipRect.height = 600;

            if (!_pipelineState) {
                printf("ERROR: Failed acquiring pipeline state descriptor.");
                return nil;
            }

            // Create vertices.
            Vertex verts[] = {
                    Vertex{{-0.5f, -0.5f, 0}, {255, 0, 0, 255}},
                    Vertex{{0, 0.5f, 0}, {0, 255, 0, 255}},
                    Vertex{{0.5, -0.5f, 0}, {0, 0, 255, 255}}
            };

            Vertex verts1[] = {
                    Vertex{{-0.1f, -0.1f, 0}, {255, 0, 0, 255}},
                    Vertex{{0, 0.1f, 0}, {0, 255, 0, 255}},
                    Vertex{{0.1, -0.1f, 0}, {0, 0, 255, 255}}
            };

            Vertex verts2[] = {
                    Vertex{{0.2f, -0.1f, 0}, {255, 0, 0, 255}},
                    Vertex{{0.3, 0.1f, 0}, {0, 255, 0, 255}},
                    Vertex{{0.4, -0.1f, 0}, {0, 0, 255, 255}}
            };
            _vertexBuffer = [cml.device newBufferWithBytes:verts
                                                    length:sizeof(verts)
                                                   options:MTLResourceCPUCacheModeDefaultCache];
            _vertexBuffer1 = [cml.device newBufferWithBytes:verts1
                                                     length:sizeof(verts1)
                                                    options:MTLResourceCPUCacheModeDefaultCache];
            _vertexBuffer2 = [cml.device newBufferWithBytes:verts2
                                                     length:sizeof(verts2)
                                                    options:MTLResourceCPUCacheModeDefaultCache];
            if (!_vertexBuffer) {
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

    - (void)clipVertexBuffer:(id<MTLBuffer>)vertexBuffer stencilTexture:(id<MTLTexture>)stencilTexture {
        MTLRenderPassDescriptor *rpds = [MTLRenderPassDescriptor renderPassDescriptor];
        id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
        rpds.stencilAttachment.clearStencil = 0;
        rpds.stencilAttachment.loadAction = MTLLoadActionClear;
        rpds.stencilAttachment.texture = stencilTexture;

        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:rpds];
        [encoder setDepthStencilState:_depthStencilClear];
        [encoder setRenderPipelineState:_pipelineStencilClear];

        [encoder setStencilReferenceValue:255];
        [encoder setVertexBuffer:vertexBuffer
                          offset:0
                         atIndex:MeshVertexBuffer];
        [encoder setVertexBuffer:_uniformBuffer
                          offset:0 atIndex:FrameUniformBuffer];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];

        [encoder endEncoding];
        [commandBuffer commit];
    }

    - (void)drawObj:(id <CAMetalDrawable>)cdl vertexBuffer:(id <MTLBuffer>)vertexBuffer stencilTexture:(id <MTLTexture>)stencilTexture clear:(BOOL)clear {
        id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

        MTLRenderPassDescriptor *rpd = [MTLRenderPassDescriptor renderPassDescriptor];

        MTLRenderPassColorAttachmentDescriptor *colorAttachment = rpd.colorAttachments[0];
        colorAttachment.texture = cdl.texture;

        colorAttachment.loadAction = clear ? MTLLoadActionClear: MTLLoadActionLoad;
        colorAttachment.clearColor = MTLClearColorMake(0.0f, 0.0f, 0.0f, 1.0f);

        colorAttachment.storeAction = MTLStoreActionStore;
        rpd.stencilAttachment.texture = stencilTexture;
        rpd.stencilAttachment.loadAction = MTLLoadActionLoad;
        rpd.stencilAttachment.storeAction = MTLStoreActionDontCare;

        id <MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:rpd];
        [encoder setScissorRect:_clipRect];
        [encoder setDepthStencilState:_stencilState];

        [encoder setStencilReferenceValue:0xFF];

        [encoder setFrontFacingWinding:MTLWindingCounterClockwise];
        [encoder setRenderPipelineState:_pipelineState];
        [encoder setVertexBuffer:vertexBuffer
                          offset:0
                         atIndex:MeshVertexBuffer];
        [encoder setVertexBuffer:_uniformBuffer
                          offset:0 atIndex:FrameUniformBuffer];
        // [encoder setViewport:{0, 0, 800, 600, 0, 1}];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [encoder endEncoding];
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];
    }

    - (void)update {
        dispatch_semaphore_wait(_renderSemaphore, DISPATCH_TIME_FOREVER);
        CAMetalLayer* cml = static_cast<CAMetalLayer *>(self.layer);
        CGSize drawableSize = self.bounds.size;

        if (self.sizeUpdated)
        {
            // Set the metal layer to the drawable size in case orientation or size changes.
            // Scale drawableSize so that drawable is 1:1 width pixels not 1:1 to points.
            NSScreen* screen = self.window.screen ?: [NSScreen mainScreen];
            drawableSize.width *= screen.backingScaleFactor;
            drawableSize.height *= screen.backingScaleFactor;

            _clipRect.x = static_cast<NSUInteger>(drawableSize.width / 3);
            _clipRect.y = static_cast<NSUInteger>(drawableSize.height / 3);
            _clipRect.width = static_cast<NSUInteger>(drawableSize.width / 3);
            _clipRect.height = static_cast<NSUInteger>(drawableSize.height / 3);

            MTLTextureDescriptor *stencilTextureDescriptor =
                    [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatStencil8
                                                                       width:drawableSize.width height:drawableSize.height mipmapped:NO];

            stencilTextureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
            stencilTextureDescriptor.storageMode = MTLStorageModePrivate;
            if (_stencilTexture) {
                [_stencilTexture release];
                [_stencilTexture1 release];
            }
            _stencilTexture = [cml.device newTextureWithDescriptor:stencilTextureDescriptor];
            _stencilTexture1 = [cml.device newTextureWithDescriptor:stencilTextureDescriptor];


            ((CAMetalLayer *)self.layer).drawableSize = drawableSize;

            self.sizeUpdated = NO;
        }

        id<CAMetalDrawable> cdl = [((CAMetalLayer *)self.layer) nextDrawable];

        if (!cdl) {
            printf("ERROR: Failed to get a valid drawable.");
        } else {

            simd::float4x4 rot(simd::float4{1, 0, 0, 0},
                               simd::float4{0, 1, 0, 0},
                               simd::float4{0, 0, 1, 0},
                               simd::float4{0, 0, 0, 1});

            FrameUniforms *uniforms = (FrameUniforms *) [_uniformBuffer contents];
            uniforms->projectionViewModel = rot;

            // Create a command buffer.

            // Encode render command.

            [self clipVertexBuffer:_vertexBuffer1 stencilTexture:_stencilTexture];
            [self drawObj:cdl vertexBuffer:_vertexBuffer stencilTexture:_stencilTexture clear:YES];

            [self clipVertexBuffer:_vertexBuffer2 stencilTexture:_stencilTexture1];
            [self drawObj:cdl vertexBuffer:_vertexBuffer stencilTexture:_stencilTexture1 clear:NO];

            id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

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
