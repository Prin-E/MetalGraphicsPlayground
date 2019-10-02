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
    float4 clip_pos      [[position]];
    float2 uv;
} ScreenFragment;

#endif /* ShaderCommon_h */
