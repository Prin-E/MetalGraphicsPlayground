//
//  MGPFrustum.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/08/13.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPFrustum.h"
#import "MGPCamera.h"
#import "MGPPlane.h"
#import "MGPLight.h"

@implementation MGPFrustum

- (instancetype)init {
    self = [super init];
    if(self) {
        [self _makePlanes];
    }
    return self;
}

- (instancetype)initWithCamera:(MGPCamera *)camera {
    self = [super init];
    if(self) {
        [self _makePlanes];
        [self setPlanesForCamera: camera];
    }
    return self;
}

- (void)_makePlanes {
    // make 6 planes!
    MGPPlane *nearPlane = [[MGPPlane alloc] init];
    MGPPlane *farPlane = [[MGPPlane alloc] init];
    MGPPlane *leftPlane = [[MGPPlane alloc] init];
    MGPPlane *rightPlane = [[MGPPlane alloc] init];
    MGPPlane *bottomPlane = [[MGPPlane alloc] init];
    MGPPlane *topPlane = [[MGPPlane alloc] init];
    _planes = @[ nearPlane, farPlane, leftPlane, rightPlane, bottomPlane, topPlane ];
}

- (void)setPlanesForCamera:(MGPCamera *)camera {
    [self setPlanesWithProjectionState:camera.projectionState
                               matrix:camera.cameraToWorldMatrix];
}

- (void)setPlanesWithProjectionState:(MGPProjectionState)proj
                              matrix:(simd_float4x4)matrix {
    simd_float3 position = matrix.columns[3].xyz;
    
    // basis vectors and related constants
    simd_float3 right = matrix.columns[0].xyz;
    simd_float3 up = matrix.columns[1].xyz;
    simd_float3 forward = matrix.columns[2].xyz;
    float centerZ = (proj.nearPlane + proj.farPlane) * 0.5f;
    float tanHalfFov = proj.orthographicSize * 0.5f * proj.orthographicRate + tanf(proj.fieldOfView * 0.5f) * (1.0f - proj.orthographicRate);
    float tanHalfFovAspectRatio = tanHalfFov * proj.aspectRatio;
    
    // apply center, normal of planes
    MGPPlane *nearPlane = _planes[0];
    MGPPlane *farPlane = _planes[1];
    MGPPlane *leftPlane = _planes[2];
    MGPPlane *rightPlane = _planes[3];
    MGPPlane *bottomPlane = _planes[4];
    MGPPlane *topPlane = _planes[5];
    nearPlane.center = position + forward * proj.nearPlane;
    nearPlane.normal = forward;
    farPlane.center = position + forward * proj.farPlane;
    farPlane.normal = -forward;
    leftPlane.center = position + centerZ * (forward - right * tanHalfFovAspectRatio);
    leftPlane.normal = simd_cross(up, simd_normalize(forward - right * tanHalfFovAspectRatio));
    rightPlane.center = position + centerZ * (forward + right * tanHalfFovAspectRatio);
    rightPlane.normal = simd_cross(simd_normalize(forward + right * tanHalfFovAspectRatio), up);
    bottomPlane.center = position + centerZ * (forward - tanHalfFov * up);
    bottomPlane.normal = simd_cross(simd_normalize(forward - tanHalfFov * up), right);
    topPlane.center = position + centerZ * (forward + tanHalfFov * up);
    topPlane.normal = simd_cross(right, simd_normalize(forward + tanHalfFov * up));
}

- (void)setPlanesForLight:(MGPLight *)light {
    light_t shaderProps = light.shaderProperties;
    MGPProjectionState proj = light.projectionState;
    [self setPlanesWithProjectionState:proj
                               matrix:simd_inverse(shaderProps.light_view)];
}

- (void)multiplyMatrix:(simd_float4x4)matrix {
    for(MGPPlane *plane in _planes) {
        [plane multiplyMatrix:matrix];
    }
}

- (MGPFrustum *)frustumByMultipliedWithMatrix:(simd_float4x4)matrix {
    MGPFrustum *newFrustum = [[MGPFrustum alloc] init];
    [newFrustum _makePlanes];
    for(NSUInteger i = 0; i < _planes.count; i++) {
        newFrustum->_planes[i].normal = _planes[i].normal;
        newFrustum->_planes[i].center = _planes[i].center;
    }
    [newFrustum multiplyMatrix:matrix];
    return newFrustum;
}

@end
