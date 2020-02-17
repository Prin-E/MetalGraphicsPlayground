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
#include "CommonMath.h"
#include "ColorSpace.h"
#include "Shadow.h"
#include "Lighting.h"

using namespace metal;

// g-buffer prepass
constant bool has_albedo_map [[function_constant(fcv_albedo)]];
constant bool has_normal_map [[function_constant(fcv_normal)]];
constant bool has_roughness_map [[function_constant(fcv_roughness)]];
constant bool has_metalic_map [[function_constant(fcv_metalic)]];
constant bool has_occlusion_map [[function_constant(fcv_occlusion)]];
constant bool has_anisotropic_map [[function_constant(fcv_anisotropic)]];
constant bool flip_vertically [[function_constant(fcv_flip_vertically)]];
constant bool srgb_texture [[function_constant(fcv_srgb_texture)]];

// g-buffer shade pass
constant bool uses_ibl_irradiance_map [[function_constant(fcv_uses_ibl_irradiance_map)]];
constant bool uses_ibl_specular_map [[function_constant(fcv_uses_ibl_specular_map)]];
constant bool uses_ssao_map [[function_constant(fcv_uses_ssao_map)]];

// shared
constant bool uses_anisotropic_map = uses_anisotropy && has_anisotropic_map;

// g-buffer vertex input data
typedef struct {
    float3 pos     [[attribute(attrib_pos)]];
    float2 uv      [[attribute(attrib_uv)]];
    float3 normal  [[attribute(attrib_normal)]];
    float3 tangent [[attribute(attrib_tangent)]];
} GBufferVertex;

// g-buffer fragment input data
typedef struct {
    float4 clip_pos     [[position]];
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
    half4 shading   [[color(attachment_shading)]];
    half4 tangent   [[color(attachment_tangent), function_constant(uses_anisotropy)]];
} GBufferOutput;

#pragma mark - Prepass
vertex GBufferFragment gbuffer_prepass_vert(GBufferVertex in [[stage_in]],
                                    constant camera_props_t &cameraProps [[buffer(1)]],
                                    constant instance_props_t *instanceProps [[buffer(2)]],
                                    uint iid [[instance_id]]) {
    GBufferFragment out;
    float4 v = float4(in.pos, 1.0);
    float4x4 modelview = cameraProps.view * instanceProps[iid].model;
    out.clip_pos = cameraProps.projection * modelview * v;
    out.normal = (modelview * float4(in.normal, 0.0)).xyz;
    out.tangent = (modelview * float4(in.tangent, 0.0)).xyz;
    out.bitangent = cross(out.tangent, out.normal);
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
                                  texture2d<half> anisotropicMap [[texture(tex_anisotropic), function_constant(uses_anisotropic_map)]]
                                  ) {
    GBufferOutput out;
    material_t material = instanceProps[in.iid].material;
    
    if(flip_vertically) {
        in.uv.y = 1.0 - in.uv.y;
    }
    
    if(has_albedo_map) {
        out.albedo = albedoMap.sample(linear_clamp_to_edge, in.uv);
        if(srgb_texture) {
            out.albedo = srgb_to_linear_fast(out.albedo);
        }
        // NOTE: g-buffer doesn't support alpha blending...
        //       so that I added simple alpha testing.
        // TODO: alpha-blending support
        if(out.albedo.a < 0.05)
            discard_fragment();
    }
    else {
        out.albedo = half4(half3(material.albedo), 1.0);
    }
    
    float3 n = in.normal;
    float3 t = in.tangent;
    float3 b = in.bitangent;
    if(has_normal_map) {
        half4 nc = normalMap.sample(linear_clamp_to_edge, in.uv);
        nc = nc * 2.0 - 1.0;
        n = normalize(normalize(n) * nc.z + normalize(t) * nc.x + normalize(b) * nc.y);
    }
    else {
        n = normalize(n);
    }
    out.normal = half4(half3((n + 1.0) * 0.5), 1.0);
    
    if(uses_anisotropic_map) {
        half4 tc = anisotropicMap.sample(linear_clamp_to_edge, in.uv);
        tc = tc * 2.0 - 1.0;
        t = normalize(float3(tc.xyz));
    }
    else {
        if(has_normal_map) {
            t = cross(n, normalize(b));
        }
        else {
            t = normalize(t);
        }
    }
    
    if(uses_anisotropy)
        out.tangent = half4(half3((t + 1.0) * 0.5), 1.0);
    
    out.shading = half4(material.roughness, material.metalic, 1, material.anisotropy * 0.5 + 0.5);
    if(has_roughness_map) {
        out.shading.x = roughnessMap.sample(linear_clamp_to_edge, in.uv).r;
    }
    if(has_metalic_map) {
        out.shading.y = metalicMap.sample(linear, in.uv).r;
    }
    if(has_occlusion_map) {
        out.shading.z = occlusionMap.sample(linear, in.uv).r;
    }
    return out;
}

#pragma mark - Indirect Lighting
fragment half4 gbuffer_indirect_light_frag(ScreenFragment in [[stage_in]],
                                           constant camera_props_t &camera_props [[buffer(0)]],
                                           constant light_global_t &light_global [[buffer(1)]],
                                           texture2d<half> albedo [[texture(attachment_albedo)]],
                                           texture2d<half> normal [[texture(attachment_normal)]],
                                           texture2d<half> shading [[texture(attachment_shading)]],
                                           texture2d<half> tangent [[texture(attachment_tangent), function_constant(uses_anisotropy)]],
                                           depth2d<float> depth [[texture(attachment_depth)]],
                                           texturecube<half> irradiance [[texture(attachment_irradiance), function_constant(uses_ibl_irradiance_map)]],
                                           texturecube<half> prefilteredSpecular [[texture(attachment_prefiltered_specular), function_constant(uses_ibl_specular_map)]],
                                           texture2d<half> brdfLookup [[texture(attachment_brdf_lookup), function_constant(uses_ibl_specular_map)]],
                                           texture2d<half> ssao [[texture(attachment_ssao), function_constant(uses_ssao_map)]]) {
    float4 out_color = float4(0.0, 0.0, 0.0, 0.0);
    
    float4 n_c = float4(normal.sample(linear_clamp_to_edge, in.uv));
    if(n_c.w == 0.0)
        return half4(0, 0, 0, 0);
    float3 n = normalize((n_c.xyz - 0.5) * 2.0);
    float3 view_pos = view_pos_from_depth(camera_props.projectionInverse, in.uv, depth.sample(nearest_clamp_to_edge, in.uv));
    float3 v = normalize(-view_pos);
    float n_v = max(0.001, saturate(dot(n, v)));
    
    float3 albedo_color = float3(albedo.sample(linear_clamp_to_edge, in.uv).xyz);
    half4 shading_props_color = shading.sample(linear_clamp_to_edge, in.uv);
    half roughness = shading_props_color.x;
    half metalic = shading_props_color.y;
    half occlusion = shading_props_color.z;
    
    // reflection (world-space)
    float3 r = n;
    if(uses_anisotropy && (uses_ibl_irradiance_map || uses_ibl_specular_map)) {
        half anisotropy = shading_props_color.w * 2.0 - 1.0;
        float4 t_c = float4(tangent.sample(linear_clamp_to_edge, in.uv));
        float3 t = normalize((t_c.xyz - 0.5) * 2.0);
        r = get_reflected_vector(n, t, v, roughness, anisotropy);
    }
    float3 w_r = (camera_props.viewInverse * float4(r, 0.0)).xyz;
    
    // SSAO
    half ao = 1.0;
    if(uses_ssao_map) {
        ao = 1.0 - ssao.sample(linear_clamp_to_edge, in.uv).r;
    }
    
    // global ambient color
    out_color.xyz += ao * light_global.ambient_color * albedo_color * occlusion;
    
    // irradiance
    float3 k_s = float3(0);
    if(uses_ibl_irradiance_map) {
        float3 irradiance_color = float3(irradiance.sample(linear, w_r).xyz);
        k_s = fresnel(mix(0.04, albedo_color, metalic), n_v);
        float3 k_d = (float3(1.0) - k_s) * (1.0 - metalic);
        out_color.xyz += ao * k_d * irradiance_color * albedo_color * occlusion;
    }
    
    // prefiltered specular
    if(uses_ibl_specular_map) {
        float mip_index = roughness * prefilteredSpecular.get_num_mip_levels();
        float3 prefiltered_color = float3(prefilteredSpecular.sample(linear, w_r, level(mip_index)).xyz);
        float3 environment_brdf = float3(brdfLookup.sample(linear_clamp_to_edge, float2(roughness, n_v)).xyz);
        out_color.xyz += ao * k_s * prefiltered_color * (albedo_color * environment_brdf.x + environment_brdf.y) * occlusion;
    }
    
    return half4(out_color);
}

#pragma mark - Direct Lighting
fragment half4 gbuffer_directional_shadowed_light_frag(ScreenFragment in [[stage_in]],
                                                       constant camera_props_t &camera_props [[buffer(0)]],
                                                       constant light_global_t &light_global [[buffer(1)]],
                                                       constant light_t &light [[buffer(2)]],
                                                       texture2d<half> albedo [[texture(attachment_albedo)]],
                                                       texture2d<half> normal [[texture(attachment_normal)]],
                                                       texture2d<half> shading [[texture(attachment_shading)]],
                                                       texture2d<half> tangent [[texture(attachment_tangent), function_constant(uses_anisotropy)]],
                                                       depth2d<float> depth [[texture(attachment_depth)]],
                                                       depth2d<float> shadow_map [[texture(attachment_shadow_map)]]) {
    float4 out_color = float4(0.0, 0.0, 0.0, 0.0);
    
    float4 n_c = float4(normal.sample(linear_clamp_to_edge, in.uv));
    if(n_c.w == 0.0)
        return half4(0, 0, 0, 0);
    float3 n = normalize((n_c.xyz - 0.5) * 2.0);
    float3 t = float3(1.0, 0.0, 0.0);
    
    if(uses_anisotropy) {
        float4 t_c = float4(tangent.sample(linear_clamp_to_edge, in.uv));
        t = normalize((t_c.xyz - 0.5) * 2.0);
    }
    
    float3 view_pos = view_pos_from_depth(camera_props.projectionInverse, in.uv, depth.sample(nearest_clamp_to_edge, in.uv));
    float3 albedo_color = float3(albedo.sample(linear, in.uv).xyz);
    half4 shading_props_color = shading.sample(linear, in.uv);
    
    out_color.xyz += calculate_directional_shadow_lit_color(view_pos,
                                                            n,
                                                            t,
                                                            shading_props_color,
                                                            camera_props,
                                                            light_global,
                                                            light,
                                                            shadow_map) * albedo_color;
    
    return half4(out_color);
}

#pragma mark - Shading
fragment half4 gbuffer_shade_frag(ScreenFragment in [[stage_in]],
                                  constant camera_props_t &camera_props [[buffer(0)]],
                                  constant light_global_t &light_global [[buffer(1)]],
                                  constant light_t *lights [[buffer(2)]],
                                  device uint4 *light_cull_buffer [[buffer(3)]],
                                  texture2d<half> albedo [[texture(attachment_albedo)]],
                                  texture2d<half> normal [[texture(attachment_normal)]],
                                  texture2d<half> shading [[texture(attachment_shading)]],
                                  texture2d<half> tangent [[texture(attachment_tangent), function_constant(uses_anisotropy)]],
                                  depth2d<float> depth [[texture(attachment_depth)]]) {
    float4 out_color = float4(0.0, 0.0, 0.0, 1.0);
    
    float4 n_c = float4(normal.sample(linear_clamp_to_edge, in.uv));
    if(n_c.w == 0.0)
        return half4(0, 0, 0, 0);
    float3 n = normalize((n_c.xyz - 0.5) * 2.0);
    float3 t = float3(1.0, 0.0, 0.0);
    
    if(uses_anisotropy) {
        float4 t_c = float4(tangent.sample(linear_clamp_to_edge, in.uv));
        t = normalize((t_c.xyz - 0.5) * 2.0);
    }
    
    float3 view_pos = view_pos_from_depth(camera_props.projectionInverse, in.uv, depth.sample(nearest_clamp_to_edge, in.uv));
    float3 albedo_color = float3(albedo.sample(linear_clamp_to_edge, in.uv).xyz);
    half4 shading_props_color = shading.sample(linear_clamp_to_edge, in.uv);
    
    // lit
    const uint tile_size = light_global.tile_size;
    uint light_cull_grid_dim_x = uint((albedo.get_width() + tile_size - 1) / tile_size);
    uint2 pixel_pos = uint2(albedo.get_width() * in.uv.x, albedo.get_height() * in.uv.y);
    uint2 grid_pos = pixel_pos / tile_size;
    uint light_cull_grid_index = grid_pos.y * light_cull_grid_dim_x + grid_pos.x;
    
    out_color.xyz += calculate_lit_color(view_pos,
                                         n,
                                         t,
                                         shading_props_color,
                                         camera_props,
                                         light_global,
                                         lights,
                                         light_cull_buffer[light_cull_grid_index]) * albedo_color;
    
    return half4(out_color);
}

#pragma mark - Pipelines for non-light culled (legacy)
// TODO : use argument buffer for optimizing resource-bindings
fragment half4 gbuffer_light_frag(ScreenFragment in [[stage_in]],
                                  constant camera_props_t &camera_props [[buffer(0)]],
                                  constant light_t *lights [[buffer(1)]],
                                  constant light_global_t &light_global [[buffer(2)]],
                                  texture2d<half> normal [[texture(attachment_normal)]],
                                  texture2d<half> shading [[texture(attachment_shading)]],
                                  texture2d<half> tangent [[texture(attachment_tangent), function_constant(uses_anisotropy)]],
                                  texture2d<float> depth [[texture(attachment_depth)]],
                                  shadow_array shadow_maps [[texture(attachment_shadow_map)]]) {
    float4 out_color = float4(0.0, 0.0, 0.0, 0.0);
    
    // shared values
    float4 n_c = float4(normal.sample(linear_clamp_to_edge, in.uv));
    if(n_c.w == 0.0)
        return half4(0, 0, 0, 0);
    float3 n = normalize((n_c.xyz - 0.5) * 2.0);
    float4 t_c = float4(tangent.sample(linear_clamp_to_edge, in.uv));
    float3 t = normalize((t_c.xyz - 0.5) * 2.0);
    float3 b = cross(t, n);
    half4 shading_values = shading.sample(linear_clamp_to_edge, in.uv);
    
    shading_t shading_params;
    shading_params.albedo = float3(1);
    shading_params.roughness = shading_values.x;
    shading_params.metalic = shading_values.y;
    shading_params.occlusion = shading_values.z;
    shading_params.anisotropy = shading_values.w * 2.0 - 1.0;
    
    // world-space pos
    float depth_value = depth.sample(nearest_clamp_to_edge, in.uv).r;
    float4 view_pos = float4(view_pos_from_depth(camera_props.projectionInverse, in.uv, depth_value), 1.0);
    float4 world_pos = camera_props.viewInverse * view_pos;
    
    // calculate lights
    for(uint i = 0; i < 4; i++) {
        float lit = get_shadow_lit(shadow_maps[i], lights[i], light_global, world_pos);
        
        if(lit > 0.0) {
            // query light direction from view matrix
            float3 light_dir_invert = -float3(lights[i].light_view[0].z,
                                              lights[i].light_view[1].z,
                                              lights[i].light_view[2].z);
            
            float light_dist = 1.0;
            if(lights[i].type == 1) {
                float3 light_pos = lights[i].position;
                float3 pos_to_light = light_pos.xyz - world_pos.xyz;
                light_dist = max(0.1, length(pos_to_light));
                light_dir_invert = pos_to_light / light_dist;
            }
            
            light_dir_invert = (camera_props.view * float4(light_dir_invert, 0.0)).xyz;

            float3 light_color = lights[i].color;
            float light_intensity = lights[i].intensity;
            light_intensity *= (1.0f - smoothstep(lights[i].radius * 0.75, lights[i].radius, light_dist));
            float3 v = normalize(-view_pos.xyz);
            float3 h = normalize(light_dir_invert + v);
            float h_v = max(0.001, saturate(dot(h, v)));
            float n_h = dot(n, h);
            float t_h = dot(t, h);
            float b_h = dot(b, h);
            float n_l = max(0.001, saturate(dot(n, light_dir_invert)));
            float t_l = max(0.001, saturate(dot(t, light_dir_invert)));
            float b_l = max(0.001, saturate(dot(b, light_dir_invert)));
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
            
            out_color.xyz += lit * calculate_brdf(shading_params) / (light_dist * light_dist);
        }
    }
    return half4(out_color);
}

fragment half4 gbuffer_shade_old_frag(ScreenFragment in [[stage_in]],
                                  constant camera_props_t &cameraProps [[buffer(0)]],
                                  constant light_global_t &light_global [[buffer(1)]],
                                  texture2d<half> albedo [[texture(attachment_albedo)]],
                                  texture2d<half> normal [[texture(attachment_normal)]],
                                  texture2d<half> shading [[texture(attachment_shading)]],
                                  depth2d<float> depth [[texture(attachment_depth)]],
                                  texture2d<half> light [[texture(attachment_light)]],
                                  texture2d<half> tangent [[texture(attachment_tangent)]],
                                  texturecube<half> irradiance [[texture(attachment_irradiance), function_constant(uses_ibl_irradiance_map)]],
                                  texturecube<half> prefilteredSpecular [[texture(attachment_prefiltered_specular), function_constant(uses_ibl_specular_map)]],
                                  texture2d<half> brdfLookup [[texture(attachment_brdf_lookup), function_constant(uses_ibl_specular_map)]],
                                  texture2d<half> ssao [[texture(attachment_ssao), function_constant(uses_ssao_map)]]) {
    float4 out_color = float4(0.0, 0.0, 0.0, 1.0);
    
    float4 n_c = float4(normal.sample(linear_clamp_to_edge, in.uv));
    if(n_c.w == 0.0)
        return half4(0, 0, 0, 0);
    float3 n = normalize((n_c.xyz - 0.5) * 2.0);
    float3 view_pos = view_pos_from_depth(cameraProps.projectionInverse, in.uv, depth.sample(nearest_clamp_to_edge, in.uv));
    float3 v = normalize(-view_pos);
    float n_v = max(0.001, saturate(dot(n, v)));
    
    float3 albedo_color = float3(albedo.sample(linear_clamp_to_edge, in.uv).xyz);
    half4 shading_props_color = shading.sample(linear_clamp_to_edge, in.uv);
    half roughness = shading_props_color.x;
    half metalic = shading_props_color.y;
    half occlusion = shading_props_color.z;
    half4 light_color = light.sample(linear_clamp_to_edge, in.uv);
    
    // reflection (world-space)
    float3 r = n;
    if(uses_anisotropy && (uses_ibl_irradiance_map || uses_ibl_specular_map)) {
        half anisotropy = shading_props_color.w * 2.0 - 1.0;
        float4 t_c = float4(tangent.sample(linear_clamp_to_edge, in.uv));
        float3 t = normalize((t_c.xyz - 0.5) * 2.0);
        r = get_reflected_vector(n, t, v, roughness, anisotropy);
    }
    float3 w_r = (cameraProps.viewInverse * float4(r, 0.0)).xyz;
    
    // SSAO
    half ao = 1.0;
    if(uses_ssao_map) {
        ao = 1.0 - ssao.sample(linear_clamp_to_edge, in.uv).r;
    }
    
    // global ambient color
    out_color.xyz += ao * light_global.ambient_color * albedo_color * occlusion;
    
    // irradiance
    float3 k_s = float3(0);
    if(uses_ibl_irradiance_map) {
        float3 irradiance_color = float3(irradiance.sample(linear, w_r).xyz);
        k_s = fresnel(mix(0.04, albedo_color, metalic), n_v);
        float3 k_d = (float3(1.0) - k_s) * (1.0 - metalic);
        out_color.xyz += ao * k_d * irradiance_color * albedo_color * occlusion;
    }
    
    // prefiltered specular
    if(uses_ibl_specular_map) {
        float mip_index = roughness * prefilteredSpecular.get_num_mip_levels();
        float3 prefiltered_color = float3(prefilteredSpecular.sample(linear, w_r, level(mip_index)).xyz);
        float3 environment_brdf = float3(brdfLookup.sample(linear_clamp_to_edge, float2(roughness, n_v)).xyz);
        out_color.xyz += ao * k_s * prefiltered_color * (albedo_color * environment_brdf.x + environment_brdf.y);
    }
    
    // lit
    out_color.xyz += float3(light_color.xyz) * albedo_color;
    
    return half4(out_color);
}
