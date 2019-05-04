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
    half4 albedo    [[color(attachment_albedo)]];
    half4 normal    [[color(attachment_normal)]];
    float4 pos      [[color(attachment_pos)]];
    half4 shading   [[color(attachment_shading)]];
} GBufferData;

typedef struct {
    float3 pos     [[attribute(attrib_pos)]];
    float2 uv      [[attribute(attrib_uv)]];
    float3 normal  [[attribute(attrib_normal)]];
    float3 tangent [[attribute(attrib_tangent)]];
} GBufferVertex;

typedef struct {
    float4 clipPos      [[position]];
    float4 viewPos;
    float2 uv;
    float3 normal;
    float3 tangent;
    float3 bitangent;
} GBufferFragment;

typedef struct {
    float3 pos  [[attribute(attrib_pos)]];
    float2 uv   [[attribute(attrib_uv)]];
} LightingVertex;

typedef struct {
    float4 clipPos      [[position]];
    float2 uv;
} LightingFragment;

vertex GBufferFragment gbuffer_vert(GBufferVertex in [[stage_in]],
                                    constant camera_props_t &cameraProps [[buffer(1)]],
                                    device instance_props_t *instanceProps [[buffer(2)]],
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
                                  constant camera_props_t &cameraProps [[buffer(1)]],
                                  device instance_props_t *instanceProps [[buffer(2)]],
                                  texture2d<half> albedoMap [[texture(tex_albedo), function_constant(has_albedo_map)]],
                                  texture2d<half> normalMap [[texture(tex_normal), function_constant(has_normal_map)]],
                                  texture2d<half> roughnessMap [[texture(tex_roughness), function_constant(has_roughness_map)]],
                                  texture2d<half> metalicMap [[texture(tex_metalic), function_constant(has_metalic_map)]]
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

vertex LightingFragment lighting_vert(LightingVertex in [[stage_in]]) {
    LightingFragment out;
    out.clipPos = float4(in.pos, 1.0);
    out.uv = in.uv;
    return out;
}

fragment half4 lighting_frag(LightingFragment in [[stage_in]],
                             texture2d<half> albedo [[texture(attachment_albedo)]],
                             texture2d<half> normal [[texture(attachment_normal)]],
                             texture2d<float> pos [[texture(attachment_pos)]],
                             texture2d<half> shading [[texture(attachment_shading)]]) {
    constexpr sampler linear(mip_filter::linear,
                             mag_filter::linear,
                             min_filter::linear);
    
    return albedo.sample(linear, in.uv);
}