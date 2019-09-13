//
//  MGPRenderer.m
//  MetalDeferred
//
//  Created by 이현우 on 29/04/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPRenderer.h"

@implementation MGPRenderer {
    dispatch_semaphore_t _semaphore;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        [self initMetal];
    }
    return self;
}

- (void)initMetal {
    // Selcct low power device (for debugging)
    /*
    NSArray *devices = MTLCopyAllDevices();
    for(id<MTLDevice> device in devices) {
        if(device.isLowPower) {
            _device = device;
            break;
        }
    }
    */
    
    if(_device == nil) {
        _device = MTLCreateSystemDefaultDevice();
    }
    _defaultLibrary = [_device newDefaultLibrary];
    _queue = [_device newCommandQueue];
    _semaphore = dispatch_semaphore_create(3);
    
    NSLog(@"Selected GPU : %@", _device.name);
}

- (void)update:(float)deltaTime {
    // do nothing
}

- (void)render {
    [self beginFrame];
    
    id<MTLCommandBuffer> buffer = [_queue commandBuffer];
    
    // draws solid background
    MTLRenderPassDescriptor *renderPass = [MTLRenderPassDescriptor new];
    renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
    renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.4, 0.8, 1.0);
    renderPass.colorAttachments[0].texture = _view.currentDrawable.texture;
    
    id<MTLRenderCommandEncoder> enc = [buffer renderCommandEncoderWithDescriptor: renderPass];
    [enc endEncoding];
    [buffer presentDrawable: _view.currentDrawable];
    [buffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        [self endFrame];
    }];
    [buffer commit];
}

- (void)resize:(CGSize)newSize {
    // do nothing
}

#pragma mark - Internal frame rendering
- (void)beginFrame {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
}

- (void)endFrame {
    dispatch_semaphore_signal(_semaphore);
}

@end
