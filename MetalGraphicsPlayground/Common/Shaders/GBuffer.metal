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

constant bool has_albedo_map [[function_constant(fcv_albedo)]];
constant bool has_normal_map [[function_constant(fcv_normal)]];
constant bool has_roughness_map [[function_constant(fcv_roughness)]];
constant bool has_metalic_map [[function_constant(fcv_metalic)]];

// g-buffer fragment output data
typedef struct {
    half4 albedo    [[color(0)]];
    half4 normal    [[color(1)]];
    float4 pos      [[color(2)]];
    half4 shading   [[color(3)]];
} GBufferData;

typedef struct {
    float3 pos     [[attribute(0)]];
    float2 uv      [[attribute(1)]];
    float3 normal  [[attribute(2)]];
    float3 tangent [[attribute(3)]];
} GBufferVertex;

typedef struct {
    float4 clipPos      [[position]];
    float4 viewPos;
    float2 uv;
    float3 normal;
    float3 tangent;
    float3 bitangent;
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
    out.tangent = (modelView * float4(in.tangent, 0.0)).xyz;
    out.bitangent = cross(out.tangent, out.normal);
    out.uv = in.uv;
    return out;
}

fragment GBufferData gbuffer_frag(GBufferFragment in [[stage_in]],
                                  constant camera_props_t &cameraProps [[buffer(0)]],
                                  texture2d<half> albedoMap [[texture(0), function_constant(has_albedo_map)]],
                                  texture2d<half> normalMap [[texture(1), function_constant(has_normal_map)]],
                                  texture2d<half> roughnessMap [[texture(2), function_constant(has_roughness_map)]],
                                  texture2d<half> metalicMap [[texture(3), function_constant(has_metalic_map)]]
                                  ) {
    constexpr sampler linear(mip_filter::linear,
                             mag_filter::linear,
                             min_filter::linear);
    
    GBufferData out;
    if(has_albedo_map) {
        out.albedo = albedoMap.sample(linear, in.uv);
    }
    else {
        out.albedo = half4(1.0);
    }
    if(has_normal_map) {
        half4 nc = normalMap.sample(linear, in.uv);
        nc = nc * 2.0 - 1.0;
        float3 n = in.normal * nc.z + in.tangent * nc.x + in.bitangent * nc.y;
        out.normal = half4(half3((n + 1.0) * 0.5), 0.0);
    }
    else {
        out.normal = half4(half3((in.normal + 1.0) * 0.5), 0.0);
    }
    out.pos = in.viewPos;
    out.shading = half4(0,0,0,0);
    if(has_roughness_map) {
        out.shading.x = roughnessMap.sample(linear, in.uv).r;
    }
    if(has_metalic_map) {
        out.shading.y = metalicMap.sample(linear, in.uv).r;
    }
    return out;
}
