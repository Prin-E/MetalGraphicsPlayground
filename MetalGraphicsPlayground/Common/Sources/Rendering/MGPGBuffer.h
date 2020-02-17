//
//  MGPGBuffer.h
//  MetalDeferred
//
//  Created by 이현우 on 01/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

@import Metal;

NS_ASSUME_NONNULL_BEGIN

typedef struct MGPGBufferPrepassFunctionConstants {
    bool hasAlbedoMap;
    bool hasNormalMap;
    bool hasRoughnessMap;
    bool hasMetalicMap;
    bool hasOcclusionMap;
    bool hasAnisotropicMap;
    bool flipVertically;
    bool sRGBTexture;
    bool usesAnisotropy;
} MGPGBufferPrepassFunctionConstants;

typedef struct MGPGBufferShadingFunctionConstants {
    bool hasIBLIrradianceMap;
    bool hasIBLSpecularMap;
    bool hasSSAOMap;
    bool usesAnisotropy;
} MGPGBufferShadingFunctionConstants;

typedef NS_OPTIONS(NSUInteger, MGPGBufferAttachmentType) {
    MGPGBufferAttachmentTypeOutput = 1 << 0,
    MGPGBufferAttachmentTypeDepth = 1 << 1,
    MGPGBufferAttachmentTypeAlbedo = 1 << 2,
    MGPGBufferAttachmentTypeNormal = 1 << 3,
    MGPGBufferAttachmentTypeShading = 1 << 4,
    MGPGBufferAttachmentTypeTangent = 1 << 5,
    MGPGBufferAttachmentTypeLighting = 1 << 6,
    MGPGBufferAttachmentTypeAll = (MGPGBufferAttachmentTypeOutput   |
                                   MGPGBufferAttachmentTypeDepth    |
                                   MGPGBufferAttachmentTypeAlbedo   |
                                   MGPGBufferAttachmentTypeNormal   |
                                   MGPGBufferAttachmentTypeShading  |
                                   MGPGBufferAttachmentTypeTangent  |
                                   MGPGBufferAttachmentTypeLighting )
};

/*
 - G-Buffer -
 G-Buffer requires at-least 3-render passes. (prepass->light(cull or accumulation)->shade)
 */
@interface MGPGBuffer : NSObject

// g-buffer
@property (readonly) id<MTLTexture> albedo;     // RGB+A
@property (readonly) id<MTLTexture> normal;     // view-space (XYZ+A(0.0:empty-space))
@property (readonly) id<MTLTexture> shading;    // R:roughness,G:metalic,B:occlusion,A:TODO
@property (readonly) id<MTLTexture> tangent;    // view-space (XYZ+A(0.0:empty-space))

// light-accumulation-output
@property (readonly) id<MTLTexture> lighting;

// shade-final-output
@property (readonly) id<MTLTexture> output;

// depth
@property (readonly) id<MTLTexture> depth;

// attachments
@property (nonatomic) MGPGBufferAttachmentType attachments;

// base vertex descriptor
@property (readonly) MTLVertexDescriptor *baseVertexDescriptor;

// render pass
@property (readonly) MTLRenderPassDescriptor *renderPassDescriptor;
@property (readonly) MTLRenderPassDescriptor *lightingPassBaseDescriptor;
@property (readonly) MTLRenderPassDescriptor *lightingPassAddDescriptor;
@property (readonly) MTLRenderPassDescriptor *indirectLightingPassDescriptor;
@property (readonly) MTLRenderPassDescriptor *directionalShadowedLightingPassDescriptor;
@property (readonly) MTLRenderPassDescriptor *shadingPassDescriptor;

// resolution
@property (nonatomic, readonly) CGSize size;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                       library:(id<MTLLibrary>)library
                          size:(CGSize)newSize;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                       library:(id<MTLLibrary>)library
                          size:(CGSize)newSize
                   attachments:(MGPGBufferAttachmentType)attachments;

- (void)resize:(CGSize)newSize;

// render pipeline
- (id<MTLRenderPipelineState>)renderPipelineStateWithConstants: (MGPGBufferPrepassFunctionConstants)constants
                                                         error: (NSError **)error;
- (id<MTLRenderPipelineState>)lightingPipelineStateWithError: (NSError **)error;
- (id<MTLRenderPipelineState>)lightingPipelineStateWithConstants:(MGPGBufferShadingFunctionConstants)constants
                                                           error: (NSError **)error;
- (id<MTLRenderPipelineState>)indirectLightingPipelineStateWithConstants: (MGPGBufferShadingFunctionConstants)constants
                                                                   error: (NSError **)error;
- (id<MTLRenderPipelineState>)directionalShadowedLightingPipelineStateWithConstants: (MGPGBufferShadingFunctionConstants)constants
                                                                              error: (NSError**)error;
- (id<MTLRenderPipelineState>)shadingPipelineStateWithConstants: (MGPGBufferShadingFunctionConstants)constants
                                                          error: (NSError **)error;
- (id<MTLRenderPipelineState>)nonLightCulledShadingPipelineStateWithConstants: (MGPGBufferShadingFunctionConstants)constants
                                                          error: (NSError **)error;

@end

NS_ASSUME_NONNULL_END
