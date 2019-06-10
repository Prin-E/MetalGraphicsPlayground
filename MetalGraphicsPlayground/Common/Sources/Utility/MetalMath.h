//
//  MetalMath.h
//  MetalGraphics
//
//  Created by 이현우 on 2016. 6. 19..
//  Copyright © 2016년 Prin_E. All rights reserved.
//

#ifndef MetalMath_h
#define MetalMath_h

#include <simd/simd.h>

#ifdef __cplusplus
extern "C" {
#endif
matrix_float4x4 matrix_from_perspective_fov_aspectLH(const float fovY, const float aspect, const float nearZ, const float farZ);
matrix_float4x4 matrix_from_translation(float x, float y, float z);
matrix_float4x4 matrix_ortho(float left, float right, float bottom, float top, float near, float far);
matrix_float4x4 matrix_from_rotation(float radians, float x, float y, float z);
matrix_float4x4 matrix_lookat(vector_float3 eye,
                              vector_float3 center,
                              vector_float3 up);
#ifdef __cplusplus
}
#endif
#endif /* MetalMath_h */
