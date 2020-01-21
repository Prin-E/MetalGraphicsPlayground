//
//  SSAO.metal
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 25/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include "SharedStructures.h"
#include "CommonMath.h"
#include "Blur.h"

using namespace metal;

kernel void ssao(texture2d<float> normal [[texture(0)]],
                 texture2d<float> tangent [[texture(1)]],
                 texture2d<float> depth [[texture(2)]],
                 texture2d<float, access::write> output [[texture(3)]],
                 device float3 *random_samples [[buffer(0)]],
                 constant ssao_props_t &ssao_props [[buffer(1)]],
                 constant camera_props_t &camera_props [[buffer(2)]],
                 uint2 thread_pos [[thread_position_in_grid]]) {
    if(output.get_width() <= thread_pos.x || output.get_height() <= thread_pos.y)
        return;
    
    const uint num_samples = ssao_props.num_samples;
    const float sample_bias = ssao_props.bias;
    const float radius = ssao_props.radius;
    const float intensity = ssao_props.intensity;
    
    uint downscale = (uint)(pow(2.0, ssao_props.downsample) + 0.00001);
    uint2 coords = thread_pos * downscale;
    uint2 size = uint2(output.get_width(), output.get_height()) * downscale - uint2(1, 1);
    
    float3 n = normalize(normal.read(coords).xyz * 2.0 - 1.0);
    float3 t = normalize(tangent.read(coords).xyz * 2.0 - 1.0);
    float3 b = cross(t, n);
    float depth_value = depth.read(coords).r;
    
    float3 view_pos = view_pos_from_depth(camera_props.projectionInverse, coords, size, depth_value);
    float occlusion = 0;
    for(uint i = 0; i < num_samples; i++) {
        float3 sample = random_samples[i];
        float3 view_offset_pos = view_pos + radius * float3(t * sample.x + b * sample.y + n * sample.z);
        float4 proj_offset_pos = camera_props.projection * float4(view_offset_pos, 1.0);
        proj_offset_pos = proj_offset_pos / proj_offset_pos.w;
        proj_offset_pos.xyz = proj_offset_pos.xyz * 0.5 + 0.5;
        proj_offset_pos.xy = saturate(proj_offset_pos.xy);
        proj_offset_pos.y = 1.0 - proj_offset_pos.y;
        
        // clip space -> screen space
        uint2 screen_offset_pos = uint2(proj_offset_pos.x * size.x, proj_offset_pos.y * size.y);
        
        // screen space -> view space
        float depth_sample_value = depth.read(screen_offset_pos).r;
        float3 view_sample_pos = view_pos_from_depth(camera_props.projectionInverse, screen_offset_pos, size, depth_sample_value);
        
        // check occlusion
        float range_check = smoothstep(0.0, 1.0, radius / abs(view_sample_pos.z - view_pos.z));
        occlusion += (view_offset_pos.z >= view_sample_pos.z + sample_bias ? 1.0 : 0.0) * range_check;
    }
    
    occlusion /= float(num_samples);
    output.write(occlusion * intensity, thread_pos);
}

kernel void ssao_blur_horizontal(texture2d<float> ssao [[texture(0)]],
                                 texture2d<float, access::write> output [[texture(1)]],
                                 uint2 thread_pos [[thread_position_in_grid]],
                                 uint2 thread_group_pos [[thread_position_in_threadgroup]]) {
    threadgroup float group_vals[22][16] = {};
    uint2 groupval_pos = thread_group_pos + uint2(3, 0);
    bool out_of_range = (thread_pos.x >= ssao.get_width()) || (thread_pos.y < ssao.get_height());
    
    if(!out_of_range) {
        // read values by threadgroup
        float val = ssao.read(thread_pos).r;
        group_vals[groupval_pos.x][groupval_pos.y] = val;
        if(thread_group_pos.x == 0) {
            if(thread_pos.x == 0) {
                group_vals[groupval_pos.x-1][groupval_pos.y] = val;
                group_vals[groupval_pos.x-2][groupval_pos.y] = val;
                group_vals[groupval_pos.x-3][groupval_pos.y] = val;
            }
            else {
                group_vals[groupval_pos.x-1][groupval_pos.y] = ssao.read(thread_pos-uint2(1,0)).r;
                group_vals[groupval_pos.x-2][groupval_pos.y] = ssao.read(thread_pos-uint2(2,0)).r;
                group_vals[groupval_pos.x-3][groupval_pos.y] =  ssao.read(thread_pos-uint2(3,0)).r;
            }
        }
        else if(thread_group_pos.x == 15) {
            group_vals[groupval_pos.x+1][groupval_pos.y] = ssao.read(thread_pos+uint2(1,0)).r;
            group_vals[groupval_pos.x+2][groupval_pos.y] = ssao.read(thread_pos+uint2(2,0)).r;
            group_vals[groupval_pos.x+3][groupval_pos.y] =  ssao.read(thread_pos+uint2(3,0)).r;
        }
        else if(thread_pos.x + 1 == ssao.get_width()) {
            group_vals[groupval_pos.x+1][groupval_pos.y] = val;
            group_vals[groupval_pos.x+2][groupval_pos.y] = val;
            group_vals[groupval_pos.x+3][groupval_pos.y] = val;
        }
    }
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    if(!out_of_range) {
        // horizontal blur
        float a = group_vals[groupval_pos.x-3][groupval_pos.y];
        float b = group_vals[groupval_pos.x-2][groupval_pos.y];
        float c = group_vals[groupval_pos.x-1][groupval_pos.y];
        float d = group_vals[groupval_pos.x][groupval_pos.y];
        float e = group_vals[groupval_pos.x+1][groupval_pos.y];
        float f = group_vals[groupval_pos.x+2][groupval_pos.y];
        float g = group_vals[groupval_pos.x+3][groupval_pos.y];
        output.write(blur_gaussian(a,b,c,d,e,f,g),thread_pos);
    }
}

kernel void ssao_blur_vertical(texture2d<float> ssao [[texture(0)]],
                               texture2d<float, access::write> output [[texture(1)]],
                               uint2 thread_pos [[thread_position_in_grid]],
                               uint2 thread_group_pos [[thread_position_in_threadgroup]]) {
    threadgroup float group_vals[16][22] = {};
    uint2 groupval_pos = thread_group_pos + uint2(3, 0);
    bool out_of_range = (thread_pos.x >= ssao.get_width()) || (thread_pos.y < ssao.get_height());
    
    if(!out_of_range) {
        // read values by threadgroup
        float val = ssao.read(thread_pos).r;
        uint2 groupval_pos = thread_group_pos + uint2(0, 3);
        group_vals[groupval_pos.x][groupval_pos.y] = val;
        if(thread_group_pos.y == 0) {
            if(thread_pos.y == 0) {
                group_vals[groupval_pos.x][groupval_pos.y-1] = val;
                group_vals[groupval_pos.x][groupval_pos.y-2] = val;
                group_vals[groupval_pos.x][groupval_pos.y-3] = val;
            }
            else {
                group_vals[groupval_pos.x][groupval_pos.y-1] = ssao.read(thread_pos-uint2(0,1)).r;
                group_vals[groupval_pos.x][groupval_pos.y-2] = ssao.read(thread_pos-uint2(0,2)).r;
                group_vals[groupval_pos.x][groupval_pos.y-3] =  ssao.read(thread_pos-uint2(0,3)).r;
            }
        }
        else if(thread_group_pos.y == 15) {
            group_vals[groupval_pos.x][groupval_pos.y+1] = ssao.read(thread_pos+uint2(0,1)).r;
            group_vals[groupval_pos.x][groupval_pos.y+2] = ssao.read(thread_pos+uint2(0,2)).r;
            group_vals[groupval_pos.x][groupval_pos.y+3] =  ssao.read(thread_pos+uint2(0,3)).r;
        }
        else if(thread_pos.y + 1 == ssao.get_height()) {
            group_vals[groupval_pos.x][groupval_pos.y+1] = val;
            group_vals[groupval_pos.x][groupval_pos.y+2] = val;
            group_vals[groupval_pos.x][groupval_pos.y+3] = val;
        }
    }
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    if(!out_of_range) {
        // vertical blur
        float a = group_vals[groupval_pos.x][groupval_pos.y-3];
        float b = group_vals[groupval_pos.x][groupval_pos.y-2];
        float c = group_vals[groupval_pos.x][groupval_pos.y-1];
        float d = group_vals[groupval_pos.x][groupval_pos.y];
        float e = group_vals[groupval_pos.x][groupval_pos.y+1];
        float f = group_vals[groupval_pos.x][groupval_pos.y+2];
        float g = group_vals[groupval_pos.x][groupval_pos.y+3];
        output.write(blur_gaussian(a,b,c,d,e,f,g),thread_pos);
    }
}
