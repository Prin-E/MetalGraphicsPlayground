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

using namespace metal;

kernel void ssao(texture2d<float> normal [[texture(0)]],
                 texture2d<float> tangent [[texture(1)]],
                 texture2d<float> pos [[texture(2)]],
                 texture2d<float, access::write> output [[texture(3)]],
                 device float3 *random_samples [[buffer(0)]],
                 constant camera_props_t &camera_props [[buffer(1)]],
                 uint2 thread_pos [[thread_position_in_grid]]) {
    if(output.get_width() <= thread_pos.x || output.get_height() <= thread_pos.y)
        return;
    
    float3 n = normalize(normal.read(thread_pos).xyz * 2.0 - 1.0);
    float3 t = normalize(tangent.read(thread_pos).xyz * 2.0 - 1.0);
    float3 b = cross(t, n);
    constexpr float radius = 100;   // TODO
    
    float3 p = pos.read(thread_pos).xyz;
    constexpr uint num_samples = 32;
    constexpr float sample_bias = 0.005;
    float4 vp = camera_props.view * float4(p, 1.0);
    
    float occlusion = 0;
    for(uint i = 0; i < num_samples; i++) {
        float3 sample = random_samples[i];
        float3 sample_pos = p + radius * float3(t * sample.x + b * sample.y + n * sample.z);
        float4 view_sample_pos = camera_props.view * float4(sample_pos, 1.0);
        float4 proj_sample_pos = camera_props.projection * view_sample_pos;
        proj_sample_pos = proj_sample_pos / proj_sample_pos.w;
        proj_sample_pos.xyz = proj_sample_pos.xyz * 0.5 + 0.5;
        if(proj_sample_pos.x > 1.0 || proj_sample_pos.y > 1.0 ||
           proj_sample_pos.x < 0.0 || proj_sample_pos.y < 0.0)
            continue;
        
        uint2 screen_sample_pos = uint2(proj_sample_pos.x * output.get_width(), proj_sample_pos.y * output.get_height());
        
        float3 p2 = pos.read(screen_sample_pos).xyz;
        float4 vp2 = camera_props.view * float4(p2, 1.0);
        float range_check = smoothstep(0.0, 1.0, radius / abs(vp2.z - vp.z));
        occlusion += (vp.z > vp2.z + sample_bias ? 1.0 : 0.0) * range_check;
    }
    
    occlusion /= float(num_samples);
    output.write(1.0 - occlusion, thread_pos);
}
