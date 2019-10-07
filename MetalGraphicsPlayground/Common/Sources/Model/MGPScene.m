//
//  MGPScene.m
//  MetalPostProcessing
//
//  Created by 이현우 on 03/07/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPScene.h"
#import "MGPSceneNode.h"
#import "../Utility/MetalMath.h"
#import <simd/simd.h>

@implementation MGPScene

- (instancetype)init {
    self = [super init];
    if(self) {
        [self _makeDefaultProperties];
    }
    return self;
}

- (void)_makeDefaultProperties {
    _lightGlobalProps.ambient_color = simd_make_float3(0.0, 0.0, 0.0);
    _lightGlobalProps.tile_size = 16;
    _lightGlobalProps.light_projection = matrix_from_perspective_fov_aspectLH(DEG_TO_RAD(60), 1.0, 0.25, 100);
    _rootNode = [[MGPSceneNode alloc] init];
}

@end
