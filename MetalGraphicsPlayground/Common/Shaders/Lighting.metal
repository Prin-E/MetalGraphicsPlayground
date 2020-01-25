//
//  Lighting.metal
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/10/02.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include "Lighting.h"
#include "Shadow.h"

using namespace metal;

void fill_shading_params_for_light(thread shading_t &shading_params,
                                   constant light_t &light,
                                   float3 l,
                                   float3 v,
                                   float3 n,
                                   float3 t,
                                   float3 b) {
    float3 light_color = light.color;
    float light_intensity = light.intensity;
    
    float3 h = normalize(l + v);
    float h_v = max(0.001, saturate(dot(h, v)));
    float n_h = dot(n, h);
    float t_h = dot(t, h);
    float b_h = dot(b, h);
    float n_l = max(0.001, saturate(dot(n, l)));
    float t_l = max(0.001, saturate(dot(t, l)));
    float b_l = max(0.001, saturate(dot(b, l)));
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
}

float3 calculate_directional_shadow_lit_color(float3 v,
                                              float4 world_pos,
                                              float3 view_normal,
                                              float3 view_tangent,
                                              float3 view_bitangent,
                                              half4 shading_values,
                                              constant camera_props_t &camera_props,
                                              constant light_global_t &light_global,
                                              constant light_t *lights,
                                              shadow_array shadow_maps,
                                              shading_t shading_params,
                                              uint bitmask,
                                              uint index_offset) {
    float3 lit_color = float3(0);
    uint light_index = index_offset;
    while(bitmask) {
        if(bitmask & 0x1) {
            constant light_t &light = lights[light_index];
            depth2d<float> shadow_map = shadow_maps[light_index];
            float lit = get_shadow_lit(shadow_map, light, light_global, world_pos);

            if(lit > 0) {
                // query light direction from view matrix
                float3 l = -float3(light.light_view[0].z,
                                   light.light_view[1].z,
                                   light.light_view[2].z);
                l = (camera_props.view * float4(l, 0.0)).xyz;

                // fill shading parameters
                fill_shading_params_for_light(shading_params, light, l, v, view_normal, view_tangent, view_bitangent);
                
                // calculate and append lit color
                lit_color += calculate_brdf(shading_params) * shading_values.z * lit;
            }
        }
        bitmask >>= 1;
        light_index += 1;
    }
    return lit_color;
}

float3 calculate_directional_lit_color(float3 v,
                                       float4 world_pos,
                                       float3 view_normal,
                                       float3 view_tangent,
                                       float3 view_bitangent,
                                       half4 shading_values,
                                       constant camera_props_t &camera_props,
                                       constant light_t *lights,
                                       shading_t shading_params,
                                       uint bitmask,
                                       uint index_offset) {
    float3 lit_color = float3(0);
    uint light_index = index_offset;
    while(bitmask) {
        if(bitmask & 0x1) {
            constant light_t &light = lights[light_index];

            // query light direction from view matrix
            float3 l = -float3(light.light_view[0].z,
                               light.light_view[1].z,
                               light.light_view[2].z);
            l = (camera_props.view * float4(l, 0.0)).xyz;

            // fill shading parameters
            fill_shading_params_for_light(shading_params, light, l, v, view_normal, view_tangent, view_bitangent);
            
            // calculate and append lit color
            lit_color += calculate_brdf(shading_params) * shading_values.z;
        }
        bitmask >>= 1;
        light_index += 1;
    }
    return lit_color;
}

float3 calculate_pointlight_lit_color(float3 v,
                                      float4 world_pos,
                                      float3 view_normal,
                                      float3 view_tangent,
                                      float3 view_bitangent,
                                      half4 shading_values,
                                      constant camera_props_t &camera_props,
                                      constant light_t *lights,
                                      shading_t shading_params,
                                      uint bitmask,
                                      uint index_offset) {
    
    float3 lit_color = float3(0);
    uint light_index = index_offset;
    while(bitmask) {
        if(bitmask & 0x1)
        {
            constant light_t &light = lights[light_index];
            float light_dist = 1.0;
            float3 light_pos = light.position;
            float3 pos_to_light = light_pos.xyz - world_pos.xyz;
            light_dist = max(0.1, length(pos_to_light));
            float3 l = pos_to_light / light_dist;
            l = (camera_props.view * float4(l, 0.0)).xyz;
            
            // fill shading parameters
            fill_shading_params_for_light(shading_params, light, l, v, view_normal, view_tangent, view_bitangent);
            shading_params.light *= (1.0f - smoothstep(light.radius * 0.75, light.radius, light_dist));
            
            // calculate and append lit color
            lit_color += calculate_brdf(shading_params) * shading_values.z / (light_dist * light_dist);
        }
        bitmask >>= 1;
        light_index += 1;
    }
    return lit_color;
}

float3 calculate_lit_color(float3 view_pos,
                           float3 view_normal,
                           float3 view_tangent,
                           half4 shading_values,
                           constant camera_props_t &camera_props,
                           constant light_global_t &light_global,
                           constant light_t *lights,
                           uint4 light_cull_cell,
                           shadow_array shadow_maps) {
    float3 lit_color = float3(0);
    
    if(shading_values.z < 0.0001)
        return lit_color;
    
    // prepare
    float4 world_pos = camera_props.viewInverse * float4(view_pos, 1.0);
    float3 v = normalize(-view_pos);
    float3 view_bitangent = cross(view_tangent, view_normal);
    thread shading_t shading_params;
    shading_params.albedo = float3(1);
    shading_params.roughness = shading_values.x;
    shading_params.metalic = shading_values.y;
    shading_params.anisotropy = shading_values.w * 2.0 - 1.0;
    
    // directional light (with shadow)
    lit_color += calculate_directional_shadow_lit_color(v, world_pos, view_normal, view_tangent, view_bitangent, shading_values, camera_props, light_global, lights, shadow_maps, shading_params, light_cull_cell.x >> 16, 0);
    
    // directional light
    lit_color += calculate_directional_lit_color(v, world_pos, view_normal, view_tangent, view_bitangent, shading_values, camera_props, lights, shading_params, light_cull_cell.x & 0xFF, 0);

    // point light
    lit_color += calculate_pointlight_lit_color(v, world_pos, view_normal, view_tangent, view_bitangent, shading_values, camera_props, lights, shading_params, light_cull_cell.y, 0);
    lit_color += calculate_pointlight_lit_color(v, world_pos, view_normal, view_tangent, view_bitangent, shading_values, camera_props, lights, shading_params, light_cull_cell.z, 32);
    
    return lit_color;
}
