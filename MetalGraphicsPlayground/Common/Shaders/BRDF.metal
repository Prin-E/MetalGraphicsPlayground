//
//  BRDF.metal
//  MetalDeferred
//
//  Created by 이현우 on 06/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include "BRDF.h"
#include "CommonVariables.h"
#include "CommonMath.h"

float fresnel(float f0, float h_v) {
    return f0 + (1.0 - f0) * pow(1.0 - h_v, 5.0f);
}

float3 fresnel(float3 f0, float h_v) {
    return f0 + (1.0 - f0) * pow(1.0 - h_v, 5.0f);
}

inline float geometry_schlick(float n_v, float k) {
    return n_v / max(0.00001, n_v * (1.0 - k) + k);
}

float geometry_smith(float n_l, float n_v, float k) {
    return geometry_schlick(n_l, k) * geometry_schlick(n_v, k);
}

float distribution_ggx(float n_h, float a) {
    float a_sqr = sqr(a);
    float d = n_h * (a_sqr * n_h - n_h) + 1;
    return a_sqr / max(0.00001, PI * d * d);
}

float3 calculate_brdf(shading_t shading) {
    // NDF
    float a = sqr(shading.roughness);
    float g_s = geometry_smith(shading.n_l, shading.n_v, sqr(a+1) * 0.125);
    float d_s = distribution_ggx(shading.n_h, a);
    float3 f_s = fresnel(mix(0.04, shading.albedo, shading.metalic), shading.h_v);
    
    // diffuse, specular
    float c_d = PI_DIV;
    float3 c_s = g_s * d_s * f_s / max(0.00001, 4.0 * shading.n_l * shading.n_v);
    
    // output
    float3 k_d = (float3(1.0) - f_s) * (1.0 - shading.metalic);
    float3 out_color = k_d * c_d + c_s;
    out_color *= shading.albedo * shading.light * shading.n_l;
    return out_color;
    
}
