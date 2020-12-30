//
//  MGPPostProcessingLayer.m
//  MetalPostProcessing
//
//  Created by 이현우 on 24/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPPostProcessingLayer.h"
#import "MGPPostProcessing.h"
#import "../Rendering/MGPGBuffer.h"
#import "../../Shaders/SharedStructures.h"
#import "../Utility/MGPTextureManager.h"

NSString * const MGPPostProcessingLayerErrorDomain = @"MGPPostProcessingLayerErrorDomain";

@implementation MGPPostProcessingLayer {
    @protected
    id<MTLDevice> _device;
    id<MTLLibrary> _library;
    __weak MGPPostProcessing *_postProcessing;
}

@synthesize postProcessing = _postProcessing;
@synthesize enabled = _enabled;

- (instancetype)init {
    @throw [NSException exceptionWithName: MGPPostProcessingLayerErrorDomain
                                   reason: @"Use initWithDevice:library: instead."
                                 userInfo: @{
                                             NSLocalizedDescriptionKey : @"Use initWithDevice:library: instead."
                                             }];
    return nil;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device library:(id<MTLLibrary>)library {
    self = [super init];
    if(self) {
        _device = device;
        _library = library;
        _enabled = YES;
    }
    return self;
}

- (NSUInteger)renderingOrder {
    return MGPPostProcessingRenderingOrderAfterShadePass;
}

- (void)render:(id<MTLCommandBuffer>)buffer {}
- (void)resize:(CGSize)newSize {}

@end

@implementation MGPPostProcessingLayerSSAO {
    id<MTLComputePipelineState> _ssaoPipeline;
    id<MTLComputePipelineState> _blurHPipeline, _blurVPipeline;
    id<MTLComputePipelineState> _deinterleave2x2Pipeline, _interleave2x2Pipeline;
    id<MTLBuffer> _ssaoRandomSamplesBuffer;
    id<MTLBuffer> _ssaoPropsBuffer;
    CGSize _destinationResolution;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device library:(id<MTLLibrary>)library {
    self = [super initWithDevice: device library: library];
    if(self) {
        _numSamples = 32;
        _downsample = 1;
        _intensity = 0.5f;
        _radius = 0.1f;
        _bias = 0.05f;
        [self _makeComputePipeline];
        [self _makeRandomSamples];
        [self _makePropsBuffer];
    }
    return self;
}

- (void)_makeComputePipeline {
    _ssaoPipeline = [_device newComputePipelineStateWithFunction: [_library newFunctionWithName: @"ssao"]
                                                           error: nil];
    _blurHPipeline = [_device newComputePipelineStateWithFunction: [_library newFunctionWithName: @"ssao_blur_horizontal"]
                                                            error: nil];
    _blurVPipeline = [_device newComputePipelineStateWithFunction: [_library newFunctionWithName: @"ssao_blur_vertical"]
                                                            error: nil];
    _deinterleave2x2Pipeline = [_device newComputePipelineStateWithFunction: [_library newFunctionWithName: @"deinterleave_depth_2x2"]
                                                                      error: nil];
    _interleave2x2Pipeline = [_device newComputePipelineStateWithFunction: [_library newFunctionWithName: @"interleave_depth_2x2"]
                                                                    error: nil];
}

- (void)_makeTexturesWithSize: (CGSize)size {
    size.width = MAX(16, size.width / powf(2, _downsample));
    size.height = MAX(16, size.height / powf(2, _downsample));
    
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatR16Float
                                                                                    width: size.width
                                                                                   height: size.height
                                                                                mipmapped: NO];
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    desc.storageMode = MTLStorageModePrivate;
    _ssaoTexture = [_device newTextureWithDescriptor: desc];
    _ssaoTexture.label = @"SSAO Texture";
}

- (void)_makeRandomSamples {
    const int numSamples = 256;
    
    _ssaoRandomSamplesBuffer = [_device newBufferWithLength: sizeof(simd_float3) * numSamples
                                                    options: MTLResourceStorageModeManaged];
    for(int i = 0; i < numSamples; i++) {
        simd_float3 sample = {};
        sample.x = arc4random() / (float)UINT_MAX * 2.0f - 1.0f;
        sample.y = arc4random() / (float)UINT_MAX * 2.0f - 1.0f;
        sample.z = arc4random() / (float)UINT_MAX;
        sample = simd_normalize(sample) * (0.15f + 0.85f * powf((float)arc4random() / (float)UINT_MAX, 2.0f));
        ((simd_float3*)_ssaoRandomSamplesBuffer.contents)[i] = sample;
    }
    [_ssaoRandomSamplesBuffer didModifyRange: NSMakeRange(0, sizeof(simd_float3) * numSamples)];
}

- (void)_makePropsBuffer {
    _ssaoPropsBuffer = [_device newBufferWithLength: sizeof(ssao_props_t) * 3
                                            options: MTLResourceStorageModeManaged];
}

- (NSUInteger)renderingOrder {
    return MGPPostProcessingRenderingOrderBeforeLightPass;
}

- (void)setDownsample:(uint32_t)downsample {
    _downsample = downsample;
    if(_ssaoTexture != nil)
        [self _makeTexturesWithSize: _destinationResolution];
}

- (void)render: (id<MTLCommandBuffer>)buffer {
    ssao_props_t props = {
        .num_samples = _numSamples,
        .downsample = _downsample,
        .intensity = _intensity,
        .radius = _radius,
        .bias = _bias
    };
    memcpy(_ssaoPropsBuffer.contents + sizeof(ssao_props_t) * _postProcessing.currentBufferIndex,
           &props, sizeof(ssao_props_t));
    [_ssaoPropsBuffer didModifyRange: NSMakeRange(sizeof(ssao_props_t) * _postProcessing.currentBufferIndex, sizeof(ssao_props_t))];
    
    // make temporary textures
    id<MTLTexture> temporarySSAOTexture = nil;
    id<MTLTexture> deinterleavedTextureArray = nil;
    temporarySSAOTexture = [_postProcessing.textureManager newTemporaryTextureWithWidth:_ssaoTexture.width
                                                                                 height:_ssaoTexture.height
                                                                            pixelFormat:MTLPixelFormatR16Float
                                                                            storageMode:MTLStorageModePrivate
                                                                                  usage:MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite
                                                                       mipmapLevelCount:1
                                                                            arrayLength:1];
    _type = MGPSSAOTypeAdaptive;
    if(_type == MGPSSAOTypeAdaptive) {
        deinterleavedTextureArray = [_postProcessing.textureManager newTemporaryTextureWithWidth:_destinationResolution.width / 2
                                                                                          height:_destinationResolution.height / 2
                                                                                     pixelFormat:MTLPixelFormatR16Float
                                                                                     storageMode:MTLStorageModePrivate
                                                                                           usage:MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite
                                                                                mipmapLevelCount:1
                                                                                     arrayLength:4];
    }
    
    
    NSUInteger width = _ssaoTexture.width, height = _ssaoTexture.height;
    MGPGBuffer *gBuffer = _postProcessing.gBuffer;
    id<MTLBuffer> cameraBuffer = _postProcessing.cameraBuffer;
    NSUInteger currentBufferIndex = _postProcessing.currentBufferIndex;
    
    id<MTLComputeCommandEncoder> encoder = [buffer computeCommandEncoder];
    [encoder setLabel: @"SSAO"];
    
    // num threads, threadgroups
    MTLSize threadsPerThreadgroup = MTLSizeMake(16, 16, 1);
    MTLSize threadgroups = MTLSizeMake((width+threadsPerThreadgroup.width-1)/threadsPerThreadgroup.width,
                                       (height+threadsPerThreadgroup.height-1)/threadsPerThreadgroup.height,
                                       1);
    
    MTLSize threadgroups2 = MTLSizeMake((_destinationResolution.width+threadsPerThreadgroup.width-1)/threadsPerThreadgroup.width,
                                       (_destinationResolution.height+threadsPerThreadgroup.height-1)/threadsPerThreadgroup.height,
                                       1);
    
    // deinterleave
    if(_type == MGPSSAOTypeAdaptive) {
        [encoder setComputePipelineState: _deinterleave2x2Pipeline];
        [encoder setTexture:gBuffer.depth atIndex:0];
        [encoder setTexture:deinterleavedTextureArray atIndex:1];
        [encoder dispatchThreadgroups:threadgroups2
                threadsPerThreadgroup:threadsPerThreadgroup];
    }
    
    // step 1 : ssao
    [encoder setComputePipelineState: _ssaoPipeline];
    [encoder setTexture: gBuffer.depth atIndex: 0];
    [encoder setTexture: gBuffer.normal atIndex: 1];
    [encoder setTexture: gBuffer.tangent atIndex: 2];
    [encoder setTexture: _ssaoTexture atIndex: 3];
    [encoder setBuffer: _ssaoRandomSamplesBuffer
                offset: 0
               atIndex: 0];
    [encoder setBuffer: _ssaoPropsBuffer
                offset: sizeof(ssao_props_t) * _postProcessing.currentBufferIndex
               atIndex: 1];
    [encoder setBuffer: cameraBuffer
                offset: currentBufferIndex * sizeof(camera_props_t)
               atIndex: 2];
    [encoder dispatchThreadgroups:threadgroups
            threadsPerThreadgroup:threadsPerThreadgroup];
    
    // step 2 : blur horizontal
    [encoder setComputePipelineState: _blurHPipeline];
    [encoder setTexture: _ssaoTexture atIndex: 0];
    [encoder setTexture: temporarySSAOTexture atIndex: 1];
    [encoder dispatchThreadgroups:threadgroups
            threadsPerThreadgroup:threadsPerThreadgroup];
    
    // step 3 : blur vertical
    [encoder setComputePipelineState: _blurVPipeline];
    [encoder setTexture: temporarySSAOTexture atIndex: 0];
    [encoder setTexture: _ssaoTexture atIndex: 1];
    [encoder dispatchThreadgroups:threadgroups
            threadsPerThreadgroup:threadsPerThreadgroup];
    
    // interleave
    if(_type == MGPSSAOTypeAdaptive) {
        temporarySSAOTexture = [_postProcessing.textureManager newTemporaryTextureWithWidth:_destinationResolution.width
                                                                                     height:_destinationResolution.height
                                                                                pixelFormat:MTLPixelFormatR16Float
                                                                                storageMode:MTLStorageModePrivate
                                                                                      usage:MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite
                                                                           mipmapLevelCount:1
                                                                                arrayLength:1];
        
        [encoder setComputePipelineState: _interleave2x2Pipeline];
        [encoder setTexture:deinterleavedTextureArray atIndex:0];
        [encoder setTexture:temporarySSAOTexture atIndex:1];
        [encoder dispatchThreadgroups:threadgroups2
                threadsPerThreadgroup:threadsPerThreadgroup];
    }
    
    [encoder endEncoding];
    
    [_postProcessing.textureManager releaseTemporaryTexture:temporarySSAOTexture];
}

- (void)resize: (CGSize)newSize {
    _destinationResolution = newSize;
    [self _makeTexturesWithSize: newSize];
}

@end

@implementation MGPPostProcessingLayerScreenSpaceReflection {
    id<MTLComputePipelineState> _ssrPipeline;
    id<MTLBuffer> _ssrPropsBuffer;
    id<MTLTexture> _ssrOutputTexture, _ssrPrevOutputTexture;
    NSUInteger _ssrPrevOutputTextureLifetime;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device library:(id<MTLLibrary>)library {
    self = [super initWithDevice:device
                         library:library];
    if(self) {
        _iteration = 32;
        _step = 1.0;
        _opacity = 0.5;
        [self _makeAssets];
    }
    return self;
}

- (void)_makeAssets {
    _ssrPipeline = [_device newComputePipelineStateWithFunction: [_library newFunctionWithName: @"ssr"]
                                                          error: nil];
    _ssrPropsBuffer = [_device newBufferWithLength: sizeof(screen_space_reflection_props_t) * 3
                                           options: MTLResourceStorageModeManaged];
}

- (void)_makeTexturesWithSize:(CGSize)newSize {
    NSUInteger width = newSize.width + 0.001;
    NSUInteger height = newSize.height + 0.001;
    
    if(_ssrOutputTexture == nil ||
       _ssrOutputTexture.width != width ||
       _ssrOutputTexture.height != height) {
        _ssrPrevOutputTexture = _ssrOutputTexture;
        _ssrPrevOutputTextureLifetime = 3;  // becuase our implementation uses triple buffering
        
        MTLTextureDescriptor *textureDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:self.postProcessing.gBuffer.output.pixelFormat
                                                                                               width:width
                                                                                              height:height
                                                                                           mipmapped:NO];
        textureDesc.storageMode = MTLStorageModePrivate;
        textureDesc.usage = MTLTextureUsageShaderWrite;
        _ssrOutputTexture = [_device newTextureWithDescriptor:textureDesc];
        _ssrOutputTexture.label = @"SSR Color Temporary";
    }
}

- (NSUInteger)renderingOrder {
    return MGPPostProcessingRenderingOrderAfterShadePass;
}

- (void)render:(id<MTLCommandBuffer>)buffer {
    screen_space_reflection_props_t props = {
        .iteration = _iteration,
        .step = _step,
        .opacity = _opacity,
        .attenuation = _attenuation,
        .vignette = _vignette
    };
    
    memcpy(_ssrPropsBuffer.contents + sizeof(screen_space_reflection_props_t) * _postProcessing.currentBufferIndex,
           &props, sizeof(screen_space_reflection_props_t));
    [_ssrPropsBuffer didModifyRange: NSMakeRange(sizeof(screen_space_reflection_props_t) * _postProcessing.currentBufferIndex, sizeof(ssao_props_t))];
    
    // manage previous ssr texture lifetime
    if(_ssrPrevOutputTextureLifetime > 0) {
        _ssrPrevOutputTextureLifetime -= 1;
        if(_ssrPrevOutputTextureLifetime == 0) {
            _ssrPrevOutputTexture = nil;
        }
    }
    
    MGPGBuffer *gBuffer = _postProcessing.gBuffer;
    id<MTLBuffer> cameraBuffer = _postProcessing.cameraBuffer;
    NSUInteger currentBufferIndex = _postProcessing.currentBufferIndex;
    NSUInteger width = gBuffer.size.width, height = gBuffer.size.height;
    
    [buffer pushDebugGroup: @"Screen-Space Reflection"];
    
    // step 1 : screen space reflection
    id<MTLComputeCommandEncoder> encoder = [buffer computeCommandEncoder];
    [encoder setLabel: @"SSR #1 : Compute"];
    [encoder setComputePipelineState: _ssrPipeline];
    [encoder setTexture: gBuffer.normal atIndex: 0];
    [encoder setTexture: gBuffer.depth atIndex: 1];
    [encoder setTexture: gBuffer.shading atIndex: 2];
    [encoder setTexture: gBuffer.output atIndex: 3];
    [encoder setTexture: _ssrOutputTexture atIndex: 4];
    [encoder setBuffer: _ssrPropsBuffer
                offset: sizeof(screen_space_reflection_props_t) * _postProcessing.currentBufferIndex
               atIndex: 0];
    [encoder setBuffer: cameraBuffer
                offset: currentBufferIndex * sizeof(camera_props_t)
               atIndex: 1];
    [encoder dispatchThreadgroups: MTLSizeMake((width+15)/16, (height+15)/16, 1)
            threadsPerThreadgroup: MTLSizeMake(16, 16, 1)];
    [encoder endEncoding];
    
    // step 2 : blit to output texture
    id<MTLBlitCommandEncoder> blit = [buffer blitCommandEncoder];
    [blit setLabel: @"SSR #2 : Blit to output texture"];
    [blit copyFromTexture:_ssrOutputTexture
              sourceSlice:0
              sourceLevel:0
             sourceOrigin:MTLOriginMake(0, 0, 0)
               sourceSize:MTLSizeMake(_ssrOutputTexture.width, _ssrOutputTexture.height, 1)
                toTexture:gBuffer.output
         destinationSlice:0
         destinationLevel:0
        destinationOrigin:MTLOriginMake(0, 0, 0)];
    [blit endEncoding];
    
    [buffer popDebugGroup];
}

- (void)resize: (CGSize)newSize {
    [self _makeTexturesWithSize:newSize];
}

@end

@implementation MGPPostProcessingLayerTemporalAA

- (NSUInteger)renderingOrder {
    return MGPPostProcessingRenderingOrderAfterShadePass;
}

@end
