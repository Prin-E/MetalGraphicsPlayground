//
//  DDSTextureLoader.h
//  MetalGraphicsPlayground
//
//  Created by 이현우 on 11/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

// Original source from DirectXTK - https://github.com/microsoft/DirectXTex/
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

#include <stdint.h>
#include <Metal/Metal.h>

#ifdef __cplusplus
extern "C" {
#endif
    
extern NSString * const DDSTextureErrorDomain;
    
typedef enum _DDS_ALPHA_MODE
{
    DDS_ALPHA_MODE_UNKNOWN       = 0,
    DDS_ALPHA_MODE_STRAIGHT      = 1,
    DDS_ALPHA_MODE_PREMULTIPLIED = 2,
    DDS_ALPHA_MODE_OPAQUE        = 3,
    DDS_ALPHA_MODE_CUSTOM        = 4,
} DDS_ALPHA_MODE;

BOOL CreateDDSTextureFromMemory(id<MTLDevice> device,
                                const uint8_t* ddsData,
                                size_t ddsDataSize,
                                size_t maxsize,
                                MTLTextureUsage usage,
                                MTLStorageMode storageMode,
                                bool forceSRGB,
                                id<MTLTexture>* texture,
                                DDS_ALPHA_MODE* alphaMode,
                                NSError** error);

BOOL CreateDDSTextureFromFile(id<MTLDevice> device,
                              const NSString* szFileName,
                              size_t maxsize,
                              MTLTextureUsage usage,
                              MTLStorageMode storageMode,
                              bool forceSRGB,
                              id<MTLTexture>* texture,
                              DDS_ALPHA_MODE* alphaMode,
                              NSError** error);

#ifdef __cplusplus
}
#endif
