//
//  MGPSceneNode.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/09/01.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPSceneNode.h"

@implementation MGPSceneNode {
    NSMutableArray<MGPSceneNode *> *_children;
    matrix_float4x4 _localToParentMatrix, _parentToLocalMatrix;
    simd_float3 _position, _rotation, _scale;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        _children = [NSMutableArray new];
        _localToParentMatrix = matrix_identity_float4x4;
        _parentToLocalMatrix = matrix_identity_float4x4;
        _localToWorldMatrix = matrix_identity_float4x4;
        _worldToLocalMatrix = matrix_identity_float4x4;
    }
    return self;
}

- (simd_float3)position {
    return _position;
}

- (void)setPosition:(simd_float3)position {
    _localToParentMatrix.columns[3].xyz = position;
    _parentToLocalMatrix.columns[3].xyz = -position;
}

- (simd_float3)rotation {
    return _rotation;
}

- (simd_float3)scale {
    return _scale;
}

- (void)setScale:(simd_float3)scale {
    _scale = scale;
}

- (void)addChild:(MGPSceneNode *)node {
    if(node == self || node == nil || [_children objectAtIndex: node] != NSNotFound)
        return;
    [_children addObject: node];
}

- (void)removeChild:(MGPSceneNode *)node {
    if(node != nil)
        [_children removeObject: node];
}


@end
