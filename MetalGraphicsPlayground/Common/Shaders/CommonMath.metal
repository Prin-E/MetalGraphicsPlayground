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

float3 view_pos_from_depth(constant float4x4 &invProjection, uint2 coords, uint2 size, float depth) {
    float2 uv = float2(coords) / float2(size);
    uv.y = 1.0 - uv.y;
    float4 ndc = float4(uv * 2.0 - 1.0, depth, 1.0);
    float4 vp = invProjection * ndc;
    vp.xyz /= vp.w;
    return vp.xyz;
}

float3 view_pos_from_depth(constant matrix_float4x4 &invProjection, float2 uv, float depth) {
    uv.y = 1.0 - uv.y;
    float4 ndc = float4(uv * 2.0 - 1.0, depth, 1.0);
    float4 vp = invProjection * ndc;
    vp.xyz /= vp.w;
    return vp.xyz;
}
