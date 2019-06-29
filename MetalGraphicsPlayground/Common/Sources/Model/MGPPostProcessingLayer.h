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

@protocol MGPPostProcessingLayer <NSObject>

- (instancetype)initWithDevice: (id<MTLDevice>)device
                       library: (id<MTLLibrary>)library;
- (NSUInteger)renderingOrder;
- (void)render:(id<MTLCommandBuffer>)buffer;

@end

@interface MGPPostProcessingLayer : NSObject <MGPPostProcessingLayer>

@end

// Ambient Occlusion
@interface MGPPostProcessingLayerSSAO : MGPPostProcessingLayer
@end

NS_ASSUME_NONNULL_END
