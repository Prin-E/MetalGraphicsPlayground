//
//  MGPGBuffer.h
//  MetalDeferred
//
//  Created by 이현우 on 01/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

@import Metal;

NS_ASSUME_NONNULL_BEGIN

@interface MGPGBuffer : NSObject

// g-buffer
@property (readonly) id<MTLTexture> albedo;     // RGB+A
@property (readonly) id<MTLTexture> normal;     // view-space (XYZ+A(0.0:empty-space))
@property (readonly) id<MTLTexture> pos;        // view-space (XYZ)
@property (readonly) id<MTLTexture> shading;    // R:roughness,G:metalic,BA:TODO
@property (readonly) id<MTLTexture> tangent;    // view-space (XYZ+A(0.0:empty-space))

// lighting-output
@property (readonly) id<MTLTexture> lighting;

// depth
@property (readonly) id<MTLTexture> depth;

// base vertex descriptor
@property (readonly) MTLVertexDescriptor *baseVertexDescriptor;

// render pass
@property (readonly) MTLRenderPassDescriptor *renderPassDescriptor;
@property (readonly) MTLRenderPassDescriptor *lightingPassDescriptor;

// resolution
@property (nonatomic, readonly) CGSize size;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                       library:(id<MTLLibrary>)library
                          size:(CGSize)newSize;

- (void)resize:(CGSize)newSize;

// render pipeline
- (id<MTLRenderPipelineState>)renderPipelineStateWithConstants: (MTLFunctionConstantValues *)constantValues
                                                         error: (NSError **)error;
- (id<MTLRenderPipelineState>)lightingPipelineStateWithError: (NSError **)error;

@end

NS_ASSUME_NONNULL_END