//
//  BRDF.metal
//  MetalGraphics
//
//  Created by 이현우 on 2017. 2. 8..
//  Copyright © 2017년 Prin_E. All rights reserved.
//

#include "BRDF.h"

constexpr sampler s(coord::normalized,
                    address::clamp_to_edge,
                    filter::linear,
                    min_filter::linear,
                    mag_filter::linear,
                    mip_filter::linear);

constant float PI = 3.14159265;
constant float PI_2 = 6.2831853072;

// ===============================================================================================
// http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html
// ===============================================================================================
float2 hammersley(uint i, uint N)
{
    // 2.3283064365386963e-10 = 0.5 / 0x10000000
    float ri = reverse_bits(i) * 2.3283064365386963e-10;
    return float2(float(i) / float(N), ri);
}

half4 irradiance_filter(texturecube<half> cubeMap, float3 normal)
{
    float3 up = float3(0, 1, 0);
    float3 right = normalize(cross(up,normal));
    up = cross(normal,right);
    
    float3 sumColor = float3(0, 0, 0);
    float index = 0;
    
    // hammersley point sampling
    for(uint i = 0, N = 1024; i < N; i++) {
        float2 Xi = hammersley(i, N);
        
        float phi = PI_2 * Xi.x;
        float theta = Xi.y * PI * 0.5;
        
        float3 temp = cos(phi) * right + sin(phi) * up;
        float3 sampleVector = cos(theta) * normal + sin(theta) * temp;
        sumColor += float3(cubeMap.sample(s, sampleVector).rgb) * cos(theta) * sin(theta);
        index++;
    }
    
    return half4(half3(3.14159 * sumColor / index), 1.0);
}

// ===============================================================================================
// http://graphicrants.blogspot.com.au/2013/08/specular-brdf-reference.html
// ===============================================================================================
float GGX(float NdotV, float a)
{
    float k = a / 2;
    return NdotV / (NdotV * (1.0f - k) + k);
}

// ===============================================================================================
// Geometry Term
// -----------------------------------------------------------------------------------------------
// Defines the shadowing from the microfacets.
//
// Smith approximation:
// http://blog.selfshadow.com/publications/s2013-shading-course/rad/s2013_pbs_rad_notes.pdf
// http://graphicrants.blogspot.fr/2013/08/specular-brdf-reference.html
//
// ===============================================================================================
float G_Smith(float a, float nDotV, float nDotL)
{
    return GGX(nDotL, a * a) * GGX(nDotV, a * a);
}

// ================================================================================================
// Fresnel
// ------------------------------------------------------------------------------------------------
// The Fresnel function describes the amount of light that reflects from a mirror surface
// given its index of refraction.
//
// Schlick's approximation:
// http://blog.selfshadow.com/publications/s2013-shading-course/rad/s2013_pbs_rad_notes.pdf
// http://graphicrants.blogspot.fr/2013/08/specular-brdf-reference.html
//
// ================================================================================================
float3 Schlick_Fresnel(float3 f0, float3 h, float3 l)
{
    return f0 + (1.0f - f0) * pow((1.0f - dot(l, h)), 5.0f);
}

// ================================================================================================
// http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf
// ================================================================================================
float3 PrefilterEnvMap(float Roughness, float3 R, texturecube<half> cubeMap)
{
    float TotalWeight = 0.0000001f;
    
    float3 N = R;
    float3 V = R;
    float3 PrefilteredColor = 0;
    
    const uint NumSamples = 512;
    
    for (uint i = 0; i < NumSamples; i++)
    {
        float2 Xi = hammersley(i, NumSamples);
        float3 H = ImportanceSampleGGX(Xi, Roughness, N);
        float3 L = 2 * dot(V, H) * H - V;
        float NoL = saturate(dot(N, L));
        
        if (NoL > 0)
        {
            PrefilteredColor += float3(cubeMap.sample(s, L).rgb) * NoL;
            TotalWeight += NoL;
        }
    }
    
    return PrefilteredColor / TotalWeight;
}

// ===============================================================================================
// http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf
// ===============================================================================================
float3 ImportanceSampleGGX(float2 Xi, float Roughness, float3 N)
{
    float a = Roughness * Roughness; // DISNEY'S ROUGHNESS [see Burley'12 siggraph]
    
    float Phi = PI_2 * Xi.x;
    float CosTheta = sqrt((1 - Xi.y) / (1 + (a * a - 1) * Xi.y));
    float SinTheta = sqrt(1 - CosTheta * CosTheta);
    
    float3 H;
    H.x = SinTheta * cos(Phi);
    H.y = SinTheta * sin(Phi);
    H.z = CosTheta;
    
    float3 UpVector = abs(N.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
    float3 TangentX = normalize(cross(UpVector, N));
    float3 TangentY = cross(N, TangentX);
    
    // Tangent to world space
    return TangentX * H.x + TangentY * H.y + N * H.z;
}

//=================================================================================================
// http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf
// ================================================================================================
float2 IntegrateBRDF(float Roughness, float NoV)
{
    float3 V;
    
    V.x = sqrt(1.0f - NoV * NoV);	// Sin
    V.y = 0;
    V.z = NoV;						// Cos
    
    float A = 0;
    float B = 0;
    
    float3 N = float3(0.0f, 0.0f, 1.0f);
    
    const uint NumSamples = 64;
    
    for (uint i = 0; i < NumSamples; i++)
    {
        float2 Xi = hammersley(i, NumSamples);
        float3 H = ImportanceSampleGGX(Xi, Roughness, N);
        float3 L = 2.0f * dot(V, H) * H - V;
        
        float NoL = saturate(L.z);
        float NoH = saturate(H.z);
        float VoH = saturate(dot(V, H));
        
        if (NoL > 0)
        {
            float G = G_Smith(Roughness, NoV, NoL);
            
            float G_Vis = G * VoH / (NoH * NoV);
            float Fc = pow(1 - VoH, 5);
            A += (1 - Fc) * G_Vis;
            B += Fc * G_Vis;
        }
    }
    
    return float2(A, B) / NumSamples;
}

// ================================================================================================
// Split sum approximation of indirect specular lighting using a pre-filtered mip-mapped
// radiance environment map and BRDF integration map.
// ================================================================================================
half3 ApproximateSpecularIBL(half3 specularAlbedo, float3 reflectDir, float nDotV, float Roughness,
                              texturecube<half> PMREM, texture2d<float> LUT)
{
    // Mip level is in [0, 6] range and roughness is [0, 1].
    float mipIndex = Roughness * 6;
    
    half3 prefilteredColor = PMREM.sample(s, reflectDir, level(mipIndex)).xyz;
    float3 environmentBRDF  = LUT.sample(s, float2(Roughness, nDotV)).xyz;
    
    return half3(prefilteredColor * (specularAlbedo * environmentBRDF.x + environmentBRDF.y));
}
