//
//  Shadow.metal
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 12/07/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include "SharedStructures.h"
#include "CommonVariables.h"

using namespace metal;

typedef struct {
    float3 pos     [[attribute(attrib_pos)]];
    float2 uv      [[attribute(attrib_uv)]];
    float3 normal  [[attribute(attrib_normal)]];
    float3 tangent [[attribute(attrib_tangent)]];
    float3 bitangent [[attribute(attrib_bitangent)]];
} ShadowVertex;

typedef struct {
    float4 clipPos      [[position]];
    float2 uv;
} ShadowFragment;

vertex ShadowFragment shadow_vert(ShadowVertex in [[stage_in]],
                                  constant light_t &light [[buffer(1)]],
                                  constant light_global_t &light_global [[buffer(2)]],
                                  constant instance_props_t *instanceProps [[buffer(3)]],
                                  uint iid [[instance_id]]) {
    ShadowFragment out;
    float4 v = float4(in.pos, 1.0);
    out.clipPos = light_global.light_projection * light.light_view * instanceProps[iid].model * v;
    out.uv = in.uv;
    return out;
}

// for Debug only
fragment half4 shadow_frag(ShadowFragment in [[stage_in]],
                           texture2d<half> albedo [[texture(0)]]) {
    return albedo.sample(linear, in.uv);
}
