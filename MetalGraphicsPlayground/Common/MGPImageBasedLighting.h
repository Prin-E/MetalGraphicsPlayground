//
//  MGPImageBasedLighting.h
//  MetalDeferred
//
//  Created by 이현우 on 09/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

@import Metal;

NS_ASSUME_NONNULL_BEGIN

@interface MGPImageBasedLighting : NSObject

- (instancetype)initWithDevice:(id<MTLDevice>)device
                       library:(id<MTLLibrary>)library
            equirectangularMap:(id<MTLTexture>)equirectangularMap;

// cubemaps
@property (readonly) id<MTLTexture> environmentMap;
@property (readonly) id<MTLTexture> irradianceMap;
@property (readonly) id<MTLTexture> prefilteredSpecularMap;

// LUT
@property (readonly) id<MTLTexture> BRDFLookupTexture;

- (BOOL)isAnyRenderingRequired;
- (BOOL)isEnvironmentMapRenderingRequired;
- (BOOL)isIrradianceMapRenderingRequired;
- (BOOL)isSpecularMapRenderingRequired;
- (BOOL)isLookupTextureRenderingRequired;

- (void)render:(id<MTLCommandBuffer>)buffer;
- (void)renderEnvironmentMap:(id<MTLCommandBuffer>)buffer;
- (void)renderIrradianceMap:(id<MTLCommandBuffer>)buffer;
- (void)renderSpecularLightingMap:(id<MTLCommandBuffer>)buffer;
- (void)renderLookupTexture:(id<MTLCommandBuffer>)buffer;

@end

NS_ASSUME_NONNULL_END
