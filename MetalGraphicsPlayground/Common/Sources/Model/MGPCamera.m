//
//  MGPCamera.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 22/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "../Model/MGPCamera.h"
#import "../Utility/MetalMath.h"
#import "MGPFrustum.h"

@implementation MGPCamera {
    MGPProjectionState _projectionState;
    MGPFrustum *_frustum;
}

@synthesize position = _position;
@synthesize rotation = _rotation;

- (instancetype)init {
    self = [super init];
    if(self) {
        _worldToCameraMatrix = matrix_identity_float4x4;
        _worldToCameraRotationMatrix = matrix_identity_float4x4;
        _cameraToWorldMatrix = matrix_identity_float4x4;
        _cameraToWorldRotationMatrix = matrix_identity_float4x4;
        _projectionMatrix = matrix_identity_float4x4;
        
        _fStop = 1.4f;
        _shutterSpeed = 1.0f / 60.0f;
        _ISO = 100;
        
        _frustum = [[MGPFrustum alloc] initWithCamera: self];
    }
    return self;
}

- (MGPProjectionState)projectionState {
    return _projectionState;
}

- (void)setProjectionState:(MGPProjectionState)projectionState {
    @synchronized (self) {
        _projectionState = projectionState;
        _projectionMatrix = matrix_from_perspective_fov_aspectLH(_projectionState.fieldOfView, _projectionState.aspectRatio, _projectionState.nearPlane, _projectionState.farPlane);
        [_frustum setPlanesForCamera: self];
    }
}

- (simd_float3)position {
    return _position;
}

- (void)setPosition:(simd_float3)position {
    @synchronized (self) {
        _position = position;
        _worldToCameraMatrix.columns[3].xyz = -simd_mul(_worldToCameraRotationMatrix,
                                                        simd_make_float4(_position, 1)).xyz;
        _cameraToWorldMatrix.columns[3].xyz = _position;
        [_frustum setPlanesForCamera: self];
    }
}

- (simd_float3)rotation {
    return _rotation;
}

- (void)setRotation:(simd_float3)rotation {
    @synchronized (self) {
        _rotation = rotation;
        _worldToCameraRotationMatrix = simd_mul(matrix_from_rotation(-_rotation.x, 1, 0, 0),
                                                simd_mul(matrix_from_rotation(-_rotation.y, 0, 1, 0),
                                                         matrix_from_rotation(-_rotation.z, 0, 0, 1)));
        _cameraToWorldRotationMatrix = simd_transpose(_worldToCameraRotationMatrix);
        for(int i = 0; i < 3; i++) {
            _worldToCameraMatrix.columns[i].xyz = _worldToCameraRotationMatrix.columns[i].xyz;
            _cameraToWorldMatrix.columns[i].xyz = _cameraToWorldRotationMatrix.columns[i].xyz;
        }
        _worldToCameraMatrix.columns[3].xyz = -simd_mul(_worldToCameraRotationMatrix,
                                                        simd_make_float4(_position, 1)).xyz;
        [_frustum setPlanesForCamera: self];
    }
}

- (simd_float3)right {
    return _cameraToWorldRotationMatrix.columns[0].xyz;
}

- (simd_float3)up {
    return _cameraToWorldRotationMatrix.columns[1].xyz;
}

- (simd_float3)forward {
    return _cameraToWorldRotationMatrix.columns[2].xyz;
}

- (camera_props_t)shaderProperties {
    camera_props_t props = {};
    props.position = _position;
    props.rotation = _worldToCameraRotationMatrix;
    props.view = _worldToCameraMatrix;
    props.projection = _projectionMatrix;
    props.viewProjection = simd_mul(_projectionMatrix, _worldToCameraMatrix);
    return props;
}

- (float)exposureValue {
    float ev = log2(_fStop * _fStop / _shutterSpeed);
    if(_ISO != 100) {
        float ec = log2(_ISO);
        ev -= ec;
    }
    return ev;
}

@end
