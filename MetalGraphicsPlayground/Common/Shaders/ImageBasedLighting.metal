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

typedef struct {
    float4 clipPos [[position]];
    float3 pos;
    uint rid [[render_target_array_index]];
} EnvironmentFragment;

#pragma mark - Environment
vertex EnvironmentFragment environment_vert(constant float3 *in [[buffer(0)]],
                                            constant float3 *cubeVertices [[buffer(1)]],
                                            uint vid [[vertex_id]],
                                            uint iid [[instance_id]]) {
    EnvironmentFragment out;
    float3 pos = in[vid];
    out.clipPos = float4(pos, 1.0);
    out.pos = cubeVertices[6*iid+vid];
    out.rid = iid;
    return out;
}

fragment half4 environment_frag(EnvironmentFragment in [[stage_in]],
                                texture2d<half> equirectangularMap [[texture(0)]]) {
    float2 uv = sample_spherical(normalize(in.pos.xyz));
    half4 out_color = equirectangularMap.sample(linear, uv);
    return out_color;
}

#pragma mark - Irradiance
half4 irradiance_filter(texturecube<half> envMap, float3 normal);

fragment half4 irradiance_frag(EnvironmentFragment in [[stage_in]],
                               texturecube<half> environmentMap [[texture(0)]]) {
    half4 out_color = irradiance_filter(environmentMap, normalize(in.pos.xyz));
    return out_color;
}

half4 irradiance_filter(texturecube<half> cubeMap, float3 normal)
{
    float3 up = float3(0, 1, 0);
    float3 right = normalize(cross(up,normal));
    up = cross(normal,right);
    
    float3 sumColor = float3(0, 0, 0);
    float index = 0;
    
    
    float delta = 0.0125;
    for(float phi = 0.0; phi < PI * 2.0; phi += delta) {
        for(float theta = 0.0; theta < 0.5 * PI; theta += delta) {
            float3 temp = cos(phi) * right + sin(phi) * up;
            float3 sampleVector = cos(theta) * normal + sin(theta) * temp;
            sumColor += float3(cubeMap.sample(linear, sampleVector).rgb) * cos(theta) * sin(theta);
            index++;
        }
    }
    
    /*
    // hammersley point sampling
    for(uint i = 0, N = 4096; i < N; i++) {
        float2 Xi = hammersley(i, N);
        
        float phi = PI_2 * Xi.x;
        float theta = Xi.y * PI * 0.5;
        
        float3 temp = cos(phi) * right + sin(phi) * up;
        float3 sampleVector = cos(theta) * normal + sin(theta) * temp;
        sumColor += float3(cubeMap.sample(linear, sampleVector).rgb) * cos(theta) * sin(theta);
        index++;
    }
     */
    return half4(half3(3.14159 * sumColor / index), 1.0);
}
