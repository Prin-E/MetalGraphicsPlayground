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
        _normal = normal;
    }
    return self;
}

+ (instancetype)planeWithCenter: (simd_float3)center
                         normal: (simd_float3)normal {
    MGPPlane *plane = [[self.class alloc] initWithCenter: center
                                                  normal: normal];
    return plane;
}

@end
