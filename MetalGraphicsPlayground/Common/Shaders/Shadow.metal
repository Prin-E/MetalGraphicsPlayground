//
//  Shadow.metal
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 12/07/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include "SharedStructures.h"
#include "CommonVariables.h"
#include "Shadow.h"

#define SHADOW_ANTIALIASING 1
#if SHADOW_ANTIALIASING == 1
    #define SHADOW_SAMPLE_FUNC shadow_sample_linear
#elif SHADOW_ANTIALIASING == 2
#define SHADOW_SAMPLE_FUNC shadow_sample_dithered
#elif SHADOW_ANTIALIASING == 3
#define SHADOW_SAMPLE_FUNC shadow_sample_antialiased_4x4
#else
#define SHADOW_SAMPLE_FUNC shadow_sample
#endif

using namespace metal;

typedef struct {
    float3 pos     [[attribute(attrib_pos)]];
} ShadowVertex;

typedef struct {
    float4 clip_pos      [[position]];
} ShadowFragment;

#pragma mark - Stages
vertex ShadowFragment shadow_vert(ShadowVertex in [[stage_in]],
                                  constant light_t &light [[buffer(1)]],
                                  constant light_global_t &light_global [[buffer(2)]],
                                  constant instance_props_t *instanceProps [[buffer(3)]],
                                  uint iid [[instance_id]]) {
    ShadowFragment out;
    float4 v = float4(in.pos, 1.0);
    out.clip_pos = light.light_view_projection * instanceProps[iid].model * v;
    return out;
}

// for Debug only
fragment float shadow_frag(ShadowFragment in [[stage_in]]) {
    //return albedo.sample(linear, in.uv);
    return in.clip_pos.z;
}

#pragma mark - Sampling
// Basic hard-shadow sampling
float shadow_sample(depth2d<float> shadow_map,
                    float2 shadow_size,
                    float2 light_view_pos,
                    float2 light_screen_uv,
                    float light_depth_test) {
    float depth_value = shadow_map.sample(nearest_clamp_to_edge, light_screen_uv);
    float lit = step(light_depth_test, depth_value);
    return lit;
}

// Software bilinear sampling
float shadow_sample_linear(depth2d<float> shadow_map,
                           float2 shadow_size,
                           float2 light_view_pos,
                           float2 light_screen_uv,
                           float light_depth_test) {
    float2 shadow_size_div1 = 1.0 / shadow_size;
    float2 light_screen_xy = light_screen_uv * shadow_size + 0.5;
    float2 light_screen_xy_fract = fract(light_screen_xy);
    light_screen_uv = (light_screen_xy - light_screen_xy_fract) / shadow_size;
    
    float depth_value_1 = shadow_sample(shadow_map, shadow_size, light_view_pos,
                                        light_screen_uv, light_depth_test);
    float depth_value_2 = shadow_sample(shadow_map, shadow_size, light_view_pos,
                                        light_screen_uv + float2(shadow_size_div1.x, 0), light_depth_test);
    float depth_value_3 = shadow_sample(shadow_map, shadow_size, light_view_pos,
                                        light_screen_uv + float2(0, shadow_size_div1.y), light_depth_test);
    float depth_value_4 = shadow_sample(shadow_map, shadow_size, light_view_pos,
                                        light_screen_uv + shadow_size_div1, light_depth_test);
    
    float depth_value_mix1 = mix(depth_value_1, depth_value_2, light_screen_xy_fract.x);
    float depth_value_mix2 = mix(depth_value_3, depth_value_4, light_screen_xy_fract.x);
    float lit = mix(depth_value_mix1, depth_value_mix2, light_screen_xy_fract.y);
    return lit;
}

// Using 16-samples of percentage-closer sampling
// The result looks like smooth antialiased shadows
// https://developer.nvidia.com/gpugems/GPUGems/gpugems_ch11.html
float shadow_sample_antialiased_4x4(depth2d<float> shadow_map,
                                    float2 shadow_size,
                                    float2 light_view_pos,
                                    float2 light_screen_uv,
                                    float light_depth_test) {
    float lit = 0.0;
    float x, y;
    float depth_value = 0.0;
    float2 shadow_size_div1 = 1.0 / shadow_size;
    
    for(y = -1.5; y <= 1.51; y += 1.0) {
        for(x = -1.5; x <= 1.51; x += 1.0) {
            float2 offset = float2(x,y) * shadow_size_div1;
            
            depth_value = shadow_map.sample(nearest_clamp_to_edge, light_screen_uv + offset);
            lit += step(light_depth_test, depth_value);
            
            // linear sampling (very slow!)
            /*
            lit += shadow_sample_linear(shadow_map, shadow_size, light_view_pos,
                                        light_screen_uv + offset, light_depth_test);
             */
        }
    }
    return lit * 0.0625;
}

// Using four-samples of percentage-closer sampling
// The result looks like dithered antialiased shadows
// https://developer.nvidia.com/gpugems/GPUGems/gpugems_ch11.html
float shadow_sample_dithered(depth2d<float> shadow_map,
                             float2 shadow_size,
                             float2 light_view_pos,
                             float2 light_screen_uv,
                             float light_depth_test) {
    float lit = 0.0;
    float2 shadow_size_div1 = 1.0 / shadow_size;
    float2 offset = (float2)(fract(light_view_pos * 0.5) > 0.25);
    offset.y += offset.x;  // y ^= x in floating point
    if (offset.y > 1.1)
        offset.y = 0;
    
    constexpr uint num_samples = 4;
    float2 offsets[num_samples];
    offsets[0] = (offset + float2(-1.5, 0.5)) * shadow_size_div1;
    offsets[1] = (offset + float2(0.5, 0.5)) * shadow_size_div1;
    offsets[2] = (offset + float2(-1.5, -1.5)) * shadow_size_div1;
    offsets[3] = (offset + float2(0.5, -1.5)) * shadow_size_div1;
    
    float depth_value = 0;
    depth_value = shadow_map.sample(nearest_clamp_to_edge, light_screen_uv + offsets[0]);
    lit += step(light_depth_test, depth_value);
    depth_value = shadow_map.sample(nearest_clamp_to_edge, light_screen_uv + offsets[1]);
    lit += step(light_depth_test, depth_value);
    depth_value = shadow_map.sample(nearest_clamp_to_edge, light_screen_uv + offsets[2]);
    lit += step(light_depth_test, depth_value);
    depth_value = shadow_map.sample(nearest_clamp_to_edge, light_screen_uv + offsets[3]);
    lit += step(light_depth_test, depth_value);
    
    // linear sampling
    /*
    lit += shadow_sample_linear(shadow_map, shadow_size, light_view_pos,
                                light_screen_uv + offsets[0], light_depth_test);
    lit += shadow_sample_linear(shadow_map, shadow_size, light_view_pos,
                                light_screen_uv + offsets[1], light_depth_test);
    lit += shadow_sample_linear(shadow_map, shadow_size, light_view_pos,
                                light_screen_uv + offsets[2], light_depth_test);
    lit += shadow_sample_linear(shadow_map, shadow_size, light_view_pos,
                                light_screen_uv + offsets[3], light_depth_test);
     */
    lit /= (float)num_samples;
    
    return lit;
}

#pragma mark - Shadow
float get_shadow_lit(depth2d<float> shadow_map,
                     constant light_t &light,
                     constant light_global_t &light_global,
                     float4 world_pos) {
    float lit = 1.0;
    float2 shadow_size = float2(shadow_map.get_width(), shadow_map.get_height());
    
    if(light.cast_shadow) {
        float4 light_view_pos = light.light_view * world_pos;
        float4 light_clip_pos = light_global.light_projection * light_view_pos;
        light_clip_pos /= max(0.001, light_clip_pos.w);
        float2 light_screen_uv = light_clip_pos.xy * 0.5 + 0.5;
        light_screen_uv.y = 1.0 - light_screen_uv.y;
        
        lit = SHADOW_SAMPLE_FUNC(shadow_map,
                                 shadow_size,
                                 light_view_pos.xy,
                                 light_screen_uv,
                                 light_clip_pos.z - light.shadow_bias);
    }
    return lit;
}
