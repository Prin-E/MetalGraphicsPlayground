//
//  MGPCamera.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 22/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "../Model/MGPCamera.h"
#import "../Utility/MetalMath.h"

@implementation MGPCamera {
    MGPProjectionState _projectionState;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        _cameraMatrix = matrix_identity_float4x4;
        _rotationMatrix = matrix_identity_float4x4;
        _cameraInverseMatrix = matrix_identity_float4x4;
        _rotationInverseMatrix = matrix_identity_float4x4;
        _projectionMatrix = matrix_identity_float4x4;
    }
    return self;
}

- (MGPProjectionState)projectionState {
    return _projectionState;
}

- (void)setProjectionState:(MGPProjectionState)projectionState {
    _projectionState = projectionState;
    _projectionMatrix = matrix_from_perspective_fov_aspectLH(_projectionState.fieldOfView, _projectionState.aspectRatio, _projectionState.nearPlane, _projectionState.farPlane);
}

@end
