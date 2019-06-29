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
        clone.hasShadow = _hasShadow;
    }
    return clone;
}

- (light_t)shaderLightProperties {
    light_t light;
    light.direction = _direction;
    light.position = _position;
    light.intensity = _intensity;
    light.color = _color;
    return light;
}

@end
