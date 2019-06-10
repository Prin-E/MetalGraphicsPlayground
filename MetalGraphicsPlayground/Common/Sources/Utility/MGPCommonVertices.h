//
//  MGPCommonVertices.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 09/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#ifndef MGPCommonVertices_h
#define MGPCommonVertices_h

#include <simd/simd.h>

#ifdef __cplusplus
extern "C" {
#endif

static const simd_float3 QuadVertices[] =
{
    { -1.0f, -1.0f, 0.0f },
    { -1.0f, 1.0f, 0.0f },
    { 1.0f, 1.0f, 0.0f },
    { 1.0f, 1.0f, 0.0f },
    { 1.0f, -1.0f, 0.0f },
    { -1.0f, -1.0f, 0.0f }
};

static const simd_float3 SkyboxVertices[] = {
    // +x
    {  1.0f, -1.0f,  1.0f },
    {  1.0f,  1.0f,  1.0f },
    {  1.0f,  1.0f, -1.0f },
    {  1.0f,  1.0f, -1.0f },
    {  1.0f, -1.0f, -1.0f },
    {  1.0f, -1.0f,  1.0f },
    
    // -x
    { -1.0f, -1.0f, -1.0f },
    { -1.0f,  1.0f, -1.0f },
    { -1.0f,  1.0f,  1.0f },
    { -1.0f,  1.0f,  1.0f },
    { -1.0f, -1.0f,  1.0f },
    { -1.0f, -1.0f, -1.0f },
    
    // +y
    { -1.0f,  1.0f,  1.0f },
    { -1.0f,  1.0f, -1.0f },
    {  1.0f,  1.0f, -1.0f },
    {  1.0f,  1.0f, -1.0f },
    {  1.0f,  1.0f,  1.0f },
    { -1.0f,  1.0f,  1.0f },
    
    // -y
    { -1.0f, -1.0f, -1.0f },
    { -1.0f, -1.0f,  1.0f },
    {  1.0f, -1.0f,  1.0f },
    {  1.0f, -1.0f,  1.0f },
    {  1.0f, -1.0f, -1.0f },
    { -1.0f, -1.0f, -1.0f },
    
    // +z
    { -1.0f, -1.0f,  1.0f },
    { -1.0f,  1.0f,  1.0f },
    {  1.0f,  1.0f,  1.0f },
    {  1.0f,  1.0f,  1.0f },
    {  1.0f, -1.0f,  1.0f },
    { -1.0f, -1.0f,  1.0f },
    
    // -z
    {  1.0f, -1.0f, -1.0f },
    {  1.0f,  1.0f, -1.0f },
    { -1.0f,  1.0f, -1.0f },
    { -1.0f,  1.0f, -1.0f },
    { -1.0f, -1.0f, -1.0f },
    {  1.0f, -1.0f, -1.0f }
};

#ifdef __cplusplus
}
#endif

#endif /* MGPCommonVertices_h */
