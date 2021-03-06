//
//  MGPLight.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 23/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import "MGPProjectionState.h"
#import "MGPLightType.h"
#import "../../Shaders/SharedStructures.h"

NS_ASSUME_NONNULL_BEGIN

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

// point-light properties
@property (nonatomic) float radius;

// directional and spot-light properties
@property (nonatomic) float shadowNear, shadowFar;

@property (nonatomic) MGPFrustum *frustum;

- (light_t)shaderProperties;
- (MGPProjectionState)projectionState;

@end

NS_ASSUME_NONNULL_END
