//
//  MGPView.h
//  MetalDeferred
//
//  Created by 이현우 on 29/04/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

@import Cocoa;
@import Metal;
@import QuartzCore.CAMetalLayer;

NS_ASSUME_NONNULL_BEGIN

@class MGPRenderer;
/*
 Custom implementation like MTKView for macOS
 */
@interface MGPView : NSView

// frame info
@property (readonly) uint64_t currentFrame;
@property (readonly) float deltaTime;
@property (readonly) float currentFramesPerSecond;
@property (readonly) id<CAMetalDrawable> currentDrawable;

// renderer
@property (strong) MGPRenderer *renderer;

@end

NS_ASSUME_NONNULL_END
