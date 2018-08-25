//
//  SharedStructures.h
//  MetalTest
//
//  Created by 이현우 on 2015. 8. 8..
//  Copyright (c) 2015년 Prin_E. All rights reserved.
//

#ifndef SharedStructures_h
#define SharedStructures_h

#include <simd/simd.h>

typedef struct __attribute__((__aligned__(256)))
{
    matrix_float4x4 modelview_projection_matrix;
    matrix_float4x4 normal_matrix;
    float time;
    int a;
} uniforms_t;

#endif /* SharedStructures_h */

