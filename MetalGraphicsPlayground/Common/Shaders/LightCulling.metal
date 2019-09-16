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
using namespace metal;

constant uint tile_size = 16;//[[function_constant(fcv_light_cull_tile_size)]];

// uint4 per grid cell
// [ dir_light_shadow | dir_light ] [ point_light_33~64 ] [ point_light_1~32 ] [ unused ]
kernel void cull_lights(texture2d<float> depth [[texture(0)]],
                        device uint *light_cull_buffer [[buffer(0)]],
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
    atomic_fetch_max_explicit(&max_depth_value, depth_value, memory_order_relaxed);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // construct tile matrix, frustum planes
    float tile_min_depth = as_type<float>(atomic_load_explicit(&min_depth_value, memory_order_relaxed));
    float tile_max_depth = as_type<float>(atomic_load_explicit(&max_depth_value, memory_order_relaxed));
    float tile_depth_range = tile_max_depth - tile_min_depth;
    
    float4x4 viewproj_mat = camera_props.viewProjection;
    float3 tile_bias = float3(-2.0 * float(threadgroup_pos.x) + float(threadgroup_num.x) - 1.0,
                              -2.0 * float(threadgroup_pos.y) + float(threadgroup_num.y) - 1.0,
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
        // directional light
        constant light_t &light = lights[light_index];
        uint bit_index = uint(light.cast_shadow) * 16 + light_index;
        atomic_fetch_or_explicit(&light_bit_mask[0], 1 << bit_index, memory_order_relaxed);
    }
    
    for(uint light_index = thread_index_in_group + light_globals.first_point_light_index; light_index < light_globals.num_light; light_index += tile_size * tile_size) {
        constant light_t &light = lights[light_index];
        bool overlapped = true;
        for(uint plane_index = 0; plane_index < 6; plane_index++) {
            if(dot(tile_planes[plane_index], float4(light.position, 1.0)) < -light.radius) {
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
    
    // directional light will not be culled
    if(thread_index_in_group == 0) {
        uint buffer_index = (threadgroup_pos.y * tile_size + threadgroup_pos.x) * 4;
        light_cull_buffer[buffer_index] = atomic_load_explicit(&light_bit_mask[0], memory_order_relaxed);
        light_cull_buffer[buffer_index + 1] = atomic_load_explicit(&light_bit_mask[1], memory_order_relaxed);
        light_cull_buffer[buffer_index + 2] = atomic_load_explicit(&light_bit_mask[2], memory_order_relaxed);
        light_cull_buffer[buffer_index + 3] = atomic_load_explicit(&light_bit_mask[3], memory_order_relaxed);
    }
}
