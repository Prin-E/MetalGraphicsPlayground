//
//  SharedStructures.h
//  MetalGraphics
//
//  Created by 이현우 on 2016. 6. 19..
//  Copyright © 2016년 Prin_E. All rights reserved.
//

#ifndef SharedStructures_h
#define SharedStructures_h

#import <simd/simd.h>

typedef struct __attribute__((__aligned__(256)))
{
    matrix_float4x4 view;
    matrix_float4x4 projection;
    matrix_float4x4 lightView;
    matrix_float4x4 lightProjection;
    vector_float4 lightPos;
    vector_float4 lightColor;
    float lightIntensity;
} uniform_t;

typedef struct __attribute__((__aligned__(256)))
{
    matrix_float4x4 model;
    vector_float4 albedo;
} transform_t;

typedef struct {
    float x;
    float y;
    float z;
    int next;
} iz_buffer_t;

#endif /* SharedStructures_h */
