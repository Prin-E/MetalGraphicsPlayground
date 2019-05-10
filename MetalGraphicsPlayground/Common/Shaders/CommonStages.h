//
//  ShaderCommon.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 09/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#ifndef ShaderCommon_h
#define ShaderCommon_h

#include <metal_stdlib>
using namespace metal;

typedef struct {
    float3 pos;
} ScreenVertex;

typedef struct {
    float4 clipPos      [[position]];
    float2 uv;
} ScreenFragment;

vertex ScreenFragment screen_vert(constant ScreenVertex *in [[buffer(0)]],
                                  uint vid [[vertex_id]]);

fragment half4 screen_frag(ScreenFragment in [[stage_in]],
                           texture2d<half> tex [[texture(0)]]);

#endif /* ShaderCommon_h */
