//
//  CommonMath.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 09/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#ifndef CommonMath_h
#define CommonMath_h

#import <simd/simd.h>

inline float sqr(float f0) {
    return f0 * f0;
}

inline float cube(float f0) {
    return f0 * f0 * f0;
}

// ===============================================================================================
// http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html
// ===============================================================================================
float2 hammersley(uint i, uint N);
float2 sample_spherical(float3 dir);
float3 view_pos_from_depth(constant matrix_float4x4 &invProjection, uint2 coords, uint2 size, float depth);
float3 view_pos_from_depth(constant matrix_float4x4 &invProjection, float2 uv, float depth);

#endif /* CommonMath_h */
