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

@implementation MGPFrustum

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
    MGPProjectionState proj = camera.projectionState;
    simd_float3 cameraPos = camera.position;
    simd_float4x4 cameraMatrix = camera.worldToCameraMatrix;
    
    // basis vectors and related constants
    simd_float3 right = cameraMatrix.columns[0].xyz;
    simd_float3 forward = cameraMatrix.columns[1].xyz;
    simd_float3 up = cameraMatrix.columns[2].xyz;
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
    nearPlane.center = cameraPos + forward * proj.nearPlane;
    nearPlane.normal = forward;
    farPlane.center = cameraPos + forward * proj.farPlane;
    farPlane.normal = -forward;
    leftPlane.center = cameraPos - right * tanHalfFovAspectRatio;
    leftPlane.normal = simd_cross(up, simd_normalize(-right * tanHalfFovAspectRatio));
    rightPlane.center = cameraPos + right * tanHalfFovAspectRatio;
    rightPlane.normal = simd_cross(simd_normalize(right * tanHalfFovAspectRatio), up);
    bottomPlane.center = cameraPos + centerZ * forward - tanHalfFov * up;
    bottomPlane.normal = simd_cross(simd_normalize(centerZ * forward - tanHalfFov * up), right);
    topPlane.center = cameraPos + centerZ * forward + tanHalfFov * up;
    topPlane.normal = simd_cross(right, simd_normalize(centerZ * forward + tanHalfFov * up));
}

@end
