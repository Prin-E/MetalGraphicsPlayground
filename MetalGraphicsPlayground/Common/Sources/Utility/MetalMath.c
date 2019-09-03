//
//  MetalMath.c
//  MetalGraphics
//
//  Created by 이현우 on 2016. 6. 19..
//  Copyright © 2016년 Prin_E. All rights reserved.
//

#include "MetalMath.h"

matrix_float4x4 matrix_from_perspective_fov_aspectLH(const float fovY, const float aspect, const float nearZ, const float farZ)
{
    float yscale = 1.0f / tanf(fovY * 0.5f); // 1 / tan == cot
    float xscale = yscale / aspect;
    float q = farZ / (farZ - nearZ);
    
    matrix_float4x4 m = {
        .columns[0] = { xscale, 0.0f, 0.0f, 0.0f },
        .columns[1] = { 0.0f, yscale, 0.0f, 0.0f },
        .columns[2] = { 0.0f, 0.0f, q, 1.0f },
        .columns[3] = { 0.0f, 0.0f, q * -nearZ, 0.0f }
    };
    
    return m;
}

matrix_float4x4 matrix_from_translation(float x, float y, float z)
{
    matrix_float4x4 m = matrix_identity_float4x4;
    m.columns[3] = (vector_float4) { x, y, z, 1.0 };
    return m;
}

matrix_float4x4 matrix_ortho(float left, float right, float bottom, float top, float near, float far) {
    matrix_float4x4 matrix;
    matrix.columns[0] = vector4(2 / (right - left), 0.0f, 0.0f, 0.0f);
    matrix.columns[1] = vector4(0.0f, 2 / (top - bottom), 0.0f, 0.0f);
    matrix.columns[2] = vector4(0.0f, 0.0f, 2 / (far - near), 0.0f);
    matrix.columns[3] = vector4(-(right + left) / (right - left),
                                -(top + bottom) / (top - bottom),
                                -(near) / (far - near), 1.0f);
    return matrix;
}

matrix_float4x4 matrix_from_rotation(float radians, float x, float y, float z)
{
    vector_float3 v = vector_normalize(((vector_float3){x, y, z}));
    float cos = cosf(radians);
    float cosp = 1.0f - cos;
    float sin = sinf(radians);
    
    matrix_float4x4 m = {
        .columns[0] = {
            cos + cosp * v.x * v.x,
            cosp * v.x * v.y + v.z * sin,
            cosp * v.x * v.z - v.y * sin,
            0.0f,
        },
        
        .columns[1] = {
            cosp * v.x * v.y - v.z * sin,
            cos + cosp * v.y * v.y,
            cosp * v.y * v.z + v.x * sin,
            0.0f,
        },
        
        .columns[2] = {
            cosp * v.x * v.z + v.y * sin,
            cosp * v.y * v.z - v.x * sin,
            cos + cosp * v.z * v.z,
            0.0f,
        },
        
        .columns[3] = { 0.0f, 0.0f, 0.0f, 1.0f
        }
    };
    return m;
}

matrix_float4x4 matrix_from_euler(vector_float3 euler) {
    // M = Mz * My * Mx (right to left)
    simd_float4 euler_f4 = simd_make_float4(euler, 0.0f);
    simd_float4 s = _simd_sin_f4(euler_f4);
    simd_float4 c = _simd_cos_f4(euler_f4);
    matrix_float4x4 matrix = matrix_identity_float4x4;
    matrix.columns[0] = simd_make_float4(c.y*c.z, c.y*s.z, -s.y, 0.0);
    matrix.columns[1] = simd_make_float4(s.x*s.y*c.z-c.x*s.z, s.x*s.y*s.z+c.x*c.z, s.x*c.y, 0.0);
    matrix.columns[2] = simd_make_float4(c.x*s.y*c.z+s.x*s.z, c.x*s.y*s.z-s.x*c.z, c.x*c.y, 0.0);
    matrix.columns[3] = simd_make_float4(0, 0, 0, 1);
    return matrix;
}

matrix_float4x4 matrix_lookat(vector_float3 eye,
                            vector_float3 center,
                            vector_float3 up)
{
    vector_float3 zAxis = vector_normalize(center - eye);
    vector_float3 xAxis = vector_normalize(vector_cross(up, zAxis));
    vector_float3 yAxis = vector_cross(zAxis, xAxis);
    
    vector_float4 P;
    vector_float4 Q;
    vector_float4 R;
    vector_float4 S;
    
    P.x = xAxis.x;
    P.y = yAxis.x;
    P.z = zAxis.x;
    P.w = 0.0f;
    
    Q.x = xAxis.y;
    Q.y = yAxis.y;
    Q.z = zAxis.y;
    Q.w = 0.0f;
    
    R.x = xAxis.z;
    R.y = yAxis.z;
    R.z = zAxis.z;
    R.w = 0.0f;
    
    S.x = -vector_dot(xAxis, eye);
    S.y = -vector_dot(yAxis, eye);
    S.z = -vector_dot(zAxis, eye);
    S.w =  1.0f;
    
    return matrix_from_columns(P, Q, R, S);
} // lookAt

void matrix_decompose_trs(simd_float4x4 matrix, simd_float3 *pos, simd_float3 *rot, simd_float3 *scale) {
    simd_float3 s = simd_make_float3(1, 1, 1);
    
    // pos
    if(pos) {
        *pos = matrix.columns[3].xyz;
    }
    
    // scale
    if(scale) {
        s = simd_make_float3(simd_length(matrix.columns[0].xyz),
                             simd_length(matrix.columns[1].xyz),
                             simd_length(matrix.columns[2].xyz));
        *scale = s;
    }
    
    // rotation
    // https://nghiaho.com/?page_id=846
    if(rot) {
        float m00 = matrix.columns[0].x;
        float m01 = matrix.columns[0].y;
        float m02 = matrix.columns[0].z;
        float m12 = matrix.columns[1].z;
        float m22 = matrix.columns[2].z;
        
        // if scale is 0, euler angles can't be decomposed :-(
        size_t isScaleXNotZero = fabsf(s.x) >= 1e10f;
        size_t isScaleZNotZero = fabsf(s.z) >= 1e10f;
        rot->x = isScaleZNotZero ? atan2f(m12, m22) : 0.0f;
        rot->y = isScaleZNotZero ? atan2f(-m02, sqrtf(m12*m12 + m22*m22)) : 0.0f;
        rot->z = isScaleXNotZero ? atan2f(m01, m00) : 0.0f;
    }
}
