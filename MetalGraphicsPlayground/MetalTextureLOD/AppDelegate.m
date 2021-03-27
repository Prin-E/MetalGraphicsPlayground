//
//  AppDelegate.m
//  MetalGraphicsLine
//
//  Created by 이현우 on 2015. 9. 6..
//  Copyright © 2015년 Prin_E. All rights reserved.
//

#import "AppDelegate.h"
#import <simd/simd.h>
#import "SharedStructures.h"
#import "MyView.h"
#import <OpenGL/OpenGL.h>

static NSUInteger kTextureWidth = 512;
static NSUInteger kTextureHeight = 512;
static NSUInteger kTextureComp = 4;

@interface AppDelegate () {
    id<MTLDevice> _device;
    id<MTLLibrary> _library;
    id<MTLCommandQueue> _queue;
    
    dispatch_semaphore_t _semaphore;
    
    id<MTLDepthStencilState> _depthState;
    id<MTLTexture> _texture;
    id<MTLBuffer> _vertexBuffer;
    id<MTLBuffer> _indexBuffer;
    id<MTLBuffer> _uniformBuffer;
    id<MTLSamplerState> _sampler;
    id<MTLTexture> _renderTexture;
    
    id<MTLRenderPipelineState> _renderPipelineState;
    id<MTLRenderPipelineState> _renderPipelineState2;
    
    unsigned char *_imagePixels;
    unsigned char *_pixels;
    
    float _aspectRatio;
    float _radian;
    unsigned long _frame;
}

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet MyView *view;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSImage *myImage = [NSImage imageNamed: @"PrinE2013"];
    NSBitmapImageRep *myImgRep = (NSBitmapImageRep *)[[myImage representations] objectAtIndex: 0];
    kTextureWidth = myImage.size.width;
    kTextureHeight = myImage.size.height;
    
    _imagePixels = (unsigned char *)malloc(kTextureWidth * kTextureHeight * kTextureComp);
    _pixels = (unsigned char *)malloc(kTextureWidth * kTextureHeight * kTextureComp);
    memset(_pixels, 0, kTextureWidth * kTextureHeight * kTextureComp);
    memset(_imagePixels, 0, kTextureWidth * kTextureHeight * kTextureComp);
    
    for(int i = 0; i < kTextureHeight; i++) {
        for(int j = 0; j < kTextureWidth; j++) {
            NSUInteger offset = i * kTextureWidth * kTextureComp + j * kTextureComp;
            NSColor *color = [myImgRep colorAtX: j y: i];
            _imagePixels[offset] = (unsigned char)([color redComponent] * 255.0f);
            _imagePixels[offset + 1] = (unsigned char)([color greenComponent] * 255.0f);
            _imagePixels[offset + 2] = (unsigned char)([color blueComponent] * 255.0f);
            _imagePixels[offset + 3] = (unsigned char)([color alphaComponent] * 255.0f);
        }
    }
    [self _initView];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver: self selector: @selector(windowWillClose:) name: NSWindowWillCloseNotification object: nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    free(_pixels);
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)windowWillClose:(NSNotification *)notification {
    [NSApp terminate: self];
}

- (void)_initView {
    NSArray<id<MTLDevice>> *devices = MTLCopyAllDevices();
    
    for(id<MTLDevice> device in devices) {
        if(!device.isRemovable) {
            _device = device;
            NSLog(@"We'll use device \"%@\"", device.name);
            break;
        }
    }
    
    if(_device == nil)
        _device = MTLCreateSystemDefaultDevice();
    
    uint64_t workingSetSize = _device.recommendedMaxWorkingSetSize;
    NSLog(@"Recommended working set size : %llu", workingSetSize);
    
    // Check GPU family version
    NSLog(@"MTLFeatureSet_macOS_GPUFamily1_v1: %d", [_device supportsFeatureSet: MTLFeatureSet_macOS_GPUFamily1_v1]);
    if (@available(macOS 10.12, *)) {
        NSLog(@"MTLFeatureSet_macOS_GPUFamily1_v2: %d", [_device supportsFeatureSet: MTLFeatureSet_macOS_GPUFamily1_v2]);
    }
    if (@available(macOS 10.13, *)) {
        NSLog(@"MTLFeatureSet_macOS_GPUFamily1_v3: %d", [_device supportsFeatureSet: MTLFeatureSet_macOS_GPUFamily1_v3]);
    }
    if (@available(macOS 10.14, *)) {
        NSLog(@"MTLFeatureSet_macOS_GPUFamily2_v1: %d", [_device supportsFeatureSet: MTLFeatureSet_macOS_GPUFamily2_v1]);
    }
    
    // Check features support
    if (@available(macOS 10.13, *)) {
        MTLReadWriteTextureTier rwTexTier = _device.readWriteTextureSupport;
        if (rwTexTier == MTLReadWriteTextureTier1)
            NSLog(@"MTLReadWriteTextureTier1");
        else if (rwTexTier == MTLReadWriteTextureTier2)
            NSLog(@"MTLReadWriteTextureTier2");
        MTLArgumentBuffersTier iabTier = _device.argumentBuffersSupport;
        if (iabTier == MTLArgumentBuffersTier1)
            NSLog(@"MTLIndirectArgumentBuffersTier1");
        else if (iabTier == MTLArgumentBuffersTier2)
            NSLog(@"MTLIndirectArgumentBuffersTier2");
        BOOL rasterOrderGroupsSupported = _device.rasterOrderGroupsSupported;
        NSLog(@"Raster order group : %d", rasterOrderGroupsSupported);
        MTLSize maxThreadsPerThreadgroup = _device.maxThreadsPerThreadgroup;
        NSLog(@"Max threads per threadgroup : %lux%lux%lu", maxThreadsPerThreadgroup.width, maxThreadsPerThreadgroup.height, maxThreadsPerThreadgroup.depth);
        NSInteger maxThreadgroupMemoryLength = _device.maxThreadgroupMemoryLength;
        NSLog(@"Max threadgroup memory length : %lu", maxThreadgroupMemoryLength);
    }
    
    _library = [_device newDefaultLibrary];
    _queue = [_device newCommandQueue];
    
    /*
    MTLHeapDescriptor *heapDesc = [MTLHeapDescriptor new];
    heapDesc.size = 1024*1024*1024;
    id<MTLHeap> heap = [_device newHeapWithDescriptor: heapDesc];
    
    id<MTLBuffer> b1 = [heap newBufferWithLength: 1024*1024*256 options: MTLResourceStorageModePrivate];
    NSLog(@"max available : %lu", [heap maxAvailableSizeWithAlignment: 256]);
    id<MTLBuffer> b2 = [heap newBufferWithLength: 1024*1024*256 options: MTLResourceStorageModePrivate];
    NSLog(@"max available : %lu", [heap maxAvailableSizeWithAlignment: 256]);
    id<MTLBuffer> b3 = [heap newBufferWithLength: 1024*1024*256 options: MTLResourceStorageModePrivate];
    NSLog(@"max available : %lu", [heap maxAvailableSizeWithAlignment: 256]);
    id<MTLBuffer> b4 = [heap newBufferWithLength: 1024*1024*256 options: MTLResourceStorageModePrivate];
    NSLog(@"max available : %lu", [heap maxAvailableSizeWithAlignment: 256]);
    
    [b1 makeAliasable];
    [b3 makeAliasable];
    NSLog(@"max available : %lu", [heap maxAvailableSizeWithAlignment: 256]);
    
    id<MTLBuffer> b5 = [heap newBufferWithLength: 1024*1024*384 options: MTLResourceStorageModePrivate];
    NSLog(@"max available : %lu", [heap maxAvailableSizeWithAlignment: 256]);
    */
    
    _view.delegate = self;
    _view.device = _device;
    _view.preferredFramesPerSecond = 60;
    _view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    _view.sampleCount = 1;
    //_view.colorspace = CGColorSpaceCreateWithName(kCGColorSpaceLinearGray);
    _semaphore = dispatch_semaphore_create(3);
    
    MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthStateDesc.depthWriteEnabled = YES;
    _depthState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];
    
    MTLTextureDescriptor *textureDesc = [[MTLTextureDescriptor alloc] init];
    textureDesc.textureType = MTLTextureType2D;
    textureDesc.pixelFormat = MTLPixelFormatRGBA8Unorm;
    textureDesc.width = kTextureWidth;
    textureDesc.height = kTextureHeight;
    textureDesc.mipmapLevelCount = 9;
    _texture = [_device newTextureWithDescriptor: textureDesc];
    
    textureDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatBGRA8Unorm
                                                                     width: 640
                                                                    height: 480
                                                                 mipmapped: NO];
    textureDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    _renderTexture = [_device newTextureWithDescriptor: textureDesc];
    
    MTLSamplerDescriptor *samplerDesc = [[MTLSamplerDescriptor alloc] init];
    samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
    samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDesc.sAddressMode = MTLSamplerAddressModeRepeat;
    samplerDesc.tAddressMode = MTLSamplerAddressModeRepeat;
    samplerDesc.mipFilter = MTLSamplerMipFilterLinear;
    
    _sampler = [_device newSamplerStateWithDescriptor: samplerDesc];
    
    float posAndUVs[] = {
        -2.0f, -1.0f, 0.0f, 0.0f, 3.0f,
        -2.0f, 1.0f, 0.0f, 0.0f, 0.0f,
        2.0f, 1.0f, 0.0f, 6.0f, 0.0f,
        2.0f, -1.0f, 0.0f, 6.0f, 3.0f,
        
        -1.0f, -1.0f, 0.0f, 0.0f, 1.0f,
        -1.0f, 0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, -1.0f, 0.0f, 1.0f, 1.0f
    };
    
    int indices[] = {
        0, 1, 2, 0, 2, 3
    };
    
    _vertexBuffer = [_device newBufferWithBytes: posAndUVs length: sizeof(posAndUVs) options: MTLResourceStorageModeShared];
    _indexBuffer = [_device newBufferWithBytes: indices length: sizeof(indices) options: MTLResourceStorageModeShared];
    _uniformBuffer = [_device newBufferWithLength: sizeof(uniforms_t)*3 options: 0];
    [self mtkView: _view drawableSizeWillChange: _view.drawableSize];
    
    MTLVertexDescriptor *vertexDesc = [[MTLVertexDescriptor alloc] init];
    vertexDesc.attributes[0].format = MTLVertexFormatFloat3;
    vertexDesc.attributes[0].offset = 0;
    vertexDesc.attributes[0].bufferIndex = 0;
    vertexDesc.attributes[1].format = MTLVertexFormatFloat2;
    vertexDesc.attributes[1].offset = sizeof(float) * 3;
    vertexDesc.attributes[1].bufferIndex = 0;
    vertexDesc.layouts[0].stride = sizeof(float) * 5;
    vertexDesc.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    
    // first pipeline
    MTLRenderPipelineDescriptor *pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDesc.vertexDescriptor = vertexDesc;
    pipelineDesc.vertexFunction = [_library newFunctionWithName: @"vert"];
    pipelineDesc.fragmentFunction = [_library newFunctionWithName: @"frag"];
    pipelineDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pipelineDesc.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDesc.colorAttachments[1].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDesc.sampleCount = _view.sampleCount;
    _renderPipelineState = [_device newRenderPipelineStateWithDescriptor: pipelineDesc
                                                                   error: nil];
    
    // second pipeline
    pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDesc.vertexDescriptor = vertexDesc;
    pipelineDesc.vertexFunction = [_library newFunctionWithName: @"vert2"];
    pipelineDesc.fragmentFunction = [_library newFunctionWithName: @"frag2"];
    pipelineDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pipelineDesc.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDesc.sampleCount = _view.sampleCount;
    _renderPipelineState2 = [_device newRenderPipelineStateWithDescriptor: pipelineDesc
                                                                    error: nil];
}

- (void)_prepare {
    
    static char off = 0;
    for(int i = 0; i < kTextureHeight; i++) {
        for(int j = 0; j < kTextureWidth; j++) {
            NSUInteger offset = i * kTextureWidth * kTextureComp + j * kTextureComp;
            _pixels[offset] = MIN(_imagePixels[offset] + ABS((char)(i + off)) * 2, 255);
            _pixels[offset + 1] = MIN(_imagePixels[offset + 1] + ABS((char)(i + off)) * 2, 255);
            _pixels[offset + 2] = MIN(_imagePixels[offset + 2] + ABS((char)(i + off)) * 2, 255);
            _pixels[offset + 3] = 255;
        }
    }
    off++;
    [_texture replaceRegion: MTLRegionMake2D(0, 0, kTextureWidth, kTextureHeight) mipmapLevel: 0 withBytes: _pixels bytesPerRow: kTextureWidth * kTextureComp];
    
    _radian += 3.14159f * 0.0008333f;
    if(_radian > 6.28318f)
        _radian -= 6.28318f;
    
    matrix_float4x4 rotate = matrix_from_rotation(_radian, 0, 0, 1);
    
    uniforms_t *uniform = (uniforms_t *)[_uniformBuffer contents];
    memcpy(&uniform->normal_matrix, (const void *)&rotate, sizeof rotate);
    uniform->a = 0;
}

- (void)drawInMTKView:(MTKView *)view {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    [self _prepare];
    
    id<MTLCommandBuffer> buffer = [_queue commandBuffer];
    buffer.label = @"MyBuffer";
    
    id<MTLBlitCommandEncoder> enc = [buffer blitCommandEncoder];
    [enc generateMipmapsForTexture: _texture];
    [enc endEncoding];
    
    MTLRenderPassDescriptor *renderPassDesc = _view.currentRenderPassDescriptor;
    renderPassDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.14f, 0.48f, 1.0f, 1.0f);
    renderPassDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDesc.colorAttachments[1].texture = _renderTexture;
    renderPassDesc.colorAttachments[1].clearColor = MTLClearColorMake(0.0f, 0.0f, 0.0f, 1.0f);
    renderPassDesc.colorAttachments[1].loadAction = MTLLoadActionClear;
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor: renderPassDesc];
    encoder.label = @"MyEncoder";
    [encoder setDepthStencilState: _depthState];
    [encoder setRenderPipelineState: _renderPipelineState];
    [encoder setVertexBuffer: _vertexBuffer offset: 0 atIndex: 0];
    [encoder setVertexBuffer: _uniformBuffer offset: 0 atIndex: 1];
    [encoder setFragmentTexture: _texture atIndex: 0];
    [encoder setFragmentSamplerState: _sampler atIndex: 0];
    [encoder setFragmentBuffer: _uniformBuffer offset: 0 atIndex: 1];
    [encoder drawIndexedPrimitives: MTLPrimitiveTypeTriangle
                        indexCount: 6
                         indexType: MTLIndexTypeUInt32
                       indexBuffer:_indexBuffer indexBufferOffset: 0];
    [encoder endEncoding];
    
    if(_view.showsRenderTexture) {
        renderPassDesc = _view.currentRenderPassDescriptor;
        renderPassDesc.colorAttachments[0].loadAction = MTLLoadActionDontCare;
        encoder = [buffer renderCommandEncoderWithDescriptor: renderPassDesc];
        encoder.label = @"SecondEncoder";
        [encoder setDepthStencilState: _depthState];
        [encoder setRenderPipelineState: _renderPipelineState2];
        [encoder setVertexBuffer: _vertexBuffer offset: sizeof(float) * 20 atIndex: 0];
        [encoder setFragmentTexture: _renderTexture atIndex: 0];
        [encoder setFragmentSamplerState: _sampler atIndex: 0];
        [encoder drawIndexedPrimitives: MTLPrimitiveTypeTriangle
                            indexCount: 6
                             indexType: MTLIndexTypeUInt32
                           indexBuffer: _indexBuffer
                     indexBufferOffset: 0];
        [encoder endEncoding];
    }
    
    [buffer addCompletedHandler: ^(id<MTLCommandBuffer> buffer) {
        dispatch_semaphore_signal(self->_semaphore);
    }];
    
    [buffer presentDrawable: _view.currentDrawable];
    [buffer commit];
    
    _frame++;
    uniforms_t *uniform = (uniforms_t *)[_uniformBuffer contents];
    uniform->time += 0.01666f;
    if(uniform->time >= 8.0f) uniform->time = 0.0f;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    _aspectRatio = size.width / size.height;
    
    if(_uniformBuffer != nil) {
        matrix_float4x4 ortho = matrix_ortho(-1.0f * _aspectRatio, 1.0f * _aspectRatio, -1.0f, 1.0f, -1.0f, 1.0f);
        uniforms_t *uniform = (uniforms_t *)[_uniformBuffer contents];
        memcpy(&uniform->modelview_projection_matrix, (const void *)&ortho, sizeof ortho);
    }
    
    MTLTextureDescriptor *textureDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatBGRA8Unorm
                                                                                           width: size.width
                                                                                          height: size.height
                                                                                       mipmapped: NO];
    textureDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    textureDesc.storageMode = MTLStorageModePrivate;
    _renderTexture = [_device newTextureWithDescriptor: textureDesc];
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
