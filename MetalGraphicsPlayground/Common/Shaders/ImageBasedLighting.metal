//
//  BRDF.metal
//  MetalDeferred
//
//  Created by 이현우 on 06/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include "SharedStructures.h"
#include "CommonStages.h"
#include "CommonMath.h"
#include "CommonVariables.h"
#include "BRDF.h"

using namespace metal;

typedef struct {
    float4 clip_pos [[position]];
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
    out.clip_pos = float4(pos, 1.0);
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
    float delta = 0.025;
    for(float phi = 0.0; phi < PI * 2.0; phi += delta) {
        for(float theta = 0.0; theta < 0.5 * PI; theta += delta) {
            float3 temp = cos(phi) * right + sin(phi) * up;
            float3 sampleVector = cos(theta) * normal + sin(theta) * temp;
            sumColor += float3(cubeMap.sample(linear, sampleVector).rgb) * cos(theta) * sin(theta);
            index++;
        }
    }
    return half4(half3(3.14159 * sumColor / index), 1.0);
}

#pragma mark - Prefiltered specular
// ===============================================================================================
// http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf
// ===============================================================================================
float3 importance_sample_ggx(float2 Xi, float roughness, float3 n)
{
    float a = roughness * roughness;
    
    float phi = PI_2 * Xi.x;
    float cos_theta = sqrt((1 - Xi.y) / (1 + (a * a - 1) * Xi.y));
    float sin_theta = sqrt(1 - cos_theta * cos_theta);
    
    float3 H;
    H.x = sin_theta * cos(phi);
    H.y = sin_theta * sin(phi);
    H.z = cos_theta;
    
    float3 up = abs(n.z) < 0.5 ? float3(0, 0, 1) : float3(1, 0, 0);
    float3 tangent_x = normalize(cross(up, n));
    float3 tangent_y = normalize(cross(n, tangent_x));
    
    // Tangent to world space
    return tangent_x * H.x + tangent_y * H.y + n * H.z;
}

// ================================================================================================
// http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf
// ================================================================================================
float3 prefilter_environment_map(float roughness, float3 R, texturecube<half> cubeMap)
{
    float3 N = R;
    float3 V = R;
    
    const uint resolution = cubeMap.get_width();
    const uint num_mip_level = cubeMap.get_num_mip_levels();
    const float texel = 4.0 * PI / (num_mip_level * resolution * resolution);
    const uint num_samples = 1024;
    
    float3 prefiltered_color = float3(0);
    float weight = 0.0;
    for (uint i = 0; i < num_samples; i++)
    {
        float2 Xi = hammersley(i, num_samples);
        float3 H = importance_sample_ggx(Xi, roughness, N);
        float3 L = 2 * dot(V, H) * H - V;
        float n_l = saturate(dot(N, L));
        float n_h = saturate(dot(N, H));
        float h_v = saturate(dot(H, V));
        
        if (n_l > 0)
        {
            float d = distribution_ggx(n_h, roughness * roughness);
            float pdf = (d * n_h / (4.0 + h_v)) + 0.00001;
            
            float sample = 1.0 / (float(num_samples) * pdf + 0.00001);
            float mip_level = roughness == 0.0 ? 0.0 : 0.5 * log2(sample / texel);
            
            //prefiltered_color += float3(cubeMap.sample(linear, L).rgb) * n_l;
            prefiltered_color += float3(cubeMap.sample(linear, L, level(mip_level)).rgb) * n_l;
            weight += n_l;
        }
    }
    return prefiltered_color / max(0.00001, weight);
}

fragment float4 prefiltered_specular_frag(EnvironmentFragment in [[stage_in]],
                                          texturecube<half> cubeMap [[texture(0)]],
                                          constant prefiltered_specular_option_t &option [[buffer(1)]]) {
    float3 normal = normalize(in.pos.xyz);
    float roughness = option.roughness;
    return float4(prefilter_environment_map(roughness, normal, cubeMap), 1.0);
}

#pragma mark - BRDF Lookup
float2 integrate_brdf(float n_v, float roughness)
{
    float3 V;
    
    V.x = sqrt(1.0f - n_v * n_v);   // Sin
    V.y = 0;
    V.z = n_v;                      // Cos
    
    float A = 0;
    float B = 0;
    
    float3 N = float3(0.0f, 0.0f, 1.0f);
    float k = sqr(roughness) * 0.5;
    
    const uint num_samples = 1024;
    for (uint i = 0; i < num_samples; i++)
    {
        float2 Xi = hammersley(i, num_samples);
        float3 H = importance_sample_ggx(Xi, roughness, N);
        float3 L = 2.0f * dot(V, H) * H - V;
        
        float n_l = saturate(L.z);
        float n_h = saturate(H.z);
        float v_h = saturate(dot(V, H));
        
        if (n_l > 0)
        {
            float g = geometry_smith(n_l, n_v, k);
            float g_vis = g * v_h / (n_h * n_v);
            float f_c = pow(1 - v_h, 5);
            A += (1.0 - f_c) * g_vis;
            B += f_c * g_vis;
        }
    }
    
    return float2(A, B) / num_samples;
}

fragment float4 brdf_lookup_frag(ScreenFragment in [[stage_in]]) {
    float2 uv = in.uv;
    return float4(integrate_brdf(uv.x, uv.y), 0, 1);
}
