//
//  MGPTextureLoader.h
//  MetalPostProcessing
//
//  Created by 이현우 on 11/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import <Foundation/Foundation.h>
@import Metal;

NS_ASSUME_NONNULL_BEGIN

@interface MGPTextureLoader : NSObject

@property (readonly, nonatomic) id<MTLDevice> device;

- (instancetype)initWithDevice: (id<MTLDevice>)device;

- (id<MTLTexture>)newTextureWithName: (NSString *)name
                               usage: (MTLTextureUsage)textureUsage
                         storageMode: (MTLStorageMode)storageMode
                               error: (NSError **)error;

- (id<MTLTexture>)newTextureFromPath: (NSString *)filePath
                               usage: (MTLTextureUsage)textureUsage
                         storageMode: (MTLStorageMode)storageMode
                               error: (NSError **)error;

- (id<MTLTexture>)newTextureFromURL: (NSURL *)url
                              usage: (MTLTextureUsage)textureUsage
                        storageMode: (MTLStorageMode)storageMode
                              error: (NSError **)error;

@end

NS_ASSUME_NONNULL_END
