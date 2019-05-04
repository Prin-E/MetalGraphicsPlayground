//
//  SharedStructures.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 02/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#ifndef SharedStructures_h
#define SharedStructures_h

#include <simd/simd.h>

typedef struct __attribute__((__aligned__(256))) {
    matrix_float4x4 view;
    matrix_float4x4 projection;
} camera_props_t;

typedef struct {
    float roughness;
    float metalic;
} material_t;

typedef struct __attribute__((__aligned__(256))) {
    matrix_float4x4 model;
    material_t material;
} instance_props_t;

typedef enum {
    attachment_albedo,
    attachment_normal,
    attachment_pos,
    attachment_shading
} attachment_index;

typedef enum {
    fcv_albedo,
    fcv_normal,
    fcv_roughness,
    fcv_metalic
} function_constant_values;

// vertex attribute
typedef enum {
    attrib_pos,
    attrib_uv,
    attrib_normal,
    attrib_tangent
} attribute_index;

// texture index
typedef enum {
    tex_albedo,
    tex_normal,
    tex_roughness,
    tex_metalic,
    tex_total
} texture_index;

#endif /* SharedStructures_h */