//
//  Skybox.metal
//  MetalDeferred
//
//  Created by 이현우 on 09/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include "SharedStructures.h"

using namespace metal;

constant constexpr float PI = 3.14159265;
constant constexpr float PI_DIV = 1.0 / PI;

typedef struct {
    float3 pos;
} SkyboxVertex;

typedef struct {
    float4 clipPos      [[position]];
    float3 pos;
} SkyboxFragment;

constexpr sampler linear(mip_filter::linear,
                         mag_filter::linear,
                         min_filter::linear,
                         coord::normalized,
                         address::repeat);

// Skybox
vertex SkyboxFragment skybox_vert(constant SkyboxVertex *in [[buffer(0)]],
                                  constant camera_props_t &cameraProps [[buffer(1)]],
                                  uint vid [[vertex_id]]) {
    SkyboxFragment out;
    float3 pos = in[vid].pos;
    out.pos = pos;
    out.clipPos = cameraProps.projection * cameraProps.rotation * float4(pos * 50.0, 1.0);
    return out;
}

fragment half4 skybox_frag(SkyboxFragment in [[stage_in]],
                           texture2d<half> equirectangularMap [[texture(0)]]) {
    float3 dir = normalize(in.pos);
    float pi = acos(dir.y);
    float theta = atan2(dir.z,abs(dir.x));
    
    float2 uv;
    uv.x = 0.75 + -theta * PI_DIV * 0.5;
    if(in.pos.x < 0.0)
        uv.x = (0.5 - uv.x) - 0.5;
    uv.y = pi * PI_DIV;
    half4 out_color = equirectangularMap.sample(linear, uv);
    out_color.a = 0;
    //return half4(half2(uv), 0.0, 1.0);
    return out_color;
}
