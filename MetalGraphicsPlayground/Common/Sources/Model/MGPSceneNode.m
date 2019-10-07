//
//  MGPSceneNode.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/09/01.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPSceneNode.h"
#import "../Utility/MetalMath.h"
#import "MGPSceneNodeComponent.h"

@implementation MGPSceneNode {
    NSMutableArray<MGPSceneNode *> *_children;
    NSMutableArray<MGPSceneNodeComponent *> *_components;
    simd_float4x4 _localToParentRotationMatrix, _parentToLocalRotationMatrix;
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
        _localToWorldRotationMatrix = matrix_identity_float4x4;
        _worldToLocalRotationMatrix = matrix_identity_float4x4;
        _scale = simd_make_float3(1, 1, 1);
    }
    return self;
}

#pragma mark - Matrix, Transform
- (void)setLocalToParentMatrix:(matrix_float4x4)localToParentMatrix {
    _localToParentMatrix = localToParentMatrix;
    _parentToLocalMatrix = simd_inverse(localToParentMatrix);
    [self _decomposeMatrixToTRS];
}

- (void)setParentToLocalMatrix:(matrix_float4x4)parentToLocalMatrix {
    _parentToLocalMatrix = parentToLocalMatrix;
    _localToParentMatrix = simd_inverse(parentToLocalMatrix);
    [self _decomposeMatrixToTRS];
}

- (simd_float3)position {
    return _position;
}

- (void)setPosition:(simd_float3)position {
    _localToParentMatrix.columns[3].xyz = position;
    _parentToLocalMatrix.columns[3].xyz = simd_make_float3(0);
    _parentToLocalMatrix.columns[3].xyz = -simd_mul(_parentToLocalMatrix, simd_make_float4(position, 1.0)).xyz;
    [self _calculateLocalWorldMatrices];
}

- (simd_float3)rotation {
    return _rotation;
}

- (void)setRotation:(simd_float3)rotation {
    _rotation = rotation;
    [self _generateMatrices];
}

- (simd_float3)scale {
    return _scale;
}

- (void)setScale:(simd_float3)scale {
    _scale = scale;
    [self _generateMatrices];
}

#pragma mark - Managing relations
- (void)addChild:(MGPSceneNode *)node {
    if(node == self || node == nil || [_children indexOfObject: node] != NSNotFound)
        return;
    [_children addObject: node];
}

- (void)removeChild:(MGPSceneNode *)node {
    if(node != nil)
        [_children removeObject: node];
}

#pragma mark - Components
- (void)addComponent: (MGPSceneNodeComponent *)component {
    if(component.node == nil) {
        [_components addObject: component];
        component.node = self;
    }
    else {
        @throw [NSException exceptionWithName:@"MGPSceneNodeErrorDomain"
                                       reason:@"Component is already attached to another node!"
                                     userInfo:@{}];
    }
}

- (MGPSceneNodeComponent *)componentAtIndex: (NSUInteger)index {
    return [_components objectAtIndex:index];
}

- (MGPSceneNodeComponent *)componentOfType: (Class)theClass {
    for(MGPSceneNodeComponent *elem in _components) {
        if(elem.class == theClass)
            return elem;
    }
    return nil;
}

- (void)removeComponentAtIndex: (NSUInteger)index {
    [_components removeObjectAtIndex:index];
}

- (void)removeAllComponents {
    [_components removeAllObjects];
}

- (void)removeComponentOfType: (Class)theClass {
    for(NSUInteger i = 0; i < _components.count; i++) {
        MGPSceneNodeComponent *comp = [_components objectAtIndex:i];
        if(comp.class == theClass)
            [_components removeObjectAtIndex:i--];
    }
}

#pragma mark - Matrix operations
- (void)_generateMatrices {
    // get rotation matrix
    simd_float4x4 localToParentMatrix = matrix_from_euler(_rotation);
    simd_float4x4 parentToLocalMatrix = simd_transpose(localToParentMatrix);
    _localToParentRotationMatrix = localToParentMatrix;
    _parentToLocalRotationMatrix = parentToLocalMatrix;
    
    // apply scales
    simd_float3 scaleDiv1 = 1.0 / _scale;
    localToParentMatrix.columns[0].x *= _scale.x;
    localToParentMatrix.columns[1].y *= _scale.y;
    localToParentMatrix.columns[2].z *= _scale.z;
    parentToLocalMatrix.columns[0].x *= scaleDiv1.x;
    parentToLocalMatrix.columns[1].y *= scaleDiv1.y;
    parentToLocalMatrix.columns[2].z *= scaleDiv1.z;
    
    // apply positions
    localToParentMatrix.columns[3].xyz = _position;
    parentToLocalMatrix.columns[3].xyz = simd_make_float3(0);
    parentToLocalMatrix.columns[3].xyz = -simd_mul(parentToLocalMatrix, simd_make_float4(_position, 1.0)).xyz;
    
    // replace current matrices
    _localToParentMatrix = localToParentMatrix;
    _parentToLocalMatrix = parentToLocalMatrix;
    
    [self _calculateLocalWorldMatrices];
}

- (void)_calculateLocalWorldMatrices {
    if(_parent) {
        _localToWorldMatrix = simd_mul(_parent.localToWorldMatrix, _localToParentMatrix);
        _worldToLocalMatrix = simd_mul(_parent.worldToLocalMatrix, _parentToLocalMatrix);
        _localToWorldRotationMatrix = simd_mul(_parent.localToWorldRotationMatrix, _localToParentRotationMatrix);
        _worldToLocalRotationMatrix = simd_mul(_parent.worldToLocalRotationMatrix, _parentToLocalRotationMatrix);
    }
    else {
        _localToWorldMatrix = _localToParentMatrix;
        _worldToLocalMatrix = _parentToLocalMatrix;
        _localToWorldRotationMatrix = _localToParentRotationMatrix;
        _worldToLocalRotationMatrix = _parentToLocalRotationMatrix;
    }
    
    if(_children.count > 0) {
        for(MGPSceneNode *child in _children) {
            [child _calculateLocalWorldMatrices];
        }
    }
}

- (void)_decomposeMatrixToTRS {
    matrix_decompose_trs(_localToParentMatrix, &_position, &_rotation, &_scale);
}

@end
