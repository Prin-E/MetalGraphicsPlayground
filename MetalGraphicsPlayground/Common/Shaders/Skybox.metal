//
//  Skybox.metal
//  MetalDeferred
//
//  Created by 이현우 on 09/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include "SharedStructures.h"
#include "CommonVariables.h"
#include "CommonMath.h"

using namespace metal;

typedef struct {
    float3 pos;
} SkyboxVertex;

typedef struct {
    float4 clipPos      [[position]];
    float3 pos;
} SkyboxFragment;

// Skybox
vertex SkyboxFragment skybox_vert(constant SkyboxVertex *in [[buffer(0)]],
                                  constant camera_props_t &cameraProps [[buffer(1)]],
                                  uint vid [[vertex_id]]) {
    SkyboxFragment out;
    float3 pos = in[vid].pos;
    float c = cameraProps.projection[2][2];
    float d = cameraProps.projection[3][2];
    float far = d / (1 - c);
    out.pos = pos;
    out.clipPos = cameraProps.projection * cameraProps.rotation * float4(pos * far * 0.5, 1.0);
    return out;
}

fragment half4 skybox_frag(SkyboxFragment in [[stage_in]],
                           texturecube<half> cubeMap [[texture(0)]]) {
    half4 out_color = half4(cubeMap.sample(linear, normalize(in.pos)).xyz, 0.0);
    return out_color;
}
