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
                         queue:(id<MTLCommandQueue>)queue;

@property (nonatomic, strong) id<MTLTexture> environmentEquirectangularMap;    // Input
@property (readonly) id<MTLTexture> irradianceEquirectangularMap;   // Irradiance
@property (readonly) id<MTLTexture> specularEquirectangularMap;     // Specular
@property (readonly) id<MTLTexture> integrationLookupTexture;       // LUT

- (void)renderIrradianceMap:(id<MTLCommandBuffer>)buffer;
- (void)renderSpecularLightingMap:(id<MTLCommandBuffer>)buffer;

@end

NS_ASSUME_NONNULL_END
