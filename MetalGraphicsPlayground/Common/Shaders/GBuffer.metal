//
//  GBuffer.metal
//  MetalDeferred
//
//  Created by 이현우 on 01/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include "SharedStructures.h"
#include "BRDF.h"

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
    uint iid;
} GBufferFragment;

typedef struct {
    float3 pos;
} LightingVertex;

typedef struct {
    float4 clipPos      [[position]];
    float2 uv;
} LightingFragment;

vertex GBufferFragment gbuffer_vert(GBufferVertex in [[stage_in]],
                                    constant camera_props_t &cameraProps [[buffer(1)]],
                                    constant instance_props_t *instanceProps [[buffer(2)]],
                                    uint iid [[instance_id]]) {
    GBufferFragment out;
    float4 v = float4(in.pos, 1.0);
    float4x4 modelView = cameraProps.view * instanceProps[iid].model;
    out.viewPos = modelView * v;
    out.clipPos = cameraProps.projection * out.viewPos;
    out.normal = (modelView * float4(in.normal, 0.0)).xyz;
    out.tangent = (modelView * float4(in.tangent, 0.0)).xyz;
    out.bitangent = cross(out.tangent, out.normal);
    out.uv = in.uv;
    out.iid = iid;
    return out;
}

fragment GBufferData gbuffer_frag(GBufferFragment in [[stage_in]],
                                  constant camera_props_t &cameraProps [[buffer(1)]],
                                  constant instance_props_t *instanceProps [[buffer(2)]],
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
        float3 n = normalize(in.normal) * nc.z + normalize(in.tangent) * nc.x + normalize(in.bitangent) * nc.y;
        out.normal = half4(half3((normalize(n) + 1.0) * 0.5), 1.0);
    }
    else {
        out.normal = half4(half3((normalize(in.normal) + 1.0) * 0.5), 1.0);
    }
    out.pos = in.viewPos;
    out.shading = half4(instanceProps[in.iid].material.roughness,instanceProps[in.iid].material.metalic,0,0);
    if(has_roughness_map) {
        out.shading.x = roughnessMap.sample(linear, in.uv).r;
    }
    if(has_metalic_map) {
        out.shading.y = metalicMap.sample(linear, in.uv).r;
    }
    return out;
}

vertex LightingFragment lighting_vert(constant LightingVertex *in [[buffer(0)]],
                                      uint vid [[vertex_id]]) {
    LightingFragment out;
    out.clipPos = float4(in[vid].pos, 1.0);
    out.uv = (out.clipPos.xy + 1.0) * 0.5;
    out.uv.y = 1.0 - out.uv.y;
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
    
    // TODO
    float3 light_dir = normalize(float3(1.0, 1.0, -1.0));
    float3 light_color = float3(0.24, 0.48, 1.0);
    float light_intensity = 20;
    
    float4 n_c = float4(normal.sample(linear, in.uv));
    if(n_c.w == 0.0)
        return half4(0, 0, 0, 1);
    float3 n = (n_c.xyz - 0.5) * 2.0 * n_c.w;
    float3 v = -normalize(pos.sample(linear, in.uv).xyz);
    float n_l = max(0.001, saturate(dot(n, light_dir)));
    float n_v = max(0.001, saturate(dot(n, v)));
    float n_h = max(0.001, saturate(dot(n, normalize(light_dir + v))));
    half4 shading_values = shading.sample(linear, in.uv);
    
    shading_t shading_params;
    shading_params.albedo = float4(albedo.sample(linear, in.uv)).xyz;
    shading_params.light = light_color * light_intensity;
    shading_params.roughness = shading_values.x;
    shading_params.metalic = shading_values.y;
    shading_params.n_l = n_l;
    shading_params.n_v = n_h;
    shading_params.n_h = n_v;
    
    float3 out_color = calculate_brdf(shading_params);
    return half4(half3(out_color), 1.0);
}
