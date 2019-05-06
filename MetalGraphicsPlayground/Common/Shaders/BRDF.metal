//
//  BRDF.metal
//  MetalDeferred
//
//  Created by 이현우 on 06/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include "BRDF.h"

constant constexpr float PI = 3.14159265;

inline float sqr(float f0) {
    return f0 * f0;
}

inline float fresnel(float f0, float n_h) {
    return f0 + (1.0 - f0) * pow(n_h, 5.0f);
}

inline float geometry_schlick(float n_v, float a) {
    float k = sqr(a + 1.0) * 0.125;
    return n_v / (n_v * (1.0 - k) + k);
}

inline float geometry_smith(float n_l, float n_v, float a) {
    return geometry_schlick(n_l, a) * geometry_schlick(n_v, a);
}

inline float distribution_ggx(float n_h, float a) {
    float a_sqr = sqr(a);
    float d = n_h * (a_sqr * n_h - n_h) + 1;
    return a_sqr / (PI * d * d);
}

float3 diffuse(shading_t shading) {
    return shading.albedo * shading.light * shading.n_l / PI;
}

float3 specular(shading_t shading) {
    float r = shading.roughness;
    float a = sqr(r);
    float f_s = fresnel(0.2, shading.n_h);
    float g_s = geometry_smith(shading.n_h, shading.n_h, a);
    float d_s = distribution_ggx(shading.n_h, a);
    return f_s * g_s * d_s * shading.albedo * shading.light / (4.0 * shading.n_l * shading.n_v);
}
