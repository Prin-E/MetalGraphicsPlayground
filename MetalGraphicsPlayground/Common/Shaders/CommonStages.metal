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

vertex ScreenFragment screen_vert(constant ScreenVertex *in [[buffer(0)]],
                                  uint vid [[vertex_id]]) {
    ScreenFragment out;
    out.clip_pos = float4(in[vid].pos, 1.0);
    out.uv = (out.clip_pos.xy + 1.0) * 0.5;
    out.uv.y = 1.0 - out.uv.y;
    return out;
}

fragment half4 screen_frag(ScreenFragment in [[stage_in]],
                            texture2d<half> tex [[texture(0)]]) {
    
    half4 out_color = tex.sample(linear, in.uv);
    return out_color;
}
