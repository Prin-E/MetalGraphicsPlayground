//
//  CustomMetalLayer.h
//  MetalCustomCALayer
//
//  Created by 이현우 on 31/12/2018.
//  Copyright © 2018 Prin_E. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@import Metal;
@import QuartzCore.CAMetalLayer;

NS_ASSUME_NONNULL_BEGIN

@class CustomMetalLayerView;
@protocol CustomMetalRendering
@required
@property (readonly) id<MTLDevice> device;
- (void)renderFromView: (CustomMetalLayerView *)view;
- (void)resize: (CGSize)newSize;
@end

/*
 Alternative implementation of MTKView for macOS
 */
@interface CustomMetalLayerView : NSView

// frame info
@property (readonly) uint64_t currentFrame;
@property (readonly) float deltaTime;
@property (readonly) float currentFramesPerSecond;
@property (readonly) id<CAMetalDrawable> currentDrawable;

// renderer
@property (strong) id<CustomMetalRendering> renderer;

@end

NS_ASSUME_NONNULL_END
