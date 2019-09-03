//
//  MGPLight.m
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 23/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPLight.h"
#import "MGPFrustum.h"
#import "../Utility/MetalMath.h"

static NSUInteger _MGPLightCounter = 0;

@implementation MGPLight {
    NSUInteger _id;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        @synchronized (self) {
            _identifier = ++_MGPLightCounter;
        }
        _type = MGPLightTypeDirectional;
        _direction = vector3(0.0f, 0.0f, 1.0f);
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

- (instancetype)initNonVariableInitialized {
    return [super init];
}

- (NSUInteger)hash {
    return _identifier;
}

- (BOOL)isEqual:(id)object {
    if(![object isKindOfClass: MGPLight.class]) return NO;
    MGPLight *other = object;
    return _identifier == other->_identifier;
}

- (id)copyWithZone:(NSZone *)zone {
    MGPLight* clone = [[[self class] alloc] initNonVariableInitialized];
    if(clone) {
        clone->_identifier = _identifier;
        clone.type = _type;
        clone.direction = _direction;
        clone.position = _position;
        clone.intensity = _intensity;
        clone.color = _color;
        clone.castShadows = _castShadows;
    }
    return clone;
}

- (light_t)shaderProperties {
    light_t light;
    
    vector_float3 forward = _direction;
    vector_float3 up = vector3(0.0f, 1.0f, 0.0f);
    if(ABS(simd_dot(forward, up)) < 0.01f)
        up = vector3(0.0f, 0.0f, -1.0f);
    vector_float3 right = simd_cross(up, forward);
    up = simd_cross(forward, right);
    
    light.light_view = matrix_lookat(_position, _position + _direction, up);
    light.intensity = _intensity;
    light.color = _color;
    light.cast_shadow = _castShadows;
    light.shadow_bias = _shadowBias;
    return light;
}

- (MGPFrustum *)frustum {
    [_frustum setPlanesForLight:self];
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
