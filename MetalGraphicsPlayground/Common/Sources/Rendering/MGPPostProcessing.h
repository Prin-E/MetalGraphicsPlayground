//
//  MGPPostProcessing.h
//  MetalPostProcessing
//
//  Created by 이현우 on 24/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MGPPostProcessingLayer.h"
@import Metal;

NS_ASSUME_NONNULL_BEGIN

@class MGPTextureManager;

@interface MGPPostProcessing : NSObject

@property (nonatomic, readonly) id<MTLDevice> device;
@property (nonatomic, readonly) id<MTLLibrary> library;
@property (nonatomic, readonly) MGPTextureManager *textureManager;

// ordered by renderingOrder
@property (nonatomic, readonly) NSArray<id<MGPPostProcessingLayer>> *layers;

// camera, g-buffer
@property (nonatomic) MGPGBuffer *gBuffer;
@property (nonatomic) id<MTLBuffer> cameraBuffer;
@property (nonatomic) NSUInteger currentBufferIndex;

// init
- (instancetype)initWithDevice:(id<MTLDevice>)device
                       library:(id<MTLLibrary>)library;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                       library:(id<MTLLibrary>)library
                textureManager:(MGPTextureManager *)textureManager;

// add/remove
- (void)addLayer:(id<MGPPostProcessingLayer>)layer;
- (id<MGPPostProcessingLayer>)layerAtIndex:(NSUInteger)index;
- (id<MGPPostProcessingLayer>)layerByClass:(Class)layerClass;
- (void)removeLayerAtIndex:(NSUInteger)index;
- (void)removeLayerByClass:(Class)layerClass;

// indexed subscript
- (id<MGPPostProcessingLayer>)objectAtIndexedSubscript: (NSUInteger)index;

// query layers for rendering order
- (NSArray<id<MGPPostProcessingLayer>> *)orderedLayersForRenderingOrder: (MGPPostProcessingRenderingOrder)renderingOrder;

- (void)render:(id<MTLCommandBuffer>)buffer forRenderingOrder: (MGPPostProcessingRenderingOrder)renderingOrder;
- (void)resize:(CGSize)newSize;

@end

NS_ASSUME_NONNULL_END
