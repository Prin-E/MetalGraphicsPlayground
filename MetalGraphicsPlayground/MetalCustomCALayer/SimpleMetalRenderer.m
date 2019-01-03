//
//  SimpleMetalRenderer.m
//  MetalCustomCALayer
//
//  Created by 이현우 on 01/01/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "SimpleMetalRenderer.h"
@import Metal;

@interface SimpleMetalRenderer ()
- (void)initMetal;
@end

@implementation SimpleMetalRenderer {
    id<MTLDevice> _device;
    id<MTLLibrary> _library;
    id<MTLCommandQueue> _queue;
    dispatch_semaphore_t _semaphore;
}
@synthesize device = _device;

- (instancetype)init {
    self = [super init];
    if(self) {
        [self initMetal];
    }
    return self;
}

- (void)initMetal {
    _device = MTLCreateSystemDefaultDevice();
    _library = [_device newDefaultLibrary];
    _queue = [_device newCommandQueue];
    _semaphore = dispatch_semaphore_create(3);
}

- (nonnull id<MTLDevice>)device {
    return _device;
}

- (void)renderFromView:(CustomMetalLayerView *)view {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    
    id<MTLCommandBuffer> buffer = [_queue commandBuffer];
    static float f = 0.0f;
    static float inc = 1.0f;
    f += view.deltaTime * inc;
    if(f >= 1.0f)
        inc = -1.0f;
    else if(f <= 0.0f)
        inc = 1.0f;
    
    MTLRenderPassDescriptor *renderPass = [MTLRenderPassDescriptor new];
    renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
    renderPass.colorAttachments[0].clearColor = MTLClearColorMake(f, 0.4, 0.8, 1.0);
    renderPass.colorAttachments[0].texture = view.currentDrawable.texture;
    
    id<MTLRenderCommandEncoder> enc = [buffer renderCommandEncoderWithDescriptor: renderPass];
    [enc endEncoding];
    [buffer presentDrawable: view.currentDrawable];
    [buffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        dispatch_semaphore_signal(self->_semaphore);
    }];
    [buffer commit];
}

- (void)resize:(CGSize)newSize {
    // do nothing
}

@end
