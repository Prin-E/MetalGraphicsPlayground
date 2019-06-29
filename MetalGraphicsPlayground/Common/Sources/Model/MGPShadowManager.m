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

NSString * const MGPShadowManagerErrorDoamin = @"MGPShadowManagerError";

@implementation MGPShadowManager {
    NSMutableDictionary<MGPLight*, MGPShadowBuffer*> *_shadowBufferDict;
    MGPCamera *_camera;
    id<MTLRenderPipelineState> _shadowPipeline;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                       library:(id<MTLLibrary>)library {
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
        _shadowBufferDict = [NSMutableDictionary dictionaryWithCapacity: 8];
    }
    return self;
}

- (MGPShadowBuffer *)newShadowBufferForLight:(MGPLight *)light
                                  resolution:(NSUInteger)resolution
                               cascadeLevels:(NSUInteger)cascadeLevels {
    if(![_shadowBufferDict objectForKey: light]) {
        MGPShadowBuffer *buffer = [[MGPShadowBuffer alloc] initWithDevice: _device
                                                                    light: light
                                                               resolution: resolution
                                                            cascadeLevels: cascadeLevels];
        _shadowBufferDict[light] = buffer;
    }
    return [_shadowBufferDict objectForKey: light];
}

- (void)render:(id<MTLCommandBuffer>)buffer {
    // TODO
}

@end
