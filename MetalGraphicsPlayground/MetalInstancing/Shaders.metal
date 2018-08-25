//
//  Shaders.metal
//  MetalInstancing
//
//  Created by 이현우 on 2017. 7. 6..
//  Copyright © 2017년 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include "SharedStructures.h"

using namespace metal;

typedef struct {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 uv [[attribute(2)]];
} vertex_in;

typedef struct {
    float4 position [[position]];
} vertex_out;

vertex vertex_out vert(vertex_in v [[stage_in]], constant instance_buffer_t *buffer [[buffer(1)]], uint instance_id [[instance_id]]) {
    vertex_out o;
    float3 scale = buffer->scale[instance_id];
    float3 pos = buffer->pos[instance_id];
    float4x4 mat = float4x4(float4(scale.x, 0, 0, 0), float4(0, scale.y, 0, 0), float4(0, 0, scale.z, 0), float4(pos, 1));
    o.position = mat * float4(v.position, 1.0);
//    o.position = float4(v.position + buffer->pos[instance_id], 1.0);
    return o;
}

fragment half4 frag(vertex_out v [[stage_in]]) {
    return half4(1,1,1,1);
}
