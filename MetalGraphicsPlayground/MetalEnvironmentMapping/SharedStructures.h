//
//  SharedStructures.h
//  MetalGraphics
//
//  Created by 이현우 on 2016. 12. 20..
//  Copyright © 2016년 Prin_E. All rights reserved.
//

#ifndef SharedStructures_h
#define SharedStructures_h

#import <simd/simd.h>

typedef struct __attribute__((__aligned__(256)))
{
    matrix_float4x4 model;
    matrix_float4x4 view;
    matrix_float4x4 projection;
    matrix_float4x4 modelviewInverse;
} uniform_t;

typedef struct __attribute__((__aligned__(256)))
{
    matrix_float4x4 model;
    matrix_float4x4 view;
    matrix_float4x4 projection;
} irradiance_uniform_t;

typedef struct __attribute__((__aligned__(256)))
{
    int cubeFace;
    int mipLevel;
} cubemap_rendertarget_info_t;

typedef struct __attribute__((__aligned__(256)))
{
    float time;
    float roughness;
    float metalic;
    vector_float4 albedo;
} app_info_t;

#endif /* SharedStructures_h */
