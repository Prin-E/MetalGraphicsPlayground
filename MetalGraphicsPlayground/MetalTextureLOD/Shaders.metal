//
//  Shaders.metal
//  MetalTest
//
//  Created by 이현우 on 2015. 8. 8..
//  Copyright (c) 2015년 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "SharedStructures.h"

using namespace metal;

typedef struct
{
    float3 position [[attribute(0)]];
    float2 uv [[attribute(1)]];
} vertex_t;

typedef struct {
    float4 position [[position]];
    float2 uv;
    half4  color;
} ColorInOut;

typedef struct {
    half4 albedo [[color(0)]];
    half4 rt [[color(1)]];
} FragOutput;

typedef struct __attribute__((__aligned__(256)))
{
    matrix_float4x4 modelview_projection_matrix;
    matrix_float4x4 normal_matrix;
    float time;
    atomic_int a;
} uniforms_t_metal;

float filterwidth(float2 v);

// Vertex shader function
vertex ColorInOut vert(vertex_t vertex_array [[stage_in]], constant uniforms_t &uniform [[buffer(1)]])
{
    ColorInOut out;
    
    float4 in_position = float4(vertex_array.position, 1.0);
    out.position = uniform.modelview_projection_matrix * uniform.normal_matrix * in_position;
    out.uv = vertex_array.uv;
    
    return out;
}

vertex ColorInOut vert2(vertex_t vertex_array [[stage_in]])
{
    ColorInOut out;
    
    float4 in_position = float4(vertex_array.position, 1.0);
    out.position = in_position;
    
    return out;
}

float filterwidth(float2 v) {
    float2 fw = max(abs(dfdx(v)), abs(dfdy(v)));
    return max(fw.x, fw.y);
}

// Fragment shader function
fragment FragOutput frag(ColorInOut in [[stage_in]],
                         texture2d<float> texture [[texture(0)]],
                         sampler samp [[sampler(0)]],
                         constant uniforms_t &uniform [[buffer(1)]])
{
    FragOutput output;
    float4 in_color = texture.sample(samp, in.uv, level(uniform.time));
    output.albedo = half4(in_color.r, in_color.g, in_color.b, 1.0);
    output.rt = output.albedo * 0.5;
    
    /*
    output.albedo = fmod(floor(in.uv.x) + floor(in.uv.y), 2) < 1.0 ? half4(0,0,0,1):half4(1,1,1,1);
    float width = filterwidth(in.uv);
    float2 p0 = in.uv - 0.5 * width, p1 = in.uv + 0.5 * width;
    float2 b0 = floor(p0*0.5)+2.0*max(p0*0.5-floor(p0*0.5)-0.5,0.0);
    float2 b1 = floor(p1*0.5)+2.0*max(p1*0.5-floor(p1*0.5)-0.5,0.0);
    float2 i = (b1-b0)/width;
    output.albedo = half4(1,1,1,0)*(i.x * i.y + (1 - i.x) * (1 - i.y)) + half4(0,0,0,1);
    */
    
    return output;
}

fragment half4 frag2(ColorInOut in [[stage_in]],
                          texture2d<float> texture [[texture(0)]],
                          sampler samp [[sampler(0)]])
{
    float4 in_color = texture.sample(samp, in.uv);
    return half4(in_color.r, in_color.g, in_color.b, 1.0);
}
