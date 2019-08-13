//
//  MGPPlane.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/08/13.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPPlane.h"

@implementation MGPPlane

- (instancetype)initWithCenter:(simd_float3)center normal:(simd_float3)normal {
    self = [super init];
    if(self) {
        _center = center;
        _normal = simd_normalize(normal);
    }
    return self;
}

+ (instancetype)planeWithCenter: (simd_float3)center
                         normal: (simd_float3)normal {
    MGPPlane *plane = [[self.class alloc] initWithCenter: center
                                                  normal: normal];
    return plane;
}

- (simd_float4)equation {
    return simd_make_float4(_normal.x, _normal.y, _normal.z, -simd_dot(_normal, _center));
}

- (float)distanceToPosition:(simd_float3)position {
    float distance = simd_dot(_normal, position - _center);
    return distance;
}

@end
