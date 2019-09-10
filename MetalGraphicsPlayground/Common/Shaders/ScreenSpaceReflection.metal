//
//  ScreenSpaceReflection.metal
//  MetalTextureLOD
//
//  Created by 이현우 on 2019/09/06.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include "SharedStructures.h"
#include "CommonMath.h"
#include "ColorSpace.h"
#include "BRDF.h"

using namespace metal;

float attenuate(float2 uv, uint2 size, float attenuation) {
    float offset = min(1.0 - max(uv.x, uv.y), min(uv.x, uv.y));
    float result = offset / attenuation;
    result = saturate(result);
    return pow(result, 0.5);
}

float vignette(float2 uv, uint2 size, float vignette) {
    float2 k = abs(uv - 0.5) * vignette;
    k.x *= 1.0f / float(size.x);
    return pow(saturate(1.0 - dot(k, k)), 5.0);
}

kernel void ssr(texture2d<float> normal [[texture(0)]],
                texture2d<float> depth [[texture(1)]],
                texture2d<half> shading [[texture(2)]],
                texture2d<float> color [[texture(3)]],
                texture2d<float, access::write> output [[texture(4)]],
                constant screen_space_reflection_props_t &ssr_props [[buffer(0)]],
                constant camera_props_t &camera_props [[buffer(1)]],
                uint2 thread_pos [[thread_position_in_grid]]) {
    if(output.get_width() <= thread_pos.x || output.get_height() <= thread_pos.y)
        return;
    
    float4 color_value = color.read(thread_pos);
    float4 normal_value = normal.read(thread_pos);
    if(normal_value.a < 0.0001) {
        output.write(color_value, thread_pos);
        return;
    }
    float3 view_normal = (camera_props.view * float4(normalize(normal.read(thread_pos).xyz * 2.0 - 1.0), 0.0)).xyz;
    float depth_value = depth.read(thread_pos).r;
    half4 shading_value = shading.read(thread_pos);
    
    uint2 size = uint2(output.get_width(), output.get_height());
    float3 view_pos = view_pos_from_depth(camera_props.projectionInverse, thread_pos, size, depth_value);
    
    // reflection ray via surface normal
    float3 view_pos_n = normalize(view_pos);
    float3 ray_dir = reflect(view_pos_n, view_normal);
    
    // fresnel
    half metalic = shading_value.y;
    if(metalic < 0.01) {
        output.write(color_value, thread_pos);
        return;
    }
    float3 f_s = fresnel(mix(0.04, color_value.xyz, metalic), max(dot(view_pos_n, view_normal), 0.0));
    
    // perform ray-marching
    float step_length = ssr_props.step;
    for(int i = 0, cnt = ssr_props.iteration; i < cnt; i++) {
        view_pos += ray_dir * step_length;
        float4 current_ray_ndc = camera_props.projection * float4(view_pos, 1.0);
        current_ray_ndc /= current_ray_ndc.w;
        uint2 current_ray_coords = uint2((current_ray_ndc.xy * 0.5 + 0.5) * float2(size));
        current_ray_coords.y = size.y - current_ray_coords.y;
        float hit_depth_z = depth.read(current_ray_coords).r;
        float3 hit_view_pos = view_pos_from_depth(camera_props.projectionInverse, current_ray_coords, size, hit_depth_z);
        if(view_pos.z > hit_view_pos.z) {
            // binary search
            float step_length_2 = step_length;
            for(int j = 0; j < 12; j++) {
                if(abs(view_pos.z - hit_view_pos.z) < 0.005)
                    break;
                
                step_length_2 *= 0.5;
                if(view_pos.z > hit_view_pos.z) {
                    view_pos -= ray_dir * step_length_2;
                }
                else {
                    view_pos += ray_dir * step_length_2;
                }
                
                current_ray_ndc = camera_props.projection * float4(view_pos, 1.0);
                current_ray_ndc /= current_ray_ndc.w;
                current_ray_coords = uint2((current_ray_ndc.xy * 0.5 + 0.5) * float2(size));
                current_ray_coords.y = size.y - current_ray_coords.y;
                hit_depth_z = depth.read(current_ray_coords).r;
                hit_view_pos = view_pos_from_depth(camera_props.projectionInverse, current_ray_coords, size, hit_depth_z);
            }
            
            if(current_ray_ndc.x < -1.0 || current_ray_ndc.x > 1.0 ||
               current_ray_ndc.y < -1.0 || current_ray_ndc.y > 1.0) {
                break;
            }
            
            float4 surface_color = color.read(current_ray_coords);
            float3 reflection_color = surface_color.xyz * ssr_props.opacity * metalic * f_s;
            
            // vignette, attenuation
            float2 coords_uv = current_ray_ndc.xy * 0.5 + 0.5;
            reflection_color *= attenuate(coords_uv, size, ssr_props.attenuation) * vignette(coords_uv, size, ssr_props.vignette);
            
            color_value.xyz += reflection_color;
            break;
        }
    }
    
    output.write(color_value, thread_pos);
}
