//
//  MGPGizmos.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/08/20.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <simd/simd.h>

@import Metal;

NS_ASSUME_NONNULL_BEGIN

@interface MGPGizmos : NSObject

@property (nonatomic) NSUInteger currentBufferIndex;

@property (nonatomic, readonly) id<MTLRenderPipelineState> wireframePipeline;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                       library:(id<MTLLibrary>)library
                 gizmoCapacity:(NSUInteger)capacity
             maxBuffersInFight:(NSUInteger)inFlight;

- (void)drawWireframeSphereWithCenter:(simd_float3)position
                               radius:(float)radius;

- (void)prepareEncodingWithColorTexture:(id<MTLTexture>)colorTex
                           depthTexture:(id<MTLTexture>)depthTex
                           cameraBuffer:(id<MTLBuffer>)cameraBuffer
                            bufferIndex:(NSUInteger)bufferIndex;
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)buffer;

@end

NS_ASSUME_NONNULL_END
