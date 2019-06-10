//
//  MGPImageBasedLighting.m
//  MetalDeferred
//
//  Created by 이현우 on 09/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPImageBasedLighting.h"
#import "../Model/MGPMesh.h"
#import "../Utility/MetalMath.h"
#import "../../Shaders/SharedStructures.h"

@implementation MGPImageBasedLighting {
    id<MTLDevice> _device;
    id<MTLLibrary> _library;
    id<MTLBuffer> _quadVerticesBuffer;
    id<MTLBuffer> _skyboxVerticesBuffer;
    id<MTLBuffer> _prefilteredSpeuclarOptionBuffer;
    
    id<MTLTexture> _equirectangularMap;
    
    id<MTLRenderPipelineState> _renderPipelineEnvironmentMap;
    id<MTLRenderPipelineState> _renderPipelineIrradianceMap;
    id<MTLRenderPipelineState> _renderPipelineSpecularMap;
    id<MTLRenderPipelineState> _renderPipelineLookupTexture;
    MTLRenderPassDescriptor *_renderPassEnvironmentMap;
    MTLRenderPassDescriptor *_renderPassIrradianceMap;
    MTLRenderPassDescriptor *_renderPassSpecularMap;
    MTLRenderPassDescriptor *_renderPassLookupTexture;
    
    BOOL _isEnvironmentMapRenderingRequired;
    BOOL _isIrradianceMapRenderingRequired;
    BOOL _isSpecularMapRenderingRequired;
    BOOL _isLookupTextureRenderingRequired;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                       library:(id<MTLLibrary>)library
            equirectangularMap:(id<MTLTexture>)equirectangularMap {
    self = [super init];
    if(self) {
        _device = device;
        _library = library;
        
        [self _initBuffers];
        
        _equirectangularMap = equirectangularMap;
        [self _makeEmptyTextures];
        [self _makeRenderPipelines];
        [self _makeRenderPass];
    }
    return self;
}

- (void)_initBuffers {
    _quadVerticesBuffer = [MGPMesh createQuadVerticesBuffer: _device];
    _skyboxVerticesBuffer = [MGPMesh createSkyboxVerticesBuffer: _device];
    
    const prefiltered_specular_option_t options[] = {
        { 0 }, { 0.2 }, { 0.4 }, { 0.6 }, { 0.8 }, { 1.0 }
    };
    _prefilteredSpeuclarOptionBuffer = [_device newBufferWithLength:sizeof(options)
                                                            options:MTLResourceStorageModeManaged];
    memcpy(_prefilteredSpeuclarOptionBuffer.contents, options, sizeof(options));
    [_prefilteredSpeuclarOptionBuffer didModifyRange: NSMakeRange(0, sizeof(options))];
    
}

- (void)_makeEmptyTextures {
    MTLTextureDescriptor *desc = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat: MTLPixelFormatRGBA16Float
                                                                                       size: 256
                                                                                  mipmapped: NO];
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    desc.storageMode = MTLStorageModePrivate;
    
    // irradiance, specular map doesn't require large texture size!
    desc.width = desc.height = 512;
    desc.mipmapLevelCount = 6;
    _environmentMap = [_device newTextureWithDescriptor: desc];
    _environmentMap.label = @"Environment Map";
    desc.width = desc.height = 32;
    desc.mipmapLevelCount = 1;
    _irradianceMap = [_device newTextureWithDescriptor: desc];
    _irradianceMap.label = @"Irradiance Map";
    desc.width = desc.height = 256;
    desc.mipmapLevelCount = 6;
    _prefilteredSpecularMap = [_device newTextureWithDescriptor: desc];
    _prefilteredSpecularMap.label = @"Prefiltered Specular Map";
    desc.width = desc.height = 256;
    desc.mipmapLevelCount = 1;
    desc.textureType = MTLTextureType2D;
    _BRDFLookupTexture = [_device newTextureWithDescriptor: desc];
    _BRDFLookupTexture.label = @"BRDF Lookup";
    
    _isEnvironmentMapRenderingRequired = YES;
    _isIrradianceMapRenderingRequired = YES;
    _isSpecularMapRenderingRequired = YES;
    _isLookupTextureRenderingRequired = YES;
}

- (void)_makeRenderPipelines {
    _renderPipelineEnvironmentMap = [self _makeRenderPipelineForTexture: _environmentMap
                                                     vertexFunctionName: @"environment_vert"
                                                   fragmentFunctionName: @"environment_frag"];
    
    _renderPipelineIrradianceMap = [self _makeRenderPipelineForTexture: _irradianceMap
                                                    vertexFunctionName: @"environment_vert"
                                                  fragmentFunctionName: @"irradiance_frag"];
    
    _renderPipelineSpecularMap = [self _makeRenderPipelineForTexture: _prefilteredSpecularMap
                                                  vertexFunctionName: @"environment_vert"
                                                fragmentFunctionName: @"prefiltered_specular_frag"];
    
    _renderPipelineLookupTexture = [self _makeRenderPipelineForTexture: _BRDFLookupTexture
                                                    vertexFunctionName: @"screen_vert"
                                                  fragmentFunctionName: @"brdf_lookup_frag"];
}

- (void)_makeRenderPass {
    MTLRenderPassDescriptor *renderPass = [MTLRenderPassDescriptor new];
    renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
    renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
    renderPass.renderTargetArrayLength = 6;
    
    // Environment Map
    renderPass.colorAttachments[0].texture = _environmentMap;
    _renderPassEnvironmentMap = [renderPass copy];
    
    // Irradiance Map
    renderPass.colorAttachments[0].texture = _irradianceMap;
    _renderPassIrradianceMap = [renderPass copy];
    
    // Specular Map
    renderPass.colorAttachments[0].texture = _prefilteredSpecularMap;
    _renderPassSpecularMap = [renderPass copy];
    
    // Lookup Texture
    renderPass.colorAttachments[0].texture = _BRDFLookupTexture;
    renderPass.renderTargetArrayLength = 0;
    _renderPassLookupTexture = [renderPass copy];
}

- (id<MTLRenderPipelineState>)_makeRenderPipelineForTexture: (id<MTLTexture>)texture
                                         vertexFunctionName: (NSString *)vertexFunctionName
                                       fragmentFunctionName: (NSString *)fragmentFunctionName
{
    MTLRenderPipelineDescriptor *pipelineDesc = [MTLRenderPipelineDescriptor new];
    
    pipelineDesc.vertexFunction = [_library newFunctionWithName: vertexFunctionName];
    pipelineDesc.fragmentFunction = [_library newFunctionWithName: fragmentFunctionName];
    pipelineDesc.colorAttachments[0].pixelFormat = texture.pixelFormat;
    pipelineDesc.label = texture.label;
    pipelineDesc.inputPrimitiveTopology = MTLPrimitiveTopologyClassTriangle;
    
    NSError *error = nil;
    id<MTLRenderPipelineState> renderPipeline = [_device newRenderPipelineStateWithDescriptor: pipelineDesc
                                                                                        error: &error];
    if(error) {
        NSLog(@"%@", error);
    }
    return renderPipeline;
}

- (BOOL)isAnyRenderingRequired {
    return _isEnvironmentMapRenderingRequired || _isIrradianceMapRenderingRequired ||
    _isSpecularMapRenderingRequired || _isLookupTextureRenderingRequired;
}

- (BOOL)isEnvironmentMapRenderingRequired {
    return _isEnvironmentMapRenderingRequired;
}

- (BOOL)isIrradianceMapRenderingRequired {
    return _isIrradianceMapRenderingRequired;
}

- (BOOL)isSpecularMapRenderingRequired {
    return _isSpecularMapRenderingRequired;
}

- (BOOL)isLookupTextureRenderingRequired {
    return _isLookupTextureRenderingRequired;
}

- (void)render:(id<MTLCommandBuffer>)buffer {
    if(_isEnvironmentMapRenderingRequired)
        [self renderEnvironmentMap:buffer];
    if(_isIrradianceMapRenderingRequired)
        [self renderIrradianceMap:buffer];
    if(_isSpecularMapRenderingRequired)
        [self renderSpecularLightingMap:buffer];
    if(_isLookupTextureRenderingRequired)
        [self renderLookupTexture:buffer];
    
    if(!self.isAnyRenderingRequired) {
        _equirectangularMap = nil;
    }
}

- (void)renderEnvironmentMap:(id<MTLCommandBuffer>)buffer {
    id<MTLRenderCommandEncoder> enc = [buffer renderCommandEncoderWithDescriptor: _renderPassEnvironmentMap];
    enc.label = @"Environment Map";
    [enc setRenderPipelineState: _renderPipelineEnvironmentMap];
    [enc setCullMode: MTLCullModeBack];
    [enc setVertexBuffer: _quadVerticesBuffer
                  offset: 0
                 atIndex: 0];
    [enc setVertexBuffer: _skyboxVerticesBuffer
                  offset: 0
                 atIndex: 1];
    [enc setFragmentTexture: _equirectangularMap
                    atIndex: 0];
    [enc drawPrimitives: MTLPrimitiveTypeTriangle
            vertexStart: 0
            vertexCount: 6
          instanceCount: 6];
    [enc endEncoding];
    
    id<MTLBlitCommandEncoder> blit = [buffer blitCommandEncoder];
    [blit generateMipmapsForTexture: _environmentMap];
    [blit endEncoding];
    
    _isEnvironmentMapRenderingRequired = NO;
}

- (void)renderIrradianceMap:(id<MTLCommandBuffer>)buffer {
    id<MTLRenderCommandEncoder> enc = [buffer renderCommandEncoderWithDescriptor: _renderPassIrradianceMap];
    enc.label = @"Irradiance Map";
    [enc setRenderPipelineState: _renderPipelineIrradianceMap];
    [enc setCullMode: MTLCullModeBack];
    [enc setVertexBuffer: _quadVerticesBuffer
                  offset: 0
                 atIndex: 0];
    [enc setVertexBuffer: _skyboxVerticesBuffer
                  offset: 0
                 atIndex: 1];
    [enc setFragmentTexture: _environmentMap
                    atIndex: 0];
    [enc drawPrimitives: MTLPrimitiveTypeTriangle
            vertexStart: 0
            vertexCount: 6
          instanceCount: 6];
    [enc endEncoding];
    
    _isIrradianceMapRenderingRequired = NO;
}

- (void)renderSpecularLightingMap:(id<MTLCommandBuffer>)buffer {
    for(int level = 0; level < 6; level++) {
        _renderPassSpecularMap.colorAttachments[0].level = level;
        id<MTLRenderCommandEncoder> enc = [buffer renderCommandEncoderWithDescriptor: _renderPassSpecularMap];
        enc.label = [NSString stringWithFormat: @"Prefiltered Specular Map (level = %d)", level];
        [enc setRenderPipelineState: _renderPipelineSpecularMap];
        [enc setCullMode: MTLCullModeBack];
        [enc setVertexBuffer: _quadVerticesBuffer
                      offset: 0
                     atIndex: 0];
        [enc setVertexBuffer: _skyboxVerticesBuffer
                      offset: 0
                     atIndex: 1];
        [enc setFragmentTexture: _environmentMap
                        atIndex: 0];
        [enc setFragmentBuffer: _prefilteredSpeuclarOptionBuffer
                        offset: sizeof(prefiltered_specular_option_t) * level
                       atIndex: 1];
        [enc drawPrimitives: MTLPrimitiveTypeTriangle
                vertexStart: 0
                vertexCount: 6
              instanceCount: 6];
        [enc endEncoding];
    }
    
    _isSpecularMapRenderingRequired = NO;
}

- (void)renderLookupTexture:(id<MTLCommandBuffer>)buffer {
    id<MTLRenderCommandEncoder> enc = [buffer renderCommandEncoderWithDescriptor: _renderPassLookupTexture];
    enc.label = @"BRDF Lookup";
    [enc setRenderPipelineState: _renderPipelineLookupTexture];
    [enc setCullMode: MTLCullModeBack];
    [enc setVertexBuffer: _quadVerticesBuffer
                  offset: 0
                 atIndex: 0];
    [enc drawPrimitives: MTLPrimitiveTypeTriangle
            vertexStart: 0
            vertexCount: 6];
    [enc endEncoding];
    
    _isLookupTextureRenderingRequired = NO;
}

@end
