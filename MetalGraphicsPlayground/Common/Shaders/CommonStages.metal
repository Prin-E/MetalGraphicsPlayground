//
//  ShaderCommon.metal
//  MetalDeferred
//
//  Created by 이현우 on 09/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include "CommonStages.h"
#include "CommonVariables.h"

using namespace metal;

vertex ScreenFragment screen_vert(uint vid [[vertex_id]]) {
    // from "Vertex Shader Tricks" by AMD - GDC 2014
    ScreenFragment out;
    out.clip_pos = float4((float)(vid / 2) * 4.0 - 1.0,
                          (float)(vid % 2) * 4.0 - 1.0,
                          0.0,
                          1.0);
    out.uv = float2((float)(vid / 2) * 2.0, 1.0 - (float)(vid % 2) * 2.0);
    return out;
}

fragment half4 screen_frag(ScreenFragment in [[stage_in]],
                           texture2d<half> tex [[texture(0)]]) {
    half4 out_color = tex.sample(linear, in.uv);
    return out_color;
}
