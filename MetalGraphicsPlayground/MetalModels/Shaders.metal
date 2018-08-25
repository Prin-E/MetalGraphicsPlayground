//
//  Shaders.metal
//  MetalGraphics
//
//  Created by 이현우 on 2015. 9. 16..
//  Copyright © 2015년 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "SharedStructures.h"
using namespace metal;

// Variables in constant address space
constant float3 light_position = float3(0.0, 1.0, -1.0);
constant float4 ambient_color  = float4(0.18, 0.24, 0.8, 1.0);
constant float4 diffuse_color  = float4(0.4, 0.4, 1.0, 1.0);

typedef struct {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
} vertex_in;

typedef struct {
    float4 position [[position]];
    float4 normal;
    half4 color;
} vertex_out;

vertex vertex_out vert(vertex_in v [[stage_in]], constant uniform_t &uniform [[buffer(1)]]) {
    vertex_out out;
    out.position = uniform.projection * uniform.modelview * float4(v.position, 1.0);
    out.normal = uniform.modelview * float4(v.normal, 0.0);
    
    float4 eye_normal = normalize(uniform.modelview * float4(v.normal, 0.0));
    float n_dot_l = dot(eye_normal.rgb, normalize(light_position));
    n_dot_l = fmax(0.0, n_dot_l);
    
    out.color = half4(ambient_color + diffuse_color * n_dot_l);
    
    return out;
}

fragment half4 frag(vertex_out v [[stage_in]]) {
    return v.color;
}
