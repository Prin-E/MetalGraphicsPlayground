//
//  BRDF.metal
//  MetalDeferred
//
//  Created by 이현우 on 06/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

inline float sqr(float f0) {
    return f0 * f0;
}

inline float fresnel(float f0, float dotProduct) {
    return f0 + (1.0 - f0) * pow(dotProduct, 5.0f);
}

