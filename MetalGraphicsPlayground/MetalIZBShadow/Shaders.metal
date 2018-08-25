//
//  Shaders.metal
//  MetalGraphics
//
//  Created by 이현우 on 2016. 6. 19..
//  Copyright © 2016년 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "SharedStructures.h"
using namespace metal;

// Variables in constant address space
constant float4 ambient_color  = float4(0.1, 0.1, 0.1, 1.0);
constexpr sampler s(coord::normalized,
                    address::clamp_to_edge,
                    filter::nearest);

typedef struct {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 uv [[attribute(2)]];
} vertex_in;

typedef struct {
    float4 position [[position]];
    float2 uv;
    float4 viewPos;
    float4 lightPos;
    float4 normal;
} vertex_out;

float get_shadow(float4 lightPos, depth2d<float> shadowMap);

vertex vertex_out vert(vertex_in v [[stage_in]], constant uniform_t &uniform [[buffer(1)]], constant transform_t &tf [[buffer(2)]]) {
    vertex_out out;
    float4 viewPos = uniform.view * tf.model * float4(v.position, 1.0);
    float4 lightPos = uniform.lightProjection * uniform.lightView * tf.model * float4(v.position, 1.0);
    float4 viewNormal = normalize(uniform.view * tf.model * float4(v.normal, 0.0));
    
    lightPos /= max(0.001, lightPos.w);
    lightPos.xy = lightPos.xy * 0.5 + 0.5;
    lightPos.y = 1.0 - lightPos.y;
    
    out.position = uniform.projection * viewPos;
    out.viewPos = viewPos;
    out.lightPos = lightPos;
    out.normal = viewNormal;
    out.uv = v.uv;
    return out;
}

fragment half4 frag(vertex_out v [[stage_in]],
                    depth2d<float> shadowMap [[texture(0)]],
                    constant uniform_t &uniform [[buffer(1)]],
                    constant transform_t &tf [[buffer(2)]]) {
    float n_dot_l = dot(v.normal.rgb, normalize(uniform.view * uniform.lightPos - v.viewPos).rgb);
    n_dot_l = fmax(0.0, n_dot_l);
    half4 color = half4(ambient_color + uniform.lightColor * uniform.lightIntensity * n_dot_l * tf.albedo);
    color = pow(color, 1.0/2.2);
    
    float4 lightPos = v.lightPos;
    float depth = shadowMap.sample(s, lightPos.xy);
    
    if(depth < lightPos.z - 0.005)
        color.xyz *= 0.5;
    
    return color;
}

