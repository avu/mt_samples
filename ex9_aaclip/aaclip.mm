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
    id<MTLRenderPipelineState>  _pipelineState;
    id <MTLRenderPipelineState> _pipelineState3;
    id<MTLRenderPipelineState>  _stencilRenderState;
    id<MTLDepthStencilState>    _stencilState;
    id <MTLTexture>             _aaStencilData;
    id <MTLTexture>             _aaStencilTexture;
    id <MTLTexture>             _stencilData;
    id <MTLTexture>             _stencilTexture;
    MTLScissorRect              _clipRect;
    id <MTLBuffer>              _uniformBuffer;
    id <MTLBuffer>              _uniformBuffer3;
    id<MTLBuffer>  			    _vertexBuffer;
    id<MTLBuffer>  			    _vertexBuffer1;
    id <MTLBuffer>              _vertexBuffer2;
    BOOL 				        _sizeUpdated;
    id<MTLTexture>              _sampleTxt;
    id<MTLTexture>              _bufTxt;
    MTLRenderPassDescriptor    *rpd;
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

        _shaders = [cml.device newLibraryWithFile: @"aaclipsh.metallib" error:&error];
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

        id<MTLFunction> stencilFragmentProgram = [_shaders newFunctionWithName:@"frag_stencil"];
        if (!stencilFragmentProgram)
        {
            printf("ERROR: Couldn't load fragment function from default library.");
            return nil;
        }

        id<MTLFunction> stencilVertexProgram = [_shaders newFunctionWithName:@"vert_stencil"];
        if (!stencilVertexProgram)
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

        _uniformBuffer = [cml.device newBufferWithLength:sizeof(FrameUniforms)
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

        pipelineStateDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        pipelineStateDesc.colorAttachments[0].blendingEnabled = YES;
        pipelineStateDesc.colorAttachments[0].rgbBlendOperation =   MTLBlendOperationAdd;
        pipelineStateDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
        pipelineStateDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
        pipelineStateDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDesc.sampleCount      = 4;
        pipelineStateDesc.vertexFunction   = vertexProgram;
        pipelineStateDesc.fragmentFunction = fragmentProgram;
        pipelineStateDesc.vertexDescriptor = vertDesc;
        _pipelineState = [cml.device newRenderPipelineStateWithDescriptor:pipelineStateDesc
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
        MTLDepthStencilDescriptor* stencilDescriptor;
        stencilDescriptor = [[MTLDepthStencilDescriptor new] autorelease];
        stencilDescriptor.frontFaceStencil.stencilCompareFunction = MTLCompareFunctionEqual;
        stencilDescriptor.frontFaceStencil.stencilFailureOperation = MTLStencilOperationKeep;

        stencilDescriptor.backFaceStencil.stencilCompareFunction = MTLCompareFunctionEqual;
        stencilDescriptor.backFaceStencil.stencilFailureOperation = MTLStencilOperationKeep;

        _stencilState = [cml.device newDepthStencilStateWithDescriptor:stencilDescriptor];
        MTLRenderPipelineDescriptor * stencilPipelineDesc = [[MTLRenderPipelineDescriptor new] autorelease];
        stencilPipelineDesc.sampleCount = 4;
        //stencilPipelineDesc.sampleCount = 1;
        stencilPipelineDesc.vertexDescriptor = vertDesc;
        stencilPipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm; // A byte buffer format
        stencilPipelineDesc.vertexFunction = stencilVertexProgram;
        stencilPipelineDesc.fragmentFunction = stencilFragmentProgram;
        _stencilRenderState = [cml.device newRenderPipelineStateWithDescriptor:stencilPipelineDesc error:&error];

        MTLTextureDescriptor *desc = [MTLTextureDescriptor new];
        desc.textureType = MTLTextureType2DMultisample;
        desc.width = (NSUInteger)(self.frame.size.width *  [[NSScreen mainScreen] backingScaleFactor]);
        desc.height = (NSUInteger)(self.frame.size.height *  [[NSScreen mainScreen] backingScaleFactor]);
        desc.sampleCount = 4;
        desc.pixelFormat = MTLPixelFormatBGRA8Unorm;
        desc.storageMode = MTLStorageModePrivate;
        _sampleTxt = [cml.device newTextureWithDescriptor:desc];

        desc = [MTLTextureDescriptor new];
        desc.width = (NSUInteger)(self.frame.size.width *  [[NSScreen mainScreen] backingScaleFactor]);
        desc.height = (NSUInteger)(self.frame.size.height *  [[NSScreen mainScreen] backingScaleFactor]);
        desc.pixelFormat = MTLPixelFormatBGRA8Unorm;
        desc.storageMode = MTLStorageModePrivate;
        desc.textureType = MTLTextureType2D;
        _bufTxt = [cml.device newTextureWithDescriptor:desc];
        
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

        Vertex verts2[] = {
                Vertex{{-0.1f, 0.1f, 0.0f}, {255, 0, 0, 255}},
                Vertex{{0.1f, -0.1f, 0.0f}, {0, 255, 0, 255}},
                Vertex{{0.1f, 0.1f, 0.0f}, {0, 0, 255, 255}},
                Vertex{{0.1f, 0.1f, 0.0f}, {255, 0, 0, 255}},
                Vertex{{-0.1f, 0.1f, 0.0f}, {0, 255, 0, 255}},
                Vertex{{-0.1f, 0.1f, 0.0f}, {0, 0, 255, 255}}
        };

// Create vertices.
        TVertex verts1[] = {
                TVertex{{-1.0f, -1.0f, 0}, {255, 0, 0, 255}, {0, 0}},
                TVertex{{-1.0f, 1.0f, 0}, {0, 255, 0, 255}, {0, 1}},
                TVertex{{1.0, -1.0f, 0}, {0, 0, 255, 255}, {1, 0}},
                TVertex{{-1.0f, 1.0f, 0}, {0, 255, 0, 255}, {0, 1}},
                TVertex{{1.0f, 1.0f, 0}, {255, 0, 0, 255}, {1, 1}},
                TVertex{{1.0, -1.0f, 0}, {0, 0, 255, 255}, {1, 0}}
        };
        _vertexBuffer = [cml.device newBufferWithBytes:verts
                                                length:sizeof(verts)
                                               options:MTLResourceCPUCacheModeDefaultCache];

        _vertexBuffer1 = [cml.device newBufferWithBytes:verts2
                                                 length:sizeof(verts2)
                                                options:MTLResourceCPUCacheModeDefaultCache];

        _vertexBuffer2 = [cml.device newBufferWithBytes:verts1
                                                 length:sizeof(verts1)
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

- (void)update {
    dispatch_semaphore_wait(_renderSemaphore, DISPATCH_TIME_FOREVER);

    if (self.sizeUpdated)
    {
        // Set the metal layer to the drawable size in case orientation or size changes.
        CGSize drawableSize = self.bounds.size;
        CAMetalLayer* cml = static_cast<CAMetalLayer *>(self.layer);
        NSScreen* screen = self.window.screen ?: [NSScreen mainScreen];
        drawableSize.width *= screen.backingScaleFactor;
        drawableSize.height *= screen.backingScaleFactor;

        _clipRect.x = static_cast<NSUInteger>(drawableSize.width / 3);
        _clipRect.y = static_cast<NSUInteger>(drawableSize.height / 3);
        _clipRect.width = static_cast<NSUInteger>(drawableSize.width / 3);
        _clipRect.height = static_cast<NSUInteger>(drawableSize.height / 3);

        MTLTextureDescriptor *stencilDataDescriptor =
                [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                                   width:drawableSize.width height:drawableSize.height mipmapped:NO];
        stencilDataDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        stencilDataDescriptor.storageMode = MTLStorageModePrivate;

        if (_stencilData) {
            [_stencilData release];
        }

        _stencilData = [cml.device newTextureWithDescriptor:stencilDataDescriptor];

        MTLTextureDescriptor *stencilTextureDescriptor =
                [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatStencil8
                                                                   width:drawableSize.width height:drawableSize.height mipmapped:NO];

        stencilTextureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
        stencilTextureDescriptor.storageMode = MTLStorageModePrivate;
        if (_stencilTexture) {
            [_stencilTexture release];
        }
        _stencilTexture = [cml.device newTextureWithDescriptor:stencilTextureDescriptor];

        stencilDataDescriptor =
                [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Uint
                 width:drawableSize.width height:drawableSize.height mipmapped:NO];

        stencilDataDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        stencilDataDescriptor.storageMode = MTLStorageModePrivate;
        //stencilDataDescriptor.sampleCount = 4;
        stencilDataDescriptor.textureType = MTLTextureType2D;


        if (_aaStencilData) {
            [_aaStencilData release];
        }

        _aaStencilData = [cml.device newTextureWithDescriptor:stencilDataDescriptor];

        stencilTextureDescriptor =
                [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatStencil8
                 width:drawableSize.width height:drawableSize.height mipmapped:NO];

        stencilTextureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
        stencilTextureDescriptor.storageMode = MTLStorageModePrivate;
        stencilTextureDescriptor.sampleCount = 4;
        stencilTextureDescriptor.textureType = MTLTextureType2DMultisample;
        if (_aaStencilTexture) {
            [_aaStencilTexture release];
        }
        _aaStencilTexture = [cml.device newTextureWithDescriptor:stencilTextureDescriptor];

        NSUInteger width = drawableSize.width;
        NSUInteger height = drawableSize.height;
        id <MTLBuffer> buff = [cml.device newBufferWithLength:width * height options:MTLResourceStorageModeShared];
        id <MTLBuffer> buff1 = [cml.device newBufferWithLength:width * height options:MTLResourceStorageModeShared];
        memset(buff.contents, 0xff, width * height);
        memset(buff.contents, 0, width * height);
        for (int i = width/2 - 100; i < width/2 + 100; i++) {
            for (int j = height/2 - 100; j < height/2 + 100; j++) {
                ((char*)buff.contents)[j*width + i] = 0;
            }
        }

//        id<MTLCommandBuffer> commandBuf = [_commandQueue commandBuffer];
//        id<MTLBlitCommandEncoder> blitEncoder = [commandBuf blitCommandEncoder];

//        [blitEncoder copyFromBuffer:buff
//                       sourceOffset:0
//                  sourceBytesPerRow:width
//                sourceBytesPerImage:width * height
//                         sourceSize:MTLSizeMake(width, height, 1)
//                          toTexture:_stencilData
//                   destinationSlice:0
//                   destinationLevel:0
//                  destinationOrigin:MTLOriginMake(0, 0, 0)];
//        [blitEncoder endEncoding];

//        [commandBuf commit];
//        [commandBuf waitUntilCompleted];


        [buff release];
        ((CAMetalLayer *)self.layer).drawableSize = drawableSize;

        self.sizeUpdated = NO;
    }

    id<CAMetalDrawable> cdl = [((CAMetalLayer *)self.layer) nextDrawable];

    if (!cdl) {
        printf("ERROR: Failed to get a valid drawable.");
    } else {
        MTLRenderPassDescriptor* rpds = [MTLRenderPassDescriptor renderPassDescriptor];

        MTLRenderPassColorAttachmentDescriptor *colorAttachment = rpds.colorAttachments[0];
        colorAttachment.texture = _stencilData;
//        colorAttachment.resolveTexture = _stencilData;
        colorAttachment.storeAction = MTLStoreActionStore;
        colorAttachment.loadAction = MTLLoadActionClear;
        colorAttachment.clearColor = MTLClearColorMake(0.0f, 0.0f, 0.0f, 0.0f);

        MTLRenderPassDescriptor* rpd = [MTLRenderPassDescriptor renderPassDescriptor];

        colorAttachment = rpd.colorAttachments[0];
        colorAttachment.texture = _sampleTxt;
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

        simd::float4x4 rot(simd::float4{1, 0, 0, 0},
                           simd::float4{0, 1, 0, 0},
                           simd::float4{0, 0, 1, 0},
                           simd::float4{0, 0, 0, 1});

        FrameUniforms *uniforms = (FrameUniforms *) [_uniformBuffer contents];
        uniforms->projectionViewModel = rot;
        
        FrameUniforms *uniforms3 = (FrameUniforms *) [_uniformBuffer3 contents];
        uniforms3->projectionViewModel = rot;
        // Create a command buffer.

        // Encode render command.
//        id <MTLRenderCommandEncoder> encoder = nil;

        id <MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:rpds];
        [encoder setRenderPipelineState:_stencilRenderState];
    //    [encoder setScissorRect:_clipRect];
        [encoder setVertexBuffer:_vertexBuffer1
                          offset:0
                         atIndex:MeshVertexBuffer];
        [encoder setVertexBuffer:_uniformBuffer
                          offset:0 atIndex:FrameUniformBuffer];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [encoder endEncoding];

        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];

        commandBuffer = [_commandQueue commandBuffer];
        id<MTLBuffer> buff =
                [((CAMetalLayer*)(self.layer)).device newBufferWithLength:_aaStencilData.width * _aaStencilData.height*4
                                         options:MTLResourceStorageModeShared];

        id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
        [blitEncoder copyFromTexture:_aaStencilData
                         sourceSlice:0
                         sourceLevel:0
                        sourceOrigin:MTLOriginMake(0, 0, 0)
                          sourceSize:MTLSizeMake(_aaStencilData.width, _aaStencilData.height, 1)
                            toBuffer:buff
                   destinationOffset:0
              destinationBytesPerRow:_aaStencilData.width*4
            destinationBytesPerImage:_aaStencilData.width * _aaStencilData.height*4];

        [blitEncoder copyFromBuffer:buff
                       sourceOffset:0
                  sourceBytesPerRow:_aaStencilData.width*4
                sourceBytesPerImage:_aaStencilData.width * _aaStencilData.height*4
                         sourceSize:MTLSizeMake(_aaStencilData.width, _aaStencilData.height, 1)
                          toTexture:_aaStencilTexture
                   destinationSlice:0
                   destinationLevel:0
                  destinationOrigin:MTLOriginMake(0, 0, 0)];
        [blitEncoder endEncoding];

        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];

        [buff release];

        commandBuffer = [_commandQueue commandBuffer];
        encoder = [commandBuffer renderCommandEncoderWithDescriptor:rpd];
        [encoder setScissorRect:_clipRect];
       // [encoder setDepthStencilState:_stencilState];

        [encoder setStencilReferenceValue:0xFF];

        [encoder setFrontFacingWinding:MTLWindingCounterClockwise];
        [encoder setRenderPipelineState:_pipelineState];
        [encoder setVertexBuffer:_vertexBuffer
                          offset:0
                         atIndex:MeshVertexBuffer];
        [encoder setVertexBuffer:_uniformBuffer
                          offset:0 atIndex:FrameUniformBuffer];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [encoder endEncoding];

        id <MTLRenderCommandEncoder> encoder3 = [commandBuffer renderCommandEncoderWithDescriptor:rpd3];

        [encoder3 setRenderPipelineState:_pipelineState3];
        [encoder3 setVertexBuffer:_vertexBuffer2
                           offset:0
                          atIndex:MeshVertexBuffer];
        [encoder3 setVertexBuffer:_uniformBuffer3
                           offset:0 atIndex:FrameUniformBuffer];
        [encoder3 setFragmentTexture: _bufTxt atIndex: 0];
        [encoder3 setFragmentTexture: _stencilData atIndex: 1];


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
