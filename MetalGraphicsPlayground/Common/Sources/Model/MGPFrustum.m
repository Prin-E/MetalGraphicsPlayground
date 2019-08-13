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
        [self _makePlanesWithCamera: camera];
    }
    return self;
}

- (void)_makePlanesWithCamera: (MGPCamera *)camera {
    MGPProjectionState proj = camera.projectionState;
    simd_float3 cameraPos = camera.position;
    simd_float4x4 cameraMatrix = camera.cameraMatrix;
    
    // TODO: implement orthographic view frustum
    
    // basis vectors and related constants
    simd_float3 right = cameraMatrix.columns[0].xyz;
    simd_float3 forward = cameraMatrix.columns[1].xyz;
    simd_float3 up = cameraMatrix.columns[2].xyz;
    float centerZ = (proj.nearPlane + proj.farPlane) * 0.5f;
    float tanHalfFov = tanf(proj.fieldOfView * 0.5f);
    float tanHalfFovAspectRatio = tanHalfFov * proj.aspectRatio;
    
    // make 6 planes!
    MGPPlane *nearPlane = [MGPPlane planeWithCenter: cameraPos + forward * proj.nearPlane
                                        normal: forward];
    MGPPlane *farPlane = [MGPPlane planeWithCenter: cameraPos + forward * proj.farPlane
                                       normal: -forward];
    MGPPlane *leftPlane = [MGPPlane planeWithCenter: cameraPos - right * tanHalfFovAspectRatio
                                             normal: simd_cross(up, simd_normalize(-right * tanHalfFovAspectRatio))];
    MGPPlane *rightPlane = [MGPPlane planeWithCenter: cameraPos + right * tanHalfFovAspectRatio
                                         normal: simd_cross(simd_normalize(right * tanHalfFovAspectRatio), up)];
    MGPPlane *bottomPlane = [MGPPlane planeWithCenter: cameraPos + centerZ * forward - tanHalfFov * up
                                               normal: simd_cross(simd_normalize(centerZ * forward - tanHalfFov * up), right)];
    MGPPlane *topPlane = [MGPPlane planeWithCenter: cameraPos + centerZ * forward + tanHalfFov * up
                                            normal: simd_cross(right, simd_normalize(centerZ * forward + tanHalfFov * up))];
    _planes = @[ nearPlane, farPlane, leftPlane, rightPlane, bottomPlane, topPlane ];
}

@end
