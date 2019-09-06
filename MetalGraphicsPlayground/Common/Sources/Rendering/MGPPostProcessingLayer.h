//
//  MGPPostProcessingLayer.h
//  MetalPostProcessing
//
//  Created by 이현우 on 24/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
@import Metal;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, MGPPostProcessingRenderingOrder) {
    MGPPostProcessingRenderingOrderBeforePrepass = 0,
    MGPPostProcessingRenderingOrderBeforeLightPass = 1000,
    MGPPostProcessingRenderingOrderBeforeShadePass = 2000,
    MGPPostProcessingRenderingOrderAfterShadePass = 3000
};

#pragma mark - Base protocol and class
@class MGPGBuffer;
@class MGPPostProcessing;
@protocol MGPPostProcessingLayer <NSObject>

@property (weak) MGPPostProcessing *postProcessing;

- (instancetype)initWithDevice: (id<MTLDevice>)device
                       library: (id<MTLLibrary>)library;
- (NSUInteger)renderingOrder;                   // ascending
- (void)render:(id<MTLCommandBuffer>)buffer;
- (void)resize:(CGSize)newSize;

@end

@interface MGPPostProcessingLayer : NSObject <MGPPostProcessingLayer>
@end

#pragma mark - Ambient Occlusion
@interface MGPPostProcessingLayerSSAO : MGPPostProcessingLayer

@property (nonatomic, readonly) id<MTLTexture> ssaoTexture;

@property (nonatomic) uint32_t numSamples;
@property (nonatomic) uint32_t downsample;  // 0 : full size, 1~n : 2^n downscale
@property (nonatomic) float intensity;      // 0.0~1.0
@property (nonatomic) float radius;         // world-space
@property (nonatomic) float bias;           // world-space

@end

#pragma mark - Screen Space Reflection
@interface MGPPostProcessingLayerScreenSpaceReflection : MGPPostProcessingLayer

@property (nonatomic) uint32_t iteration;
@property (nonatomic) float step;
@property (nonatomic) float opacity;

@end

#pragma mark - Temporal AA
// TODO:
@interface MGPPostProcessingLayerTemporalAA : MGPPostProcessingLayer

@property (nonatomic, readonly) id<MTLTexture> historyTexture;

@end

NS_ASSUME_NONNULL_END
