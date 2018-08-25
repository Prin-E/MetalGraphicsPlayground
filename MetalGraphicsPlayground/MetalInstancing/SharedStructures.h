//
//  SharedStructures.h
//  MetalGraphics
//
//  Created by 이현우 on 2017. 7. 6..
//  Copyright © 2017년 Prin_E. All rights reserved.
//

#ifndef SharedStructures_h
#define SharedStructures_h

#import <simd/simd.h>

typedef struct {
    vector_float3 pos[1600];
    vector_float3 scale[1600];
} instance_buffer_t;

#endif /* SharedStructures_h */
