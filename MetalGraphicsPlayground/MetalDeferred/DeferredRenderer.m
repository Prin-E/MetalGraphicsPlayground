//
//  DeferredRenderer.m
//  MetalDeferred
//
//  Created by 이현우 on 03/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "DeferredRenderer.h"
#import "../Common/MGPGBuffer.h"

@implementation DeferredRenderer {
    MGPGBuffer *gBuffer;
    float f;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        // TODO
    }
    return self;
}

- (void)initAssets {
    // G-buffer
    gBuffer = [[MGPGBuffer alloc] init];
}

- (void)update:(float)deltaTime {
    f += deltaTime;
    if(f >= 1.0f) {
        f = 0.0f;
    }
}

- (void)render {
    [self beginFrame];
    
    id<MTLCommandBuffer> buffer = [self.queue commandBuffer];
    
    // draws solid background
    MTLRenderPassDescriptor *renderPass = [MTLRenderPassDescriptor new];
    renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
    renderPass.colorAttachments[0].clearColor = MTLClearColorMake(f, 0.4, 0.8, 1.0);
    renderPass.colorAttachments[0].texture = self.view.currentDrawable.texture;
    
    id<MTLRenderCommandEncoder> enc = [buffer renderCommandEncoderWithDescriptor: renderPass];
    [enc endEncoding];
    [buffer presentDrawable: self.view.currentDrawable];
    [buffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        [self endFrame];
    }];
    [buffer commit];
}

@end
