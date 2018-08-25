//
//  Shadow.metal
//  MetalGraphics
//
//  Created by 이현우 on 2016. 7. 3..
//  Copyright © 2016년 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "SharedStructures.h"

using namespace metal;

typedef struct {
    float3 position [[attribute(0)]];
} vertex_in;

typedef struct {
    float4 position [[position]];
} vertex_out;

vertex vertex_out shadowmap_vert(vertex_in v [[stage_in]], constant uniform_t &uniform [[buffer(1)]], constant transform_t &tf [[buffer(2)]]) {
    vertex_out out;
    float4 viewPos = uniform.lightView * tf.model * float4(v.position, 1.0);
    out.position = uniform.lightProjection * viewPos;
    return out;
}

vertex vertex_out izb_eyeviewdepth_vert(vertex_in v [[stage_in]], constant uniform_t &uniform [[buffer(1)]], constant transform_t &tf [[buffer(2)]]) {
    vertex_out out;
    out.position = uniform.projection * uniform.view * tf.model * float4(v.position, 1.0);
    return out;
}

kernel void izb_compute_depth(texture2d<float, access::read> depthTex [[texture(0)]],
                              texture2d<uint> izbHeadTex [[texture(1)]],
                              device float4 &izbBuffer [[buffer(0)]],
                              ushort2 pos [[thread_position_in_grid]]) {
    uint width = izbHeadTex.get_width();
    uint height = izbHeadTex.get_height();
    uint2 bounds(width, height);
    uint2 position = uint2(pos);
    
    threadgroup_barrier(mem_flags::mem_device);
}
