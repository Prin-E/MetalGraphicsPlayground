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
    NSTimeInterval _prevCPUTimeInterval;
    NSTimeInterval _prevGPUTimeInterval;    // for 10.14 or earlier
    
    float _renderScale;
}

@synthesize renderScale = _renderScale;

- (instancetype)init {
    self = [super init];
    if(self) {
        [self initMetal];
        _size = CGSizeMake(512, 512);
        _scaledSize = CGSizeMake(512, 512);
        _renderScale = 1.0f;
    }
    return self;
}

- (void)initMetal {
    // Selcct low power device (for debugging)
    NSArray *devices = MTLCopyAllDevices();
    for(id<MTLDevice> device in devices) {
        if(device.isLowPower) {
            //_device = device;
            break;
        }
    }
    
    if(_device == nil) {
        _device = MTLCreateSystemDefaultDevice();
    }
    _defaultLibrary = [_device newDefaultLibrary];
    _queue = [_device newCommandQueue];
    _semaphore = dispatch_semaphore_create(kMaxBuffersInFlight);
    
    NSLog(@"Selected GPU : %@", _device.name);
}

- (void)update:(float)deltaTime {
    // do nothing
}

- (void)resize:(CGSize)newSize {
    _size = newSize;
    _scaledSize = CGSizeMake(ceilf(_size.width * _renderScale), ceilf(_size.height * _renderScale));
}

- (float)renderScale {
    return _renderScale;
}

- (void)setRenderScale:(float)renderScale {
    _renderScale = renderScale;
    [self resize:_size];
}

#pragma mark - Rendering
- (void)beginFrame {
    [self wait];
    
    _prevCPUTimeInterval = [NSDate timeIntervalSinceReferenceDate];
}

- (void)endFrame {
    // calculate CPU time
    NSTimeInterval CPUTimeInterval = [NSDate timeIntervalSinceReferenceDate];
    _CPUTime = CPUTimeInterval - _prevCPUTimeInterval;
    
    //NSLog(@"CPU : %.5fms", _CPUTime*1000);
    // circulate buffer index
    _currentBufferIndex = (_currentBufferIndex + 1) % kMaxBuffersInFlight;
}

- (void)render {
    id<MTLCommandBuffer> buffer = [_queue commandBuffer];
    
    [self beginGPUTime:buffer];
    
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
        [self endGPUTime:buffer];
        [self signal];
    }];
    
    [buffer commit];
}

#pragma mark - Synchronization
- (void)waitGpu {
    id<MTLCommandBuffer> emptyBuffer = [_queue commandBuffer];
    [emptyBuffer commit];
    [emptyBuffer waitUntilCompleted];
}

- (void)wait {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
}

- (void)signal {
    dispatch_semaphore_signal(_semaphore);
}

#pragma mark - GPU Time
- (void)beginGPUTime:(id<MTLCommandBuffer>)buffer {
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    if(version.majorVersion <= 10 && version.minorVersion < 15) {
        [buffer addScheduledHandler:^(id<MTLCommandBuffer> buffer) {
            self->_prevGPUTimeInterval = [NSDate timeIntervalSinceReferenceDate];
        }];
    }
}

- (void)endGPUTime:(id<MTLCommandBuffer>)buffer {
    // calculate GPU time and signal
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    if(version.majorVersion > 10 || version.minorVersion >= 15) {
        if(@available(macOS 10.15, *)) {
            self->_GPUTime = buffer.GPUEndTime - buffer.GPUStartTime;
        }
    }
    else {
        NSTimeInterval GPUTimeInterval = [NSDate timeIntervalSinceReferenceDate];
        self->_GPUTime = GPUTimeInterval - self->_prevGPUTimeInterval;
        self->_prevGPUTimeInterval = GPUTimeInterval;
    }
}

@end
