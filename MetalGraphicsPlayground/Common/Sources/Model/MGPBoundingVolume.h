//
//  MGPBoundingVolume.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/08/14.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

@class MGPFrustum;

@protocol MGPBoundingVolume <NSObject>

@property simd_float3 position;

- (BOOL)isCulledInFrustum:(MGPFrustum *)frustum;

@end

@interface MGPBoundingBox : NSObject <MGPBoundingVolume>

@property simd_float3 extent;
@property simd_float3x3 rotation;

@end

@interface MGPBoundingSphere : NSObject <MGPBoundingVolume>

@property float radius;

@end

NS_ASSUME_NONNULL_END
