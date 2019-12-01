//
//  MGPDeferredRenderer.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/10/09.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPDeferredRenderer.h"
#import "MGPGBuffer.h"
#import "MGPPostProcessing.h"
#import "MGPFrustum.h"
#import "MGPCameraComponent.h"
#import "MGPMeshComponent.h"
#import "MGPLightComponent.h"
#import "MGPMesh.h"
#import "MGPBoundingVolume.h"
#import "MGPShadowBuffer.h"
#import "MGPShadowManager.h"
#import "LightingCommon.h"

const uint32_t kNumLight = MAX_NUM_LIGHTS;
const size_t kShadowResolution = 512;
const size_t kLightCullBufferSize = 8100*4*16;
const size_t _lightGridTileSize = 16;

@interface MGPDeferredRenderer ()
@end

@implementation MGPDeferredRenderer {
    MGPGBuffer *_gBuffer;
    MGPPostProcessing *_postProcess;
    MGPShadowManager *_shadowManager;
    id<MTLDepthStencilState> _depthStencil;
    id<MTLComputePipelineState> _computePipelineLightCulling;
    id<MTLBuffer> _lightCullBuffer;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super initWithDevice:device];
    if(self) {
        [self _initAssets];
    }
    return self;
}

- (void)_initAssets {
    // G-buffer
    _gBuffer = [[MGPGBuffer alloc] initWithDevice:self.device
                                          library:self.defaultLibrary
                                             size:CGSizeMake(512,512)];
    
    // depth-stencil
    MTLDepthStencilDescriptor *depthStencilDesc = [[MTLDepthStencilDescriptor alloc] init];
    [depthStencilDesc setDepthWriteEnabled:YES];
    [depthStencilDesc setDepthCompareFunction:MTLCompareFunctionLessEqual];
    _depthStencil = [self.device newDepthStencilStateWithDescriptor:depthStencilDesc];
    
    // light-cull
    _lightCullBuffer = [self.device newBufferWithLength: kLightCullBufferSize
                                                options:MTLResourceStorageModePrivate];
    _computePipelineLightCulling = [self.device newComputePipelineStateWithFunction: [self.defaultLibrary newFunctionWithName: @"cull_lights"]
                                                                              error: nil];
}

- (void)beginFrame {
    [super beginFrame];
}

- (void)render {
    // begin
    id<MTLCommandBuffer> commandBuffer = [self.queue commandBuffer];
    commandBuffer.label = @"Render";
    
    // Post-process before prepass
    [_postProcess render: commandBuffer
       forRenderingOrder: MGPPostProcessingRenderingOrderBeforePrepass];
    
    // G-buffer prepass
    id<MTLRenderCommandEncoder> prepassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _gBuffer.renderPassDescriptor];
    [self renderGBuffer:prepassEncoder];
     
    // Shadowmap Passes
    [self renderShadows: commandBuffer];
    
    // Post-process before light pass
    [_postProcess render: commandBuffer
       forRenderingOrder: MGPPostProcessingRenderingOrderBeforeLightPass];
    
    // Light cull pass
    id<MTLComputeCommandEncoder> lightCullPassEncoder = [commandBuffer computeCommandEncoder];
    [self computeLightCullGrid:lightCullPassEncoder];
    
    // Post-process before shade pass
    [_postProcess render: commandBuffer
       forRenderingOrder: MGPPostProcessingRenderingOrderBeforeShadePass];
    
    // G-buffer shade pass
    id<MTLRenderCommandEncoder> shadingPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _gBuffer.shadingPassDescriptor];
    [self renderShading:shadingPassEncoder];
    
    // Post-process before prepass
    [_postProcess render: commandBuffer
       forRenderingOrder: MGPPostProcessingRenderingOrderAfterShadePass];
    
    // present to framebuffer
    _renderPassPresent.colorAttachments[0].texture = self.view.currentDrawable.texture;
    id<MTLRenderCommandEncoder> presentCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _renderPassPresent];
    [self renderFramebuffer:presentCommandEncoder];
    
    // present
    [commandBuffer presentDrawable: self.view.currentDrawable];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        if(handler != nil)
            handler();
    }];
    
    [commandBuffer commit];
}

- (void)endFrame {
    [super endFrame];
}

- (void)renderDrawCalls:(MGPDrawCallList *)drawCallList
           bindTextures:(BOOL)bindTextures
                encoder:(id<MTLRenderCommandEncoder>)encoder {
    MGPFrustum *frustum = drawCallList.frustum;
    
    id<MTLTexture> textures[tex_total] = {};
    BOOL textureChangedFlags[tex_total] = {};
    for(int i = 0; i < tex_total; i++) {
        textureChangedFlags[i] = YES;
    }
    id<MTLRenderPipelineState> prevPrepassPipeline = nil;
    for(MGPDrawCall *drawCall in drawCallList.drawCalls) {
        MGPMesh *mesh = drawCall.mesh;
        NSUInteger instanceCount = drawCall.instanceCount;
        id<MTLBuffer> instancePropsBuffer = drawCall.instancePropsBuffer;
        NSUInteger instancePropsBufferOffset = drawCall.instancePropsBufferOffset;
        
        // Set vertex buffer
        [encoder setVertexBuffer: mesh.metalKitMesh.vertexBuffers[0].buffer
                          offset: 0
                         atIndex: 0];
        
        // draw submeshes
        for(MGPSubmesh *submesh in mesh.submeshes) {
            id<MGPBoundingVolume> volume = submesh.volume;
            
            // Culling
            if([volume isCulledInFrustum:frustum])
                continue;
            
            // Texture binding
            if(bindTextures) {
                // Check previous draw call's textures and current textures are duplicated.
                for(int i = 0; i < tex_total; i++) {
                    id<MTLTexture> texture = submesh.textures[i];
                    if(texture == (id<MTLTexture>)NSNull.null)
                        texture = nil;
                    if(textures[i] != texture) {
                        textureChangedFlags[i] = YES;
                        textures[i] = texture;
                    }
                }
                
                // Set textures
                for(int i = 0; i < tex_total; i++) {
                    if(textureChangedFlags[i]) {
                        [encoder setFragmentTexture: textures[i] atIndex: i];
                        textureChangedFlags[i] = NO;
                    }
                }
                
                // Set render pipeline for G-buffer
                MGPGBufferPrepassFunctionConstants prepassConstants = {};
                prepassConstants.hasAlbedoMap = submesh.textures[tex_albedo] != NSNull.null;
                prepassConstants.hasNormalMap = submesh.textures[tex_normal] != NSNull.null;
                prepassConstants.hasRoughnessMap = submesh.textures[tex_roughness] != NSNull.null;
                prepassConstants.hasMetalicMap = submesh.textures[tex_metalic] != NSNull.null;
                prepassConstants.hasOcclusionMap = submesh.textures[tex_occlusion] != NSNull.null;
                prepassConstants.hasAnisotropicMap = submesh.textures[tex_anisotropic] != NSNull.null;
                prepassConstants.flipVertically = YES;  // for sponza textures
                prepassConstants.sRGBTexture = YES;     // for sponza textures
                
                id<MTLRenderPipelineState> prepassPipeline = [_gBuffer renderPipelineStateWithConstants: prepassConstants
                                                                                                  error: nil];
                if(prepassPipeline != nil &&
                   prevPrepassPipeline != prepassPipeline) {
                    [encoder setRenderPipelineState: prepassPipeline];
                    prevPrepassPipeline = prepassPipeline;
                }
            }
            
            // instance props buffer
            [encoder setVertexBuffer: instancePropsBuffer
                              offset: instancePropsBufferOffset
                             atIndex: 2];
            [encoder setFragmentBuffer: instancePropsBuffer
                                offset: instancePropsBufferOffset
                               atIndex: 2];
            
            // Draw call
            [encoder drawIndexedPrimitives: submesh.metalKitSubmesh.primitiveType
                                indexCount: submesh.metalKitSubmesh.indexCount
                                 indexType: submesh.metalKitSubmesh.indexType
                               indexBuffer: submesh.metalKitSubmesh.indexBuffer.buffer
                         indexBufferOffset: submesh.metalKitSubmesh.indexBuffer.offset
                             instanceCount: instanceCount];
        }
    }
}


- (void)renderGBuffer:(id<MTLRenderCommandEncoder>)encoder {
    encoder.label = @"G-buffer";
    [encoder setCullMode: MTLCullModeBack];
    
    // camera
    [encoder setVertexBuffer: _cameraPropsBuffer
                      offset: _currentBufferIndex * sizeof(camera_props_t)
                     atIndex: 1];
    [encoder setFragmentBuffer: _cameraPropsBuffer
                        offset: _currentBufferIndex * sizeof(camera_props_t)
                       atIndex: 1];
    
    [self renderDrawCalls:nil
             bindTextures:YES
                  encoder:encoder];
    
    [encoder endEncoding];
}

- (void)renderShadows:(id<MTLCommandBuffer>)buffer {
    if(_lightComponents.count == 0) return;
    
    for(NSUInteger i = 0, count = _lightComponents.count; i < count; i++) {
        MGPLightComponent *lightComponent = _lightComponents[i];
        if(lightComponent.castShadows) {
            MGPShadowBuffer *shadowBuffer = [_shadowManager newShadowBufferForLightComponent: lightComponent
                                                                                  resolution: kShadowResolution
                                                                               cascadeLevels: 1];
            
            if(shadowBuffer != nil) {
                id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor: shadowBuffer.shadowPass];
                encoder.label = [NSString stringWithFormat: @"Shadow #%lu", i+1];
                [encoder setRenderPipelineState: _shadowManager.shadowPipeline];
                [encoder setDepthStencilState: _depthStencil];
                [encoder setCullMode: MTLCullModeBack];
                
                [encoder setVertexBuffer: _lightPropsBuffer
                                  offset: (_currentBufferIndex * kNumLight + i) * sizeof(light_t)
                                 atIndex: 1];
                [encoder setVertexBuffer: _lightGlobalBuffer
                                  offset: _currentBufferIndex * sizeof(light_global_t)
                                 atIndex: 2];
                [encoder setVertexBuffer: _instancePropsBuffer
                                  offset: _currentBufferIndex * sizeof(instance_props_t) * kNumInstance
                                 atIndex: 3];
                
                MGPDrawCallList *drawCallList = [self drawCallListWithFrustum:lightComponent.frustum];
                
                [self renderDrawCalls:drawCallList
                         bindTextures:NO
                              encoder:encoder];
                
                [encoder endEncoding];
            }
        }
    }
}

- (void)computeLightCullGrid:(id<MTLComputeCommandEncoder>)encoder {
    encoder.label = @"Light Culling";
    
    [encoder setComputePipelineState: _computePipelineLightCulling];
    NSUInteger tileSize = _lightGridTileSize;
    NSUInteger width = _gBuffer.size.width + 0.5;
    NSUInteger height = _gBuffer.size.height + 0.5;
    width = (width + tileSize - 1) / tileSize;
    height = (height + tileSize - 1) / tileSize;
    MTLSize threadSize = MTLSizeMake(width, height, 1);
    [encoder setBuffer: _lightCullBuffer
                offset: 0
               atIndex: 0];
    [encoder setBuffer: _lightPropsBuffer
                offset: _currentBufferIndex * sizeof(light_t) * kNumLight
               atIndex: 1];
    [encoder setBuffer: _lightGlobalBuffer
                offset: _currentBufferIndex * sizeof(light_global_t)
               atIndex: 2];
    [encoder setBuffer: _cameraPropsBuffer
                offset: _currentBufferIndex * sizeof(camera_props_t)
               atIndex: 3];
    [encoder setTexture: _gBuffer.depth
                atIndex: 0];
    [encoder dispatchThreadgroups:threadSize
            threadsPerThreadgroup:MTLSizeMake(tileSize, tileSize, 1)];
    [encoder endEncoding];
}

- (void)renderShading:(id<MTLRenderCommandEncoder>)encoder {
    MGPGBufferShadingFunctionConstants shadingConstants = {};
    shadingConstants.hasIBLIrradianceMap = _IBLOn;
    shadingConstants.hasIBLSpecularMap = _IBLOn;
    shadingConstants.hasSSAOMap = _ssaoOn;
    
    if(_lightCullOn) {
        _renderPipelineShading = [_gBuffer shadingPipelineStateWithConstants: shadingConstants
                                                                       error: nil];
    }
    else {
        _renderPipelineShading = [_gBuffer nonLightCulledShadingPipelineStateWithConstants: shadingConstants
                                                                       error: nil];
    }
    
    encoder.label = @"Shading";
    [encoder setRenderPipelineState: _renderPipelineShading];
    [encoder setCullMode: MTLCullModeBack];
    [encoder setFragmentBuffer: _cameraPropsBuffer
                        offset: _currentBufferIndex * sizeof(camera_props_t)
                       atIndex: 0];
    [encoder setFragmentBuffer: _lightGlobalBuffer
                        offset: _currentBufferIndex * sizeof(light_global_t)
                       atIndex: 1];
    [encoder setFragmentBuffer: _lightPropsBuffer
                        offset: _currentBufferIndex * sizeof(light_t) * kNumLight
                       atIndex: 2];
    [encoder setFragmentBuffer: _lightCullBuffer
                        offset: 0
                       atIndex: 3];
    [encoder setFragmentTexture: _gBuffer.albedo
                        atIndex: attachment_albedo];
    [encoder setFragmentTexture: _gBuffer.normal
                        atIndex: attachment_normal];
    [encoder setFragmentTexture: _gBuffer.shading
                        atIndex: attachment_shading];
    [encoder setFragmentTexture: _gBuffer.depth
                        atIndex: attachment_depth];
    [encoder setFragmentTexture: _gBuffer.tangent
                        atIndex: attachment_tangent];
    [encoder setFragmentTexture: _gBuffer.depth
                        atIndex: attachment_depth];
    if(!_lightCullOn) {
        [encoder setFragmentTexture: _gBuffer.lighting
                            atIndex: attachment_light];
    }
    if(_IBLOn) {
        [encoder setFragmentTexture: _IBLs[_renderingIBLIndex].irradianceMap
                            atIndex: attachment_irradiance];
        [encoder setFragmentTexture: _IBLs[_renderingIBLIndex].prefilteredSpecularMap
                            atIndex: attachment_prefiltered_specular];
        [encoder setFragmentTexture: _IBLs[_renderingIBLIndex].BRDFLookupTexture
                            atIndex: attachment_brdf_lookup];
    }
    if(_postProcess.layers.count > 0) {
        [encoder setFragmentTexture: ((MGPPostProcessingLayerSSAO *)_postProcess[0]).ssaoTexture
                            atIndex: attachment_ssao];
    }
    for(NSUInteger i = 0; i < light_globals[_currentBufferIndex].first_point_light_index; i++) {
        if(_lights[i].castShadows) {
            MGPShadowBuffer *shadowBuffer = [_shadowManager newShadowBufferForLight: _lights[i]
                                                                         resolution: kShadowResolution
                                                                      cascadeLevels: 1];
            [encoder setFragmentTexture: shadowBuffer.texture
                                atIndex: i+attachment_shadow_map];
        }
        else {
            [encoder setFragmentTexture: nil
                                atIndex: i+attachment_shadow_map];
        }
    }
    [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                vertexStart: 0
                vertexCount: 6];
    
    [encoder endEncoding];
}

- (void)renderFramebuffer:(id<MTLRenderCommandEncoder>)encoder {
    encoder.label = @"Present";
    
    if(_gBufferIndex == 6) {
        // Draw light-culling tiles
        [encoder setRenderPipelineState: _renderPipelineLightCullTile];
        [encoder setFragmentBuffer: _lightCullBuffer
                            offset: 0
                           atIndex: 0];
        [encoder setFragmentBuffer: _lightGlobalBuffer
                            offset: _currentBufferIndex * sizeof(light_global_t)
                           atIndex: 1];
    }
    else {
        [encoder setRenderPipelineState: _renderPipelinePresent];
    }
    
    [encoder setCullMode: MTLCullModeBack];
    [encoder setFragmentTexture: [self _presentationGBuferTexture]
                        atIndex: 0];
    [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                vertexStart: 0
                vertexCount: 6];
    
    [encoder endEncoding];
}

- (id<MTLTexture>)_presentationGBuferTexture {
    switch(_gBufferIndex) {
        case 1:
            return _gBuffer.albedo;
        case 2:
            return _gBuffer.normal;
        case 3:
            return _gBuffer.tangent;
        case 4:
            return _gBuffer.shading;
        case 5:
            return _ssao.ssaoTexture;
        default:
            return _gBuffer.output;
    }
}

- (void)resize:(CGSize)newSize {
    [_gBuffer resize:newSize];
    [super resize:newSize];
}

@end
