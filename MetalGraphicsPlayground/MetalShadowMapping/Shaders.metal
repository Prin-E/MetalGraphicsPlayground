//
//  Shaders.metal
//  MetalGraphics
//
//  Created by 이현우 on 2015. 12. 6..
//  Copyright © 2015년 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include "SharedStructures.h"

using namespace metal;

// Variables in constant address space
constant float3 light_position = float3(5.0, 5.0, -5.0);
constant float4 ambient_color  = float4(0.0, 0.0, 0.0, 1.0);
constant float4 albedo_color  = float4(0.84, 0.89, 0.92, 1.0);

constexpr sampler s(coord::normalized,
                    address::clamp_to_edge,
                    filter::nearest);

constexpr sampler cube_sampler(coord::normalized,
                    address::repeat,
                    filter::linear);

typedef struct {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
} vertex_in;

typedef struct {
    float4 out_pos [[position]];
    float3 world_pos;
    float3 view_vec;
    float4 light_pos;
    float3 normal;
} vertex_out;

typedef struct {
    float3 position [[attribute(0)]];
} sv_in;

typedef struct {
    float4 position [[position]];
} sv_out;

typedef struct {
    float3 position [[attribute(0)]];
    float2 uv [[attribute(1)]];
} pv_in;

typedef struct {
    float4 position [[position]];
    float3 pos;
    float2 uv;
} pv_out;

vertex sv_out shadow_vert(sv_in v [[stage_in]], constant uniform_t &uniform [[buffer(1)]]) {
    sv_out out;
    out.position = uniform.light * float4(v.position, 1.0);
    return out;
}

vertex vertex_out vert(vertex_in v [[stage_in]], constant uniform_t &uniform [[buffer(1)]]) {
    vertex_out out;
    out.out_pos = uniform.projection * uniform.modelview * float4(v.position, 1.0);
    out.world_pos = v.position - float3(0, 2, 0);
    out.view_vec = -float3(uniform.modelview * float4(v.position, 1.0));
    out.light_pos = uniform.light * float4(v.position, 1.0);
    out.normal = float3(uniform.modelview * float4(v.normal, 0.0));
    
    return out;
}

float get_shadow(float4 lightPos, depth2d<float> shadowMap) {
    lightPos.x = lightPos.x * 0.5 + 0.5;
    lightPos.y = lightPos.y * 0.5 + 0.5;
    lightPos.y = 1.0 - lightPos.y;
    
    float shadow = 0.0;
    const float gauss[25] = {
        0.003, 0.013, 0.022, 0.013, 0.003,
        0.013, 0.059, 0.097, 0.059, 0.013,
        0.022, 0.097, 0.159, 0.097, 0.022,
        0.013, 0.059, 0.097, 0.059, 0.013,
        0.003, 0.013, 0.022, 0.013, 0.003
    };
    
    for(int u = 0; u < 5; u++) {
        for(int v = 0; v < 5; v++) {
            float2 uv = lightPos.xy + float2(u-2,v-2) * 0.001;
            if(uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
                float depth = shadowMap.sample(s,uv);
                float z = lightPos.z;
                if(depth < z - 0.0175) {
                    shadow += gauss[v*5+u];
                    //shadow += 0.025;
                }
            }
        }
    }
    return shadow;
}

fragment float4 frag_cubeMapPlane(vertex_out v [[stage_in]],
                     depth2d<float> shadowMap [[texture(0)]],
                     texturecube<float> cubeMap [[texture(1)]],
                     constant uniform_t &uniform [[buffer(1)]]) {
    
    float4 lightPos = v.light_pos;
    float w = max(0.0001, lightPos.w);
    lightPos /= w;
    
    float3 p = v.world_pos;
    p.z = -p.z;
    float4 color = cubeMap.sample(cube_sampler, float3(p));
    float shadow = get_shadow(lightPos, shadowMap);
    color = color * (1.0 - shadow);
    return color;
}

fragment float4 frag(vertex_out v [[stage_in]],
                     depth2d<float> shadowMap [[texture(0)]],
                     texturecube<float> cubeMap [[texture(1)]],
                     constant uniform_t &uniform [[buffer(1)]]) {
    float4 lightPos = v.light_pos;
    float w = max(0.0001, lightPos.w);
    lightPos /= w;
    
    float3 half_vec = normalize(normalize(light_position) + normalize(v.view_vec));
    float n_dot_l = dot(normalize(v.normal), normalize(light_position));
    float l_dot_h = dot(half_vec, normalize(light_position));
    float n_dot_v = dot(normalize(v.view_vec), normalize(v.normal));
    float n_dot_h = dot(half_vec, normalize(v.normal));
    n_dot_l = fmax(0.0, n_dot_l);
    l_dot_h = fmax(0.0, l_dot_h);
    n_dot_v = fmax(0.0, n_dot_v);
    n_dot_h = fmax(0.0, n_dot_h);
    
    // diffuse
    float4 diffuse = float4(albedo_color * n_dot_l / 3.14);
    float fd90 = 0.5 + 2.0 * l_dot_h * l_dot_h * uniform.roughness;
    diffuse = diffuse * (1.0 + (fd90 - 1.0) * pow(1 - n_dot_l, 5.0)) *
    (1.0 + (fd90 - 1.0) * pow(1 - n_dot_v, 5.0));
    
    // specular
    float a = uniform.roughness * uniform.roughness;
    float a2 = a * a;
    
    float d = ( n_dot_h * a2 - n_dot_h ) * n_dot_h + 1;	// 2 mad
    float d_ggx = a2 / ( 3.14159*d*d );					// 4 mul, 1 rcp
    
    float d_c = 1.0;
    float d_gtr = d_c / fmax(0.01, pow(a * n_dot_h * n_dot_h + (1.0 - n_dot_h * n_dot_h), 1.0));
    
    float f0 = 0.075;
    float f_schlick = f0 + (1.0 - f0) * pow(1.0 - l_dot_h, 5.0);
    
    /*
    float k = a * 0.5;
    float Vis_SchlickV = n_dot_v * (1 - k) + k;
    float Vis_SchlickL = n_dot_l * (1 - k) + k;
    float g_schlick = 0.25 / ( Vis_SchlickV * Vis_SchlickL );
    */
    
    //float g_a2 = a2;
    float g_a2 = (0.5 + 0.5 * uniform.roughness) * (0.5 + 0.5 * uniform.roughness);
    float g_ggx = 2 * n_dot_v / (n_dot_v + sqrt(g_a2 + (1 - g_a2) * n_dot_v * n_dot_v));
    
    float specular = d_ggx * f_schlick * g_ggx;// / (4 * n_dot_l * n_dot_v);
    
    // shadow
    float shadow = get_shadow(lightPos, shadowMap);
    diffuse = diffuse * (1.0 - shadow * g_a2) * (1.0 - uniform.metalic);
    specular = specular * (1.0 - shadow);
    
    // color
    float4 color = ambient_color + diffuse * (1.0 - specular) + specular * albedo_color;
    //float4 color = specular * albedo_color;
    
    float3 p = v.world_pos;
    p.z = -p.z;
    color = color * g_a2 + cubeMap.sample(cube_sampler, float3(p)) * (1.25 - g_a2) * (1.0 - shadow * g_a2) * uniform.metalic;
    
    return color;
}

vertex pv_out shadow_preview_vert(pv_in v [[stage_in]]) {
    pv_out out;
    out.position = float4(v.position, 1.0);
    out.pos = v.position;
    out.uv = float2(v.uv.x, 1.0 - v.uv.y);
    return out;
}

fragment half4 shadow_preview_frag(pv_out v [[stage_in]], constant uniform_t &uniform [[buffer(1)]], depth2d<float> shadowMap [[texture(0)]]) {
    half4 color = half4(1.0, 1.0, 1.0, 1.0);
    float depth = shadowMap.sample(s, v.uv);
    color = color * depth;
    color.a = 1.0;
    return color;
}
