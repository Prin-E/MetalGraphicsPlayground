//
//  MGPShadowManager.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 29/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPShadowManager.h"
#import "MGPShadowBuffer.h"
#import "MGPLight.h"
#import "MGPCamera.h"
#import "MGPLightComponent.h"

NSString * const MGPShadowManagerErrorDoamin = @"MGPShadowManagerError";

@implementation MGPShadowManager {
    NSMutableDictionary<MGPLight*, MGPShadowBuffer*> *_shadowBufferDict;
    NSMutableDictionary<MGPLightComponent*, MGPShadowBuffer*> *_lightCompShadowBufferDict;
    MGPCamera *_camera;
    id<MTLRenderPipelineState> _shadowPipeline;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                       library:(id<MTLLibrary>)library
              vertexDescriptor:(nonnull MTLVertexDescriptor *)vertexDescriptor {
    self = [super init];
    if(self) {
        if(device == nil)
        {
            @throw [NSException exceptionWithName: MGPShadowManagerErrorDoamin
                                           reason: @"device is nil."
                                         userInfo: @{
                                                     NSLocalizedDescriptionKey : @"device is null."
                                                     }];
        }
        
        _device = device;
        _library = library;
        _vertexDescriptor = vertexDescriptor;
        _shadowBufferDict = [NSMutableDictionary dictionaryWithCapacity: 8];
        [self _makeRenderPipeline];
    }
    return self;
}

- (void)_makeRenderPipeline {
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    desc.vertexDescriptor = _vertexDescriptor;
    desc.vertexFunction = [_library newFunctionWithName: @"shadow_vert"];
    
    _shadowPipeline = [_device newRenderPipelineStateWithDescriptor: desc
                                                              error: nil];
}

- (MGPShadowBuffer *)newShadowBufferForLight:(MGPLight *)light
                                  resolution:(NSUInteger)resolution
                               cascadeLevels:(NSUInteger)cascadeLevels {
    MGPShadowBuffer *buffer = nil;
    if(light.castShadows) {
        buffer = [_shadowBufferDict objectForKey: light];
        if(buffer == nil) {
            buffer = [[MGPShadowBuffer alloc] initWithDevice: _device
                                                       light: light
                                                  resolution: resolution
                                               cascadeLevels: cascadeLevels];
            _shadowBufferDict[light] = buffer;
        }
    }
    return buffer;
}

- (MGPShadowBuffer *)newShadowBufferForLightComponent:(MGPLightComponent *)lightComponent
                                           resolution:(NSUInteger)resolution
                                        cascadeLevels:(NSUInteger)cascadeLevels {
    MGPShadowBuffer *buffer = nil;
    if(lightComponent.castShadows) {
        buffer = [_lightCompShadowBufferDict objectForKey: lightComponent];
        if(buffer == nil) {
            buffer = [[MGPShadowBuffer alloc] initWithDevice: _device
                                                       light: light
                                                  resolution: resolution
                                               cascadeLevels: cascadeLevels];
            _lightCompShadowBufferDict[lightComponent] = buffer;
        }
    }
    return buffer;
}

- (void)removeShadowBufferForLight:(MGPLight *)light {
    if([_shadowBufferDict objectForKey: light]) {
        [_shadowBufferDict removeObjectForKey: light];
    }
}

@end
