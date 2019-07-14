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
#include "CommonStages.h"

using namespace metal;

// g-buffer prepass
constant bool has_albedo_map [[function_constant(fcv_albedo)]];
constant bool has_normal_map [[function_constant(fcv_normal)]];
constant bool has_roughness_map [[function_constant(fcv_roughness)]];
constant bool has_metalic_map [[function_constant(fcv_metalic)]];
constant bool has_occlusion_map [[function_constant(fcv_occlusion)]];
constant bool has_anisotropic_map [[function_constant(fcv_anisotropic)]];
constant bool flip_vertically [[function_constant(fcv_flip_vertically)]];

// g-buffer shade pass
constant bool uses_ibl_irradiance_map [[function_constant(fcv_uses_ibl_irradiance_map)]];
constant bool uses_ibl_specular_map [[function_constant(fcv_uses_ibl_specular_map)]];
constant bool uses_ssao_map [[function_constant(fcv_uses_ssao_map)]];

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
    half4 tangent   [[color(attachment_tangent)]];
} GBufferOutput;

// g-buffer
vertex GBufferFragment gbuffer_prepass_vert(GBufferVertex in [[stage_in]],
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

fragment GBufferOutput gbuffer_prepass_frag(GBufferFragment in [[stage_in]],
                                  constant camera_props_t &cameraProps [[buffer(1)]],
                                  constant instance_props_t *instanceProps [[buffer(2)]],
                                  texture2d<half> albedoMap [[texture(tex_albedo), function_constant(has_albedo_map)]],
                                  texture2d<half> normalMap [[texture(tex_normal), function_constant(has_normal_map)]],
                                    texture2d<float> roughnessMap [[texture(tex_roughness), function_constant(has_roughness_map)]],
                                    texture2d<half> metalicMap [[texture(tex_metalic), function_constant(has_metalic_map)]],
                                    texture2d<half> occlusionMap [[texture(tex_occlusion), function_constant(has_occlusion_map)]],
                                    texture2d<half> anisotropicMap [[texture(tex_anisotropic), function_constant(has_anisotropic_map)]]
                                  ) {
    GBufferOutput out;
    material_t material = instanceProps[in.iid].material;
    
    if(flip_vertically) {
        in.uv.y = 1.0 - in.uv.y;
    }
    
    if(has_albedo_map) {
        out.albedo = albedoMap.sample(linear, in.uv);
    }
    else {
        out.albedo = half4(half3(material.albedo), 1.0);
    }
    if(has_normal_map) {
        half4 nc = normalMap.sample(linear, in.uv);
        nc = nc * 2.0 - 1.0;
        float3 n = normalize(in.normal * nc.z + in.tangent * nc.x + in.bitangent * nc.y);
        out.normal = half4(half3((n + 1.0) * 0.5), 1.0);
    }
    else {
        out.normal = half4(half3((normalize(in.normal) + 1.0) * 0.5), 1.0);
    }
    if(has_anisotropic_map) {
        half4 tc = anisotropicMap.sample(linear, in.uv);
        tc = tc * 2.0 - 1.0;
        float3 t = normalize(float3(tc.xyz));
        out.tangent = half4(half3((t + 1.0) * 0.5), 1.0);
    }
    else {
        if(has_normal_map) {
            float3 n = normalize(float3(in.normal * 2.0 - 1.0));
            float3 b = cross(normalize(in.tangent), n);
            float3 t = cross(n, b);
            out.tangent = half4(half3((t + 1.0) * 0.5), 1.0);
        }
        else {
            out.tangent = half4(half3((normalize(in.tangent) + 1.0) * 0.5), 1.0);
        }
    }
    out.pos = in.worldPos;
    out.shading = half4(material.roughness, material.metalic, 1, material.anisotropy * 0.5 + 0.5);
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
vertex ScreenFragment gbuffer_light_vert(constant ScreenVertex *in [[buffer(0)]],
                                    uint vid [[vertex_id]]) {
    ScreenFragment out;
    out.clipPos = float4(in[vid].pos, 1.0);
    out.uv = (out.clipPos.xy + 1.0) * 0.5;
    out.uv.y = 1.0 - out.uv.y;
    return out;
}

// TODO : use argument buffer for optimizing resource-bindings
fragment half4 gbuffer_light_frag(ScreenFragment in [[stage_in]],
                                  constant light_t *lights [[buffer(1)]],
                                  constant light_global_t &light_global [[buffer(2)]],
                                  texture2d<half> normal [[texture(attachment_normal)]],
                                  texture2d<float> pos [[texture(attachment_pos)]],
                                  texture2d<half> shading [[texture(attachment_shading)]],
                                  texture2d<half> tangent [[texture(attachment_tangent)]],
                                  array<texture2d<float>,32> shadow_maps [[texture(11)]]) {
    float4 out_color = float4(0.0, 0.0, 0.0, 1.0);
    
    // shared values
    float4 n_c = float4(normal.sample(linear, in.uv));
    if(n_c.w == 0.0)
        return half4(0, 0, 0, 0);
    float3 n = normalize((n_c.xyz - 0.5) * 2.0);
    float4 t_c = float4(tangent.sample(linear, in.uv));
    float3 t = normalize((t_c.xyz - 0.5) * 2.0);
    float3 b = cross(t, n);
    half4 shading_values = shading.sample(linear, in.uv);
    
    shading_t shading_params;
    shading_params.albedo = float3(1);
    shading_params.roughness = shading_values.x;
    shading_params.metalic = shading_values.y;
    shading_params.anisotropy = shading_values.w * 2.0 - 1.0;
    
    // world-space pos
    float4 world_pos = pos.sample(linear_clamp_to_edge, in.uv);
    
    // calculate lights
    for(uint i = 0; i < light_global.num_light; i++) {
        bool lit = true;
        if(lights[i].cast_shadow) {
            float4 light_view_pos = lights[i].light_view * world_pos;
            float4 light_clip_pos = light_global.light_projection * light_view_pos;
            float2 light_screen_uv = (light_clip_pos.xy / max(0.001, light_clip_pos.w)) * 0.5 + 0.5;
            light_screen_uv.y = 1.0 - light_screen_uv.y;
            
            float depth_value = shadow_maps[i].sample(linear_clamp_to_edge, light_screen_uv).r;
            lit = depth_value < light_view_pos.z - lights[i].shadow_bias;
        }
        if(lit) {
            float3 light_dir = lights[i].light_view[2].xyz;
            float3 light_color = lights[i].color;
            float light_intensity = lights[i].intensity;
            float3 v = normalize(lights[i].light_view[3].xyz - world_pos.xyz);
            float3 h = normalize(light_dir + v);
            float h_v = max(0.001, saturate(dot(h, v)));
            float n_h = dot(n, h);
            float t_h = dot(t, h);
            float b_h = dot(b, h);
            float n_l = max(0.001, saturate(dot(n, light_dir)));
            float t_l = max(0.001, saturate(dot(t, light_dir)));
            float b_l = max(0.001, saturate(dot(b, light_dir)));
            float n_v = max(0.001, saturate(dot(n, v)));
            float t_v = max(0.001, saturate(dot(t, v)));
            float b_v = max(0.001, saturate(dot(b, v)));
            
            shading_params.light = light_color * light_intensity;
            shading_params.n_l = n_l;
            shading_params.n_h = n_h;
            shading_params.h_v = h_v;
            shading_params.t_h = t_h;
            shading_params.b_h = b_h;
            shading_params.t_l = t_l;
            shading_params.b_l = b_l;
            shading_params.n_v = n_v;
            shading_params.t_v = t_v;
            shading_params.b_v = b_v;
            
            out_color.xyz += calculate_brdf(shading_params) * shading_values.z;
        }
    }
    
    return half4(out_color);
}

// shading
vertex ScreenFragment gbuffer_shade_vert(constant ScreenVertex *in [[buffer(0)]],
                                    uint vid [[vertex_id]]) {
    ScreenFragment out;
    out.clipPos = float4(in[vid].pos, 1.0);
    out.uv = (out.clipPos.xy + 1.0) * 0.5;
    out.uv.y = 1.0 - out.uv.y;
    return out;
}

fragment half4 gbuffer_shade_frag(ScreenFragment in [[stage_in]],
                                  constant camera_props_t &cameraProps [[buffer(1)]],
                                  constant light_global_t &light_global [[buffer(2)]],
                                  texture2d<half> albedo [[texture(attachment_albedo)]],
                                  texture2d<half> normal [[texture(attachment_normal)]],
                                  texture2d<float> pos [[texture(attachment_pos)]],
                                  texture2d<half> shading [[texture(attachment_shading)]],
                                  texture2d<half> light [[texture(attachment_light)]],
                                  texturecube<half> irradiance [[texture(attachment_irradiance), function_constant(uses_ibl_irradiance_map)]],
                                  texturecube<half> prefilteredSpecular [[texture(attachment_prefiltered_specular), function_constant(uses_ibl_specular_map)]],
                                  texture2d<half> brdfLookup [[texture(attachment_brdf_lookup), function_constant(uses_ibl_specular_map)]],
                                  texture2d<half> ssao [[texture(attachment_ssao), function_constant(uses_ssao_map)]]) {
    float4 out_color = float4(0.0, 0.0, 0.0, 1.0);
    
    float4 n_c = float4(normal.sample(linear, in.uv));
    if(n_c.w == 0.0)
        return half4(0, 0, 0, 0);
    float3 n = normalize((n_c.xyz - 0.5) * 2.0);
    float3 v = normalize(cameraProps.position - pos.sample(linear, in.uv).xyz);
    float n_v = max(0.001, saturate(dot(n, v)));
    float3 albedo_color = float3(albedo.sample(linear, in.uv).xyz);
    half4 shading_props_color = shading.sample(linear, in.uv);
    half roughness = shading_props_color.x;
    half metalic = shading_props_color.y;
    half occlusion = shading_props_color.z;
    half4 light_color = light.sample(linear, in.uv);
    
    // SSAO
    half ao = 1.0;
    if(uses_ssao_map) {
        ao = 1.0 - ssao.sample(linear, in.uv).r;
    }
    
    // global ambient color
    out_color.xyz += ao * light_global.ambient_color * albedo_color * occlusion;
    
    // irradiance
    float3 k_s = float3(0);
    if(uses_ibl_irradiance_map) {
        float3 irradiance_color = float3(irradiance.sample(linear, n).xyz);
        k_s = fresnel(mix(0.04, albedo_color, metalic), n_v);
        float3 k_d = (float3(1.0) - k_s) * (1.0 - metalic);
        out_color.xyz += ao * k_d * irradiance_color * albedo_color * occlusion;
    }
    
    // prefiltered specular
    if(uses_ibl_specular_map) {
        float mip_index = roughness * prefilteredSpecular.get_num_mip_levels();
        float3 prefiltered_color = float3(prefilteredSpecular.sample(linear, n, level(mip_index)).xyz);
        float3 environment_brdf = float3(brdfLookup.sample(linear_clamp_to_edge, float2(roughness, n_v)).xyz);
        out_color.xyz += ao * k_s * prefiltered_color * (albedo_color * environment_brdf.x + environment_brdf.y);
    }
    
    // lit
    out_color.xyz += float3(light_color.xyz) * albedo_color;
    
    return half4(out_color);
}

/*
// shading
vertex ScreenFragment lighting_vert(constant ScreenVertex *in [[buffer(0)]],
                                      uint vid [[vertex_id]]) {
    LightingFragment out;
    out.clipPos = float4(in[vid].pos, 1.0);
    out.uv = (out.clipPos.xy + 1.0) * 0.5;
    out.uv.y = 1.0 - out.uv.y;
    return out;
}

fragment half4 lighting_frag(ScreenFragment in [[stage_in]],
                             constant camera_props_t &cameraProps [[buffer(1)]],
                             constant light_t *lightProps [[buffer(2)]],
                             constant light_global_t &lightGlobal [[buffer(3)]],
                             texture2d<half> albedo [[texture(attachment_albedo)]],
                             texture2d<half> normal [[texture(attachment_normal)]],
                             texture2d<float> pos [[texture(attachment_pos)]],
                             texture2d<half> shading [[texture(attachment_shading)]],
                             texture2d<half> tangent [[texture(attachment_tangent)]],
                             texturecube<half> irradiance [[texture(attachment_irradiance), function_constant(uses_ibl_irradiance_map)]],
                             texturecube<half> prefilteredSpecular [[texture(attachment_prefiltered_specular), function_constant(uses_ibl_specular_map)]],
                             texture2d<half> brdfLookup [[texture(attachment_brdf_lookup), function_constant(uses_ibl_specular_map)]],
                             texture2d<half> ssao [[texture(attachment_ssao), function_constant(uses_ssao_map)]]) {
    float3 out_color = float3(0);
    
    // shared values
    float4 n_c = float4(normal.sample(linear, in.uv));
    if(n_c.w == 0.0)
        return half4(0, 0, 0, 0);
    float3 n = normalize((n_c.xyz - 0.5) * 2.0);
    float4 t_c = float4(tangent.sample(linear, in.uv));
    float3 t = normalize((t_c.xyz - 0.5) * 2.0);
    float3 b = cross(t, n);
    float3 v = normalize(cameraProps.position - pos.sample(linear, in.uv).xyz);
    float3 albedo_c = float4(albedo.sample(linear, in.uv)).xyz;
    half4 shading_values = shading.sample(linear, in.uv);
    float n_v = max(0.001, saturate(dot(n, v)));
    float t_v = max(0.001, saturate(dot(t, v)));
    float b_v = max(0.001, saturate(dot(b, v)));
    half ao = 1.0;
    
    if(uses_ssao_map) {
        ao = 1.0 - ssao.sample(linear, in.uv).r;
    }
    
    // make shading parameters
    shading_t shading_params;
    shading_params.albedo = albedo_c;
    shading_params.roughness = shading_values.x;
    shading_params.metalic = shading_values.y;
    shading_params.anisotropy = shading_values.w * 2.0 - 1.0;
    shading_params.n_v = n_v;
    shading_params.t_v = t_v;
    shading_params.b_v = b_v;
    
    // global ambient color
    out_color += lightGlobal.ambient_color;
    
    // irradiance
    if(uses_ibl_irradiance_map) {
        float3 irradiance_color = float3(irradiance.sample(linear, n).xyz);
        float3 k_s = fresnel(mix(0.04, shading_params.albedo, shading_params.metalic), n_v);
        float3 k_d = (float3(1.0) - k_s) * (1.0 - shading_params.metalic);
        out_color += ao * k_d * irradiance_color * albedo_c * shading_values.z;
    }
    
    // prefiltered specular
    if(uses_ibl_specular_map) {
        float mip_index = shading_params.roughness * prefilteredSpecular.get_num_mip_levels();
        float3 prefiltered_color = float3(prefilteredSpecular.sample(linear, n, level(mip_index)).xyz);
        float3 environment_brdf = float3(brdfLookup.sample(linear_clamp_to_edge, float2(shading_params.roughness, n_v)).xyz);
        out_color += ao * k_s * prefiltered_color * (albedo_c * environment_brdf.x + environment_brdf.y);
    }
    
    // direct lights
    const uint num_light = lightGlobal.num_light;
    for(uint light_index = 0; light_index < num_light; light_index++) {
        light_t light = lightProps[light_index];
        float3 light_dir = normalize(light.direction);
        float3 light_color = light.color;
        float light_intensity = light.intensity;
        
        float3 h = normalize(light_dir + v);
        float h_v = max(0.001, saturate(dot(h, v)));
        float n_h = dot(n, h);
        float t_h = dot(t, h);
        float b_h = dot(b, h);
        float n_l = max(0.001, saturate(dot(n, light_dir)));
        float t_l = max(0.001, saturate(dot(t, light_dir)));
        float b_l = max(0.001, saturate(dot(b, light_dir)));
        
        shading_params.light = light_color * light_intensity;
        shading_params.n_l = n_l;
        shading_params.n_h = n_h;
        shading_params.h_v = h_v;
        shading_params.t_h = t_h;
        shading_params.b_h = b_h;
        shading_params.t_l = t_l;
        shading_params.b_l = b_l;
        
        out_color += calculate_brdf(shading_params) * shading_values.z;
    }
    
    return half4(half3(out_color), 1.0);
}
*/
