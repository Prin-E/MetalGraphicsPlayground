//
//  Lighting.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 2019/10/02.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#ifndef Lighting_h
#define Lighting_h

#include "SharedStructures.h"
#include "LightingCommon.h"
#include "BRDF.h"

void fill_shading_params_for_light(thread shading_t &shading_params,
                                   constant light_t &light,
                                   float3 l,
                                   float3 v,
                                   float3 n,
                                   float3 t,
                                   float3 b);

float3 calculate_lit_color(float3 view_pos,
                           float3 view_normal,
                           float3 view_tangent,
                           half4 shading_values,
                           constant camera_props_t &camera_props,
                           constant light_global_t &light_global,
                           constant light_t *lights,
                           uint4 light_cull_cell,
                           array<texture2d<float>,MAX_NUM_DIRECTIONAL_LIGHTS> shadow_maps);


#endif /* Lighting_h */
