//
//  MGPLightComponent.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/10/07.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPLightComponent.h"
#import "MGPFrustum.h"
#import "MGPSceneNode.h"
#import "../Utility/MetalMath.h"

@implementation MGPLightComponent
- (instancetype)init {
    self = [super init];
    if(self) {
        _type = MGPLightTypeDirectional;
        _color = vector3(1.0f, 1.0f, 1.0f);
        _intensity = 1.0f;
        _castShadows = NO;
        _shadowNear = 1.0f;
        _shadowFar = 5000.0f;
        _radius = 10.0f;
        _frustum = [[MGPFrustum alloc] init];
    }
    return self;
}

- (light_t)shaderProperties {
    light_t light;
    
    simd_float4x4 localToWorld = self.localToWorldMatrix;
    
    vector_float3 forward = simd_normalize(localToWorld.columns[2].xyz);
    vector_float3 up = vector3(0.0f, 1.0f, 0.0f);
    if(ABS(simd_dot(forward, up)) > 0.999)
        up = vector3(0.0f, 0.0f, -1.0f);
    vector_float3 right = simd_cross(up, forward);
    up = simd_cross(forward, right);
    
    simd_float3 worldPos = localToWorld.columns[3].xyz;
    light.light_view = matrix_lookat(worldPos, worldPos + forward, up);
    light.position = worldPos;
    light.intensity = _intensity;
    light.color = _color;
    light.cast_shadow = _castShadows;
    light.shadow_bias = _shadowBias;
    light.type = (uint8_t)_type;
    light.radius = _radius;
    return light;
}

- (MGPFrustum *)frustum {
    light_t lightProps = self.shaderProperties;
    MGPProjectionState proj = self.projectionState;
    [_frustum setPlanesWithProjectionState:proj
                                    matrix:lightProps.light_view];
    return _frustum;
}

- (MGPProjectionState)projectionState {
    MGPProjectionState proj = {
        .aspectRatio = 1.0f
    };
    if(_type == MGPLightTypeDirectional) {
        proj.fieldOfView = DEG_TO_RAD(60.0f);
        proj.nearPlane = _shadowNear;
        proj.farPlane = _shadowFar;
    }
    else {
        proj.orthographicRate = 1.0f;
        proj.orthographicSize = _radius;
        proj.nearPlane = -_radius;
        proj.farPlane = _radius;
    }
    return proj;
}

@end
