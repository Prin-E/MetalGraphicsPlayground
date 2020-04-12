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

@synthesize scene = _scene;

- (instancetype)init {
    self = [super init];
    if(self) {
        _children = [NSMutableArray new];
        _components = [NSMutableArray new];
        _localToParentMatrix = matrix_identity_float4x4;
        _parentToLocalMatrix = matrix_identity_float4x4;
        _localToParentRotationMatrix = matrix_identity_float4x4;
        _parentToLocalRotationMatrix = matrix_identity_float4x4;
        _localToWorldMatrix = matrix_identity_float4x4;
        _worldToLocalMatrix = matrix_identity_float4x4;
        _localToWorldRotationMatrix = matrix_identity_float4x4;
        _worldToLocalRotationMatrix = matrix_identity_float4x4;
        _scale = simd_make_float3(1, 1, 1);
        _enabled = YES;
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
    _position = position;
    _localToParentMatrix.columns[3].xyz = position;
    _parentToLocalMatrix.columns[3].xyz = -simd_mul(_parentToLocalRotationMatrix,
                                                    simd_make_float4(position, 1.0)).xyz;
    [self _calculateLocalWorldMatrices];
}

- (simd_float3)rotation {
    return _rotation;
}

- (void)setRotation:(simd_float3)rotation {
    _rotation = rotation;
    [self _calculateMatrices];
}

- (simd_float3)scale {
    return _scale;
}

- (void)setScale:(simd_float3)scale {
    _scale = scale;
    [self _calculateMatrices];
}

- (void)lookAt:(simd_float3)target {
    [self lookAt:target up:simd_make_float3(0, 1, 0)];
}

- (void)lookAt:(simd_float3)target
            up:(simd_float3)up {
    simd_float3 worldPos = _localToWorldMatrix.columns[3].xyz;
    simd_float3 forward = target - worldPos;
    if(simd_length_squared(forward) > 1e-8f) {
        forward = simd_normalize(forward);
        up = simd_normalize(up);
        simd_float3 right = simd_normalize(simd_cross(up, forward));
        up = simd_normalize(simd_cross(forward, right));
        
        _localToParentRotationMatrix.columns[0] = simd_make_float4(right, 0);
        _localToParentRotationMatrix.columns[1] = simd_make_float4(up, 0);
        _localToParentRotationMatrix.columns[2] = simd_make_float4(forward, 0);
        _localToParentRotationMatrix.columns[3] = simd_make_float4(0, 0, 0, 1);
        _parentToLocalRotationMatrix = simd_transpose(_localToParentRotationMatrix);
        
        matrix_decompose_trs(_localToParentRotationMatrix, nil, &_rotation, nil);
        
        [self _applyTSWithRotationMatrix];
        [self _calculateLocalWorldMatrices];
    }
}

#pragma mark - Managing relations
- (void)addChild:(MGPSceneNode *)node {
    if(node == nil || node == self || [_children indexOfObject: node] != NSNotFound || node.parent != nil) {
        return;
    }
    [_children addObject: node];
    [node setParent:self];
    [node _calculateLocalWorldMatrices];
}

- (void)removeChild:(MGPSceneNode *)node {
    if(node != nil && node.parent == self) {
        [_children removeObject: node];
        [node setParent:nil];
        [node _calculateLocalWorldMatrices];
    }
}

- (void)setParent:(MGPSceneNode * _Nullable)node {
    _parent = node;
}

- (MGPScene * _Nullable)scene {
    MGPSceneNode *node = self;
    MGPScene * _Nullable scene = _scene;
    while(node && !scene) {
        node = node.parent;
        scene = node.scene;
    }
    return scene;
}

- (void)setScene:(MGPScene * _Nullable)scene {
    _scene = scene;
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
- (void)_calculateMatrices {
    // get rotation matrix
    _localToParentRotationMatrix = matrix_from_euler(_rotation);
    _parentToLocalRotationMatrix = simd_transpose(_localToParentRotationMatrix);
    
    [self _applyTSWithRotationMatrix];
    [self _calculateLocalWorldMatrices];
}

- (void)_applyTSWithRotationMatrix {
    simd_float4x4 localToParentMatrix = _localToParentRotationMatrix;
    simd_float4x4 parentToLocalMatrix = _parentToLocalRotationMatrix;
    
    // apply positions
    localToParentMatrix.columns[3].xyz = _position;
    parentToLocalMatrix.columns[3].xyz = -simd_mul(_parentToLocalRotationMatrix, simd_make_float4(_position, 1.0)).xyz;
    
    // apply scales
    simd_float3 scaleDiv1 = 1.0 / _scale;
    localToParentMatrix.columns[0].xyz *= _scale.x;
    localToParentMatrix.columns[1].xyz *= _scale.y;
    localToParentMatrix.columns[2].xyz *= _scale.z;
    parentToLocalMatrix.columns[0].xyz *= scaleDiv1.x;
    parentToLocalMatrix.columns[1].xyz *= scaleDiv1.y;
    parentToLocalMatrix.columns[2].xyz *= scaleDiv1.z;
    
    // replace current matrices
    _localToParentMatrix = localToParentMatrix;
    _parentToLocalMatrix = parentToLocalMatrix;
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
