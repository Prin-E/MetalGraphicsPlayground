//
//  AppDelegate.m
//  MetalMSAA
//
//  Created by 이현우 on 2015. 9. 19..
//  Copyright © 2015년 Prin_E. All rights reserved.
//

#import "AppDelegate.h"
#import "MyView.h"
#import "SharedStructures.h"

#define CHECK_ERR(X) if((X)) { NSLog(@"%@", (X)); (X)=nil; }

const NSInteger kNumInflightBuffers = 3;

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet MyView *view;

@end

@implementation AppDelegate {
    id<MTLDevice> _device;
    id<MTLCommandQueue> _queue;
    id<MTLLibrary> _library;
    
    id<MTLRenderPipelineState> _pipeline, _msPipeline;
    id<MTLBuffer> _vertexBuffer;
    id<MTLBuffer> _indexBuffer;
    id<MTLBuffer> _uniformBuffer;
    
    MTLRenderPassDescriptor *_msRPDesc;
    
    id<MTLTexture> _texture;
    
    dispatch_semaphore_t semaphore;
    
    id<MTLRenderPipelineState> _pipelineState;
    NSUInteger _textureWidth, _textureHeight, _textureComp;
    
    uniform_t _uniform;
    uint8_t _uniformBufferIndex;
    float _rot;
}

- (void)awakeFromNib {
    [self _initMetal];
    [self _initView];
    [self _initAssets];
    [self _reshape];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (void)_initMetal {
    _device = MTLCreateSystemDefaultDevice();
    _queue = [_device newCommandQueue];
    _library = [_device newDefaultLibrary];
    
    semaphore = dispatch_semaphore_create(kNumInflightBuffers);
}

- (void)_initView {
    _view.device = _device;
    _view.sampleCount = 1;
    _view.delegate = self;
    _view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    _view.preferredFramesPerSecond = 30;
}

- (void)_initAssets {
    NSError *err = nil;
    
    // BUFFER
    _uniformBuffer = [_device newBufferWithLength: kNumInflightBuffers * sizeof(uniform_t)
                                          options: 0];
    
    // TEXTURE
    NSImage *myImage = [NSImage imageNamed: @"PrinE2013"];
    NSBitmapImageRep *myImgRep = (NSBitmapImageRep *)[[myImage representations] objectAtIndex: 0];
    _textureWidth = myImage.size.width;
    _textureHeight = myImage.size.height;
    _textureComp = 4;
    
    unsigned char *_pixels = (unsigned char *)malloc(_textureWidth * _textureHeight * _textureComp);
    memset(_pixels, 0, _textureWidth * _textureHeight * _textureComp);
    
    for(int i = 0; i < _textureHeight; i++) {
        for(int j = 0; j < _textureWidth; j++) {
            NSUInteger offset = i * _textureWidth * _textureComp + j * _textureComp;
            NSColor *color = [myImgRep colorAtX: j y: i];
            _pixels[offset] = (unsigned char)([color redComponent] * 255.0f);
            _pixels[offset + 1] = (unsigned char)([color greenComponent] * 255.0f);
            _pixels[offset + 2] = (unsigned char)([color blueComponent] * 255.0f);
            _pixels[offset + 3] = (unsigned char)([color alphaComponent] * 255.0f);
        }
    }
    
    MTLTextureDescriptor *textureDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: _textureWidth height: _textureHeight mipmapped: NO];
    _texture = [_device newTextureWithDescriptor: textureDesc];
    [_texture replaceRegion: MTLRegionMake2D(0, 0, _textureWidth, _textureHeight)
                mipmapLevel: 0
                  withBytes: _pixels
                bytesPerRow: _textureComp * _textureWidth];
    free(_pixels);
    
    // VERTEX
    float vertexData[] = {
        -0.5f, 0.5f, 0.0f, 0.0f, 0.0f,
        0.5f, 0.5f, 0.0f, 1.0f, 0.0f,
        0.5f, -0.5f, 0.0f, 1.0f, 1.0f,
        -0.5f, -0.5f, 0.0f, 0.0f, 1.0f
    };
    
    _vertexBuffer = [_device newBufferWithBytes: vertexData length: sizeof vertexData options: 0];
    
    MTLVertexDescriptor *vertexDesc = [[MTLVertexDescriptor alloc] init];
    vertexDesc.attributes[0].format = MTLVertexFormatFloat3;
    vertexDesc.attributes[0].offset = 0;
    vertexDesc.attributes[0].bufferIndex = 0;
    vertexDesc.attributes[1].format = MTLVertexFormatFloat2;
    vertexDesc.attributes[1].offset = sizeof(float) * 3;
    vertexDesc.attributes[1].bufferIndex = 0;
    vertexDesc.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    vertexDesc.layouts[0].stride = sizeof(float) * 5;
    
    // INDICES
    int indices[] = {
        0, 1, 2, 0, 2, 3
    };
    
    _indexBuffer = [_device newBufferWithBytes: indices length: sizeof(indices) options: 0];
    
    // Render Pipeline
    MTLRenderPipelineDescriptor *pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDesc.vertexDescriptor = vertexDesc;
    pipelineDesc.vertexFunction = [_library newFunctionWithName: @"vert2"];
    pipelineDesc.fragmentFunction = [_library newFunctionWithName: @"frag2"];
    pipelineDesc.colorAttachments[0].pixelFormat = _view.colorPixelFormat;
    pipelineDesc.colorAttachments[0].blendingEnabled = YES;
    pipelineDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
    pipelineDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pipelineDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pipelineDesc.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    _pipeline = [_device newRenderPipelineStateWithDescriptor: pipelineDesc error: &err];
    CHECK_ERR(err);
    
    pipelineDesc.vertexFunction = [_library newFunctionWithName: @"vert"];
    pipelineDesc.fragmentFunction = [_library newFunctionWithName: @"frag"];
    pipelineDesc.sampleCount = 8;
    _msPipeline = [_device newRenderPipelineStateWithDescriptor: pipelineDesc error: &err];
    CHECK_ERR(err);
    
    // Render Pass
    textureDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatBGRA8Unorm
                                                                     width: 1000
                                                                    height: 1000
                                                                 mipmapped: NO];
    textureDesc.sampleCount = 8;
    textureDesc.storageMode = MTLStorageModePrivate;
    textureDesc.textureType = MTLTextureType2DMultisample;
    textureDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    id<MTLTexture> msColorTex = [_device newTextureWithDescriptor: textureDesc];
    textureDesc.pixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    id<MTLTexture> msDepthTex = [_device newTextureWithDescriptor: textureDesc];
    textureDesc.textureType = MTLTextureType2D;
    textureDesc.sampleCount = 8;
    textureDesc.pixelFormat = MTLPixelFormatBGRA8Unorm;
    //id<MTLTexture> resolveTexture = [_device newTextureWithDescriptor: textureDesc];
    
    _msRPDesc = [[MTLRenderPassDescriptor alloc] init];
    _msRPDesc.colorAttachments[0].texture = msColorTex;
    _msRPDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.0f, 0.0f, 0.0f, 0.0f);
    //_msRPDesc.colorAttachments[0].resolveTexture = resolveTexture;
    _msRPDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    _msRPDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
    _msRPDesc.depthAttachment.loadAction = MTLLoadActionClear;
    _msRPDesc.depthAttachment.storeAction = MTLStoreActionStore;
    _msRPDesc.depthAttachment.texture = msDepthTex;
    _msRPDesc.stencilAttachment.loadAction = MTLLoadActionClear;
    _msRPDesc.stencilAttachment.storeAction = MTLStoreActionStore;
    _msRPDesc.stencilAttachment.texture = msDepthTex;
}

- (void)drawInMTKView:(MTKView *)view {
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    id<MTLCommandBuffer> buffer = [_queue commandBuffer];
    
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor: _msRPDesc];
    [encoder setRenderPipelineState: _msPipeline];
    [encoder setVertexBuffer: _vertexBuffer offset: 0 atIndex: 0];
    [encoder setVertexBuffer: _uniformBuffer offset: _uniformBufferIndex * sizeof(uniform_t) atIndex: 1];
    [encoder setFragmentTexture: _texture atIndex: 0];
    [encoder drawIndexedPrimitives: MTLPrimitiveTypeTriangle
                        indexCount: 6
                         indexType: MTLIndexTypeUInt32
                       indexBuffer: _indexBuffer
                 indexBufferOffset: 0];
    [encoder textureBarrier];
    [encoder endEncoding];

    MTLRenderPassDescriptor *renderPassDesc = [_view currentRenderPassDescriptor];
    renderPassDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.0f, 0.4f, 0.8f, 1.0f);
    encoder = [buffer renderCommandEncoderWithDescriptor: renderPassDesc];
    [encoder setRenderPipelineState: _pipeline];
    [encoder setVertexBuffer: _vertexBuffer offset: 0 atIndex: 0];
    [encoder setVertexBuffer: _uniformBuffer offset: _uniformBufferIndex * sizeof(uniform_t) atIndex: 1];
    [encoder setFragmentTexture: _msRPDesc.colorAttachments[0].texture atIndex: 0];
    [encoder drawIndexedPrimitives: MTLPrimitiveTypeTriangle
                        indexCount: 6
                         indexType: MTLIndexTypeUInt32
                       indexBuffer: _indexBuffer
                 indexBufferOffset: 0];
    [encoder endEncoding];
    
    _uniformBufferIndex = (_uniformBufferIndex + 1) % kNumInflightBuffers;
    if(_view.mode == 2) {
        _rot += 0.01666f * M_PI * 0.25f;
        if(_rot > M_PI * 2) _rot -= M_PI * 2;
        _uniform.modelview = matrix_from_rotation(_rot, 0.0f, 0.0f, 1.0f);
    }
    [self _updateUniformBuffer];
    
    [buffer addCompletedHandler: ^(id<MTLCommandBuffer> buffer) {
        dispatch_semaphore_signal(semaphore);
    }];
    [buffer presentDrawable: _view.currentDrawable];
    [buffer commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    [self _reshape];
}

- (void)_reshape {
    CGSize size = _view.drawableSize;
    float aspect = size.width / size.height;
    _uniform.projection = matrix_ortho(-aspect / 2, aspect / 2, -1.0f / 2, 1.0f / 2, -1.0f, 1.0f);
    _uniform.modelview = matrix_from_rotation(_rot, 0.0f, 0.0f, 1.0f);
}

- (void)_updateUniformBuffer {
    memcpy(_uniformBuffer.contents + _uniformBufferIndex * sizeof(uniform_t), &_uniform, sizeof(uniform_t));
}

static matrix_float4x4 matrix_ortho(float left, float right, float bottom, float top, float near, float far) {
    matrix_float4x4 matrix;
    matrix.columns[0] = vector4(2 / (right - left), 0.0f, 0.0f, 0.0f);
    matrix.columns[1] = vector4(0.0f, 2 / (top - bottom), 0.0f, 0.0f);
    matrix.columns[2] = vector4(0.0f, 0.0f, 2 / (far - near), 0.0f);
    matrix.columns[3] = vector4(-(right + left) / (right - left),
                                -(top + bottom) / (top - bottom),
                                -(near) / (far - near), 1.0f);
    return matrix;
}

static matrix_float4x4 matrix_from_rotation(float radians, float x, float y, float z)
{
    vector_float3 v = vector_normalize(((vector_float3){x, y, z}));
    float cos = cosf(radians);
    float cosp = 1.0f - cos;
    float sin = sinf(radians);
    
    matrix_float4x4 m = {
        .columns[0] = {
            cos + cosp * v.x * v.x,
            cosp * v.x * v.y + v.z * sin,
            cosp * v.x * v.z - v.y * sin,
            0.0f,
        },
        
        .columns[1] = {
            cosp * v.x * v.y - v.z * sin,
            cos + cosp * v.y * v.y,
            cosp * v.y * v.z + v.x * sin,
            0.0f,
        },
        
        .columns[2] = {
            cosp * v.x * v.z + v.y * sin,
            cosp * v.y * v.z - v.x * sin,
            cos + cosp * v.z * v.z,
            0.0f,
        },
        
        .columns[3] = { 0.0f, 0.0f, 0.0f, 1.0f
        }
    };
    return m;
}

@end
