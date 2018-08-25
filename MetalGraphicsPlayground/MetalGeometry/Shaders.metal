//
//  Shaders.metal
//  MetalTest
//
//  Created by 이현우 on 2015. 8. 8..
//  Copyright (c) 2015년 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>

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

// Vertex shader function
vertex ColorInOut vert(vertex_t vertex_array [[stage_in]])
{
    ColorInOut out;
    
    out.position = float4(vertex_array.position, 1.0);
    out.uv = vertex_array.uv;
    
    return out;
}

// Fragment shader function
fragment FragOutput frag(ColorInOut in [[stage_in]],
                         texture2d<float> texture [[texture(0)]],
                         sampler samp [[sampler(0)]])
{
    FragOutput output;
    float4 in_color = texture.sample(samp, in.uv);
    output.albedo = half4(in_color.r, in_color.g, in_color.b, 1.0);
    output.rt = output.albedo * 0.5;
    return output;
}