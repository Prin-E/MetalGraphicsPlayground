//
//  MGPImageBasedLighting.m
//  MetalDeferred
//
//  Created by 이현우 on 09/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPImageBasedLighting.h"

@implementation MGPImageBasedLighting {
    id<MTLDevice> _device;
    id<MTLLibrary> _library;
    id<MTLCommandQueue> _queue;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                       library:(id<MTLLibrary>)library
                         queue:(id<MTLCommandQueue>)queue {
    self = [super init];
    if(self) {
        _device = device;
        _library = library;
        _queue = queue;
        [self _makeEmptyTextures];
    }
    return self;
}

- (void)_makeEmptyTextures {
    NSInteger width = 64;
    NSInteger height = 32;
    
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA16Float
                                                                                    width: width
                                                                                   height: height
                                                                                mipmapped: NO];
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    _environmentEquirectangularMap = [_device newTextureWithDescriptor: desc];
    _irradianceEquirectangularMap = [_device newTextureWithDescriptor: desc];
    _specularEquirectangularMap = [_device newTextureWithDescriptor: desc];
}

- (void)buildIrradianceTexture {
    
}

- (void)buildSpecularLightingTexture {
    
}

@end
