//
//  MGPShadowBuffer.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 28/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPShadowBuffer.h"
#import "MGPLight.h"
#import "MGPLightComponent.h"

@interface MGPShadowBuffer ()

- (void)_makeShadowTextureWithDevice: (id<MTLDevice>)device;

@end

NSString * const MGPShadowBufferErrorDoamin = @"MGPShadowBufferError";

@implementation MGPShadowBuffer

- (instancetype)initWithDevice:(id<MTLDevice>)device
                         light:(MGPLight *)light
                    resolution:(NSUInteger)resolution
                 cascadeLevels:(NSUInteger)cascadeLevels {
    self = [super init];
    if(self) {
        if(device == nil)
        {
            @throw [NSException exceptionWithName: MGPShadowBufferErrorDoamin
                                           reason: @"device is nil."
                                         userInfo: @{
                                                     NSLocalizedDescriptionKey : @"device is null."
                                                     }];
        }
        
        if(light == nil)
        {
            @throw [NSException exceptionWithName: MGPShadowBufferErrorDoamin
                                           reason: @"light is nil."
                                         userInfo: @{
                                                     NSLocalizedDescriptionKey : @"light is null."
                                                     }];
        }
        
        _light = light;
        _resolution = MAX(256, resolution);
        _cascadeLevels = MAX(1, cascadeLevels);
        
        [self _makeShadowTextureWithDevice: device];
        [self _makeShadowPass];
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                lightComponent:(MGPLightComponent *)lightComponent
                    resolution:(NSUInteger)resolution
                 cascadeLevels:(NSUInteger)cascadeLevels {
    self = [super init];
    if(self) {
        if(device == nil)
        {
            @throw [NSException exceptionWithName: MGPShadowBufferErrorDoamin
                                           reason: @"device is nil."
                                         userInfo: @{
                                                     NSLocalizedDescriptionKey : @"device is null."
                                                     }];
        }
        
        if(lightComponent == nil)
        {
            @throw [NSException exceptionWithName: MGPShadowBufferErrorDoamin
                                           reason: @"light is nil."
                                         userInfo: @{
                                                     NSLocalizedDescriptionKey : @"light is null."
                                                     }];
        }
        
        _lightComponent = lightComponent;
        _resolution = MAX(256, resolution);
        _cascadeLevels = MAX(1, cascadeLevels);
        
        [self _makeShadowTextureWithDevice: device];
        [self _makeShadowPass];
    }
    return self;
}

- (void)_makeShadowTextureWithDevice:(id<MTLDevice>)device {
    MTLTextureDescriptor *descriptor = nil;
    
    if(_light.type == MGPLightTypePoint)
        descriptor = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat: MTLPixelFormatDepth32Float
                                                                           size: _resolution
                                                                      mipmapped: _cascadeLevels > 1];
    else
        descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatDepth32Float
                                                                        width: _resolution
                                                                       height: _resolution
                                                                    mipmapped: _cascadeLevels > 1];
    
    descriptor.mipmapLevelCount = _cascadeLevels;
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    descriptor.storageMode = MTLStorageModePrivate;
    
    _texture = [device newTextureWithDescriptor: descriptor];
    _texture.label = [NSString stringWithFormat:@"Shadow (0x%llX)", (uint64_t)_light];
}

- (void)_makeShadowPass {
    _shadowPass = [[MTLRenderPassDescriptor alloc] init];
    _shadowPass.depthAttachment.loadAction = MTLLoadActionClear;
    _shadowPass.depthAttachment.storeAction = MTLStoreActionStore;
    _shadowPass.depthAttachment.texture = _texture;
}

@end
