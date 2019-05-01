//
//  GBuffer.metal
//  MetalDeferred
//
//  Created by 이현우 on 01/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include "SharedStructures.h"

using namespace metal;

// g-buffer fragment output data
typedef struct {
    half4 albedo    [[color(0)]];
    half4 normal    [[color(1)]];
    float4 pos      [[color(2)]];
    half4 shading   [[color(3)]];
} GBufferData;

typedef struct {
    float3 pos     [[attribute(0)]];
    float3 normal  [[attribute(1)]];
    float2 uv      [[attribute(2)]];
} GBufferVertex;

typedef struct {
    float4 clipPos      [[position]];
    float4 viewPos;
    float3 normal;
    float2 uv;
} GBufferFragment;

vertex GBufferFragment gbuffer_vert(GBufferVertex in [[stage_in]],
                                    constant camera_props_t &cameraProps [[buffer(0)]],
                                    device instance_props_t *instanceProps [[buffer(1)]],
                                    uint instanceId [[instance_id]]) {
    GBufferFragment out;
    float4 v = float4(in.pos, 1.0);
    float4x4 modelView = cameraProps.view * instanceProps[instanceId].model;
    out.viewPos = modelView * v;
    out.clipPos = cameraProps.projection * out.viewPos;
    out.normal = (modelView * float4(in.normal, 0.0)).xyz;
    out.uv = in.uv;
    return out;
}

fragment GBufferData gbuffer_frag(GBufferFragment in [[stage_in]],
                                  constant camera_props_t &cameraProps [[buffer(0)]],
                                  texture2d<half> albedoMap [[texture(0)]],
                                  texture2d<half> normalMap [[texture(1)]]
                                  ) {
    constexpr sampler linear(mip_filter::linear,
                             mag_filter::linear,
                             min_filter::linear);
    
    GBufferData out;
    out.albedo = albedoMap.sample(linear, in.uv);
    out.normal = half4(half3((in.normal + 1.0) * 0.5), 0.0);
    out.pos = in.viewPos;
    out.shading = half4(0,0,0,0);
    return out;
}
