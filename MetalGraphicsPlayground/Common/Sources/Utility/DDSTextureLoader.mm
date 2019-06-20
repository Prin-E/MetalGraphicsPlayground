//--------------------------------------------------------------------------------------
// File: DDSTextureLoader.cpp
//
// Functions for loading a DDS texture and creating a Direct3D runtime resource for it
//
// Note these functions are useful as a light-weight runtime loader for DDS files. For
// a full-featured DDS file reader, writer, and texture processing pipeline see
// the 'Texconv' sample and the 'DirectXTex' library.
//
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
//
// http://go.microsoft.com/fwlink/?LinkId=248926
// http://go.microsoft.com/fwlink/?LinkId=248929
//--------------------------------------------------------------------------------------

#include "DDSTextureLoader.h"

#include <assert.h>
#include <algorithm>
#include <memory>
#include <stdio.h>

using namespace DDS;

//--------------------------------------------------------------------------------------
// Macros
//--------------------------------------------------------------------------------------
#ifndef MAKEFOURCC
    #define MAKEFOURCC(ch0, ch1, ch2, ch3)                              \
                ((uint32_t)(uint8_t)(ch0) | ((uint32_t)(uint8_t)(ch1) << 8) |       \
                ((uint32_t)(uint8_t)(ch2) << 16) | ((uint32_t)(uint8_t)(ch3) << 24 ))
#endif /* defined(MAKEFOURCC) */

//--------------------------------------------------------------------------------------
// DDS file structure definitions
//
// See DDS.h in the 'Texconv' sample and the 'DirectXTex' library
//--------------------------------------------------------------------------------------
#pragma pack(push,1)

const uint32_t DDS_MAGIC = 0x20534444; // "DDS "

struct DDS_PIXELFORMAT
{
    uint32_t    size;
    uint32_t    flags;
    uint32_t    fourCC;
    uint32_t    RGBBitCount;
    uint32_t    RBitMask;
    uint32_t    GBitMask;
    uint32_t    BBitMask;
    uint32_t    ABitMask;
};

#define DDS_FOURCC      0x00000004  // DDPF_FOURCC
#define DDS_RGB         0x00000040  // DDPF_RGB
#define DDS_LUMINANCE   0x00020000  // DDPF_LUMINANCE
#define DDS_ALPHA       0x00000002  // DDPF_ALPHA
#define DDS_BUMPDUDV    0x00080000  // DDPF_BUMPDUDV

#define DDS_HEADER_FLAGS_VOLUME         0x00800000  // DDSD_DEPTH

#define DDS_HEIGHT 0x00000002 // DDSD_HEIGHT
#define DDS_WIDTH  0x00000004 // DDSD_WIDTH

#define DDS_CUBEMAP_POSITIVEX 0x00000600 // DDSCAPS2_CUBEMAP | DDSCAPS2_CUBEMAP_POSITIVEX
#define DDS_CUBEMAP_NEGATIVEX 0x00000a00 // DDSCAPS2_CUBEMAP | DDSCAPS2_CUBEMAP_NEGATIVEX
#define DDS_CUBEMAP_POSITIVEY 0x00001200 // DDSCAPS2_CUBEMAP | DDSCAPS2_CUBEMAP_POSITIVEY
#define DDS_CUBEMAP_NEGATIVEY 0x00002200 // DDSCAPS2_CUBEMAP | DDSCAPS2_CUBEMAP_NEGATIVEY
#define DDS_CUBEMAP_POSITIVEZ 0x00004200 // DDSCAPS2_CUBEMAP | DDSCAPS2_CUBEMAP_POSITIVEZ
#define DDS_CUBEMAP_NEGATIVEZ 0x00008200 // DDSCAPS2_CUBEMAP | DDSCAPS2_CUBEMAP_NEGATIVEZ

#define DDS_CUBEMAP_ALLFACES ( DDS_CUBEMAP_POSITIVEX | DDS_CUBEMAP_NEGATIVEX |\
                               DDS_CUBEMAP_POSITIVEY | DDS_CUBEMAP_NEGATIVEY |\
                               DDS_CUBEMAP_POSITIVEZ | DDS_CUBEMAP_NEGATIVEZ )

#define DDS_CUBEMAP 0x00000200 // DDSCAPS2_CUBEMAP

enum DDS_MISC_FLAGS2
{
    DDS_MISC_FLAGS2_ALPHA_MODE_MASK = 0x7L,
};

struct DDS_HEADER
{
    uint32_t        size;
    uint32_t        flags;
    uint32_t        height;
    uint32_t        width;
    uint32_t        pitchOrLinearSize;
    uint32_t        depth; // only if DDS_HEADER_FLAGS_VOLUME is set in flags
    uint32_t        mipMapCount;
    uint32_t        reserved1[11];
    DDS_PIXELFORMAT ddspf;
    uint32_t        caps;
    uint32_t        caps2;
    uint32_t        caps3;
    uint32_t        caps4;
    uint32_t        reserved2;
};

typedef enum _DXGI_FORMAT {
    DXGI_FORMAT_UNKNOWN,
    DXGI_FORMAT_R32G32B32A32_TYPELESS,
    DXGI_FORMAT_R32G32B32A32_FLOAT,
    DXGI_FORMAT_R32G32B32A32_UINT,
    DXGI_FORMAT_R32G32B32A32_SINT,
    DXGI_FORMAT_R32G32B32_TYPELESS,
    DXGI_FORMAT_R32G32B32_FLOAT,
    DXGI_FORMAT_R32G32B32_UINT,
    DXGI_FORMAT_R32G32B32_SINT,
    DXGI_FORMAT_R16G16B16A16_TYPELESS,
    DXGI_FORMAT_R16G16B16A16_FLOAT,
    DXGI_FORMAT_R16G16B16A16_UNORM,
    DXGI_FORMAT_R16G16B16A16_UINT,
    DXGI_FORMAT_R16G16B16A16_SNORM,
    DXGI_FORMAT_R16G16B16A16_SINT,
    DXGI_FORMAT_R32G32_TYPELESS,
    DXGI_FORMAT_R32G32_FLOAT,
    DXGI_FORMAT_R32G32_UINT,
    DXGI_FORMAT_R32G32_SINT,
    DXGI_FORMAT_R32G8X24_TYPELESS,
    DXGI_FORMAT_D32_FLOAT_S8X24_UINT,
    DXGI_FORMAT_R32_FLOAT_X8X24_TYPELESS,
    DXGI_FORMAT_X32_TYPELESS_G8X24_UINT,
    DXGI_FORMAT_R10G10B10A2_TYPELESS,
    DXGI_FORMAT_R10G10B10A2_UNORM,
    DXGI_FORMAT_R10G10B10A2_UINT,
    DXGI_FORMAT_R11G11B10_FLOAT,
    DXGI_FORMAT_R8G8B8A8_TYPELESS,
    DXGI_FORMAT_R8G8B8A8_UNORM,
    DXGI_FORMAT_R8G8B8A8_UNORM_SRGB,
    DXGI_FORMAT_R8G8B8A8_UINT,
    DXGI_FORMAT_R8G8B8A8_SNORM,
    DXGI_FORMAT_R8G8B8A8_SINT,
    DXGI_FORMAT_R16G16_TYPELESS,
    DXGI_FORMAT_R16G16_FLOAT,
    DXGI_FORMAT_R16G16_UNORM,
    DXGI_FORMAT_R16G16_UINT,
    DXGI_FORMAT_R16G16_SNORM,
    DXGI_FORMAT_R16G16_SINT,
    DXGI_FORMAT_R32_TYPELESS,
    DXGI_FORMAT_D32_FLOAT,
    DXGI_FORMAT_R32_FLOAT,
    DXGI_FORMAT_R32_UINT,
    DXGI_FORMAT_R32_SINT,
    DXGI_FORMAT_R24G8_TYPELESS,
    DXGI_FORMAT_D24_UNORM_S8_UINT,
    DXGI_FORMAT_R24_UNORM_X8_TYPELESS,
    DXGI_FORMAT_X24_TYPELESS_G8_UINT,
    DXGI_FORMAT_R8G8_TYPELESS,
    DXGI_FORMAT_R8G8_UNORM,
    DXGI_FORMAT_R8G8_UINT,
    DXGI_FORMAT_R8G8_SNORM,
    DXGI_FORMAT_R8G8_SINT,
    DXGI_FORMAT_R16_TYPELESS,
    DXGI_FORMAT_R16_FLOAT,
    DXGI_FORMAT_D16_UNORM,
    DXGI_FORMAT_R16_UNORM,
    DXGI_FORMAT_R16_UINT,
    DXGI_FORMAT_R16_SNORM,
    DXGI_FORMAT_R16_SINT,
    DXGI_FORMAT_R8_TYPELESS,
    DXGI_FORMAT_R8_UNORM,
    DXGI_FORMAT_R8_UINT,
    DXGI_FORMAT_R8_SNORM,
    DXGI_FORMAT_R8_SINT,
    DXGI_FORMAT_A8_UNORM,
    DXGI_FORMAT_R1_UNORM,
    DXGI_FORMAT_R9G9B9E5_SHAREDEXP,
    DXGI_FORMAT_R8G8_B8G8_UNORM,
    DXGI_FORMAT_G8R8_G8B8_UNORM,
    DXGI_FORMAT_BC1_TYPELESS,
    DXGI_FORMAT_BC1_UNORM,
    DXGI_FORMAT_BC1_UNORM_SRGB,
    DXGI_FORMAT_BC2_TYPELESS,
    DXGI_FORMAT_BC2_UNORM,
    DXGI_FORMAT_BC2_UNORM_SRGB,
    DXGI_FORMAT_BC3_TYPELESS,
    DXGI_FORMAT_BC3_UNORM,
    DXGI_FORMAT_BC3_UNORM_SRGB,
    DXGI_FORMAT_BC4_TYPELESS,
    DXGI_FORMAT_BC4_UNORM,
    DXGI_FORMAT_BC4_SNORM,
    DXGI_FORMAT_BC5_TYPELESS,
    DXGI_FORMAT_BC5_UNORM,
    DXGI_FORMAT_BC5_SNORM,
    DXGI_FORMAT_B5G6R5_UNORM,
    DXGI_FORMAT_B5G5R5A1_UNORM,
    DXGI_FORMAT_B8G8R8A8_UNORM,
    DXGI_FORMAT_B8G8R8X8_UNORM,
    DXGI_FORMAT_R10G10B10_XR_BIAS_A2_UNORM,
    DXGI_FORMAT_B8G8R8A8_TYPELESS,
    DXGI_FORMAT_B8G8R8A8_UNORM_SRGB,
    DXGI_FORMAT_B8G8R8X8_TYPELESS,
    DXGI_FORMAT_B8G8R8X8_UNORM_SRGB,
    DXGI_FORMAT_BC6H_TYPELESS,
    DXGI_FORMAT_BC6H_UF16,
    DXGI_FORMAT_BC6H_SF16,
    DXGI_FORMAT_BC7_TYPELESS,
    DXGI_FORMAT_BC7_UNORM,
    DXGI_FORMAT_BC7_UNORM_SRGB,
    DXGI_FORMAT_AYUV,
    DXGI_FORMAT_Y410,
    DXGI_FORMAT_Y416,
    DXGI_FORMAT_NV12,
    DXGI_FORMAT_P010,
    DXGI_FORMAT_P016,
    DXGI_FORMAT_420_OPAQUE,
    DXGI_FORMAT_YUY2,
    DXGI_FORMAT_Y210,
    DXGI_FORMAT_Y216,
    DXGI_FORMAT_NV11,
    DXGI_FORMAT_AI44,
    DXGI_FORMAT_IA44,
    DXGI_FORMAT_P8,
    DXGI_FORMAT_A8P8,
    DXGI_FORMAT_B4G4R4A4_UNORM,
    DXGI_FORMAT_P208,
    DXGI_FORMAT_V208,
    DXGI_FORMAT_V408,
    DXGI_FORMAT_FORCE_UINT
} DXGI_FORMAT;

typedef enum _D3D10_RESOURCE_DIMENSION {
    D3D10_RESOURCE_DIMENSION_UNKNOWN,
    D3D10_RESOURCE_DIMENSION_BUFFER,
    D3D10_RESOURCE_DIMENSION_TEXTURE1D,
    D3D10_RESOURCE_DIMENSION_TEXTURE2D,
    D3D10_RESOURCE_DIMENSION_TEXTURE3D
} D3D10_RESOURCE_DIMENSION;

struct DDS_HEADER_DXT10
{
    DXGI_FORMAT                 pixelFormat;
    D3D10_RESOURCE_DIMENSION    resourceDimension;
    uint32_t                    miscFlag; // see D3D11_RESOURCE_MISC_FLAG
    uint32_t                    arraySize;
    uint32_t                    miscFlags2;
};

#pragma pack(pop)

//--------------------------------------------------------------------------------------
namespace
{
    //--------------------------------------------------------------------------------------
    BOOL LoadTextureDataFromMemory(
        const uint8_t* ddsData,
        size_t ddsDataSize,
        const DDS_HEADER** header,
        const uint8_t** bitData,
        size_t* bitSize)
    {
        if (!header || !bitData || !bitSize)
        {
            return NO;
        }

        if (ddsDataSize > UINT32_MAX)
        {
            return NO;
        }

        if (ddsDataSize < (sizeof(uint32_t) + sizeof(DDS_HEADER)))
        {
            return NO;
        }

        // DDS files always start with the same magic number ("DDS ")
        auto dwMagicNumber = *reinterpret_cast<const uint32_t*>(ddsData);
        if (dwMagicNumber != DDS_MAGIC)
        {
            return NO;
        }

        auto hdr = reinterpret_cast<const DDS_HEADER*>(ddsData + sizeof(uint32_t));

        // Verify header to validate DDS file
        if (hdr->size != sizeof(DDS_HEADER) ||
            hdr->ddspf.size != sizeof(DDS_PIXELFORMAT))
        {
            return NO;
        }

        // Check for DX10 extension
        bool bDXT10Header = false;
        if ((hdr->ddspf.flags & DDS_FOURCC) &&
            (MAKEFOURCC('D', 'X', '1', '0') == hdr->ddspf.fourCC))
        {
            // Must be long enough for both headers and magic value
            if (ddsDataSize < (sizeof(DDS_HEADER) + sizeof(uint32_t) + sizeof(DDS_HEADER_DXT10)))
            {
                return NO;
            }

            bDXT10Header = true;
        }

        // setup the pointers in the process request
        *header = hdr;
        ptrdiff_t offset = sizeof(uint32_t)
            + sizeof(DDS_HEADER)
            + (bDXT10Header ? sizeof(DDS_HEADER_DXT10) : 0);
        *bitData = ddsData + offset;
        *bitSize = ddsDataSize - offset;

        return YES;
    }

    BOOL LoadTextureDataFromFile(const char *filePath, std::unique_ptr<uint8_t[]>& ddsData, const DDS_HEADER** header, const uint8_t** bitData, size_t* bitSize)
    {
        if (!header || !bitData || !bitSize)
        {
            return NO;
        }
        
        // open the file
        FILE *file = fopen(filePath, "r");
        if (!file)
        {
            return NO;
        }

        // Get the file size
        fseek(file, 0, SEEK_END);
        size_t fileSize = ftell(file);
        fseek(file, 0, SEEK_SET);
        
        // File is too big for 32-bit allocation, so reject read
        if(fileSize > 0xffffffff)
            return NO;
        
        // Need at least enough data to fill the header and magic number to be a valid DDS
        if (fileSize < (sizeof(uint32_t) + sizeof(DDS_HEADER)))
        {
            return NO;
        }

        // create enough space for the file data
        uint8_t *ddsDataBuffer = new (std::nothrow) uint8_t[fileSize];
        ddsData.reset(ddsDataBuffer);
        if (!ddsData)
        {
            return NO;
        }

        // read the data in
        size_t BytesRead = fread(ddsDataBuffer, 1, fileSize, file);
        if (BytesRead < fileSize)
        {
            return NO;
        }
        fclose(file);

        // DDS files always start with the same magic number ("DDS ")
        auto dwMagicNumber = *reinterpret_cast<const uint32_t*>(ddsData.get());
        if (dwMagicNumber != DDS_MAGIC)
        {
            return NO;
        }

        auto hdr = reinterpret_cast<const DDS_HEADER*>(ddsData.get() + sizeof(uint32_t));

        // Verify header to validate DDS file
        if (hdr->size != sizeof(DDS_HEADER) ||
            hdr->ddspf.size != sizeof(DDS_PIXELFORMAT))
        {
            return NO;
        }

        // Check for DX10 extension
        bool bDXT10Header = false;
        if ((hdr->ddspf.flags & DDS_FOURCC) &&
            (MAKEFOURCC('D', 'X', '1', '0') == hdr->ddspf.fourCC))
        {
            // Must be long enough for both headers and magic value
            if (fileSize < (sizeof(DDS_HEADER) + sizeof(uint32_t) + sizeof(DDS_HEADER_DXT10)))
            {
                return NO;
            }

            bDXT10Header = true;
        }

        // setup the pointers in the process request
        *header = hdr;
        ptrdiff_t offset = sizeof(uint32_t) + sizeof(DDS_HEADER)
            + (bDXT10Header ? sizeof(DDS_HEADER_DXT10) : 0);
        *bitData = ddsDataBuffer + offset;
        *bitSize = fileSize - offset;

        return YES;
    }


    //--------------------------------------------------------------------------------------
    // Return the BPP for a particular format
    //--------------------------------------------------------------------------------------
    size_t BitsPerPixel(MTLPixelFormat fmt)
    {
        switch (fmt)
        {
            case MTLPixelFormatRGBA32Sint:
            case MTLPixelFormatRGBA32Uint:
            case MTLPixelFormatRGBA32Float:
            return 128;
                
            case MTLPixelFormatRGBA16Sint:
            case MTLPixelFormatRGBA16Uint:
            case MTLPixelFormatRGBA16Float:
            case MTLPixelFormatRGBA16Snorm:
            case MTLPixelFormatRGBA16Unorm:
            case MTLPixelFormatRG32Float:
            case MTLPixelFormatRG32Uint:
            case MTLPixelFormatRG32Sint:
                return 64;

            case MTLPixelFormatR32Uint:
            case MTLPixelFormatR32Sint:
            case MTLPixelFormatR32Float:
            case MTLPixelFormatRG16Unorm:
            case MTLPixelFormatRG16Snorm:
            case MTLPixelFormatRG16Uint:
            case MTLPixelFormatRG16Sint:
            case MTLPixelFormatRG16Float:
            case MTLPixelFormatRGBA8Unorm:
            case MTLPixelFormatRGBA8Unorm_sRGB:
            case MTLPixelFormatRGBA8Snorm:
            case MTLPixelFormatRGBA8Uint:
            case MTLPixelFormatRGBA8Sint:
            case MTLPixelFormatBGRA8Unorm:
            case MTLPixelFormatBGRA8Unorm_sRGB:
            case MTLPixelFormatRGB10A2Unorm:
            case MTLPixelFormatRGB10A2Uint:
            case MTLPixelFormatRG11B10Float:
            case MTLPixelFormatRGB9E5Float:
            return 32;
                
            case MTLPixelFormatR16Unorm:
            case MTLPixelFormatR16Snorm:
            case MTLPixelFormatR16Uint:
            case MTLPixelFormatR16Sint:
            case MTLPixelFormatR16Float:
            case MTLPixelFormatRG8Unorm:
            case MTLPixelFormatRG8Snorm:
            case MTLPixelFormatRG8Uint:
            case MTLPixelFormatRG8Sint:
                return 16;
                
            case MTLPixelFormatA8Unorm:
            case MTLPixelFormatR8Unorm:
            case MTLPixelFormatR8Snorm:
            case MTLPixelFormatR8Uint:
            case MTLPixelFormatR8Sint:
                return 8;
        default:
            return 0;
        }
    }


    //--------------------------------------------------------------------------------------
    // Get surface information for a particular format
    //--------------------------------------------------------------------------------------
    BOOL GetSurfaceInfo(
        size_t width,
        size_t height,
        MTLPixelFormat fmt,
        size_t* outNumBytes,
        size_t* outRowBytes,
        size_t* outNumRows)
    {
        uint64_t numBytes = 0;
        uint64_t rowBytes = 0;
        uint64_t numRows = 0;

        bool bc = false;
        bool packed = false;
        bool planar = false;
        size_t bpe = 0;
        switch (fmt)
        {
                /*
        case DXGI_FORMAT_BC1_TYPELESS:
        case DXGI_FORMAT_BC1_UNORM:
        case DXGI_FORMAT_BC1_UNORM_SRGB:
        case DXGI_FORMAT_BC4_TYPELESS:
        case DXGI_FORMAT_BC4_UNORM:
        case DXGI_FORMAT_BC4_SNORM:
            bc = true;
            bpe = 8;
            break;

        case DXGI_FORMAT_BC2_TYPELESS:
        case DXGI_FORMAT_BC2_UNORM:
        case DXGI_FORMAT_BC2_UNORM_SRGB:
        case DXGI_FORMAT_BC3_TYPELESS:
        case DXGI_FORMAT_BC3_UNORM:
        case DXGI_FORMAT_BC3_UNORM_SRGB:
        case DXGI_FORMAT_BC5_TYPELESS:
        case DXGI_FORMAT_BC5_UNORM:
        case DXGI_FORMAT_BC5_SNORM:
        case DXGI_FORMAT_BC6H_TYPELESS:
        case DXGI_FORMAT_BC6H_UF16:
        case DXGI_FORMAT_BC6H_SF16:
        case DXGI_FORMAT_BC7_TYPELESS:
        case DXGI_FORMAT_BC7_UNORM:
        case DXGI_FORMAT_BC7_UNORM_SRGB:
            bc = true;
            bpe = 16;
            break;

        case DXGI_FORMAT_R8G8_B8G8_UNORM:
        case DXGI_FORMAT_G8R8_G8B8_UNORM:
        case DXGI_FORMAT_YUY2:
            packed = true;
            bpe = 4;
            break;

        case DXGI_FORMAT_Y210:
        case DXGI_FORMAT_Y216:
            packed = true;
            bpe = 8;
            break;

        case DXGI_FORMAT_NV12:
        case DXGI_FORMAT_420_OPAQUE:
            planar = true;
            bpe = 2;
            break;

        case DXGI_FORMAT_P010:
        case DXGI_FORMAT_P016:
            planar = true;
            bpe = 4;
            break;
                */
        default:
            break;
        }

        if (bc)
        {
            uint64_t numBlocksWide = 0;
            if (width > 0)
            {
                numBlocksWide = std::max<uint64_t>(1u, (uint64_t(width) + 3u) / 4u);
            }
            uint64_t numBlocksHigh = 0;
            if (height > 0)
            {
                numBlocksHigh = std::max<uint64_t>(1u, (uint64_t(height) + 3u) / 4u);
            }
            rowBytes = numBlocksWide * bpe;
            numRows = numBlocksHigh;
            numBytes = rowBytes * numBlocksHigh;
        }
        else if (packed)
        {
            rowBytes = ((uint64_t(width) + 1u) >> 1) * bpe;
            numRows = uint64_t(height);
            numBytes = rowBytes * height;
        }
        /*
        else if (fmt == DXGI_FORMAT_NV11)
        {
            rowBytes = ((uint64_t(width) + 3u) >> 2) * 4u;
            numRows = uint64_t(height) * 2u; // Direct3D makes this simplifying assumption, although it is larger than the 4:1:1 data
            numBytes = rowBytes * numRows;
        }*/
        else if (planar)
        {
            rowBytes = ((uint64_t(width) + 1u) >> 1) * bpe;
            numBytes = (rowBytes * uint64_t(height)) + ((rowBytes * uint64_t(height) + 1u) >> 1);
            numRows = height + ((uint64_t(height) + 1u) >> 1);
        }
        else
        {
            size_t bpp = BitsPerPixel(fmt);
            if (!bpp)
                return false;

            rowBytes = (uint64_t(width) * bpp + 7u) / 8u; // round up to nearest byte
            numRows = uint64_t(height);
            numBytes = rowBytes * height;
        }

        static_assert(sizeof(size_t) == 8, "Not a 64-bit platform!");
        
        if (outNumBytes)
        {
            *outNumBytes = static_cast<size_t>(numBytes);
        }
        if (outRowBytes)
        {
            *outRowBytes = static_cast<size_t>(rowBytes);
        }
        if (outNumRows)
        {
            *outNumRows = static_cast<size_t>(numRows);
        }

        return true;
    }


    //--------------------------------------------------------------------------------------
    #define ISBITMASK( r,g,b,a ) ( ddpf.RBitMask == r && ddpf.GBitMask == g && ddpf.BBitMask == b && ddpf.ABitMask == a )

    MTLPixelFormat GetDXGIFormat(const DDS_PIXELFORMAT& ddpf)
    {
        if (ddpf.flags & DDS_RGB)
        {
            // Note that sRGB formats are written using the "DX10" extended header

            switch (ddpf.RGBBitCount)
            {
            case 32:
                if (ISBITMASK(0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000))
                {
                    return MTLPixelFormatRGBA8Unorm;
                }

                if (ISBITMASK(0x00ff0000, 0x0000ff00, 0x000000ff, 0xff000000))
                {
                    return MTLPixelFormatBGRA8Unorm;
                }

                if (ISBITMASK(0x00ff0000, 0x0000ff00, 0x000000ff, 0x00000000))
                {
                    return MTLPixelFormatBGRA8Unorm;
                }

                // No DXGI format maps to ISBITMASK(0x000000ff,0x0000ff00,0x00ff0000,0x00000000) aka D3DFMT_X8B8G8R8

                // Note that many common DDS reader/writers (including D3DX) swap the
                // the RED/BLUE masks for 10:10:10:2 formats. We assume
                // below that the 'backwards' header mask is being used since it is most
                // likely written by D3DX. The more robust solution is to use the 'DX10'
                // header extension and specify the DXGI_FORMAT_R10G10B10A2_UNORM format directly

                // For 'correct' writers, this should be 0x000003ff,0x000ffc00,0x3ff00000 for RGB data
                if (ISBITMASK(0x3ff00000, 0x000ffc00, 0x000003ff, 0xc0000000))
                {
                    return MTLPixelFormatRGB10A2Unorm;
                }

                // No DXGI format maps to ISBITMASK(0x000003ff,0x000ffc00,0x3ff00000,0xc0000000) aka D3DFMT_A2R10G10B10

                if (ISBITMASK(0x0000ffff, 0xffff0000, 0x00000000, 0x00000000))
                {
                    return MTLPixelFormatRG16Unorm;
                }

                if (ISBITMASK(0xffffffff, 0x00000000, 0x00000000, 0x00000000))
                {
                    // Only 32-bit color channel format in D3D9 was R32F
                    return MTLPixelFormatR32Float; // D3DX writes this out as a FourCC of 114
                }
                break;

            case 24:
                // No 24bpp DXGI formats aka D3DFMT_R8G8B8
                break;

            case 16:
                // No 16bpp Metal pixel formats
                break;
            }
        }
        else if (ddpf.flags & DDS_LUMINANCE)
        {
            if (8 == ddpf.RGBBitCount)
            {
                if (ISBITMASK(0x000000ff, 0x00000000, 0x00000000, 0x00000000))
                {
                    return MTLPixelFormatR8Unorm; // D3DX10/11 writes this out as DX10 extension
                }

                // No DXGI format maps to ISBITMASK(0x0f,0x00,0x00,0xf0) aka D3DFMT_A4L4

                if (ISBITMASK(0x000000ff, 0x00000000, 0x00000000, 0x0000ff00))
                {
                    return MTLPixelFormatRG8Unorm; // Some DDS writers assume the bitcount should be 8 instead of 16
                }
            }

            if (16 == ddpf.RGBBitCount)
            {
                if (ISBITMASK(0x0000ffff, 0x00000000, 0x00000000, 0x00000000))
                {
                    return MTLPixelFormatR16Unorm; // D3DX10/11 writes this out as DX10 extension
                }
                if (ISBITMASK(0x000000ff, 0x00000000, 0x00000000, 0x0000ff00))
                {
                    return MTLPixelFormatRG8Unorm; // D3DX10/11 writes this out as DX10 extension
                }
            }
        }
        else if (ddpf.flags & DDS_ALPHA)
        {
            if (8 == ddpf.RGBBitCount)
            {
                return MTLPixelFormatA8Unorm;
            }
        }
        else if (ddpf.flags & DDS_BUMPDUDV)
        {
            if (16 == ddpf.RGBBitCount)
            {
                if (ISBITMASK(0x00ff, 0xff00, 0x0000, 0x0000))
                {
                    return MTLPixelFormatRG8Snorm; // D3DX10/11 writes this out as DX10 extension
                }
            }

            if (32 == ddpf.RGBBitCount)
            {
                if (ISBITMASK(0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000))
                {
                    return MTLPixelFormatRGBA8Snorm; // D3DX10/11 writes this out as DX10 extension
                }
                if (ISBITMASK(0x0000ffff, 0xffff0000, 0x00000000, 0x00000000))
                {
                    return MTLPixelFormatRG16Snorm; // D3DX10/11 writes this out as DX10 extension
                }

                // No DXGI format maps to ISBITMASK(0x3ff00000, 0x000ffc00, 0x000003ff, 0xc0000000) aka D3DFMT_A2W10V10U10
            }
        }
        else if (ddpf.flags & DDS_FOURCC)
        {
            if (MAKEFOURCC('D', 'X', 'T', '1') == ddpf.fourCC)
            {
                return MTLPixelFormatBC1_RGBA;
            }
            if (MAKEFOURCC('D', 'X', 'T', '3') == ddpf.fourCC)
            {
                return MTLPixelFormatBC2_RGBA;
            }
            if (MAKEFOURCC('D', 'X', 'T', '5') == ddpf.fourCC)
            {
                return MTLPixelFormatBC1_RGBA;
            }

            // While pre-multiplied alpha isn't directly supported by the DXGI formats,
            // they are basically the same as these BC formats so they can be mapped
            if (MAKEFOURCC('D', 'X', 'T', '2') == ddpf.fourCC)
            {
                return MTLPixelFormatBC2_RGBA;
            }
            if (MAKEFOURCC('D', 'X', 'T', '4') == ddpf.fourCC)
            {
                return MTLPixelFormatBC2_RGBA;
            }

            if (MAKEFOURCC('A', 'T', 'I', '1') == ddpf.fourCC)
            {
                return MTLPixelFormatBC4_RUnorm;
            }
            if (MAKEFOURCC('B', 'C', '4', 'U') == ddpf.fourCC)
            {
                return MTLPixelFormatBC4_RUnorm;
            }
            if (MAKEFOURCC('B', 'C', '4', 'S') == ddpf.fourCC)
            {
                return MTLPixelFormatBC4_RSnorm;
            }

            if (MAKEFOURCC('A', 'T', 'I', '2') == ddpf.fourCC)
            {
                return MTLPixelFormatBC5_RGUnorm;
            }
            if (MAKEFOURCC('B', 'C', '5', 'U') == ddpf.fourCC)
            {
                return MTLPixelFormatBC5_RGUnorm;
            }
            if (MAKEFOURCC('B', 'C', '5', 'S') == ddpf.fourCC)
            {
                return MTLPixelFormatBC5_RGSnorm;
            }

            // BC6H and BC7 are written using the "DX10" extended header
            /*
            if (MAKEFOURCC('R', 'G', 'B', 'G') == ddpf.fourCC)
            {
                return DXGI_FORMAT_R8G8_B8G8_UNORM;
            }
            if (MAKEFOURCC('G', 'R', 'G', 'B') == ddpf.fourCC)
            {
                return DXGI_FORMAT_G8R8_G8B8_UNORM;
            }

            if (MAKEFOURCC('Y', 'U', 'Y', '2') == ddpf.fourCC)
            {
                return DXGI_FORMAT_YUY2;
            }
             */

            // Check for D3DFORMAT enums being set here
            switch (ddpf.fourCC)
            {
                case 36: // D3DFMT_A16B16G16R16
                    return MTLPixelFormatRGBA16Unorm;
                    
                case 110: // D3DFMT_Q16W16V16U16
                    return MTLPixelFormatRGBA16Snorm;
                    
                case 111: // D3DFMT_R16F
                    return MTLPixelFormatR16Float;
                    
                case 112: // D3DFMT_G16R16F
                    return MTLPixelFormatRG16Float;
                    
                case 113: // D3DFMT_A16B16G16R16F
                    return MTLPixelFormatRGBA16Float;
                    
                case 114: // D3DFMT_R32F
                    return MTLPixelFormatR32Float;
                    
                case 115: // D3DFMT_G32R32F
                    return MTLPixelFormatRG32Float;
                    
                case 116: // D3DFMT_A32B32G32R32F
                    return MTLPixelFormatRGBA32Float;
            }
        }

        return MTLPixelFormatInvalid;
    }


    //--------------------------------------------------------------------------------------
    MTLPixelFormat MakeSRGB(MTLPixelFormat format)
    {
        switch (format)
        {
            case MTLPixelFormatRGBA8Unorm:
                return MTLPixelFormatRGBA8Unorm_sRGB;
                
            case MTLPixelFormatBGRA8Unorm:
                return MTLPixelFormatBGRA8Unorm_sRGB;
                
            case MTLPixelFormatBC1_RGBA:
                return MTLPixelFormatBC1_RGBA_sRGB;
                
            case MTLPixelFormatBC2_RGBA:
                return MTLPixelFormatBC2_RGBA_sRGB;
                
            case MTLPixelFormatBC3_RGBA:
                return MTLPixelFormatBC3_RGBA_sRGB;
                
            case MTLPixelFormatBC7_RGBAUnorm:
                return MTLPixelFormatBC7_RGBAUnorm_sRGB;

            default:
                return format;
        }
    }

    MTLPixelFormat GetMetalPixelFormatFromDXGIFormat(DXGI_FORMAT format) {
        switch(format) {
                
            case DXGI_FORMAT_R32G32B32A32_FLOAT:
                return MTLPixelFormatRGBA32Float;
            case DXGI_FORMAT_R32G32B32A32_UINT:
                return MTLPixelFormatRGBA32Uint;
            case DXGI_FORMAT_R32G32B32A32_SINT:
                return MTLPixelFormatRGBA32Sint;
            case DXGI_FORMAT_R16G16B16A16_FLOAT:
                return MTLPixelFormatRGBA16Float;
            case DXGI_FORMAT_R16G16B16A16_UNORM:
                return MTLPixelFormatRGBA16Unorm;
            case DXGI_FORMAT_R16G16B16A16_UINT:
                return MTLPixelFormatRGBA16Uint;
            case DXGI_FORMAT_R16G16B16A16_SNORM:
                return MTLPixelFormatRGBA16Snorm;
            case DXGI_FORMAT_R16G16B16A16_SINT:
                return MTLPixelFormatRGBA16Sint;
                
            case DXGI_FORMAT_R32G32_FLOAT:
                return MTLPixelFormatRG32Float;
            case DXGI_FORMAT_R32G32_UINT:
                return MTLPixelFormatRG32Uint;
            case DXGI_FORMAT_R32G32_SINT:
                return MTLPixelFormatRG32Sint;
                
            case DXGI_FORMAT_R10G10B10A2_UNORM:
                return MTLPixelFormatRGB10A2Unorm;
            case DXGI_FORMAT_R10G10B10A2_UINT:
                return MTLPixelFormatRGB10A2Uint;
            case DXGI_FORMAT_R11G11B10_FLOAT:
                return MTLPixelFormatRG11B10Float;
                
            case DXGI_FORMAT_R8G8B8A8_UNORM:
                return MTLPixelFormatRGBA8Unorm;
            case DXGI_FORMAT_R8G8B8A8_UNORM_SRGB:
                return MTLPixelFormatRGBA8Unorm_sRGB;
            case DXGI_FORMAT_R8G8B8A8_SNORM:
                return MTLPixelFormatRGBA8Snorm;
            case DXGI_FORMAT_R8G8B8A8_SINT:
                return MTLPixelFormatRGBA8Sint;
                
            case DXGI_FORMAT_R16G16_FLOAT:
                return MTLPixelFormatRG16Float;
            case DXGI_FORMAT_R16G16_UNORM:
                return MTLPixelFormatRG16Unorm;
            case DXGI_FORMAT_R16G16_UINT:
                return MTLPixelFormatRG16Uint;
            case DXGI_FORMAT_R16G16_SNORM:
                return MTLPixelFormatRG16Snorm;
            case DXGI_FORMAT_R16G16_SINT:
                return MTLPixelFormatRG16Sint;
                
            case DXGI_FORMAT_D32_FLOAT:
                return MTLPixelFormatDepth32Float;
            case DXGI_FORMAT_R32_FLOAT:
                return MTLPixelFormatR32Float;
            case DXGI_FORMAT_R32_UINT:
                return MTLPixelFormatR32Uint;
            case DXGI_FORMAT_R32_SINT:
                return MTLPixelFormatR32Sint;
                
            case DXGI_FORMAT_D24_UNORM_S8_UINT:
                return MTLPixelFormatDepth24Unorm_Stencil8;
            case DXGI_FORMAT_R8G8_UNORM:
                return MTLPixelFormatRG8Unorm;
            case DXGI_FORMAT_R8G8_UINT:
                return MTLPixelFormatRG8Uint;
            case DXGI_FORMAT_R8G8_SNORM:
                return MTLPixelFormatRG8Snorm;
            case DXGI_FORMAT_R8G8_SINT:
                return MTLPixelFormatRG8Sint;
                
                
            case DXGI_FORMAT_R16_FLOAT:
                return MTLPixelFormatR16Float;
            case DXGI_FORMAT_D16_UNORM:
                return MTLPixelFormatDepth16Unorm;
            case DXGI_FORMAT_R16_UNORM:
                return MTLPixelFormatR16Unorm;
            case DXGI_FORMAT_R16_UINT:
                return MTLPixelFormatR16Uint;
            case DXGI_FORMAT_R16_SNORM:
                return MTLPixelFormatR16Snorm;
            case DXGI_FORMAT_R16_SINT:
                return MTLPixelFormatR16Sint;
                
            case DXGI_FORMAT_R8_UNORM:
                return MTLPixelFormatR8Unorm;
            case DXGI_FORMAT_R8_UINT:
                return MTLPixelFormatR8Uint;
            case DXGI_FORMAT_R8_SNORM:
                return MTLPixelFormatR8Snorm;
            case DXGI_FORMAT_R8_SINT:
                return MTLPixelFormatR8Sint;
                
            case DXGI_FORMAT_A8_UNORM:
                return MTLPixelFormatA8Unorm;
                
            case DXGI_FORMAT_BC1_UNORM:
                return MTLPixelFormatBC1_RGBA;
            case DXGI_FORMAT_BC1_UNORM_SRGB:
                return MTLPixelFormatBC1_RGBA_sRGB;
            case DXGI_FORMAT_BC2_UNORM:
                return MTLPixelFormatBC2_RGBA;
            case DXGI_FORMAT_BC2_UNORM_SRGB:
                return MTLPixelFormatBC2_RGBA_sRGB;
                
                
            case DXGI_FORMAT_BC3_UNORM:
                return MTLPixelFormatBC3_RGBA;
            case DXGI_FORMAT_BC3_UNORM_SRGB:
                return MTLPixelFormatBC3_RGBA_sRGB;
            case DXGI_FORMAT_BC4_UNORM:
                return MTLPixelFormatBC4_RUnorm;
            case DXGI_FORMAT_BC4_SNORM:
                return MTLPixelFormatBC4_RSnorm;
            case DXGI_FORMAT_BC5_UNORM:
                return MTLPixelFormatBC5_RGUnorm;
            case DXGI_FORMAT_BC5_SNORM:
                return MTLPixelFormatBC5_RGSnorm;
            case DXGI_FORMAT_B8G8R8A8_UNORM:
                return MTLPixelFormatBGRA8Unorm;
            case DXGI_FORMAT_B8G8R8A8_UNORM_SRGB:
                return MTLPixelFormatBGRA8Unorm_sRGB;
            case DXGI_FORMAT_BC6H_UF16:
                return MTLPixelFormatBC6H_RGBUfloat;
            case DXGI_FORMAT_BC6H_SF16:
                return MTLPixelFormatBC6H_RGBFloat;
                
            case DXGI_FORMAT_BC7_UNORM:
                return MTLPixelFormatBC7_RGBAUnorm;
            case DXGI_FORMAT_BC7_UNORM_SRGB:
                return MTLPixelFormatBC7_RGBAUnorm_sRGB;
                
            default:
                return MTLPixelFormatInvalid;
        }
    }
    

    //--------------------------------------------------------------------------------------
    BOOL FillInitData(
        size_t width,
        size_t height,
        size_t depth,
        size_t mipCount,
        size_t arraySize,
        MTLPixelFormat format,
        size_t maxsize,
        size_t bitSize,
        const uint8_t* bitData,
        size_t& twidth,
        size_t& theight,
        size_t& tdepth,
        size_t& skipMip,
        D3D11_SUBRESOURCE_DATA* initData)
    {
        if (!bitData || !initData)
        {
            return E_POINTER;
        }

        skipMip = 0;
        twidth = 0;
        theight = 0;
        tdepth = 0;

        size_t NumBytes = 0;
        size_t RowBytes = 0;
        const uint8_t* pSrcBits = bitData;
        const uint8_t* pEndBits = bitData + bitSize;

        size_t index = 0;
        for (size_t j = 0; j < arraySize; j++)
        {
            size_t w = width;
            size_t h = height;
            size_t d = depth;
            for (size_t i = 0; i < mipCount; i++)
            {
                BOOL flag = GetSurfaceInfo(w, h, format, &NumBytes, &RowBytes, nullptr);
                if(!flag)
                    return false;

                if (NumBytes > UINT32_MAX || RowBytes > UINT32_MAX)
                    return false;

                if ((mipCount <= 1) || !maxsize || (w <= maxsize && h <= maxsize && d <= maxsize))
                {
                    if (!twidth)
                    {
                        twidth = w;
                        theight = h;
                        tdepth = d;
                    }

                    assert(index < mipCount * arraySize);
                    _Analysis_assume_(index < mipCount * arraySize);
                    initData[index].pSysMem = (const void*)pSrcBits;
                    initData[index].SysMemPitch = static_cast<UINT>(RowBytes);
                    initData[index].SysMemSlicePitch = static_cast<UINT>(NumBytes);
                    ++index;
                }
                else if (!j)
                {
                    // Count number of skipped mipmaps (first item only)
                    ++skipMip;
                }

                if (pSrcBits + (NumBytes*d) > pEndBits)
                {
                    return HRESULT_FROM_WIN32(ERROR_HANDLE_EOF);
                }

                pSrcBits += NumBytes * d;

                w = w >> 1;
                h = h >> 1;
                d = d >> 1;
                if (w == 0)
                {
                    w = 1;
                }
                if (h == 0)
                {
                    h = 1;
                }
                if (d == 0)
                {
                    d = 1;
                }
            }
        }

        return (index > 0) ? S_OK : E_FAIL;
    }
    
    HRESULT CreateD3DResources(id<MTLDevice> d3dDevice,
                               uint32_t resDim,
                               size_t width,
                               size_t height,
                               size_t depth,
                               size_t mipCount,
                               size_t arraySize,
                               MTLPixelFormat format,
                               MTLTextureUsage usage,
                               MTLStorageMode storageMode,
                               bool forceSRGB,
                               bool isCubeMap,
        _In_reads_opt_(mipCount*arraySize) D3D11_SUBRESOURCE_DATA* initData,
        _Outptr_opt_ ID3D11Resource** texture,
        _Outptr_opt_ ID3D11ShaderResourceView** textureView)
    {
        if (!d3dDevice)
            return E_POINTER;

        HRESULT hr = E_FAIL;

        if (forceSRGB)
        {
            format = MakeSRGB(format);
        }

        switch (resDim)
        {
        case D3D11_RESOURCE_DIMENSION_TEXTURE1D:
        {
            D3D11_TEXTURE1D_DESC desc;
            desc.Width = static_cast<UINT>(width);
            desc.MipLevels = static_cast<UINT>(mipCount);
            desc.ArraySize = static_cast<UINT>(arraySize);
            desc.Format = format;
            desc.Usage = usage;
            desc.BindFlags = bindFlags;
            desc.CPUAccessFlags = cpuAccessFlags;
            desc.MiscFlags = miscFlags & ~D3D11_RESOURCE_MISC_TEXTURECUBE;

            ID3D11Texture1D* tex = nullptr;
            hr = d3dDevice->CreateTexture1D(&desc,
                initData,
                &tex
            );
            if (SUCCEEDED(hr) && tex)
            {
                if (textureView)
                {
                    D3D11_SHADER_RESOURCE_VIEW_DESC SRVDesc = {};
                    SRVDesc.Format = format;

                    if (arraySize > 1)
                    {
                        SRVDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE1DARRAY;
                        SRVDesc.Texture1DArray.MipLevels = (!mipCount) ? -1 : desc.MipLevels;
                        SRVDesc.Texture1DArray.ArraySize = static_cast<UINT>(arraySize);
                    }
                    else
                    {
                        SRVDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE1D;
                        SRVDesc.Texture1D.MipLevels = (!mipCount) ? -1 : desc.MipLevels;
                    }

                    hr = d3dDevice->CreateShaderResourceView(tex,
                        &SRVDesc,
                        textureView
                    );
                    if (FAILED(hr))
                    {
                        tex->Release();
                        return hr;
                    }
                }

                if (texture)
                {
                    *texture = tex;
                }
                else
                {
                    SetDebugObjectName(tex, "DDSTextureLoader");
                    tex->Release();
                }
            }
        }
        break;

        case D3D11_RESOURCE_DIMENSION_TEXTURE2D:
        {
            D3D11_TEXTURE2D_DESC desc;
            desc.Width = static_cast<UINT>(width);
            desc.Height = static_cast<UINT>(height);
            desc.MipLevels = static_cast<UINT>(mipCount);
            desc.ArraySize = static_cast<UINT>(arraySize);
            desc.Format = format;
            desc.SampleDesc.Count = 1;
            desc.SampleDesc.Quality = 0;
            desc.Usage = usage;
            desc.BindFlags = bindFlags;
            desc.CPUAccessFlags = cpuAccessFlags;
            if (isCubeMap)
            {
                desc.MiscFlags = miscFlags | D3D11_RESOURCE_MISC_TEXTURECUBE;
            }
            else
            {
                desc.MiscFlags = miscFlags & ~D3D11_RESOURCE_MISC_TEXTURECUBE;
            }

            ID3D11Texture2D* tex = nullptr;
            hr = d3dDevice->CreateTexture2D(&desc,
                initData,
                &tex
            );
            if (SUCCEEDED(hr) && tex)
            {
                if (textureView)
                {
                    D3D11_SHADER_RESOURCE_VIEW_DESC SRVDesc = {};
                    SRVDesc.Format = format;

                    if (isCubeMap)
                    {
                        if (arraySize > 6)
                        {
                            SRVDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURECUBEARRAY;
                            SRVDesc.TextureCubeArray.MipLevels = (!mipCount) ? -1 : desc.MipLevels;

                            // Earlier we set arraySize to (NumCubes * 6)
                            SRVDesc.TextureCubeArray.NumCubes = static_cast<UINT>(arraySize / 6);
                        }
                        else
                        {
                            SRVDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURECUBE;
                            SRVDesc.TextureCube.MipLevels = (!mipCount) ? -1 : desc.MipLevels;
                        }
                    }
                    else if (arraySize > 1)
                    {
                        SRVDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2DARRAY;
                        SRVDesc.Texture2DArray.MipLevels = (!mipCount) ? -1 : desc.MipLevels;
                        SRVDesc.Texture2DArray.ArraySize = static_cast<UINT>(arraySize);
                    }
                    else
                    {
                        SRVDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
                        SRVDesc.Texture2D.MipLevels = (!mipCount) ? -1 : desc.MipLevels;
                    }

                    hr = d3dDevice->CreateShaderResourceView(tex,
                        &SRVDesc,
                        textureView
                    );
                    if (FAILED(hr))
                    {
                        tex->Release();
                        return hr;
                    }
                }

                if (texture)
                {
                    *texture = tex;
                }
                else
                {
                    SetDebugObjectName(tex, "DDSTextureLoader");
                    tex->Release();
                }
            }
        }
        break;

        case D3D11_RESOURCE_DIMENSION_TEXTURE3D:
        {
            D3D11_TEXTURE3D_DESC desc;
            desc.Width = static_cast<UINT>(width);
            desc.Height = static_cast<UINT>(height);
            desc.Depth = static_cast<UINT>(depth);
            desc.MipLevels = static_cast<UINT>(mipCount);
            desc.Format = format;
            desc.Usage = usage;
            desc.BindFlags = bindFlags;
            desc.CPUAccessFlags = cpuAccessFlags;
            desc.MiscFlags = miscFlags & ~D3D11_RESOURCE_MISC_TEXTURECUBE;

            ID3D11Texture3D* tex = nullptr;
            hr = d3dDevice->CreateTexture3D(&desc,
                initData,
                &tex
            );
            if (SUCCEEDED(hr) && tex)
            {
                if (textureView)
                {
                    D3D11_SHADER_RESOURCE_VIEW_DESC SRVDesc = {};
                    SRVDesc.Format = format;

                    SRVDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE3D;
                    SRVDesc.Texture3D.MipLevels = (!mipCount) ? -1 : desc.MipLevels;

                    hr = d3dDevice->CreateShaderResourceView(tex,
                        &SRVDesc,
                        textureView
                    );
                    if (FAILED(hr))
                    {
                        tex->Release();
                        return hr;
                    }
                }

                if (texture)
                {
                    *texture = tex;
                }
                else
                {
                    SetDebugObjectName(tex, "DDSTextureLoader");
                    tex->Release();
                }
            }
        }
        break;
        }

        return hr;
    }

    //--------------------------------------------------------------------------------------
    BOOL CreateTextureFromDDS(id<MTLDevice> device,
                              const DDS_HEADER* header,
                              const uint8_t* bitData,
                              size_t bitSize,
                              size_t maxsize,
                              MTLTextureUsage usage,
                              MTLStorageMode storageMode
                              bool forceSRGB,
                              id<MTLTexture>* texture)
    {
        uint32_t width = header->width;
        uint32_t height = header->height;
        uint32_t depth = header->depth;
        
        MTLTextureDescriptor descriptor = [[MTLTextureDescriptor alloc] init];
        descriptor.arrayLength = 1;
        descriptor.pixelFormat = MTLPixelFormatInvalid;
        descriptor.mipmapLevelCount = header->mipMapCount;
        bool isCubeMap = false;
        
        if (descriptor.mipmapLevelCount == 0)
            descriptor.mipmapLevelCount = 1;

        if ((header->ddspf.flags & DDS_FOURCC) &&
            (MAKEFOURCC('D', 'X', '1', '0') == header->ddspf.fourCC))
        {
            auto d3d10ext = reinterpret_cast<const DDS_HEADER_DXT10*>((const char*)header + sizeof(DDS_HEADER));

            descriptor.arrayLength = d3d10ext->arraySize;
            if (descriptor.arrayLength == 0)
            {
                return false;
            }
            
            descriptor.pixelFormat = GetMetalPixelFormatFromDXGIFormat(d3d10ext->dxgiFormat);
            if(descriptor.pixelFormat == MTLPixelFormatInvalid)
                return false;
            if(BitsPerPixel(descriptor.pixelFormat) == 0)
                return false;
            
            switch (d3d10ext->resourceDimension)
            {
                case D3D11_RESOURCE_DIMENSION_TEXTURE1D:
                    // D3DX writes 1D textures with a fixed Height of 1
                    if ((header->flags & DDS_HEIGHT) && height != 1)
                    {
                        return false;
                    }
                    height = depth = 1;
                    descriptor.textureType = MTLTextureType1D;
                    if(descriptor.arrayLength > 1)
                        descriptor.textureType = MTLTextureType1DArray;
                    break;
                    
                case D3D11_RESOURCE_DIMENSION_TEXTURE2D:
                    if (d3d10ext->miscFlag & D3D11_RESOURCE_MISC_TEXTURECUBE)
                    {
                        arraySize *= 6;
                        isCubeMap = true;
                        descriptor.textureType = MTLTextureTypeCube;
                        if(descriptor.arrayLength > 1)
                            descriptor.textureType = MTLTextureTypeCubeArray;
                    }
                    else {
                        descriptor.textureType = MTLTextureType2D;
                        if(descriptor.arrayLength > 1)
                            descriptor.textureType = MTLTextureType2DArray;
                    }
                    depth = 1;
                    break;
                    
                case D3D11_RESOURCE_DIMENSION_TEXTURE3D:
                    if (!(header->flags & DDS_HEADER_FLAGS_VOLUME))
                    {
                        return false;
                    }
                    
                    if (arraySize > 1)
                    {
                        return false;
                    }
                    
                    descriptor.textureType = MTLTextureType3D;
                    break;
                    
                default:
                    return false;
            }
        }
        else
        {
            descriptor.pixelFormat = GetDXGIFormat(header->ddspf);

            if (format == MTLPixelFormatInvalid)
                return false;

            if (header->flags & DDS_HEADER_FLAGS_VOLUME)
            {
                descriptor.textureType = MTLTextureType3D;
            }
            else
            {
                if (header->caps2 & DDS_CUBEMAP)
                {
                    // We require all six faces to be defined
                    if ((header->caps2 & DDS_CUBEMAP_ALLFACES) != DDS_CUBEMAP_ALLFACES)
                    {
                        return false;
                    }
                    descriptor.textureType = MTLTextureTypeCube;
                    descriptor.arrayLength = 6;
                    isCubeMap = true;
                }
                else {
                    descriptor.textureType = MTLTextureType2D;
                }
                depth = 1;
                
                // Note there's no way for a legacy Direct3D 9 DDS to express a '1D' texture
            }

            assert(BitsPerPixel(format) != 0);
        }

        // Bound sizes (for security purposes we don't trust DDS file metadata larger than the D3D 11.x hardware requirements)
        if (mipCount > D3D11_REQ_MIP_LEVELS)
        {
            return false;
        }

        switch (resDim)
        {
        case D3D11_RESOURCE_DIMENSION_TEXTURE1D:
            if ((arraySize > D3D11_REQ_TEXTURE1D_ARRAY_AXIS_DIMENSION) ||
                (width > D3D11_REQ_TEXTURE1D_U_DIMENSION))
            {
                return HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED);
            }
            break;

        case D3D11_RESOURCE_DIMENSION_TEXTURE2D:
            if (isCubeMap)
            {
                // This is the right bound because we set arraySize to (NumCubes*6) above
                if ((arraySize > D3D11_REQ_TEXTURE2D_ARRAY_AXIS_DIMENSION) ||
                    (width > D3D11_REQ_TEXTURECUBE_DIMENSION) ||
                    (height > D3D11_REQ_TEXTURECUBE_DIMENSION))
                {
                    return HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED);
                }
            }
            else if ((arraySize > D3D11_REQ_TEXTURE2D_ARRAY_AXIS_DIMENSION) ||
                     (width > D3D11_REQ_TEXTURE2D_U_OR_V_DIMENSION) ||
                     (height > D3D11_REQ_TEXTURE2D_U_OR_V_DIMENSION))
            {
                return HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED);
            }
            break;

        case D3D11_RESOURCE_DIMENSION_TEXTURE3D:
            if ((arraySize > 1) ||
                (width > D3D11_REQ_TEXTURE3D_U_V_OR_W_DIMENSION) ||
                (height > D3D11_REQ_TEXTURE3D_U_V_OR_W_DIMENSION) ||
                (depth > D3D11_REQ_TEXTURE3D_U_V_OR_W_DIMENSION))
            {
                return HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED);
            }
            break;

        default:
            return HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED);
        }

        bool autogen = false;
        if (mipCount == 1 && d3dContext && textureView) // Must have context and shader-view to auto generate mipmaps
        {
            // See if format is supported for auto-gen mipmaps (varies by feature level)
            UINT fmtSupport = 0;
            hr = d3dDevice->CheckFormatSupport(format, &fmtSupport);
            if (SUCCEEDED(hr) && (fmtSupport & D3D11_FORMAT_SUPPORT_MIP_AUTOGEN))
            {
                // 10level9 feature levels do not support auto-gen mipgen for volume textures
                if ((resDim != D3D11_RESOURCE_DIMENSION_TEXTURE3D)
                    || (d3dDevice->GetFeatureLevel() >= D3D_FEATURE_LEVEL_10_0))
                {
                    autogen = true;
                }
            }
        }

        if (autogen)
        {
            // Create texture with auto-generated mipmaps
            ID3D11Resource* tex = nullptr;
            hr = CreateD3DResources(d3dDevice,
                resDim, width, height, depth, 0, arraySize,
                format,
                usage,
                bindFlags | D3D11_BIND_RENDER_TARGET,
                cpuAccessFlags,
                miscFlags | D3D11_RESOURCE_MISC_GENERATE_MIPS,
                forceSRGB,
                isCubeMap,
                nullptr,
                &tex, textureView);
            if (SUCCEEDED(hr))
            {
                size_t numBytes = 0;
                size_t rowBytes = 0;
                hr = GetSurfaceInfo(width, height, format, &numBytes, &rowBytes, nullptr);
                if (FAILED(hr))
                    return hr;

                if (numBytes > bitSize)
                {
                    (*textureView)->Release();
                    *textureView = nullptr;
                    tex->Release();
                    return HRESULT_FROM_WIN32(ERROR_HANDLE_EOF);
                }

                if (numBytes > UINT32_MAX || rowBytes > UINT32_MAX)
                    return HRESULT_FROM_WIN32(ERROR_ARITHMETIC_OVERFLOW);

                D3D11_SHADER_RESOURCE_VIEW_DESC desc;
                (*textureView)->GetDesc(&desc);

                UINT mipLevels = 1;

                switch (desc.ViewDimension)
                {
                case D3D_SRV_DIMENSION_TEXTURE1D:       mipLevels = desc.Texture1D.MipLevels; break;
                case D3D_SRV_DIMENSION_TEXTURE1DARRAY:  mipLevels = desc.Texture1DArray.MipLevels; break;
                case D3D_SRV_DIMENSION_TEXTURE2D:       mipLevels = desc.Texture2D.MipLevels; break;
                case D3D_SRV_DIMENSION_TEXTURE2DARRAY:  mipLevels = desc.Texture2DArray.MipLevels; break;
                case D3D_SRV_DIMENSION_TEXTURECUBE:     mipLevels = desc.TextureCube.MipLevels; break;
                case D3D_SRV_DIMENSION_TEXTURECUBEARRAY:mipLevels = desc.TextureCubeArray.MipLevels; break;
                case D3D_SRV_DIMENSION_TEXTURE3D:       mipLevels = desc.Texture3D.MipLevels; break;
                default:
                    (*textureView)->Release();
                    *textureView = nullptr;
                    tex->Release();
                    return E_UNEXPECTED;
                }

                if (arraySize > 1)
                {
                    const uint8_t* pSrcBits = bitData;
                    const uint8_t* pEndBits = bitData + bitSize;
                    for (UINT item = 0; item < arraySize; ++item)
                    {
                        if ((pSrcBits + numBytes) > pEndBits)
                        {
                            (*textureView)->Release();
                            *textureView = nullptr;
                            tex->Release();
                            return HRESULT_FROM_WIN32(ERROR_HANDLE_EOF);
                        }

                        UINT res = D3D11CalcSubresource(0, item, mipLevels);
                        d3dContext->UpdateSubresource(tex, res, nullptr, pSrcBits, static_cast<UINT>(rowBytes), static_cast<UINT>(numBytes));
                        pSrcBits += numBytes;
                    }
                }
                else
                {
                    d3dContext->UpdateSubresource(tex, 0, nullptr, bitData, static_cast<UINT>(rowBytes), static_cast<UINT>(numBytes));
                }

                d3dContext->GenerateMips(*textureView);

                if (texture)
                {
                    *texture = tex;
                }
                else
                {
                    tex->Release();
                }
            }
        }
        else
        {
            // Create the texture
            std::unique_ptr<D3D11_SUBRESOURCE_DATA[]> initData(new (std::nothrow) D3D11_SUBRESOURCE_DATA[mipCount * arraySize]);
            if (!initData)
            {
                return E_OUTOFMEMORY;
            }

            size_t skipMip = 0;
            size_t twidth = 0;
            size_t theight = 0;
            size_t tdepth = 0;
            hr = FillInitData(width, height, depth, mipCount, arraySize,
                format, maxsize, bitSize, bitData,
                twidth, theight, tdepth, skipMip, initData.get());

            if (SUCCEEDED(hr))
            {
                hr = CreateD3DResources(d3dDevice,
                    resDim, twidth, theight, tdepth, mipCount - skipMip, arraySize,
                    format,
                    usage, bindFlags, cpuAccessFlags, miscFlags,
                    forceSRGB,
                    isCubeMap,
                    initData.get(),
                    texture, textureView);

                if (FAILED(hr) && !maxsize && (mipCount > 1))
                {
                    // Retry with a maxsize determined by feature level
                    switch (d3dDevice->GetFeatureLevel())
                    {
                    case D3D_FEATURE_LEVEL_9_1:
                    case D3D_FEATURE_LEVEL_9_2:
                        if (isCubeMap)
                        {
                            maxsize = 512 /*D3D_FL9_1_REQ_TEXTURECUBE_DIMENSION*/;
                        }
                        else
                        {
                            maxsize = (resDim == D3D11_RESOURCE_DIMENSION_TEXTURE3D)
                                ? 256 /*D3D_FL9_1_REQ_TEXTURE3D_U_V_OR_W_DIMENSION*/
                                : 2048 /*D3D_FL9_1_REQ_TEXTURE2D_U_OR_V_DIMENSION*/;
                        }
                        break;

                    case D3D_FEATURE_LEVEL_9_3:
                        maxsize = (resDim == D3D11_RESOURCE_DIMENSION_TEXTURE3D)
                            ? 256 /*D3D_FL9_1_REQ_TEXTURE3D_U_V_OR_W_DIMENSION*/
                            : 4096 /*D3D_FL9_3_REQ_TEXTURE2D_U_OR_V_DIMENSION*/;
                        break;

                    default: // D3D_FEATURE_LEVEL_10_0 & D3D_FEATURE_LEVEL_10_1
                        maxsize = (resDim == D3D11_RESOURCE_DIMENSION_TEXTURE3D)
                            ? 2048 /*D3D10_REQ_TEXTURE3D_U_V_OR_W_DIMENSION*/
                            : 8192 /*D3D10_REQ_TEXTURE2D_U_OR_V_DIMENSION*/;
                        break;
                    }

                    hr = FillInitData(width, height, depth, mipCount, arraySize, format, maxsize, bitSize, bitData,
                        twidth, theight, tdepth, skipMip, initData.get());
                    if (SUCCEEDED(hr))
                    {
                        hr = CreateD3DResources(d3dDevice,
                            resDim, twidth, theight, tdepth, mipCount - skipMip, arraySize,
                            format,
                            usage, bindFlags, cpuAccessFlags, miscFlags,
                            forceSRGB,
                            isCubeMap,
                            initData.get(),
                            texture, textureView);
                    }
                }
            }
        }

        return hr;
    }


    //--------------------------------------------------------------------------------------
    DDS_ALPHA_MODE GetAlphaMode(const DDS_HEADER* header)
    {
        if (header->ddspf.flags & DDS_FOURCC)
        {
            if (MAKEFOURCC('D', 'X', '1', '0') == header->ddspf.fourCC)
            {
                auto d3d10ext = reinterpret_cast<const DDS_HEADER_DXT10*>((const char*)header + sizeof(DDS_HEADER));
                auto mode = static_cast<DDS_ALPHA_MODE>(d3d10ext->miscFlags2 & DDS_MISC_FLAGS2_ALPHA_MODE_MASK);
                switch (mode)
                {
                case DDS_ALPHA_MODE_STRAIGHT:
                case DDS_ALPHA_MODE_PREMULTIPLIED:
                case DDS_ALPHA_MODE_OPAQUE:
                case DDS_ALPHA_MODE_CUSTOM:
                    return mode;
                }
            }
            else if ((MAKEFOURCC('D', 'X', 'T', '2') == header->ddspf.fourCC)
                || (MAKEFOURCC('D', 'X', 'T', '4') == header->ddspf.fourCC))
            {
                return DDS_ALPHA_MODE_PREMULTIPLIED;
            }
        }

        return DDS_ALPHA_MODE_UNKNOWN;
    }

BOOL CreateDDSTextureFromMemory(id<MTLDevice> device,
                                const uint8_t* ddsData,
                                size_t ddsDataSize,
                                size_t maxsize,
                                MTLTextureUsage usage,
                                MTLStorageMode storageMode,
                                bool forceSRGB,
                                id<MTLTexture>* texture,
                                DDS_ALPHA_MODE* alphaMode = nullptr)
{
    if (texture)
    {
        *texture = nullptr;
    }
    if (textureView)
    {
        *textureView = nullptr;
    }
    if (alphaMode)
    {
        *alphaMode = DDS_ALPHA_MODE_UNKNOWN;
    }

    if (!device || !ddsData || (!texture && !textureView))
    {
        return false;
    }

    // Validate DDS file in memory
    const DDS_HEADER* header = nullptr;
    const uint8_t* bitData = nullptr;
    size_t bitSize = 0;

    BOOL flag = LoadTextureDataFromMemory(ddsData, ddsDataSize, &header, &bitData, &bitSize);
    if (!flag)
        return false;

    flag = CreateTextureFromDDS(device,
                                header, bitData, bitSize,
                                maxsize,
                                usage, storageMode,
                                forceSRGB,
                                texture);
    if (flag)
    {
        texture.label = @"DDSTextureLoader";
        
        if (alphaMode)
            *alphaMode = GetAlphaMode(header);
    }

    return true;
}

BOOL CreateDDSTextureFromFile(id<MTLDevice> device,
                              const NSString* fileName,
                              size_t maxsize,
                              MTLTextureUsage usage,
                              MTLStorageMode storageMode,
                              bool forceSRGB,
                              id<MTLTexture>* texture,
                              DDS_ALPHA_MODE* alphaMode = nullptr)
{
    if (texture)
    {
        *texture = nullptr;
    }
    if (textureView)
    {
        *textureView = nullptr;
    }
    if (alphaMode)
    {
        *alphaMode = DDS_ALPHA_MODE_UNKNOWN;
    }

    if (!device || !fileName || (!texture && !textureView))
    {
        return false;
    }

    const DDS_HEADER* header = nullptr;
    const uint8_t* bitData = nullptr;
    size_t bitSize = 0;

    std::unique_ptr<uint8_t[]> ddsData;
    bool flag = LoadTextureDataFromFile(fileName, ddsData, &header, &bitData, &bitSize);
    if (!flag)
        return false;

    flag = CreateTextureFromDDS(device, header, bitData, bitSize,
                                maxsize, usage, storageMode,
                                forceSRGB, texture, textureView);

    if (flag)
    {
        (*texture).label = [fileName lastPathComponent];
        if (alphaMode)
            *alphaMode = GetAlphaMode(header);
    }

    return true;
}
