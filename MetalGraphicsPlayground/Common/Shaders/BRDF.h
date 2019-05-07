//
//  BRDF.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 07/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#ifndef BRDF_h
#define BRDF_h

#include <metal_stdlib>
using namespace metal;

typedef struct {
    float3 albedo;
    float3 light;
    float roughness;
    float metalic;
    float n_l;
    float n_v;
    float n_h;
    float h_v;
} shading_t;

float3 calculate_brdf(shading_t shading);

#endif /* BRDF_h */
