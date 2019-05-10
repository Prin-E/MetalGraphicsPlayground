//
//  BRDF.metal
//  MetalDeferred
//
//  Created by 이현우 on 06/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include "CommonStages.h"
#include "CommonMath.h"
#include "CommonVariables.h"

using namespace metal;

half4 irradiance_filter(texture2d<half> envMap, float2 uv);

fragment half4 irradiance_frag(ScreenFragment in [[stage_in]],
                               texture2d<half> envMap [[texture(0)]]) {
    half4 out_color = irradiance_filter(envMap, in.uv);
    return out_color;
}

half4 irradiance_filter(texture2d<half> envMap, float2 uv)
{
    float3 sum = float3(0, 0, 0);
    float index = 0;
    
    for(uint i = 0, N = 1024; i < N; i++) {
        float2 Xi = hammersley(i, N);
        Xi.x = 0.5 * (Xi.x - 0.5);
        Xi.y = Xi.y - 0.5;
        
        float2 sample_uv = uv + Xi;
        if(sample_uv.y >= 1.0) {
            sample_uv.y = 2.0 - sample_uv.y;
            sample_uv.x += 0.5;
        }
        else if(sample_uv.y <= 0.0) {
            sample_uv.y = abs(sample_uv.y);
            sample_uv.x += 0.5;
        }
        
        float theta = (1.0 - abs(Xi.y) * 2.0) * PI * 0.5;
        
        sum += float3(envMap.sample(linear, sample_uv).rgb) * cos(theta) * sin(theta);
        index++;
    }
    return half4(half3(3.14159 * sum / index), 1.0);
}
