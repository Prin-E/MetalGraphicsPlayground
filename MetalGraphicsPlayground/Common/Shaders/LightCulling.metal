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

constant uint tile_size [[function_constant(fcv_light_cull_tile_size)]];

kernel void cull_lights(texture2d<float> depth [[texture(0)]],
                        device uint *light_cull_buffer [[buffer(0)]],
                        constant light_t *lights [[buffer(1)]],
                        constant light_global_t &light_globals [[buffer(2)]],
                        device light_cull_t &light_cull [[buffer(3)]],
                        constant camera_props_t &camera_props [[buffer(4)]],
                        uint2 thread_pos [[thread_position_in_grid]],
                        uint2 threadgroup_pos [[threadgroup_position_in_grid]],
                        uint thread_index_in_group [[thread_index_in_threadgroup]]) {
    // initialize variables
    threadgroup atomic_uint min_depth_value;
    threadgroup atomic_uint max_depth_value;
    if(thread_index_in_group == 0)
    {
        atomic_store_explicit(&min_depth_value, 0xffffffff, memory_order_relaxed);
        atomic_store_explicit(&max_depth_value, 0, memory_order_relaxed);
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // calculate min/max depth
    float depth_value = depth.read(thread_pos).r;
    uint depth_value_uint = as_type<uint>(depth_value);
    atomic_fetch_min_explicit(&min_depth_value, depth_value_uint, memory_order_relaxed);
    atomic_fetch_max_explicit(&max_depth_value, depth_value, memory_order_relaxed);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // TODO: construct tile matrix
    float4x4 tile_matrix = light_globals.light_projection;
    threadgroup float4 tile_planes[6];
    
    // enumerate lights and test
    for(uint light_index = thread_index_in_group; light_index < light_globals.num_light; light_index += tile_size * tile_size) {
        constant light_t &light = lights[light_index];
        bool culled = false;
        for(uint plane_index = 0; plane_index < 6; plane_index++) {
            if(dot(tile_planes[plane_index], float4(light.position, 1.0)) < -light.radius) {
                culled = true;
                break;
            }
        }
        if(!culled) {
            uint element_index = light_index / 32 + 1;
            uint bit_index = light_index % 32;
            uint buffer_index = (threadgroup_pos.y * tile_size + threadgroup_pos.x) * 4 + element_index;
            light_cull_buffer[buffer_index] |= 1 << bit_index;
        }
    }
}
