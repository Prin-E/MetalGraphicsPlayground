//
//  CommonMath.metal
//  MetalDeferred
//
//  Created by 이현우 on 11/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include "CommonMath.h"
#include "CommonVariables.h"
#include <metal_stdlib>
using namespace metal;

float2 hammersley(uint i, uint N)
{
    // 2.3283064365386963e-10 = 0.5 / 0x10000000
    float ri = reverse_bits(i) * 2.3283064365386963e-10;
    return float2(float(i) / float(N), ri);
}

float2 sample_spherical(float3 dir) {
    float pi = asin(dir.y);
    float theta = atan2(dir.z,dir.x);
    
    float2 uv;
    uv.x = theta * PI_DIV * 0.5;
    uv.y = -pi * PI_DIV;
    uv += 0.5;
    
    return uv;
}
