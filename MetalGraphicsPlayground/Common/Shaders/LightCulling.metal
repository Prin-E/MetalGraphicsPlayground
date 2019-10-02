//
//  LightCulling.metal
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/09/15.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include <metal_atomic>
#include "SharedStructures.h"
#include "CommonStages.h"
#include "CommonVariables.h"
#include "LightingCommon.h"

using namespace metal;

// uint4 per grid cell : origin=top-left
// [ dir_light_shadow | dir_light ] [ point_light_1~32 ] [ point_light_33~64 ] [ unused ]
kernel void cull_lights(texture2d<float> depth [[texture(0)]],
                        device uint4 *light_cull_buffer [[buffer(0)]],
                        constant light_t *lights [[buffer(1)]],
                        constant light_global_t &light_globals [[buffer(2)]],
                        constant camera_props_t &camera_props [[buffer(3)]],
                        uint2 thread_pos [[thread_position_in_grid]],
                        uint2 threadgroup_pos [[threadgroup_position_in_grid]],
                        uint2 threadgroup_num [[threadgroups_per_grid]],
                        uint thread_index_in_group [[thread_index_in_threadgroup]]) {
    // initialize variables
    threadgroup atomic_uint min_depth_value;
    threadgroup atomic_uint max_depth_value;
    threadgroup atomic_uint light_bit_mask[4];
    const uint tile_size = light_globals.tile_size;
    
    if(thread_index_in_group == 0)
    {
        // init min/max depth value
        atomic_store_explicit(&min_depth_value, 0xffffffff, memory_order_relaxed);
        atomic_store_explicit(&max_depth_value, 0, memory_order_relaxed);
        
        // init bit mask
        atomic_store_explicit(&light_bit_mask[0], 0, memory_order_relaxed);
        atomic_store_explicit(&light_bit_mask[1], 0, memory_order_relaxed);
        atomic_store_explicit(&light_bit_mask[2], 0, memory_order_relaxed);
        atomic_store_explicit(&light_bit_mask[3], 0, memory_order_relaxed);
    }
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // calculate min/max depth
    float depth_value = depth.read(thread_pos).r;
    uint depth_value_uint = as_type<uint>(depth_value);
    atomic_fetch_min_explicit(&min_depth_value, depth_value_uint, memory_order_relaxed);
    atomic_fetch_max_explicit(&max_depth_value, depth_value_uint, memory_order_relaxed);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // construct tile matrix, frustum planes
    float tile_min_depth = as_type<float>(atomic_load_explicit(&min_depth_value, memory_order_relaxed));
    float tile_max_depth = as_type<float>(atomic_load_explicit(&max_depth_value, memory_order_relaxed));
    // from MiniEngine (does it work??)
    /*
    float rcp_z_magic = camera_props.nearPlane / (camera_props.farPlane - camera_props.nearPlane);
    float tile_min_depth = (1.0 / atomic_load_explicit(&min_depth_value, memory_order_relaxed) - 1.0) * rcp_z_magic;
    float tile_max_depth = (1.0 / atomic_load_explicit(&max_depth_value, memory_order_relaxed) - 1.0) * rcp_z_magic;
     */
    float tile_depth_range = max(FLT_MIN, tile_max_depth - tile_min_depth);
    
    float4x4 viewproj_mat = camera_props.viewProjection;
    float3 tile_bias = float3(-2.0 * float(threadgroup_pos.x) + float(threadgroup_num.x) - 1.0,
                              2.0 * float(threadgroup_pos.y) - float(threadgroup_num.y) + 1.0,
                              -tile_min_depth / tile_depth_range);
    
    float4x4 tile_mat = float4x4(float4(threadgroup_num.x, 0, 0, 0),
                                 float4(0, threadgroup_num.y, 0, 0),
                                 float4(0, 0, 1.0/tile_depth_range, 0),
                                 float4(tile_bias, 1.0));
    float4x4 tile_viewproj_mat = transpose(tile_mat * viewproj_mat);
    
    float4 tile_planes[6];
    tile_planes[0] = tile_viewproj_mat[3] + tile_viewproj_mat[0];
    tile_planes[1] = tile_viewproj_mat[3] - tile_viewproj_mat[0];
    tile_planes[2] = tile_viewproj_mat[3] + tile_viewproj_mat[1];
    tile_planes[3] = tile_viewproj_mat[3] - tile_viewproj_mat[1];
    tile_planes[4] = tile_viewproj_mat[3] + tile_viewproj_mat[2];
    tile_planes[5] = tile_viewproj_mat[3] - tile_viewproj_mat[2];
    for(uint i = 0; i < 6; i++) {
        tile_planes[i] *= rsqrt(dot(tile_planes[i].xyz, tile_planes[i].xyz));
    }
    
    // enumerate lights and test
    for(uint light_index = thread_index_in_group; light_index < light_globals.first_point_light_index; light_index += tile_size * tile_size) {
        // directional lights; will not be culled
        constant light_t &light = lights[light_index];
        uint bit_index = uint(light.cast_shadow) * MAX_NUM_DIRECTIONAL_LIGHTS + light_index;
        atomic_fetch_or_explicit(&light_bit_mask[0], 1 << bit_index, memory_order_relaxed);
    }
    
    for(uint light_index = thread_index_in_group + light_globals.first_point_light_index; light_index < light_globals.num_light; light_index += tile_size * tile_size) {
        // point lights; frustum/sphere test
        constant light_t &light = lights[light_index];
        float4 position = float4(light.position, 1.0);
        float radius = light.radius;
        bool overlapped = true;
        for(uint plane_index = 0; plane_index < 6; plane_index++) {
            float d = dot(tile_planes[plane_index], position);
            if(d < -radius) {
                overlapped = false;
            }
        }
        if(overlapped) {
            uint element_index = light_index / 32 + 1;
            uint bit_index = light_index % 32;
            atomic_fetch_or_explicit(&light_bit_mask[element_index], 1 << bit_index, memory_order_relaxed);
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    if(thread_index_in_group == 0) {
        uint buffer_index = (threadgroup_pos.y * threadgroup_num.x + threadgroup_pos.x);
        uint4 tile = uint4(0);
        tile.x = atomic_load_explicit(&light_bit_mask[0], memory_order_relaxed);
        tile.y = atomic_load_explicit(&light_bit_mask[1], memory_order_relaxed);
        tile.z = atomic_load_explicit(&light_bit_mask[2], memory_order_relaxed);
        tile.w = atomic_load_explicit(&light_bit_mask[3], memory_order_relaxed);
        light_cull_buffer[buffer_index] = tile;
    }
}

// (Debug) Tile state rendering
fragment half4 lightcull_frag(ScreenFragment in [[stage_in]],
                              device uint4 *light_cull_buffer [[buffer(0)]],
                              constant light_global_t &light_globals [[buffer(1)]],
                              texture2d<half> output [[texture(0)]]) {
    const uint tile_size = light_globals.tile_size;
    half4 output_color = output.sample(linear_clamp_to_edge, in.uv);
    
    const uint width = output.get_width();
    const uint height = output.get_height();
    const uint tile_w = (width+tile_size-1)/tile_size;
    const uint tile_h = (height+tile_size-1)/tile_size;
    const float2 pos = in.uv * float2(tile_w, tile_h);
    const uint tile_index = uint(floor(pos.y) * tile_w + floor(pos.x));
    
    half4 tile_color = half4(0, 0, 0, 0.5);
    uint4 tile = light_cull_buffer[tile_index];
    while(tile.x != 0) {
        tile_color.x += (1.0 / 4.0) * (tile.x & 1);
        tile.x = tile.x >> 1;
    }
    while(tile.y != 0) {
        tile_color.y += (1.0 / 12.0) * (tile.y & 1);
        tile.y = tile.y >> 1;
    }
    while(tile.z != 0) {
        tile_color.y += (1.0 / 12.0) * (tile.z & 1);
        tile.z = tile.z >> 1;
    }
    tile_color.xyz = pow(tile_color.xyz, 2.2);
    return half4(mix(output_color.xyz, tile_color.xyz, tile_color.a), 1.0);
}
