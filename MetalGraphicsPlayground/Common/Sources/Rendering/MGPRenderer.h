//
//  MGPRenderer.h
//  MetalDeferred
//
//  Created by 이현우 on 29/04/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

@import Metal;

#import "../View/MGPView.h"

NS_ASSUME_NONNULL_BEGIN

@interface MGPRenderer : NSObject

@property (readonly) id<MTLDevice> device;
@property (readonly) id<MTLLibrary> defaultLibrary;
@property (readonly) id<MTLCommandQueue> queue;

@property (weak) MGPView *view;

- (void)update: (float)deltaTime;
- (void)render;
- (void)resize: (CGSize)newSize;

// don't override this methods!
- (void)beginFrame;
- (void)endFrame;

- (void)waitGpu;

@end

NS_ASSUME_NONNULL_END
