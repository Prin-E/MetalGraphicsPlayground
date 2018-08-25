//
//  BRDF.h
//  MetalGraphics
//
//  Created by 이현우 on 2017. 2. 8..
//  Copyright © 2017년 Prin_E. All rights reserved.
//

#ifndef BRDF_h
#define BRDF_h

#include <metal_stdlib>
using namespace metal;

// Hammersley point sampling
float2 hammersley(uint i, uint N);

// Irradiance Filter
half4 irradiance_filter(texturecube<half> cubeMap, float3 normal);

// Microfacet Specular BRDF
float GGX(float NdotV, float a);
float G_Smith(float a, float nDotV, float nDotL);
float3 Schlick_Fresnel(float3 f0, float3 h, float3 l);

float3 PrefilterEnvMap(float Roughness, float3 R, texturecube<half> EnvMap);
float3 ImportanceSampleGGX(float2 Xi, float Roughness, float3 N);
float2 IntegrateBRDF(float Roughness, float NoV);
half3 ApproximateSpecularIBL(half3 specularAlbedo, float3 reflectDir, float nDotV, float Roughness,
                             texturecube<half> PMREM, texture2d<float> LUT);

#endif /* BRDF_h */
