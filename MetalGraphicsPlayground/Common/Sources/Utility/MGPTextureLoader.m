//
//  MGPTextureLoader.m
//  MetalPostProcessing
//
//  Created by 이현우 on 11/06/2019.
//  Copyright © 2019 Prin_E. All rights reserved.
//

#import "MGPTextureLoader.h"
#import "DDSTextureLoader.h"
@import MetalKit;

@implementation MGPTextureLoader {
    MTKTextureLoader *_mtkTextureLoader;
    id<MTLCommandQueue> _commandQueue;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if(self) {
        _device = device;
        _commandQueue = [_device newCommandQueueWithMaxCommandBufferCount:1];
        _mtkTextureLoader = [[MTKTextureLoader alloc] initWithDevice: _device];
    }
    return self;
}

- (id<MTLTexture>)newTextureWithName:(NSString *)name
                               usage:(MTLTextureUsage)textureUsage
                         storageMode:(MTLStorageMode)storageMode
                               error:(NSError * _Nullable __autoreleasing *)error {
    if(name.length == 0) {
        *error = [NSError errorWithDomain: NSURLErrorDomain
                                     code: 0
                                 userInfo: nil];
        return nil;
    }
    
    NSMutableDictionary<MTKTextureLoaderOption, id> *options = [NSMutableDictionary dictionaryWithCapacity: 4];
    options[MTKTextureLoaderOptionTextureUsage] = @(textureUsage);
    options[MTKTextureLoaderOptionTextureStorageMode] = @(storageMode);
    return [_mtkTextureLoader newTextureWithName: name
                                     scaleFactor: 1.0f
                                          bundle: nil
                                         options: options
                                           error: error];
}

- (id<MTLTexture>)newTextureFromPath:(NSString *)filePath
                               usage:(MTLTextureUsage)textureUsage
                         storageMode:(MTLStorageMode)storageMode
                               error:(NSError * _Nullable __autoreleasing *)error {
    if(filePath.length == 0) {
        *error = [NSError errorWithDomain: NSURLErrorDomain
                                     code: 0
                                 userInfo: nil];
        return nil;
    }
    NSURL *url = [NSURL fileURLWithPath:filePath];
    return [self newTextureFromURL: url
                             usage: textureUsage
                       storageMode: storageMode
                             error: error];
}

- (id<MTLTexture>)newTextureFromURL:(NSURL *)url
                              usage:(MTLTextureUsage)textureUsage
                        storageMode:(MTLStorageMode)storageMode
                              error:(NSError * _Nullable __autoreleasing *)error {
    if(url.path.length == 0) {
        if(error) {
            *error = [NSError errorWithDomain: NSURLErrorDomain
                                         code: 0
                                     userInfo: nil];
        }
        return nil;
    }
    
    if([url isFileURL] && ![url checkResourceIsReachableAndReturnError: error]) {
        return nil;
    }
    
    NSString *absolutePath = [url path];
    
    if([absolutePath.pathExtension.lowercaseString isEqualToString: @"dds"]) {
        // Because MetalKit texture loader doesn't support DDS file loading,
        // We have to use custom implementation...
        return [self newDDSTextureFromURL: url
                                    usage: textureUsage
                              storageMode: storageMode
                                    error: error];
        
    }
    else {
        // Use default MetalKit texture loader
        NSMutableDictionary<MTKTextureLoaderOption, id> *options = [NSMutableDictionary dictionaryWithCapacity: 4];
        options[MTKTextureLoaderOptionTextureUsage] = @(textureUsage);
        options[MTKTextureLoaderOptionTextureStorageMode] = @(storageMode);
        return [_mtkTextureLoader newTextureWithContentsOfURL: url
                                                      options: options
                                                        error: error];
    }
}

- (id<MTLTexture>)newDDSTextureFromURL:(NSURL *)url
                                 usage:(MTLTextureUsage)textureUsage
                           storageMode:(MTLStorageMode)storageMode
                                 error:(NSError * _Nullable __autoreleasing *)error {
    
    NSString *filePath = url.path;
    
    id<MTLTexture> texture = nil;
    @autoreleasepool {
        DDS_ALPHA_MODE alphaMode = DDS_ALPHA_MODE_UNKNOWN;
        CreateDDSTextureFromFile(self.device,
                                 filePath,
                                 0,
                                 textureUsage,
                                 MTLStorageModeManaged,
                                 false,
                                 &texture,
                                 &alphaMode,
                                 error);
        
        if(storageMode == MTLStorageModePrivate) {
            id<MTLTexture> intermediateTexture = texture;
            MTLTextureDescriptor *desc = [[MTLTextureDescriptor alloc] init];
            desc.textureType = intermediateTexture.textureType;
            desc.width = intermediateTexture.width;
            desc.height = intermediateTexture.height;
            desc.depth = intermediateTexture.depth;
            desc.mipmapLevelCount = intermediateTexture.mipmapLevelCount;
            desc.arrayLength = intermediateTexture.arrayLength;
            desc.pixelFormat = intermediateTexture.pixelFormat;
            desc.sampleCount = intermediateTexture.sampleCount;
            desc.storageMode = storageMode;
            desc.usage = textureUsage;
            texture = [_device newTextureWithDescriptor: desc];
            texture.label = intermediateTexture.label;
            
            id<MTLCommandBuffer> buffer = [_commandQueue commandBufferWithUnretainedReferences];
            id<MTLBlitCommandEncoder> blit = [buffer blitCommandEncoder];
            MTLSize size = MTLSizeMake(texture.width, texture.height, texture.depth);
            for(int level = 0; level < desc.mipmapLevelCount; level++) {
                [blit copyFromTexture: intermediateTexture
                          sourceSlice: 0
                          sourceLevel: level
                         sourceOrigin: MTLOriginMake(0, 0, 0)
                           sourceSize: size
                            toTexture: texture
                     destinationSlice: 0
                     destinationLevel: level
                    destinationOrigin: MTLOriginMake(0, 0, 0)];
                size.width = MAX(1, size.width / 2);
                size.height = MAX(1, size.height / 2);
                size.depth = MAX(1, size.depth / 2);
            }
            
            [blit endEncoding];
            [buffer commit];
            [buffer waitUntilCompleted];
        }
    }
    return texture;
}

@end
