//
//  MGPShadowBuffer.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 28/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
@import Metal;

NS_ASSUME_NONNULL_BEGIN

@class MGPLight;
@class MGPLightComponent;
@interface MGPShadowBuffer : NSObject

// properties
@property (nonatomic, readonly) MGPLight *light;
@property (nonatomic, readonly) MGPLightComponent *lightComponent;
@property (nonatomic, readonly) NSUInteger resolution;
@property (nonatomic, readonly) NSUInteger cascadeLevels;

// target texture
@property (nonatomic, readonly) id<MTLTexture> texture;

// render pass
@property (nonatomic, readonly) MTLRenderPassDescriptor *shadowPass;

- (instancetype)initWithDevice: (id<MTLDevice>)device
                         light: (MGPLight *)light
                    resolution: (NSUInteger)resolution
                 cascadeLevels: (NSUInteger)cascadeLevels;

- (instancetype)initWithDevice: (id<MTLDevice>)device
                lightComponent: (MGPLightComponent *)lightComponent
                    resolution: (NSUInteger)resolution
                 cascadeLevels: (NSUInteger)cascadeLevels;

@end

NS_ASSUME_NONNULL_END
