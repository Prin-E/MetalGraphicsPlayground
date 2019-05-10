//
//  MGPMesh.h
//  MetalTextureLOD
//
//  Created by 이현우 on 04/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
@import ModelIO;
@import Metal;
@import MetalKit;

NS_ASSUME_NONNULL_BEGIN

@interface MGPSubmesh : NSObject

@property (readonly) MTKSubmesh *metalKitSubmesh;
@property (readonly, nonnull) NSArray<id<MTLTexture>> *textures;


@end

@interface MGPMesh : NSObject

+ (NSArray<MGPMesh*>*)loadMeshesFromURL: (NSURL *)url
                modelIOVertexDescriptor: (MDLVertexDescriptor *)descriptor
                                 device: (id<MTLDevice>)device
                                  error: (NSError * __nullable * __nullable)error;


+ (NSArray<MGPMesh*>*)loadMeshesFromModelIOObject: (MDLObject *)object
                          modelIOVertexDescriptor: (nonnull MDLVertexDescriptor *)descriptor
                                           device: (id<MTLDevice>)device
                                            error: (NSError **)error;

+ (id<MTLBuffer> _Nonnull)newQuadVerticesBuffer: (id<MTLDevice>)device;
+ (id<MTLBuffer> _Nonnull)newSkyboxVerticesBuffer: (id<MTLDevice>)device;

@property (readonly) MTKMesh *metalKitMesh;
@property (readonly, nonnull) NSArray<MGPSubmesh *> *submeshes;

@end

NS_ASSUME_NONNULL_END
