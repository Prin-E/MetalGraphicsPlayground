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
    _rootNode = [[MGPSceneNode alloc] init];
}

@end
