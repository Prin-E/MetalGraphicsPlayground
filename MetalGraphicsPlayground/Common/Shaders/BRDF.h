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
    float anisotropy;
    float n_l;
    float n_v;
    float n_h;
    float h_v;
    float t_h;
    float t_v;
    float t_l;
    float b_h;
    float b_v;
    float b_l;
    
} shading_t;

float fresnel(float f0, float h_v);
float3 fresnel(float3 f0, float h_v);
float geometry_smith(float n_l, float n_v, float a);
float distribution_ggx(float n_h, float a);
float distribution_ggx_anisotropic(float n_h, float a, float anistoropy);

float3 calculate_brdf(shading_t shading);

#endif /* BRDF_h */
