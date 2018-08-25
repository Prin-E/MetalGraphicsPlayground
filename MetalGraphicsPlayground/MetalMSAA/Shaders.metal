//
//  Shaders.metal
//  MetalGraphics
//
//  Created by 이현우 on 2015. 9. 19..
//  Copyright © 2015년 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include "SharedStructures.h"

using namespace metal;

typedef struct {
    float3 position [[attribute(0)]];
    float2 uv [[attribute(1)]];
} v_in;

typedef struct {
    float4 position [[position]];
    float2 uv;
} f_in;

typedef struct {
    float4 color [[color(0)]];
} f_out;

constexpr sampler s(coord::normalized,
                    address::clamp_to_edge,
                    filter::linear);
constexpr sampler s2(coord::normalized,
                    address::clamp_to_edge,
                    filter::linear);


vertex f_in vert(v_in in [[stage_in]], device uniform_t &uniform [[buffer(1)]]) {
    f_in out;
    out.position = uniform.modelview * float4(in.position, 1.0f);
    out.uv = in.uv;
    return out;
}

fragment float4 frag(f_in in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
    float4 color = tex.sample(s2, in.uv);
    return color;
}

vertex f_in vert2(v_in in [[stage_in]], device uniform_t &uniform [[buffer(1)]]) {
    f_in out;
    out.position = uniform.projection * float4(in.position, 1.0f);
    out.uv = in.uv;
    return out;
}

fragment f_out frag2(f_in in [[stage_in]], texture2d_ms<float> tex [[texture(0)]]) {
    f_out out;
    float4 color = float4(0.0f, 0.0f, 0.0f, 0.0f);

    uint sc = 8;
    uint2 pixel = uint2(in.uv.x * 1000, in.uv.y * 1000);
    for(uint i = 0; i < sc; i++) {
        float4 sample = tex.read(pixel, i);
        color += sample;
    }
    color /= sc;
//    return color;
    
    out.color = color;
    return out;
}