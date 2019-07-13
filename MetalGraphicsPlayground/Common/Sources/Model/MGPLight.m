//
//  MGPLight.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 23/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPLight.h"

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

    light.light_view = simd_matrix(simd_make_float4(right),
                                   simd_make_float4(up),
                                   simd_make_float4(forward),
                                   vector4(-_position.x, -_position.y, -_position.z, 1.0f));
    light.intensity = _intensity;
    light.color = _color;
    light.cast_shadow = _castShadows;
    return light;
}

@end
