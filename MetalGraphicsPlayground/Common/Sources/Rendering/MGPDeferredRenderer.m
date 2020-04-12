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
#import "MGPScene.h"
#import "MGPCameraComponent.h"
#import "MGPMeshComponent.h"
#import "MGPLightComponent.h"
#import "MGPMesh.h"
#import "MGPBoundingVolume.h"
#import "MGPShadowBuffer.h"
#import "MGPShadowManager.h"
#import "LightingCommon.h"
#import "MGPCommonVertices.h"
#import "../Model/MGPImageBasedLighting.h"

#define DEFAULT_SHADOW_RESOLUTION 512
#define LIGHT_CULL_BUFFER_SIZE (8100*4*16)
#define LIGHT_CULL_GRID_TILE_SIZE 16

@interface MGPDeferredRenderer ()
@end

@implementation MGPDeferredRenderer {
    MGPPostProcessing *_postProcess;
    MGPShadowManager *_shadowManager;
    
    // common vertex buffer (quad + cube)
    id<MTLBuffer> _commonVertexBuffer;
    
    MTLRenderPassDescriptor *_renderPassSkybox;
    MTLRenderPassDescriptor *_renderPassPresent;
    id<MTLRenderPipelineState> _renderPipelineSkybox;
    id<MTLRenderPipelineState> _renderPipelinePresent;
    id<MTLDepthStencilState> _depthStencil;
    
    // Light-cull
    id<MTLComputePipelineState> _computePipelineLightCulling;
    id<MTLRenderPipelineState> _renderPipelineLightCullTile;
    id<MTLBuffer> _lightCullBuffer;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        _usesAnisotropy = YES;
        [self _initAssets];
    }
    return self;
}

- (void)_initAssets {
    // G-buffer
    MGPGBufferAttachmentType attachments =
        MGPGBufferAttachmentTypeAlbedo |
        MGPGBufferAttachmentTypeNormal |
        MGPGBufferAttachmentTypeTangent |
        MGPGBufferAttachmentTypeShading |
        MGPGBufferAttachmentTypeDepth |
        MGPGBufferAttachmentTypeOutput;
    _gBuffer = [[MGPGBuffer alloc] initWithDevice:self.device
                                          library:self.defaultLibrary
                                             size:CGSizeMake(512,512)
                                      attachments:attachments];
    
    // shadow manager
    _shadowManager = [[MGPShadowManager alloc] initWithDevice:self.device
                                                      library:self.defaultLibrary
                                             vertexDescriptor:_gBuffer.baseVertexDescriptor];
    
    // vertex buffer (mesh)
    _commonVertexBuffer = [self.device newBufferWithLength:1024
                                                   options:MTLResourceStorageModeManaged];
    memcpy(_commonVertexBuffer.contents, QuadVertices, sizeof(QuadVertices));
    memcpy(_commonVertexBuffer.contents + 256, SkyboxVertices, sizeof(SkyboxVertices));
    [_commonVertexBuffer didModifyRange: NSMakeRange(0, 1024)];
    
    // render-pass
    _renderPassSkybox = [[MTLRenderPassDescriptor alloc] init];
    _renderPassSkybox.colorAttachments[0].loadAction = MTLLoadActionClear;
    _renderPassSkybox.colorAttachments[0].storeAction = MTLStoreActionStore;
    _renderPassSkybox.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
    _renderPassSkybox.depthAttachment.loadAction = MTLLoadActionClear;
    _renderPassSkybox.depthAttachment.storeAction = MTLStoreActionStore;
    
    _renderPassPresent = [[MTLRenderPassDescriptor alloc] init];
    _renderPassPresent.colorAttachments[0].loadAction = MTLLoadActionLoad;
    _renderPassPresent.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    // pipelines
    MTLRenderPipelineDescriptor *renderPipelineDescriptorSkybox = [[MTLRenderPipelineDescriptor alloc] init];
    renderPipelineDescriptorSkybox.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    renderPipelineDescriptorSkybox.vertexFunction = [self.defaultLibrary newFunctionWithName: @"skybox_vert"];
    renderPipelineDescriptorSkybox.fragmentFunction = [self.defaultLibrary newFunctionWithName: @"skybox_frag"];
    renderPipelineDescriptorSkybox.depthAttachmentPixelFormat = _gBuffer.depth.pixelFormat;
    _renderPipelineSkybox = [self.device newRenderPipelineStateWithDescriptor: renderPipelineDescriptorSkybox
                                                                        error: nil];
    
    MTLRenderPipelineDescriptor *renderPipelineDescriptorPresent = [[MTLRenderPipelineDescriptor alloc] init];
    renderPipelineDescriptorPresent.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    renderPipelineDescriptorPresent.colorAttachments[0].blendingEnabled = YES;
    renderPipelineDescriptorPresent.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    renderPipelineDescriptorPresent.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    renderPipelineDescriptorPresent.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    renderPipelineDescriptorPresent.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
    renderPipelineDescriptorPresent.vertexFunction = [self.defaultLibrary newFunctionWithName: @"screen_vert"];
    renderPipelineDescriptorPresent.fragmentFunction = [self.defaultLibrary newFunctionWithName: @"screen_frag"];
    _renderPipelinePresent = [self.device newRenderPipelineStateWithDescriptor: renderPipelineDescriptorPresent
                                                                         error: nil];
    
    // depth-stencil
    MTLDepthStencilDescriptor *depthStencilDesc = [[MTLDepthStencilDescriptor alloc] init];
    [depthStencilDesc setDepthWriteEnabled:YES];
    [depthStencilDesc setDepthCompareFunction:MTLCompareFunctionLessEqual];
    _depthStencil = [self.device newDepthStencilStateWithDescriptor:depthStencilDesc];
    
    // light-cull
    _lightCullBuffer = [self.device newBufferWithLength: LIGHT_CULL_BUFFER_SIZE
                                                options:MTLResourceStorageModePrivate];
    _computePipelineLightCulling = [self.device newComputePipelineStateWithFunction: [self.defaultLibrary newFunctionWithName: @"cull_lights"]
                                                                              error: nil];
    
    // light-cull render pipeline
    MTLRenderPipelineDescriptor *renderPipelineDescriptorLightCullTile = [[MTLRenderPipelineDescriptor alloc] init];
    renderPipelineDescriptorLightCullTile.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    renderPipelineDescriptorLightCullTile.colorAttachments[0].blendingEnabled = YES;
    renderPipelineDescriptorLightCullTile.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    renderPipelineDescriptorLightCullTile.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    renderPipelineDescriptorLightCullTile.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    renderPipelineDescriptorLightCullTile.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
    renderPipelineDescriptorLightCullTile.vertexFunction = [self.defaultLibrary newFunctionWithName: @"screen_vert"];
    renderPipelineDescriptorLightCullTile.fragmentFunction = [self.defaultLibrary newFunctionWithName: @"lightcull_frag"];
    _renderPipelineLightCullTile = [self.device newRenderPipelineStateWithDescriptor: renderPipelineDescriptorLightCullTile
                                                                         error: nil];
}

- (void)beginFrame {
    [super beginFrame];
}

- (void)render {
    if(self.scene.IBL.isAnyRenderingRequired) {
        [self performPrefilterPass];
    }
    
    // begin
    id<MTLCommandBuffer> commandBuffer = [self.queue commandBuffer];
    commandBuffer.label = [NSString stringWithFormat: @"Render"];
    [self beginGPUTime:commandBuffer];
    
    // shadow
    [self renderShadows: commandBuffer];
    
    for(NSUInteger i = 0; i < MIN(4, _cameraComponents.count); i++) {
        MGPCameraComponent *cameraComp = _cameraComponents[i];
        if(cameraComp.enabled)
            [self renderCameraAtIndex:i commandBuffer:commandBuffer];
    }
    
    // present
    [commandBuffer presentDrawable: self.view.currentDrawable];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        [self endGPUTime:buffer];
        [self signal];
    }];
    
    [commandBuffer commit];
}

- (void)performPrefilterPass {
    id<MTLCommandBuffer> commandBuffer = [self.queue commandBuffer];
    commandBuffer.label = @"Prefilter";
    
    [self.scene.IBL render: commandBuffer];
    
    [commandBuffer commit];
}

- (void)renderCameraAtIndex:(NSUInteger)index
              commandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    [commandBuffer pushDebugGroup:[NSString stringWithFormat:@"Camera #%lu", index+1]];
    
    // skybox pass
    if(self.scene.IBL) {
        _renderPassSkybox.colorAttachments[0].texture = self.view.currentDrawable.texture;
        _renderPassSkybox.depthAttachment.texture = _gBuffer.depth;
        id<MTLRenderCommandEncoder> skyboxPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _renderPassSkybox];
        [self renderSkybox:skyboxPassEncoder];
    }
    
    // Post-process before prepass
    [_postProcess render: commandBuffer
       forRenderingOrder: MGPPostProcessingRenderingOrderBeforePrepass];
    
    // G-buffer prepass
    id<MTLRenderCommandEncoder> prepassEncoder = [commandBuffer renderCommandEncoderWithDescriptor: [_gBuffer prePassDescriptorWithAttachment:_gBuffer.attachments]];
    [self renderGBuffer:prepassEncoder];
    
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
    [self renderDirectLighting:shadingPassEncoder];
    
    // Directional lighting (with shadow) pass
    if(self.scene.lightGlobalProps.num_directional_shadowed_light > 0) {
        id<MTLRenderCommandEncoder> directionalShadowedLightingPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_gBuffer.directionalShadowedLightingPassDescriptor];
        [self renderDirectionalShadowedLighting:directionalShadowedLightingPassEncoder];
    }
    
    // Indirect lighting pass
    id<MTLRenderCommandEncoder> indirectLightingPassEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_gBuffer.indirectLightingPassDescriptor];
    [self renderIndirectLighting:indirectLightingPassEncoder];
    
    // Post-process after shade pass
    [_postProcess render: commandBuffer
       forRenderingOrder: MGPPostProcessingRenderingOrderAfterShadePass];
    
    // present to framebuffer
    _renderPassPresent.colorAttachments[0].texture = self.view.currentDrawable.texture;
    if(self.scene.IBL)
        _renderPassPresent.colorAttachments[0].loadAction = MTLLoadActionLoad;
    else
        _renderPassPresent.colorAttachments[0].loadAction = MTLLoadActionClear;
    id<MTLRenderCommandEncoder> presentCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor: _renderPassPresent];
    [self renderFramebuffer:presentCommandEncoder];
    
    [commandBuffer popDebugGroup];
}

- (void)endFrame {
    [super endFrame];
}

- (void)renderDrawCalls:(MGPDrawCallList *)drawCallList
           bindTextures:(BOOL)bindTextures
    instanceBufferIndex:(NSUInteger)slotIndex
                encoder:(id<MTLRenderCommandEncoder>)encoder {
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
                //prepassConstants.flipVertically = YES;  // for sponza textures
                //prepassConstants.sRGBTexture = YES;     // for sponza textures
                prepassConstants.usesAnisotropy = _usesAnisotropy;
                
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
                             atIndex: slotIndex];
            [encoder setFragmentBuffer: instancePropsBuffer
                                offset: instancePropsBufferOffset
                               atIndex: slotIndex];
            
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

- (void)renderSkybox:(id<MTLRenderCommandEncoder>)encoder {
    encoder.label = @"Skybox";
    [encoder setRenderPipelineState: _renderPipelineSkybox];
    [encoder setDepthStencilState: _depthStencil];
    [encoder setCullMode: MTLCullModeBack];
    
    if(self.scene.IBL) {
        [encoder setVertexBuffer: _commonVertexBuffer
                          offset: 256
                         atIndex: 0];
        [encoder setVertexBuffer: _cameraPropsBuffer
                          offset: _currentBufferIndex * (sizeof(camera_props_t) * MAX_NUM_CAMS)
                         atIndex: 1];
        [encoder setFragmentTexture: self.scene.IBL.environmentMap
                            atIndex: 0];
        [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                    vertexStart: 0
                    vertexCount: 36];
    }
    [encoder endEncoding];
}

- (void)renderGBuffer:(id<MTLRenderCommandEncoder>)encoder {
    encoder.label = @"G-buffer";
    [encoder setCullMode: MTLCullModeBack];
    [encoder setDepthStencilState: _depthStencil];
    
    // camera
    [encoder setVertexBuffer: _cameraPropsBuffer
                      offset: _currentBufferIndex * (sizeof(camera_props_t) * MAX_NUM_CAMS)
                     atIndex: 1];
    [encoder setFragmentBuffer: _cameraPropsBuffer
                        offset: _currentBufferIndex * (sizeof(camera_props_t) * MAX_NUM_CAMS)
                       atIndex: 1];
    
    // draw call
    if(_cameraComponents.count > 0) {
        MGPDrawCallList *drawCalls = [self drawCallListWithFrustum: _cameraComponents[0].frustum];
        [self renderDrawCalls:drawCalls
                 bindTextures:YES
          instanceBufferIndex:2
                      encoder:encoder];
    }
    
    [encoder endEncoding];
}

- (void)renderShadows:(id<MTLCommandBuffer>)buffer {
    if(_lightComponents.count == 0) return;
    
    for(NSUInteger i = 0, count = _lightComponents.count; i < count; i++) {
        MGPLightComponent *lightComponent = _lightComponents[i];
        if(lightComponent.castShadows) {
            MGPShadowBuffer *shadowBuffer = [_shadowManager newShadowBufferForLightComponent: lightComponent
                                                                                  resolution: DEFAULT_SHADOW_RESOLUTION
                                                                               cascadeLevels: 1];
            
            if(shadowBuffer != nil) {
                id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor: shadowBuffer.shadowPass];
                encoder.label = [NSString stringWithFormat: @"Shadow #%lu", i+1];
                [encoder setRenderPipelineState: _shadowManager.shadowPipeline];
                [encoder setDepthStencilState: _depthStencil];
                [encoder setCullMode: MTLCullModeBack];
                
                [encoder setVertexBuffer: _lightPropsBuffer
                                  offset: (_currentBufferIndex * MAX_NUM_LIGHTS + i) * sizeof(light_t)
                                 atIndex: 1];
                [encoder setVertexBuffer: _lightGlobalBuffer
                                  offset: _currentBufferIndex * sizeof(light_global_t)
                                 atIndex: 2];
                
                MGPDrawCallList *drawCallList = [self drawCallListWithFrustum:lightComponent.frustum];
                
                [self renderDrawCalls:drawCallList
                         bindTextures:NO
                  instanceBufferIndex:3
                              encoder:encoder];
                
                [encoder endEncoding];
            }
        }
    }
}

- (void)computeLightCullGrid:(id<MTLComputeCommandEncoder>)encoder {
    encoder.label = @"Light Culling";
    
    [encoder setComputePipelineState: _computePipelineLightCulling];
    NSUInteger tileSize = LIGHT_CULL_GRID_TILE_SIZE;
    NSUInteger width = _gBuffer.size.width + 0.5;
    NSUInteger height = _gBuffer.size.height + 0.5;
    width = (width + tileSize - 1) / tileSize;
    height = (height + tileSize - 1) / tileSize;
    MTLSize threadSize = MTLSizeMake(width, height, 1);
    [encoder setBuffer: _lightCullBuffer
                offset: 0
               atIndex: 0];
    [encoder setBuffer: _lightPropsBuffer
                offset: _currentBufferIndex * sizeof(light_t) * MAX_NUM_LIGHTS
               atIndex: 1];
    [encoder setBuffer: _lightGlobalBuffer
                offset: _currentBufferIndex * sizeof(light_global_t)
               atIndex: 2];
    [encoder setBuffer: _cameraPropsBuffer
                offset: _currentBufferIndex * sizeof(camera_props_t) * MAX_NUM_CAMS
               atIndex: 3];
    [encoder setTexture: _gBuffer.depth
                atIndex: 0];
    [encoder dispatchThreadgroups:threadSize
            threadsPerThreadgroup:MTLSizeMake(tileSize, tileSize, 1)];
    [encoder endEncoding];
}

- (void)renderDirectLighting:(id<MTLRenderCommandEncoder>)encoder {
    MGPGBufferShadingFunctionConstants shadingConstants = {};
    shadingConstants.usesAnisotropy = _usesAnisotropy;
    
    id<MTLRenderPipelineState> shadingPipeline = [_gBuffer shadingPipelineStateWithConstants: shadingConstants
                                                                                       error: nil];
    
    encoder.label = @"Direct Lighting";
    [encoder setRenderPipelineState: shadingPipeline];
    [encoder setCullMode: MTLCullModeBack];
    [encoder setFragmentBuffer: _cameraPropsBuffer
                        offset: _currentBufferIndex * sizeof(camera_props_t) * MAX_NUM_CAMS
                       atIndex: 0];
    [encoder setFragmentBuffer: _lightGlobalBuffer
                        offset: _currentBufferIndex * sizeof(light_global_t)
                       atIndex: 1];
    [encoder setFragmentBuffer: _lightPropsBuffer
                        offset: _currentBufferIndex * sizeof(light_t) * MAX_NUM_LIGHTS
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
    if(_usesAnisotropy) {
        [encoder setFragmentTexture: _gBuffer.tangent
                            atIndex: attachment_tangent];
    }
    
    [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                vertexStart: 0
                vertexCount: 3];
    
    [encoder endEncoding];
}

- (void)renderIndirectLighting:(id<MTLRenderCommandEncoder>)encoder {
    MGPGBufferShadingFunctionConstants shadingConstants = {};
    shadingConstants.hasIBLIrradianceMap = self.scene.IBL.irradianceMap != nil;
    shadingConstants.hasIBLSpecularMap = self.scene.IBL.prefilteredSpecularMap != nil;
    shadingConstants.hasSSAOMap = [_postProcess layerByClass:MGPPostProcessingLayerSSAO.class].enabled;
    shadingConstants.usesAnisotropy = _usesAnisotropy;
    
    id<MTLRenderPipelineState> renderPipeline = [_gBuffer indirectLightingPipelineStateWithConstants:shadingConstants
                                                                                               error:nil];
    
    encoder.label = @"Indirect Lighting";
    [encoder setRenderPipelineState: renderPipeline];
    [encoder setCullMode: MTLCullModeBack];
    [encoder setFragmentBuffer: _cameraPropsBuffer
                        offset: _currentBufferIndex * sizeof(camera_props_t) * MAX_NUM_CAMS
                       atIndex: 0];
    [encoder setFragmentBuffer: _lightGlobalBuffer
                        offset: _currentBufferIndex * sizeof(light_global_t)
                       atIndex: 1];
    [encoder setFragmentTexture: _gBuffer.albedo
                        atIndex: attachment_albedo];
    [encoder setFragmentTexture: _gBuffer.normal
                        atIndex: attachment_normal];
    [encoder setFragmentTexture: _gBuffer.shading
                        atIndex: attachment_shading];
    if(_usesAnisotropy) {
        [encoder setFragmentTexture: _gBuffer.tangent
                            atIndex: attachment_tangent];
    }
    [encoder setFragmentTexture: _gBuffer.depth
                        atIndex: attachment_depth];
    if(shadingConstants.hasIBLIrradianceMap)
        [encoder setFragmentTexture: self.scene.IBL.irradianceMap
                            atIndex: attachment_irradiance];
    if(shadingConstants.hasIBLSpecularMap) {
        [encoder setFragmentTexture: self.scene.IBL.prefilteredSpecularMap
                            atIndex: attachment_prefiltered_specular];
        [encoder setFragmentTexture: self.scene.IBL.BRDFLookupTexture
                            atIndex: attachment_brdf_lookup];
    }
    if(shadingConstants.hasSSAOMap) {
        [encoder setFragmentTexture: ((MGPPostProcessingLayerSSAO *)_postProcess[0]).ssaoTexture
                            atIndex: attachment_ssao];
    }
    [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                vertexStart: 0
                vertexCount: 3];
    
    [encoder endEncoding];
}

- (void)renderDirectionalShadowedLighting:(id<MTLRenderCommandEncoder>)encoder {
    light_global_t lightGlobalProps = self.scene.lightGlobalProps;
    MGPGBufferShadingFunctionConstants shadingConstants = {};
    shadingConstants.usesAnisotropy = _usesAnisotropy;
    NSUInteger lightBufferOffset = _currentBufferIndex * sizeof(light_t) * MAX_NUM_LIGHTS;
    
    id<MTLRenderPipelineState> renderPipeline = [_gBuffer directionalShadowedLightingPipelineStateWithConstants:shadingConstants
                                                                                                          error:nil];

    encoder.label = @"Directional Shadowed Lighting";
    [encoder setRenderPipelineState: renderPipeline];
    [encoder setCullMode: MTLCullModeBack];
    [encoder setFragmentBuffer: _cameraPropsBuffer
                        offset: _currentBufferIndex * sizeof(camera_props_t) * MAX_NUM_CAMS
                       atIndex: 0];
    [encoder setFragmentBuffer: _lightGlobalBuffer
                        offset: _currentBufferIndex * sizeof(light_global_t)
                       atIndex: 1];
    [encoder setFragmentBuffer: _lightPropsBuffer
                        offset: lightBufferOffset
                       atIndex: 2];
    [encoder setFragmentTexture: _gBuffer.albedo
                        atIndex: attachment_albedo];
    [encoder setFragmentTexture: _gBuffer.normal
                        atIndex: attachment_normal];
    [encoder setFragmentTexture: _gBuffer.shading
                        atIndex: attachment_shading];
    if(_usesAnisotropy) {
        [encoder setFragmentTexture: _gBuffer.tangent
                            atIndex: attachment_tangent];
    }
    [encoder setFragmentTexture: _gBuffer.depth
                        atIndex: attachment_depth];
    
    for(NSUInteger i = 0; i < lightGlobalProps.first_point_light_index; i++) {
        if(_lightComponents[i].castShadows) {
            MGPShadowBuffer *shadowBuffer = [_shadowManager newShadowBufferForLightComponent: _lightComponents[i]
                                                                                  resolution: DEFAULT_SHADOW_RESOLUTION
                                                                               cascadeLevels: 1];
            if(shadowBuffer) {
                [encoder pushDebugGroup:[NSString stringWithFormat:@"Directional Light #%lu", i+1]];
                [encoder setFragmentBufferOffset:lightBufferOffset + i * sizeof(light_t)
                                         atIndex:2];
                [encoder setFragmentTexture: shadowBuffer.texture
                                    atIndex: attachment_shadow_map];
                [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                            vertexStart: 0
                            vertexCount: 3];
                [encoder popDebugGroup];
            }

        }
    }
    
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
                vertexCount: 3];
    
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
        {
            MGPPostProcessingLayerSSAO *ssaoLayer = (MGPPostProcessingLayerSSAO *)[_postProcess layerByClass:MGPPostProcessingLayerSSAO.class];
            return ssaoLayer != nil ? ssaoLayer.ssaoTexture : _gBuffer.output;
        }
        default:
            return _gBuffer.output;
    }
}

- (void)resize:(CGSize)newSize {
    [super resize:newSize];
    [_gBuffer resize:self.scaledSize];
}

@end
