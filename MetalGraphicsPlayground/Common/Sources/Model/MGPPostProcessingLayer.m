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

NSString * const MGPPostProcessingLayerErrorDomain = @"MGPPostProcessingLayerErrorDomain";

@implementation MGPPostProcessingLayer {
    @protected
    id<MTLDevice> _device;
    id<MTLLibrary> _library;
    __weak MGPPostProcessing *_postProcessing;
}

@synthesize postProcessing = _postProcessing;

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
    id<MTLBuffer> _ssaoRandomSamplesBuffer;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device library:(id<MTLLibrary>)library {
    self = [super initWithDevice: device library: library];
    if(self) {
        _intensity = 0.5f;
        _radius = 0.1f;
        [self _makeComputePipeline];
        [self _makeRandomSamples];
    }
    return self;
}

- (void)_makeComputePipeline {
    _ssaoPipeline = [_device newComputePipelineStateWithFunction: [_library newFunctionWithName: @"ssao"]
                                                           error: nil];
}

- (void)_makeTexturesWithSize: (CGSize)size {
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatR16Float
                                                                                    width: size.width height:size.height
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
        sample = simd_normalize(sample) * (float)arc4random() / (float)UINT_MAX;
        ((simd_float3*)_ssaoRandomSamplesBuffer.contents)[i] = sample;
    }
    [_ssaoRandomSamplesBuffer didModifyRange: NSMakeRange(0, sizeof(simd_float3) * numSamples)];
}

- (NSUInteger)renderingOrder {
    return MGPPostProcessingRenderingOrderBeforeLightPass;
}

- (void)render: (id<MTLCommandBuffer>)buffer {
    NSUInteger width = _ssaoTexture.width, height = _ssaoTexture.height;
    MGPGBuffer *gBuffer = _postProcessing.gBuffer;
    id<MTLBuffer> cameraBuffer = _postProcessing.cameraBuffer;
    NSUInteger currentBufferIndex = _postProcessing.currentBufferIndex;
    
    id<MTLComputeCommandEncoder> encoder = [buffer computeCommandEncoder];
    [encoder setLabel: @"SSAO"];
    [encoder setComputePipelineState: _ssaoPipeline];
    [encoder setTexture: gBuffer.normal atIndex: 0];
    [encoder setTexture: gBuffer.tangent atIndex: 1];
    [encoder setTexture: gBuffer.pos atIndex: 2];
    [encoder setTexture: _ssaoTexture atIndex: 3];
    [encoder setBuffer: _ssaoRandomSamplesBuffer
                offset: 0
               atIndex: 0];
    [encoder setBuffer: cameraBuffer
                offset: currentBufferIndex * sizeof(camera_props_t)
               atIndex: 1];
    [encoder dispatchThreadgroups: MTLSizeMake((width+15)/16, (height+15)/16, 1)
            threadsPerThreadgroup: MTLSizeMake(16, 16, 1)];
    [encoder endEncoding];
}

- (void)resize: (CGSize)newSize {
    [self _makeTexturesWithSize: newSize];
}

@end
