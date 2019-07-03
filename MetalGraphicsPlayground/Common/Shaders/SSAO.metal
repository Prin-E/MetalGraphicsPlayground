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
                 constant ssao_props_t &ssao_props [[buffer(1)]],
                 constant camera_props_t &camera_props [[buffer(2)]],
                 uint2 thread_pos [[thread_position_in_grid]]) {
    if(output.get_width() <= thread_pos.x || output.get_height() <= thread_pos.y)
        return;
    
    float3 n = normalize(normal.read(thread_pos).xyz * 2.0 - 1.0);
    float3 t = normalize(tangent.read(thread_pos).xyz * 2.0 - 1.0);
    float3 b = cross(t, n);
    
    float3 world_pos = pos.read(thread_pos).xyz;
    float4 view_pos = camera_props.view * float4(world_pos, 1.0);
    
    const uint num_samples = ssao_props.num_samples;
    const float sample_bias = ssao_props.bias;
    const float radius = ssao_props.radius;
    const float intensity = ssao_props.intensity;
    
    float occlusion = 0;
    for(uint i = 0; i < num_samples; i++) {
        float3 sample = random_samples[i];
        float3 offset_pos = world_pos + radius * float3(t * sample.x + b * sample.y + n * sample.z);
        float4 view_offset_pos = camera_props.view * float4(offset_pos, 1.0);
        float4 proj_offset_pos = camera_props.projection * view_offset_pos;
        proj_offset_pos = proj_offset_pos / proj_offset_pos.w;
        proj_offset_pos.xyz = proj_offset_pos.xyz * 0.5 + 0.5;
        proj_offset_pos.xy = saturate(proj_offset_pos.xy);
        proj_offset_pos.y = 1.0 - proj_offset_pos.y;
        
        // clip space -> screen space
        uint2 screen_offset_pos = uint2(proj_offset_pos.x * output.get_width(), proj_offset_pos.y * output.get_height());
        
        // screen space -> view space
        float3 world_sample_pos = pos.read(screen_offset_pos).xyz;
        float4 view_sample_pos = camera_props.view * float4(world_sample_pos, 1.0);
        
        // check occlusion
        float range_check = smoothstep(0.0, 1.0, radius / abs(view_sample_pos.z - view_pos.z));
        occlusion += (view_offset_pos.z >= view_sample_pos.z + sample_bias ? 1.0 : 0.0) * range_check;
    }
    
    occlusion /= float(num_samples);
    output.write(occlusion * intensity, thread_pos);
}
