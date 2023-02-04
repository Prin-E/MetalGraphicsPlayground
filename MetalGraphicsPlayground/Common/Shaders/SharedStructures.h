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
    matrix_float4x4 viewInverse;
    matrix_float4x4 projectionInverse;
    matrix_float4x4 viewProjectionInverse;
    vector_float3 position;
    float nearPlane, farPlane;
} camera_props_t;

typedef struct {
    vector_float3 albedo;
    float roughness;
    float metalic;
    float anisotropy;
} material_t;

typedef struct __attribute__((__aligned__(256))) {
    matrix_float4x4 model;
    material_t material;
} instance_props_t;

typedef struct __attribute__((__aligned__(256))) {
    matrix_float4x4 light_view;
    matrix_float4x4 light_view_projection;
    vector_float3 position;
    float intensity;
    vector_float3 color;
    float radius;
    float shadow_bias;
    uint8_t type;       // 0 : directional, 1 : point
    bool cast_shadow;
} light_t;

typedef struct __attribute__((__aligned__(256))) {
    matrix_float4x4 light_projection;
    vector_float3 ambient_color;
    unsigned int num_light;                 // max num : 64 (dir.light : 16)
    unsigned int num_directional_shadowed_light;
    unsigned int first_point_light_index;
    unsigned int tile_size;                 // 16~32
} light_global_t;

typedef struct __attribute__((__aligned__(256))) {
    float roughness;
} prefiltered_specular_option_t;

typedef struct __attribute__((__aligned__(256))) {
    uint32_t num_samples;
    uint32_t downsample;
    float intensity;
    float radius;
    float bias;
} ssao_props_t;

typedef struct __attribute__((__aligned__(256))) {
    uint32_t iteration;
    float step;
    float opacity;
    float attenuation;
    float vignette;
} screen_space_reflection_props_t;

typedef enum {
    gizmo_sphere,
    gizmo_box
} gizmo_type_t;

typedef struct __attribute__((__aligned__(256))) {
    simd_float4x4 model;
    simd_float4 color;
    gizmo_type_t type;
} gizmo_props_t;

// attachment
typedef enum {
    attachment_albedo,
    attachment_normal,
    attachment_shading,
    attachment_tangent,
    attachment_depth,
    attachment_light,
    attachment_irradiance,
    attachment_prefiltered_specular,
    attachment_brdf_lookup,
    attachment_ssao,
    attachment_shadow_map,
    attachment_total
} attachment_index;

// function constant value
typedef enum {
    fcv_albedo,
    fcv_normal,
    fcv_roughness,
    fcv_metalic,
    fcv_occlusion,
    fcv_anisotropic,
    fcv_flip_vertically,
    fcv_srgb_texture,
    fcv_uses_ibl_irradiance_map,
    fcv_uses_ibl_specular_map,
    fcv_uses_ssao_map,
    fcv_light_cull_tile_size,
    fcv_uses_anisotropy
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
    tex_occlusion,
    tex_anisotropic,
    tex_total
} texture_index;

#endif /* SharedStructures_h */
