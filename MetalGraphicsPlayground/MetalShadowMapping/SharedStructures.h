//
//  SharedStructures.h
//  MetalGraphics
//
//  Created by 이현우 on 2015. 12. 6..
//  Copyright © 2015년 Prin_E. All rights reserved.
//

#ifndef SharedStructures_h
#define SharedStructures_h

#import <simd/simd.h>

typedef struct __attribute__((__aligned__(256)))
{
    matrix_float4x4 modelview;
    matrix_float4x4 projection;
    matrix_float4x4 light;
    
    float roughness;
    float metalic;
} uniform_t;

#endif /* SharedStructures_h */
