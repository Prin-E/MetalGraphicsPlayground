//
//  MGPBoundingVolume.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/08/14.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPBoundingVolume.h"
#import "MGPPlane.h"
#import "MGPFrustum.h"

@implementation MGPBoundingBox

@synthesize position = _position;

- (BOOL)isCulledInFrustum:(MGPFrustum *)frustum {
    BOOL isCulled = NO;
    simd_float3 abs_extent = simd_abs(_extent);
    NSArray<MGPPlane*> *planes = frustum.planes;
    for(MGPPlane *plane in planes) {
        float distance = [plane distanceToPosition: _position];
        float radius = simd_dot(simd_abs(plane.normal), abs_extent);
        if(distance < -radius) {
            isCulled = YES;
            break;
        }
    }
    return isCulled;
}

@end

@implementation MGPBoundingSphere

@synthesize position = _position;

- (BOOL)isCulledInFrustum:(MGPFrustum *)frustum {
    BOOL isCulled = NO;
    NSArray<MGPPlane*> *planes = frustum.planes;
    for(MGPPlane *plane in planes) {
        float distance = [plane distanceToPosition: _position];
        if(distance < -_radius) {
            isCulled = YES;
            break;
        }
    }
    return isCulled;
}

@end
