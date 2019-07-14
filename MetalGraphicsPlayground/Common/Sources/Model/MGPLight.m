//
//  MGPLight.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 23/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPLight.h"
#import "../Utility/MetalMath.h"

@implementation MGPLight

- (id)copyWithZone:(NSZone *)zone {
    MGPLight* clone = [[[self class] alloc] init];
    if(clone) {
        clone.type = _type;
        clone.direction = _direction;
        clone.position = _position;
        clone.intensity = _intensity;
        clone.color = _color;
        clone.castShadows = _castShadows;
    }
    return clone;
}

- (light_t)shaderLightProperties {
    light_t light;
    
    vector_float3 forward = _direction;
    vector_float3 up = vector3(0.0f, 1.0f, 0.0f);
    if(ABS(simd_dot(forward, up)) < 0.01f)
        up = vector3(0.0f, 0.0f, -1.0f);
    vector_float3 right = simd_cross(up, forward);
    up = simd_cross(forward, right);
    
    light.light_view = matrix_lookat(_position + forward, _position, up);
    light.intensity = _intensity;
    light.color = _color;
    light.cast_shadow = _castShadows;
    light.shadow_bias = _shadowBias;
    return light;
}

@end
