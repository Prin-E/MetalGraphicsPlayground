//
//  MGPMesh.h
//  MetalTextureLOD
//
//  Created by 이현우 on 04/05/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../Utility/MGPTextureLoader.h"
@import ModelIO;
@import Metal;
@import MetalKit;

NS_ASSUME_NONNULL_BEGIN

@protocol MGPBoundingVolume;
@interface MGPSubmesh : NSObject

@property (readonly) MTKSubmesh *metalKitSubmesh;
@property (readonly, nonnull) NSMutableArray *textures;
@property (nonatomic, readonly) id<MGPBoundingVolume> volume;

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


- (instancetype)initWithModelIOMesh: (MDLMesh *)mdlMesh
            modelIOVertexDescriptor: (nonnull MDLVertexDescriptor *)descriptor
                      textureLoader: (MGPTextureLoader *)textureLoader
                             device: (id<MTLDevice>)device
                   calculateNormals: (BOOL)calculateNormals
                              error: (NSError **)error;

+ (id<MTLBuffer>)createQuadVerticesBuffer: (id<MTLDevice>)device;
+ (id<MTLBuffer>)createSkyboxVerticesBuffer: (id<MTLDevice>)device;

@property (readonly) MTKMesh *metalKitMesh;
@property (readonly, nonnull) NSArray<MGPSubmesh *> *submeshes;
@property (readonly, nonatomic) id<MGPBoundingVolume> volume;

@end

NS_ASSUME_NONNULL_END
