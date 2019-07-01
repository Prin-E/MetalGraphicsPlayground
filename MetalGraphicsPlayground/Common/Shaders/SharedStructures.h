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
    matrix_float4x4 viewProjection;
    matrix_float4x4 rotation;
    vector_float3 position;
} camera_props_t;

typedef struct {
    vector_float3 albedo;
    float roughness;
    float metalic;
    float anisotropy;
} material_t;

typedef struct __attribute__((__aligned__(256))) {
    matrix_float4x4 model;
    matrix_float4x4 modelView;
    material_t material;
} instance_props_t;

typedef struct __attribute__((__aligned__(64))) {
    vector_float3 position;
    vector_float3 direction;
    vector_float3 color;
    float intensity;
} light_t;

typedef struct __attribute__((__aligned__(256))) {
    unsigned int num_light;
} light_global_t;

typedef struct __attribute__((__aligned__(256))) {
    float roughness;
} prefiltered_specular_option_t;

typedef struct __attribute__((__aligned__(256))) {
    uint32_t num_samples;
    float intensity;
    float radius;
    float bias;
} ssao_props_t;

typedef enum {
    attachment_albedo,
    attachment_normal,
    attachment_pos,
    attachment_shading,
    attachment_tangent,
    attachment_irradiance,
    attachment_prefiltered_specular,
    attachment_brdf_lookup,
    attachment_ssao
} attachment_index;

typedef enum {
    fcv_albedo,
    fcv_normal,
    fcv_roughness,
    fcv_metalic,
    fcv_occlusion,
    fcv_anisotropic
} function_constant_values;

// vertex attribute
typedef enum {
    attrib_pos,
    attrib_uv,
    attrib_normal,
    attrib_tangent,
    attrib_bitangent
} attribute_index;

// texture index
typedef enum {
    tex_albedo,
    tex_normal,
    tex_roughness,
    tex_metalic,
    tex_occlusion,
    tex_anisotropic,
    tex_total
} texture_index;

#endif /* SharedStructures_h */
