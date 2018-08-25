//
//  Shaders.metal
//  MetalGraphics
//
//  Created by 이현우 on 2016. 12. 20..
//  Copyright © 2016년 Prin_E. All rights reserved.
//

#include <metal_stdlib>
#include "SharedStructures.h"
#include "BRDF.h"
using namespace metal;

constexpr sampler s(coord::normalized,
                    address::clamp_to_edge,
                    filter::linear,
                    mip_filter::linear);

// Variables in constant address space
constant float3 light_position = float3(0.0, 1.0, -1.0);
//constant float4 ambient_color  = float4(0.18, 0.24, 0.8, 1.0);
constant float4 diffuse_color  = float4(0.2, 0.34, 0.4, 1.0);

constant half4 dielectricSpec = half4(0.220916301, 0.220916301, 0.220916301, 1.0 - 0.220916301);

typedef struct {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 uv [[attribute(2)]];
} vertex_in;

float3 cubeMapLookup(float3 origin, float3 rayDir, float3 boxCenter, float3 boxExtents);

typedef struct {
    float4 position [[position]];
    float3 localPos;
    float3 worldPos;
    float4 normal;
    float3 normal2;
    float3 viewVec;
    float3 viewNormal;
    float3 normal3;
    half4 color;
} vertex_out;

typedef struct {
    float4 position [[position]];
    float3 localPos;
    float3 normal;
} irradiance_vertex_out;

typedef struct {
    float4 position [[position]];
    float3 localPos;
    float3 normal;
    float2 uv;
    float3 viewVector;
} pmrem_vertex_out;

typedef struct {
    float4 position [[position]];
    float2 uv;
} lut_vertex_out;


float3 GetNormal(uint face, float2 uv);

vertex vertex_out vert(vertex_in v [[stage_in]], constant uniform_t &uniform [[buffer(1)]]) {
    vertex_out out;
    out.localPos = v.position;
    out.worldPos = float3(uniform.model * float4(v.position, 1.0));
    out.position = uniform.projection * uniform.view * uniform.model * float4(v.position, 1.0);    
    out.normal = normalize(uniform.view * uniform.model * float4(v.normal, 0.0));
    out.normal2 = reflect((uniform.view * uniform.model * float4(v.position, 1.0)).xyz, normalize(out.normal.xyz));
    out.normal2 = (uniform.modelviewInverse * float4(out.normal2, 0)).xyz;
    
    float4 viewVec4 = uniform.view * uniform.model * float4(v.position, 1.0);
    out.viewVec = -viewVec4.xyz / viewVec4.w;
    out.viewNormal = float3(uniform.view * uniform.model * float4(v.normal, 0.0));
    
    float n_dot_l = dot(out.normal.rgb, normalize(light_position));
    n_dot_l = fmax(0.0, n_dot_l);
    
    out.color = half4(/*ambient_color + */diffuse_color * n_dot_l);
    
    return out;
}

float3 cubeMapLookup(float3 origin, float3 rayDir, float3 boxCenter, float3 boxExtents) {
    float3 p = origin - boxCenter;
    
    float3 t1 = (boxExtents - p) / rayDir;
    float3 t2 = (-boxExtents - p) / rayDir;
    
    float3 tMax = max(t1, t2);
    
    float t = min(tMax.x, min(tMax.y, tMax.z));
    
    return p + t * rayDir;
}

fragment half4 frag(vertex_out v [[stage_in]], texturecube<half> cubeMap [[texture(0)]]) {
    half4 c = cubeMap.sample(s, normalize(v.localPos));
    //c = c * v.color;
    c.a = v.color.a;
    return c;
}

fragment half4 frag2(vertex_out v [[stage_in]],
                     constant app_info_t &appInfo [[buffer(0)]],
                     texturecube<half> cubeMap [[texture(0)]],
                     texturecube<half> irradianceMap [[texture(1)]],
                     texturecube<half> PMREM [[texture(2)]],
                     texture2d<float> LUT [[texture(3)]]) {
    float3 viewVec = normalize(v.normal2);
    
    half4 c = irradianceMap.sample(s, cubeMapLookup(v.worldPos, viewVec, float3(0,0,0), float3(1,1,1)));
    //half4 c2 = PMREM.sample(s, cubeMapLookup(v.worldPos, viewVec, float3(0,0,0), float3(1,1,1)), level(appInfo.time));
    
    half metalic = half(appInfo.metalic);
    half4 albedo = half4(appInfo.albedo);
    half3 c3 = ApproximateSpecularIBL(half3(1,1,1), cubeMapLookup(v.worldPos, viewVec, float3(0,0,0), float3(1,1,1)),
                                      dot(v.normal.xyz, v.viewVec),
                                      appInfo.roughness,
                                      PMREM, LUT);
    half4 c4 = half4(c3,0) * mix(dielectricSpec, albedo, metalic);
    c = c * albedo;
    c.rgb = c.rgb * (dielectricSpec.a - metalic * dielectricSpec.a);
    
    //half4 c2 = cubeMap.sample(s, cubeMapLookup(v.worldPos, viewVec, float3(0,0,0), float3(1,1,1)));
    //float schlick = 0.05 + 0.95 * pow(max(0.0, 1.0-dot(normalize(v.viewVec), normalize(v.viewNormal))), 5.0);
    //return c * (1.0-schlick) + c2 * schlick;
    //return c2;
    return c+c4;
}

vertex irradiance_vertex_out irradiance_vert(vertex_in v [[stage_in]], constant irradiance_uniform_t &uniform [[buffer(1)]]) {
    irradiance_vertex_out out;
    out.localPos = v.position;
    out.normal = normalize(uniform.view * uniform.model * float4(v.normal, 0.0)).xyz;
    out.position = uniform.projection * uniform.view * uniform.model * float4(v.position, 1.0);
    return out;
}

fragment half4 irradiance_frag(irradiance_vertex_out v [[stage_in]], texturecube<half> cubeMap [[texture(0)]],
                               constant irradiance_uniform_t &uniform [[buffer(1)]]) {
    half4 c2 = irradiance_filter(cubeMap, v.localPos);
    return c2;
}

vertex pmrem_vertex_out pmrem_vert(vertex_in v [[stage_in]], constant irradiance_uniform_t &uniform [[buffer(1)]]) {
    pmrem_vertex_out out;
    out.localPos = v.position;
    out.normal = normalize(uniform.view * uniform.model * float4(v.normal, 0.0)).xyz;
    float4 viewPos = uniform.view * uniform.model * float4(v.position, 1.0);
    out.position = uniform.projection * viewPos;
    out.viewVector = -viewPos.xyz / viewPos.w;
    out.uv = v.uv;
    return out;
}

float3 GetNormal(uint face, float2 uv)
{
    float2 debiased = uv * 2.0f - 1.0f;
    
    float3 dir = 0;
    
    switch (face)
    {
        case 0: dir = float3(1, -debiased.y, -debiased.x);
            break;
            
        case 1: dir = float3(-1, -debiased.y, debiased.x);
            break;
            
        case 2: dir = float3(debiased.x, 1, debiased.y);
            break;
            
        case 3: dir = float3(debiased.x, -1, -debiased.y);
            break;
            
        case 4: dir = float3(debiased.x, -debiased.y, 1);
            break;
            
        case 5: dir = float3(-debiased.x, -debiased.y, -1); 
            break;
    };
    
    return normalize(dir);
}

fragment half4 pmrem_frag(pmrem_vertex_out v [[stage_in]], texturecube<half> cubeMap [[texture(0)]],
                               constant irradiance_uniform_t &uniform [[buffer(1)]], constant cubemap_rendertarget_info_t &rt [[buffer(2)]]) {
    int mipLevel = rt.mipLevel;
    int cubeFace = rt.cubeFace;
    float3 normal = GetNormal(cubeFace, v.uv);
    float  roughness = saturate(mipLevel / 6.0f); // Mip level is in [0, 6] range and roughness is [0, 1]
    return half4(half3(PrefilterEnvMap(roughness, normal, cubeMap)), 1.0);
}

vertex lut_vertex_out lut_vert(vertex_in v [[stage_in]]) {
    lut_vertex_out out;
    out.position = float4(v.position.x, v.position.z, 0.0, 1.0);
    out.uv = v.uv;
    return out;
}

fragment float4 lut_frag(pmrem_vertex_out v [[stage_in]]) {
    float2 uv = 0.025 + v.uv * 0.975;
    return float4(IntegrateBRDF(uv.x, uv.y), 0, 1);
}
