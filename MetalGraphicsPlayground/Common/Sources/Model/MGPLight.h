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

@interface MGPLight : NSObject <NSCopying>

@property (nonatomic) MGPLightType type;
@property (nonatomic) simd_float3 direction;
@property (nonatomic) simd_float3 position;
@property (nonatomic) simd_float3 color;
@property (nonatomic) float intensity;
@property (nonatomic) BOOL hasShadow;

- (light_t)shaderLightProperties;

@end

NS_ASSUME_NONNULL_END
