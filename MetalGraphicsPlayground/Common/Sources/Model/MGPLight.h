//
//  MGPLight.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 23/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import "../../Shaders/SharedStructures.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, MGPLightType) {
    MGPLightTypeDirectional,
    MGPLightTypePoint
    // TODO: spot-light
};

@class MGPFrustum;
@interface MGPLight : NSObject <NSCopying>

@property (nonatomic, readonly) NSUInteger identifier;

@property (nonatomic) MGPLightType type;
@property (nonatomic) simd_float3 direction;
@property (nonatomic) simd_float3 position;
@property (nonatomic) simd_float3 color;
@property (nonatomic) float intensity;
@property (nonatomic) BOOL castShadows;
@property (nonatomic) float shadowBias;

@property (nonatomic) MGPFrustum *frustum;

- (light_t)shaderProperties;

@end

NS_ASSUME_NONNULL_END
