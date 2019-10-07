//
//  MGPCameraComponent.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/10/07.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPCameraComponent.h"
#import "../Utility/MetalMath.h"
#import "MGPFrustum.h"
#import "MGPSceneNode.h"

@implementation MGPCameraComponent {
    MGPProjectionState _projectionState;
    MGPFrustum *_frustum;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        _projectionMatrix = matrix_identity_float4x4;
        _projectionInverseMatrix = matrix_identity_float4x4;
        
        _fStop = 1.4f;
        _shutterSpeed = 1.0f / 60.0f;
        _ISO = 100;
        
        _frustum = [[MGPFrustum alloc] init];
    }
    return self;
}

- (MGPProjectionState)projectionState {
    @synchronized (self) {
        return _projectionState;
    }
}

- (void)setProjectionState:(MGPProjectionState)projectionState {
    @synchronized (self) {
        _projectionState = projectionState;
        float lerp = simd_clamp(_projectionState.orthographicRate, 0.0f, 1.0f);
        matrix_float4x4 orthographicMatrix = matrix_identity_float4x4;
        matrix_float4x4 perspectiveMatrix = matrix_identity_float4x4;
        if(lerp < 1.0f) {
            perspectiveMatrix = matrix_from_perspective_fov_aspectLH(_projectionState.fieldOfView, _projectionState.aspectRatio, _projectionState.nearPlane, _projectionState.farPlane);
        }
        if(lerp > 0.0f) {
            float heightHalf = _projectionState.orthographicSize;
            float widthHalf = heightHalf * _projectionState.aspectRatio;
            orthographicMatrix = matrix_ortho(-widthHalf, widthHalf,
                                              -heightHalf, heightHalf,
                                              _projectionState.nearPlane, _projectionState.farPlane);
        }
        
        for(int i = 0; i < 4; i++) {
            _projectionMatrix.columns[i] = perspectiveMatrix.columns[i] * (1.0f - lerp) +
                                           orthographicMatrix.columns[i] * lerp;
        }
        _projectionInverseMatrix = simd_inverse(_projectionMatrix);
        [_frustum setPlanesWithProjectionState:_projectionState
                                        matrix:self.node.localToWorldMatrix];
    }
}

- (camera_props_t)shaderProperties {
    simd_float4x4 cameraToWorldMatrix = self.localToWorldMatrix;
    simd_float4x4 worldToCameraMatrix = self.worldToLocalMatrix;
    
    @synchronized (self) {
        camera_props_t props = {};
        props.position = self.position;
        props.rotation = self.worldToLocalRotationMatrix;
        props.view = worldToCameraMatrix;
        props.projection = _projectionMatrix;
        props.viewProjection = simd_mul(_projectionMatrix, worldToCameraMatrix);
        props.viewInverse = cameraToWorldMatrix;
        props.projectionInverse = _projectionInverseMatrix;
        props.viewProjectionInverse = simd_mul(cameraToWorldMatrix, _projectionInverseMatrix);
        props.nearPlane = _projectionState.nearPlane;
        props.farPlane = _projectionState.farPlane;
        return props;
    }
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
