//
//  MGPRenderer.h
//  MetalDeferred
//
//  Created by 이현우 on 29/04/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

@import Metal;

#import "../View/MGPView.h"

#define kMaxBuffersInFlight 3

NS_ASSUME_NONNULL_BEGIN

@interface MGPRenderer : NSObject {
    @protected
    NSUInteger _currentBufferIndex;
}

@property (readonly) id<MTLDevice> device;
@property (readonly) id<MTLLibrary> defaultLibrary;
@property (readonly) id<MTLCommandQueue> queue;

@property (weak) MGPView *view;

// Render options
@property (readonly) CGSize size;
@property (readonly) CGSize scaledSize;
@property (readwrite) float renderScale;    // 1.0 : 100%


// Profiling
@property (readonly) float CPUTime;
@property (readonly) float GPUTime;

// Calculating GPU Time (MGPRenderer.GPUTime will be calculated)
- (void)beginGPUTime:(id<MTLCommandBuffer>)buffer;
- (void)endGPUTime:(id<MTLCommandBuffer>)buffer;

// Updating
- (void)update: (float)deltaTime;
- (void)resize: (CGSize)newSize;

// Rendering
- (void)beginFrame;
- (void)endFrame;
- (void)render;

// Synchronization
- (void)waitGpu;
- (void)wait;
- (void)signal;

@end

NS_ASSUME_NONNULL_END
