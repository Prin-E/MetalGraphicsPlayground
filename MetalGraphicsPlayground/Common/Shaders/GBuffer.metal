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
#include "CommonVariables.h"

using namespace metal;

constant bool has_albedo_map [[function_constant(fcv_albedo)]];
constant bool has_normal_map [[function_constant(fcv_normal)]];
constant bool has_roughness_map [[function_constant(fcv_roughness)]];
constant bool has_metalic_map [[function_constant(fcv_metalic)]];
constant bool has_occlusion_map [[function_constant(fcv_occlusion)]];

// g-buffer vertex input data
typedef struct {
    float3 pos     [[attribute(attrib_pos)]];
    float2 uv      [[attribute(attrib_uv)]];
    float3 normal  [[attribute(attrib_normal)]];
    float3 tangent [[attribute(attrib_tangent)]];
    float3 bitangent [[attribute(attrib_bitangent)]];
} GBufferVertex;

// g-buffer fragment input data
typedef struct {
    float4 clipPos      [[position]];
    float4 worldPos;
    float2 uv;
    float3 normal;
    float3 tangent;
    float3 bitangent;
    uint iid;
} GBufferFragment;

// g-buffer fragment output data
typedef struct {
    half4 albedo    [[color(attachment_albedo)]];
    half4 normal    [[color(attachment_normal)]];
    float4 pos      [[color(attachment_pos)]];
    half4 shading   [[color(attachment_shading)]];
} GBufferOutput;

// lighting vertex input data
typedef struct {
    float3 pos;
} LightingVertex;

// lighting fragment input data
typedef struct {
    float4 clipPos      [[position]];
    float2 uv;
} LightingFragment;

// present vertex input data
typedef struct {
    float3 pos;
} PresentVertex;

typedef struct {
    float4 clipPos      [[position]];
    float2 uv;
} PresentFragment;

// g-buffer
vertex GBufferFragment gbuffer_vert(GBufferVertex in [[stage_in]],
                                    constant camera_props_t &cameraProps [[buffer(1)]],
                                    constant instance_props_t *instanceProps [[buffer(2)]],
                                    uint iid [[instance_id]]) {
    GBufferFragment out;
    float4 v = float4(in.pos, 1.0);
    float4x4 model = instanceProps[iid].model;
    out.worldPos = model * v;
    out.clipPos = cameraProps.viewProjection * out.worldPos;
    out.normal = (model * float4(in.normal, 0.0)).xyz;
    out.tangent = (model * float4(in.tangent, 0.0)).xyz;
    out.bitangent = (model * float4(in.bitangent, 0.0)).xyz;
    out.uv = in.uv;
    out.iid = iid;
    return out;
}

fragment GBufferOutput gbuffer_frag(GBufferFragment in [[stage_in]],
                                  constant camera_props_t &cameraProps [[buffer(1)]],
                                  constant instance_props_t *instanceProps [[buffer(2)]],
                                  texture2d<half> albedoMap [[texture(tex_albedo), function_constant(has_albedo_map)]],
                                  texture2d<half> normalMap [[texture(tex_normal), function_constant(has_normal_map)]],
                                    texture2d<float> roughnessMap [[texture(tex_roughness), function_constant(has_roughness_map)]],
                                    texture2d<half> metalicMap [[texture(tex_metalic), function_constant(has_metalic_map)]],
                                    texture2d<half> occlusionMap [[texture(tex_occlusion), function_constant(has_occlusion_map)]]
                                  ) {
    GBufferOutput out;
    material_t material = instanceProps[in.iid].material;
    
    if(has_albedo_map) {
        out.albedo = albedoMap.sample(linear, in.uv);
    }
    else {
        out.albedo = half4(half3(material.albedo), 1.0);
    }
    if(has_normal_map) {
        half4 nc = normalMap.sample(nearest, in.uv);
        nc = nc * 2.0 - 1.0;
        float3 n = normalize(in.normal * nc.z + in.tangent * nc.x + in.bitangent * nc.y);
        out.normal = half4(half3((n + 1.0) * 0.5), 1.0);
    }
    else {
        out.normal = half4(half3((normalize(in.normal) + 1.0) * 0.5), 1.0);
    }
    out.pos = in.worldPos;
    out.shading = half4(material.roughness, material.metalic, 1, 0);
    if(has_roughness_map) {
        out.shading.x = roughnessMap.sample(linear, in.uv).r;
    }
    if(has_metalic_map) {
        out.shading.y = metalicMap.sample(linear, in.uv).r;
    }
    if(has_occlusion_map) {
        out.shading.z = occlusionMap.sample(linear, in.uv).r;
    }
    return out;
}

// lighting
vertex LightingFragment lighting_vert(constant LightingVertex *in [[buffer(0)]],
                                      uint vid [[vertex_id]]) {
    LightingFragment out;
    out.clipPos = float4(in[vid].pos, 1.0);
    out.uv = (out.clipPos.xy + 1.0) * 0.5;
    out.uv.y = 1.0 - out.uv.y;
    return out;
}

fragment half4 lighting_frag(LightingFragment in [[stage_in]],
                             constant camera_props_t &cameraProps [[buffer(1)]],
                             constant light_t *lightProps [[buffer(2)]],
                             constant light_global_t &lightGlobal [[buffer(3)]],
                             texture2d<half> albedo [[texture(attachment_albedo)]],
                             texture2d<half> normal [[texture(attachment_normal)]],
                             texture2d<float> pos [[texture(attachment_pos)]],
                             texture2d<half> shading [[texture(attachment_shading)]],
                             texturecube<half> irradiance [[texture(attachment_irradiance)]],
                             texturecube<half> prefilteredSpecular [[texture(attachment_prefiltered_specular)]],
                             texture2d<half> brdfLookup [[texture(attachment_brdf_lookup)]]) {
    float3 out_color = float3(0);
    
    // shared values
    float4 n_c = float4(normal.sample(linear, in.uv));
    if(n_c.w == 0.0)
        return half4(0, 0, 0, 0);
    float3 n = (n_c.xyz - 0.5) * 2.0 * n_c.w;
    float3 v = normalize(cameraProps.position - pos.sample(linear, in.uv).xyz);
    float3 albedo_c = float4(albedo.sample(linear, in.uv)).xyz;
    half4 shading_values = shading.sample(linear, in.uv);
    float n_v = max(0.001, saturate(dot(n, v)));
    
    // make shading parameters
    shading_t shading_params;
    shading_params.albedo = albedo_c;
    shading_params.roughness = shading_values.x;
    shading_params.metalic = shading_values.y;
    shading_params.n_v = n_v;
    
    // irradiance
    float3 irradiance_color = float3(irradiance.sample(linear, n).xyz);
    float3 k_s = fresnel(mix(0.04, shading_params.albedo, shading_params.metalic), n_v);
    float3 k_d = (float3(1.0) - k_s) * (1.0 - shading_params.metalic);
    out_color += k_d * irradiance_color * albedo_c * shading_values.z;
    
    // prefiltered specular
    float mip_index = shading_params.roughness * prefilteredSpecular.get_num_mip_levels();
    float3 prefiltered_color = float3(prefilteredSpecular.sample(linear, n, level(mip_index)).xyz);
    float3 environment_brdf = float3(brdfLookup.sample(linear_clamp_to_edge, float2(shading_params.roughness, n_v)).xyz);
    out_color += k_s * prefiltered_color * (albedo_c * environment_brdf.x + environment_brdf.y);
    
    // direct lights
    const uint num_light = lightGlobal.num_light;
    for(uint light_index = 0; light_index < num_light; light_index++) {
        light_t light = lightProps[light_index];
        float3 light_dir = normalize(light.direction);
        float3 light_color = light.color;
        float light_intensity = light.intensity;
        
        float3 h = normalize(light_dir + v);
        float n_l = max(0.001, saturate(dot(n, light_dir)));
        float n_h = max(0.001, saturate(dot(n, h)));
        float h_v = max(0.001, saturate(dot(h, v)));
        
        shading_params.light = light_color * light_intensity;
        shading_params.n_l = n_l;
        shading_params.n_h = n_h;
        shading_params.h_v = h_v;
        
        out_color += calculate_brdf(shading_params) * shading_values.z;
    }
    
    return half4(half3(out_color), 1.0);
}
